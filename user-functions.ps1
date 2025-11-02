# user-functions.ps1
# User management functions for clinical database
# Handles user creation, authentication, and retrieval

#Requires -Version 5.1

# Source dependencies
. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")

# ============================================================================
# User Creation
# ============================================================================

function New-User {
    <#
    .SYNOPSIS
        Creates a new user with hashed password
    .DESCRIPTION
        Creates a new user account with PBKDF2-hashed password.
        Validates username uniqueness before creation.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER username
        Unique username (1-50 characters)
    .PARAMETER password
        Plaintext password (will be hashed)
    .PARAMETER fullName
        User's full name
    .PARAMETER role
        User role (admin or md)
    .OUTPUTS
        Hashtable - @{ Success = $true/$false; UserID = int; Message = "" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 50)]
        [string]$username,

        [Parameter(Mandatory = $true)]
        [string]$password,

        [Parameter(Mandatory = $false)]
        [string]$fullName = "",

        [Parameter(Mandatory = $true)]
        [ValidateSet("admin", "md")]
        [string]$role
    )

    $result = @{
        Success = $false
        UserID = 0
        Message = ""
    }

    try {
        # Validate username doesn't already exist
        $existingUser = Get-UserByUsername -connection $connection -username $username
        if ($existingUser) {
            $result.Message = "Username '$username' already exists"
            Write-Log "User creation failed: Username already exists ($username)" "WARNING"
            return $result
        }

        # Hash the password (PBKDF2 with 10,000 iterations)
        $passwordResult = New-PasswordHash -password $password -iterations 10000

        # Insert user into database
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $query = @"
INSERT INTO Users (Username, PasswordHash, PasswordSalt, FullName, Role, IsActive, CreatedDate, PasswordChangedAt, FailedLoginAttempts, ForcePasswordChange)
VALUES ('$username', '$($passwordResult.Hash)', '$($passwordResult.Salt)', '$fullName', '$role', True, #$now#, #$now#, 0, False)
"@

        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            # Get the new user ID
            $userId = Invoke-ScalarQuery -connection $connection -query "SELECT @@IDENTITY"

            $result.Success = $true
            $result.UserID = $userId
            $result.Message = "User created successfully"
            Write-Log "User created: $username (ID: $userId, Role: $role)" "SUCCESS"
        }
        else {
            $result.Message = "Failed to create user (no rows inserted)"
            Write-Log "User creation failed: No rows inserted ($username)" "ERROR"
        }

        return $result
    }
    catch {
        $result.Message = "Error creating user: $($_.Exception.Message)"
        Write-Log "User creation error: $($_.Exception.Message)" "ERROR"
        return $result
    }
}

# ============================================================================
# User Retrieval
# ============================================================================

function Get-UserByUsername {
    <#
    .SYNOPSIS
        Retrieves user by username
    .DESCRIPTION
        Queries Users table and returns user record or $null if not found.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER username
        Username to retrieve
    .OUTPUTS
        Hashtable with user data or $null if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$username
    )

    $reader = $null
    try {
        $query = @"
SELECT UserID, Username, PasswordHash, PasswordSalt, FullName, Role, IsActive, CreatedDate, LastLogin, PasswordChangedAt, FailedLoginAttempts, ForcePasswordChange
FROM Users
WHERE Username = '$username'
"@

        $reader = Invoke-ReaderQuery -connection $connection -query $query

        if ($reader -and $reader.Read()) {
            $user = @{
                UserID = $reader["UserID"]
                Username = $reader["Username"]
                PasswordHash = $reader["PasswordHash"]
                PasswordSalt = $reader["PasswordSalt"]
                FullName = if ($reader["FullName"] -is [DBNull]) { "" } else { $reader["FullName"] }
                Role = $reader["Role"]
                IsActive = $reader["IsActive"]
                CreatedDate = $reader["CreatedDate"]
                LastLogin = if ($reader["LastLogin"] -is [DBNull]) { $null } else { $reader["LastLogin"] }
                PasswordChangedAt = $reader["PasswordChangedAt"]
                FailedLoginAttempts = $reader["FailedLoginAttempts"]
                ForcePasswordChange = $reader["ForcePasswordChange"]
            }

            return $user
        }
        else {
            return $null
        }
    }
    catch {
        Write-Log "Get-UserByUsername error: $($_.Exception.Message)" "ERROR"
        return $null
    }
    finally {
        if ($reader) {
            try {
                $reader.Close()
                $reader.Dispose()
            }
            catch {
                # Reader cleanup failed - log but don't throw
                Write-Log "Reader cleanup warning: $($_.Exception.Message)" "WARNING"
            }
        }
    }
}

# ============================================================================
# User Authentication
# ============================================================================

function Test-UserAuthentication {
    <#
    .SYNOPSIS
        Authenticates user credentials
    .DESCRIPTION
        Verifies username and password against stored hashed credentials.
        Updates LastLogin timestamp on successful authentication.
        Tracks failed login attempts.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER username
        Username to authenticate
    .PARAMETER password
        Plaintext password
    .OUTPUTS
        Hashtable - @{ IsAuthenticated = $true/$false; User = hashtable or $null; Message = "" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$username,

        [Parameter(Mandatory = $true)]
        [string]$password
    )

    $result = @{
        IsAuthenticated = $false
        User = $null
        Message = ""
    }

    try {
        # Retrieve user
        $user = Get-UserByUsername -connection $connection -username $username

        if (-not $user) {
            $result.Message = "User not found"
            Write-Log "Login failed: User not found ($username)" "WARNING"
            return $result
        }

        # Check if user is active
        if (-not $user.IsActive) {
            $result.Message = "User account is inactive"
            Write-Log "Login failed: User inactive ($username)" "WARNING"
            return $result
        }

        # Verify password
        $passwordValid = Test-Password `
            -password $password `
            -storedHash $user.PasswordHash `
            -storedSalt $user.PasswordSalt `
            -iterations 10000

        if ($passwordValid) {
            # Update LastLogin timestamp
            $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $updateQuery = @"
UPDATE Users
SET LastLogin = #$now#, FailedLoginAttempts = 0
WHERE UserID = $($user.UserID)
"@
            Invoke-NonQuery -connection $connection -query $updateQuery | Out-Null

            $result.IsAuthenticated = $true
            $result.User = $user
            $result.Message = "Authentication successful"
            Write-Log "Login successful: $username (Role: $($user.Role))" "SUCCESS"
        }
        else {
            # Increment failed login attempts
            $attempts = $user.FailedLoginAttempts + 1
            $updateQuery = @"
UPDATE Users
SET FailedLoginAttempts = $attempts
WHERE UserID = $($user.UserID)
"@
            Invoke-NonQuery -connection $connection -query $updateQuery | Out-Null

            $result.Message = "Invalid password"
            Write-Log "Login failed: Invalid password ($username, Attempts: $attempts)" "WARNING"
        }

        return $result
    }
    catch {
        $result.Message = "Authentication error: $($_.Exception.Message)"
        Write-Log "Authentication error: $($_.Exception.Message)" "ERROR"
        return $result
    }
}

# ============================================================================
# Module Initialization
# ============================================================================

Write-Verbose "user-functions.ps1 loaded successfully"
