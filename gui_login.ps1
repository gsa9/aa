# gui_login.ps1
# Windows Forms UI for user login and KEK validation
# Loads session KEK and launches main menu

#Requires -Version 5.1

# ============================================================================
# Dependencies
# ============================================================================

. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")
. (Join-Path $PSScriptRoot "user-functions.ps1")
. (Join-Path $PSScriptRoot "dev-mode-helpers.ps1")
. (Join-Path $PSScriptRoot "gui-admin.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# Login Form
# ============================================================================

function Show-LoginForm {
    <#
    .SYNOPSIS
        Shows cryptic Windows Forms UI for login credential collection
    .DESCRIPTION
        Cryptic login interface with hidden input box and progressive credential collection:
        - Single hidden input box (0,0 position, 0,0 size)
        - Three labels showing input (visible only in dev mode)
        - Progressive input: username -> password -> KEK password (Enter key advances)
        - Result label for validation feedback (dev mode only)
        - Only closeable via window close button (X)
    .OUTPUTS
        Hashtable with credentials or $null if cancelled
    #>
    param()

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Clinical Database - Login"
    $form.Size = New-Object System.Drawing.Size(450, 280)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(410, 30)
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Text = "Clinical Patient Data Management System"
    $form.Controls.Add($titleLabel)

    # Dev mode indicator
    $isDevMode = Test-DevMode
    if ($isDevMode) {
        $devLabel = New-Object System.Windows.Forms.Label
        $devLabel.Location = New-Object System.Drawing.Point(10, 40)
        $devLabel.Size = New-Object System.Drawing.Size(410, 20)
        $devLabel.ForeColor = [System.Drawing.Color]::Orange
        $devLabel.Text = "[DEV MODE] Cryptic login interface - debug labels visible"
        $form.Controls.Add($devLabel)
        $yPos = 70
    }
    else {
        $yPos = 50
    }

    # Enable keyboard input capture at form level (no input box needed)
    $form.KeyPreview = $true

    # Debug labels (visible only in dev mode)
    $usernameDisplayLabel = New-Object System.Windows.Forms.Label
    $usernameDisplayLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $usernameDisplayLabel.Size = New-Object System.Drawing.Size(410, 20)
    $usernameDisplayLabel.Text = "Username: "
    $usernameDisplayLabel.Visible = $isDevMode
    $form.Controls.Add($usernameDisplayLabel)

    $yPos += 30

    $passwordDisplayLabel = New-Object System.Windows.Forms.Label
    $passwordDisplayLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $passwordDisplayLabel.Size = New-Object System.Drawing.Size(410, 20)
    $passwordDisplayLabel.Text = "Password: "
    $passwordDisplayLabel.Visible = $isDevMode
    $form.Controls.Add($passwordDisplayLabel)

    $yPos += 30

    $kekPasswordDisplayLabel = New-Object System.Windows.Forms.Label
    $kekPasswordDisplayLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $kekPasswordDisplayLabel.Size = New-Object System.Drawing.Size(410, 20)
    $kekPasswordDisplayLabel.Text = "KEK Password: "
    $kekPasswordDisplayLabel.Visible = $isDevMode
    $form.Controls.Add($kekPasswordDisplayLabel)

    $yPos += 40

    # Result label (for validation feedback - dev mode only)
    $resultLabel = New-Object System.Windows.Forms.Label
    $resultLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $resultLabel.Size = New-Object System.Drawing.Size(410, 40)
    $resultLabel.ForeColor = [System.Drawing.Color]::Red
    $resultLabel.Text = ""
    $resultLabel.Visible = $isDevMode
    $form.Controls.Add($resultLabel)

    # State tracking variables (script scope for event handler access)
    $script:inputState = 0  # 0 = username, 1 = password, 2 = KEK password, 3 = validating
    $script:usernameValue = ""
    $script:passwordValue = ""
    $script:kekPasswordValue = ""
    $script:currentInput = ""  # Current field being typed
    $script:inputFrozen = $false  # Production mode: freeze input on error

    # KeyDown event handler for form (special keys)
    $form.Add_KeyDown({
        param($sender, $e)

        # Ignore input if frozen (production mode error state)
        if ($script:inputFrozen) {
            $e.SuppressKeyPress = $true
            $e.Handled = $true
            return
        }

        # Suppress Tab (prevent focus change)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Tab) {
            $e.SuppressKeyPress = $true
            $e.Handled = $true
            return
        }

        # Suppress arrow keys (Up, Down, Left, Right)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Up -or
            $e.KeyCode -eq [System.Windows.Forms.Keys]::Down -or
            $e.KeyCode -eq [System.Windows.Forms.Keys]::Left -or
            $e.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
            $e.SuppressKeyPress = $true
            $e.Handled = $true
            return
        }

        # Escape resets current field (clears input and stays in same phase)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $e.SuppressKeyPress = $true
            $e.Handled = $true
            $script:currentInput = ""

            # Update debug labels to show cleared state
            if ($isDevMode) {
                if ($script:inputState -eq 0) {
                    $usernameDisplayLabel.Text = "Username: "
                }
                elseif ($script:inputState -eq 1) {
                    $passwordDisplayLabel.Text = "Password: "
                }
                elseif ($script:inputState -eq 2) {
                    $kekPasswordDisplayLabel.Text = "KEK Password: "
                }
            }
            return
        }

        # Backspace removes last character
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
            $e.SuppressKeyPress = $true
            $e.Handled = $true
            if ($script:currentInput.Length -gt 0) {
                $script:currentInput = $script:currentInput.Substring(0, $script:currentInput.Length - 1)

                # Update debug labels
                if ($isDevMode) {
                    if ($script:inputState -eq 0) {
                        $usernameDisplayLabel.Text = "Username: $($script:currentInput)"
                    }
                    elseif ($script:inputState -eq 1) {
                        $passwordDisplayLabel.Text = "Password: " + ('*' * $script:currentInput.Length)
                    }
                    elseif ($script:inputState -eq 2) {
                        $kekPasswordDisplayLabel.Text = "KEK Password: " + ('*' * $script:currentInput.Length)
                    }
                }
            }
            return
        }

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $e.SuppressKeyPress = $true  # Prevent beep sound
            $e.Handled = $true

            if ($script:inputState -eq 0) {
                # Accept username input
                $script:usernameValue = $script:currentInput.Trim()
                $script:currentInput = ""
                $script:inputState = 1
            }
            elseif ($script:inputState -eq 1) {
                # Accept password input
                $script:passwordValue = $script:currentInput
                $script:currentInput = ""
                $script:inputState = 2
            }
            elseif ($script:inputState -eq 2) {
                # Accept KEK password input and validate credentials
                $script:kekPasswordValue = $script:currentInput
                $script:currentInput = ""
                $script:inputState = 3

                # Basic validation
                if ([string]::IsNullOrWhiteSpace($script:usernameValue)) {
                    if ($isDevMode) {
                        # Dev mode: Show error and reset for retry
                        $resultLabel.Text = "[FAIL] Username cannot be empty"
                        $script:inputState = 0
                        $script:usernameValue = ""
                        $script:passwordValue = ""
                        $script:kekPasswordValue = ""
                        $usernameDisplayLabel.Text = "Username: "
                        $passwordDisplayLabel.Text = "Password: "
                        $kekPasswordDisplayLabel.Text = "KEK Password: "
                    }
                    else {
                        # Production mode: Freeze form (no feedback, no further input)
                        $script:inputFrozen = $true
                    }
                    return
                }

                if ([string]::IsNullOrWhiteSpace($script:passwordValue)) {
                    if ($isDevMode) {
                        # Dev mode: Show error and reset for retry
                        $resultLabel.Text = "[FAIL] Password cannot be empty"
                        $script:inputState = 0
                        $script:usernameValue = ""
                        $script:passwordValue = ""
                        $script:kekPasswordValue = ""
                        $usernameDisplayLabel.Text = "Username: "
                        $passwordDisplayLabel.Text = "Password: "
                        $kekPasswordDisplayLabel.Text = "KEK Password: "
                    }
                    else {
                        # Production mode: Freeze form (no feedback, no further input)
                        $script:inputFrozen = $true
                    }
                    return
                }

                if ([string]::IsNullOrWhiteSpace($script:kekPasswordValue)) {
                    if ($isDevMode) {
                        # Dev mode: Show error and reset for retry
                        $resultLabel.Text = "[FAIL] KEK password cannot be empty"
                        $script:inputState = 0
                        $script:usernameValue = ""
                        $script:passwordValue = ""
                        $script:kekPasswordValue = ""
                        $usernameDisplayLabel.Text = "Username: "
                        $passwordDisplayLabel.Text = "Password: "
                        $kekPasswordDisplayLabel.Text = "KEK Password: "
                    }
                    else {
                        # Production mode: Freeze form (no feedback, no further input)
                        $script:inputFrozen = $true
                    }
                    return
                }

                # Database validation
                try {
                    $connection = New-DatabaseConnection

                    # Authenticate user
                    $authResult = Test-UserAuthentication `
                        -connection $connection `
                        -username $script:usernameValue `
                        -password $script:passwordValue

                    if (-not $authResult.IsAuthenticated) {
                        # Close connection
                        if ($connection -and $connection.State -eq 'Open') {
                            $connection.Close()
                            $connection.Dispose()
                        }

                        if ($isDevMode) {
                            # Dev mode: Show error and reset for retry
                            $resultLabel.Text = "[FAIL] $($authResult.Message)"
                            $script:inputState = 0
                            $script:usernameValue = ""
                            $script:passwordValue = ""
                            $script:kekPasswordValue = ""
                            $usernameDisplayLabel.Text = "Username: "
                            $passwordDisplayLabel.Text = "Password: "
                            $kekPasswordDisplayLabel.Text = "KEK Password: "
                        }
                        else {
                            # Production mode: Freeze form (no feedback, no further input)
                            $script:inputFrozen = $true
                        }
                        return
                    }

                    # Validate KEK
                    $kekHash = Invoke-ScalarQuery -connection $connection -query "SELECT ConfigValue FROM Config WHERE ConfigKey = 'KEK_Hash'"
                    $kekSalt = Invoke-ScalarQuery -connection $connection -query "SELECT ConfigValue FROM Config WHERE ConfigKey = 'KEK_Salt'"

                    $kekValidation = Test-KekPassword `
                        -password $script:kekPasswordValue `
                        -storedHash $kekHash `
                        -storedSalt $kekSalt `
                        -iterations 100000

                    if (-not $kekValidation.IsValid) {
                        # Close connection
                        if ($connection -and $connection.State -eq 'Open') {
                            $connection.Close()
                            $connection.Dispose()
                        }

                        if ($isDevMode) {
                            # Dev mode: Show error and reset for retry
                            $resultLabel.Text = "[FAIL] Invalid KEK password"
                            $script:inputState = 0
                            $script:usernameValue = ""
                            $script:passwordValue = ""
                            $script:kekPasswordValue = ""
                            $usernameDisplayLabel.Text = "Username: "
                            $passwordDisplayLabel.Text = "Password: "
                            $kekPasswordDisplayLabel.Text = "KEK Password: "
                        }
                        else {
                            # Production mode: Freeze form (no feedback, no further input)
                            $script:inputFrozen = $true
                        }
                        return
                    }

                    # All validation passed - close form with credentials and connection
                    $form.Tag = @{
                        Username = $script:usernameValue
                        Password = $script:passwordValue
                        KekPassword = $script:kekPasswordValue
                        User = $authResult.User
                        DerivedKEK = $kekValidation.DerivedKEK
                        Connection = $connection
                    }
                    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $form.Close()
                }
                catch {
                    $errorMsg = "Database error: $($_.Exception.Message)"

                    if ($isDevMode) {
                        # Dev mode: Show error and reset for retry
                        $resultLabel.Text = "[ERROR] $errorMsg"
                        $script:inputState = 0
                        $script:usernameValue = ""
                        $script:passwordValue = ""
                        $script:kekPasswordValue = ""
                        $usernameDisplayLabel.Text = "Username: "
                        $passwordDisplayLabel.Text = "Password: "
                        $kekPasswordDisplayLabel.Text = "KEK Password: "
                    }
                    else {
                        # Production mode: Freeze form (no feedback, no further input)
                        $script:inputFrozen = $true
                    }
                }
            }
        }
    })

    # KeyPress event handler for form (character input)
    $form.Add_KeyPress({
        param($sender, $e)

        # Ignore input if frozen (production mode error state)
        if ($script:inputFrozen) {
            $e.Handled = $true
            return
        }

        # Ignore control characters (already handled in KeyDown)
        $charCode = [int][char]$e.KeyChar
        if ($charCode -lt 32) {
            $e.Handled = $true
            return
        }

        # Append character to current input
        $script:currentInput += $e.KeyChar
        $e.Handled = $true

        # Update debug labels
        if ($isDevMode) {
            if ($script:inputState -eq 0) {
                $usernameDisplayLabel.Text = "Username: $($script:currentInput)"
            }
            elseif ($script:inputState -eq 1) {
                $passwordDisplayLabel.Text = "Password: " + ('*' * $script:currentInput.Length)
            }
            elseif ($script:inputState -eq 2) {
                $kekPasswordDisplayLabel.Text = "KEK Password: " + ('*' * $script:currentInput.Length)
            }
        }
    })

    # Show form
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $form.Tag) {
        $credentials = $form.Tag
        $form.Dispose()
        return $credentials
    }

    $form.Dispose()
    return $null
}

# ============================================================================
# Login Processing
# ============================================================================

function Invoke-LoginWithValidation {
    <#
    .SYNOPSIS
        Processes login with progress feedback
    .PARAMETER credentials
        Hashtable with username, password, and KEK password
    .OUTPUTS
        Hashtable with authentication result
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$credentials
    )

    $connection = $null
    $script:sessionKEK = $null

    try {
        # Open connection
        $connection = New-DatabaseConnection

        # Authenticate user
        $authResult = Test-UserAuthentication `
            -connection $connection `
            -username $credentials.Username `
            -password $credentials.Password

        # Clear password from memory
        $credentials.Password = $null

        if (-not $authResult.IsAuthenticated) {
            Write-Log "Login failed: $($authResult.Message) (username: $($credentials.Username))" "WARNING"
            return @{
                Success = $false
                Message = $authResult.Message
                User = $null
                Connection = $null
            }
        }

        Write-Log "User authenticated: $($credentials.Username)" "SUCCESS"

        # Validate KEK
        $kekHash = Invoke-ScalarQuery -connection $connection -query "SELECT ConfigValue FROM Config WHERE ConfigKey = 'KEK_Hash'"
        $kekSalt = Invoke-ScalarQuery -connection $connection -query "SELECT ConfigValue FROM Config WHERE ConfigKey = 'KEK_Salt'"

        $kekValidation = Test-KekPassword `
            -password $credentials.KekPassword `
            -storedHash $kekHash `
            -storedSalt $kekSalt `
            -iterations 100000

        # Clear KEK password from memory
        $credentials.KekPassword = $null

        if (-not $kekValidation.IsValid) {
            Write-Log "Login failed: Invalid KEK password (user: $($credentials.Username))" "WARNING"
            return @{
                Success = $false
                Message = "Invalid KEK password"
                User = $null
                Connection = $null
            }
        }

        # Store KEK in session
        $script:sessionKEK = $kekValidation.DerivedKEK

        Write-Log "Login successful: $($credentials.Username) (KEK loaded into session)" "SUCCESS"

        return @{
            Success = $true
            Message = "Login successful"
            User = $authResult.User
            Connection = $connection
        }
    }
    catch {
        Write-Log "Login error: $($_.Exception.Message)" "ERROR"

        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
            $connection.Dispose()
        }

        return @{
            Success = $false
            Message = "Login error: $($_.Exception.Message)"
            User = $null
            Connection = $null
        }
    }
}

# ============================================================================
# Main Menu
# ============================================================================

function Show-MainMenu {
    <#
    .SYNOPSIS
        Shows main application menu (Windows Forms)
    .PARAMETER user
        Authenticated user object
    .PARAMETER connection
        Open database connection
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$user,

        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    # Create main menu form
    $menuForm = New-Object System.Windows.Forms.Form
    $menuForm.Text = "Clinical Database - Main Menu"
    $menuForm.Size = New-Object System.Drawing.Size(500, 350)
    $menuForm.StartPosition = "CenterScreen"
    $menuForm.FormBorderStyle = "FixedDialog"
    $menuForm.MaximizeBox = $false
    $menuForm.MinimizeBox = $false

    # User info label
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10, 10)
    $userLabel.Size = New-Object System.Drawing.Size(460, 40)
    $userLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $userLabel.Text = "Logged in as: $($user.FullName) ($($user.Username))" + [Environment]::NewLine + "Role: $($user.Role)"
    $menuForm.Controls.Add($userLabel)

    $yPos = 60

    # Manage Patients button
    $patientsButton = New-Object System.Windows.Forms.Button
    $patientsButton.Location = New-Object System.Drawing.Point(100, $yPos)
    $patientsButton.Size = New-Object System.Drawing.Size(300, 40)
    $patientsButton.Text = "Manage Patients"
    $patientsButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("Patient management not yet implemented.", "Not Implemented", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $menuForm.Controls.Add($patientsButton)

    $yPos += 50

    # Manage Clinical Records button
    $recordsButton = New-Object System.Windows.Forms.Button
    $recordsButton.Location = New-Object System.Drawing.Point(100, $yPos)
    $recordsButton.Size = New-Object System.Drawing.Size(300, 40)
    $recordsButton.Text = "Manage Clinical Records"
    $recordsButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("Clinical records management not yet implemented.", "Not Implemented", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $menuForm.Controls.Add($recordsButton)

    $yPos += 50

    # This menu is only for MD users (clinical interface)
    # Admin users should not see this menu

    # Logout button
    $logoutButton = New-Object System.Windows.Forms.Button
    $logoutButton.Location = New-Object System.Drawing.Point(100, $yPos)
    $logoutButton.Size = New-Object System.Drawing.Size(300, 40)
    $logoutButton.Text = "Logout"
    $logoutButton.Add_Click({
        $menuForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $menuForm.Close()
    })
    $menuForm.Controls.Add($logoutButton)

    # Show form
    $menuForm.ShowDialog() | Out-Null
    $menuForm.Dispose()

    Write-Log "User logged out: $($user.Username)" "INFO"
}

# ============================================================================
# Main Entry Point
# ============================================================================

function Start-Login {
    <#
    .SYNOPSIS
        Main entry point for login UI
    .OUTPUTS
        Boolean - $true if login successful
    #>
    param()

    Write-Log "Login UI started" "INFO"

    # Check if auto-login is enabled (dev mode)
    $autoLogin = Get-DevModeAutoLogin
    $useAutoLogin = $autoLogin -ne $null

    # Main login loop - continue until user explicitly cancels
    do {
        # Auto-login (one-time only, no loop)
        if ($useAutoLogin) {
            Write-Log "Auto-login enabled - bypassing cryptic login form" "INFO"
            Write-Log "  Auto-login user: $($autoLogin.default_username)" "INFO"

            # Get password from auto_login.valid_users section
            $password = Get-DevModeTestUser -Username $autoLogin.default_username

            if (-not $password) {
                Write-Log "Auto-login failed: Password not found for user '$($autoLogin.default_username)' in auto_login.valid_users section" "ERROR"
                [System.Windows.Forms.MessageBox]::Show("Auto-login configuration error: Password not found for user '$($autoLogin.default_username)' in auto_login.valid_users section of dev_mode.yaml", "Auto-Login Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return $false
            }

            # Build credentials for auto-login
            $credentials = @{
                Username = $autoLogin.default_username
                Password = $password
                KekPassword = $autoLogin.kek_password
            }

            Write-Log "Auto-login credentials assembled from dev_mode.yaml" "INFO"

            # Process login with old validation method (for auto-login compatibility)
            $loginResult = Invoke-LoginWithValidation -credentials $credentials

            if (-not $loginResult.Success) {
                [System.Windows.Forms.MessageBox]::Show($loginResult.Message, "Login Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return $false
            }

            # KEK is already stored in session by Invoke-LoginWithValidation

            # Disable auto-login for subsequent iterations (show cryptic login form after logout)
            $useAutoLogin = $false
        }
        else {
            # Show cryptic login form (validation happens inside form)
            $loginResult = Show-LoginForm

            if (-not $loginResult) {
                Write-Log "Login cancelled by user" "INFO"
                return $false
            }

            # Store KEK in session
            $script:sessionKEK = $loginResult.DerivedKEK

            Write-Log "User authenticated: $($loginResult.Username)" "SUCCESS"
            Write-Log "Login successful: $($loginResult.Username) (KEK loaded into session)" "SUCCESS"
        }

        # Route based on user role
        if ($loginResult.User.Role -eq "admin") {
            Write-Log "Routing admin user to admin panel: $($loginResult.User.Username)" "INFO"
            Start-AdminPanel -user $loginResult.User -connection $loginResult.Connection
        }
        elseif ($loginResult.User.Role -eq "md") {
            Write-Log "Routing MD user to clinical interface: $($loginResult.User.Username)" "INFO"
            Show-MainMenu -user $loginResult.User -connection $loginResult.Connection
        }
        else {
            Write-Log "Unknown role for user: $($loginResult.User.Username) (Role: $($loginResult.User.Role))" "WARNING"
            [System.Windows.Forms.MessageBox]::Show("Unknown user role. Please contact administrator.", "Access Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }

        # Cleanup after logout
        if ($script:sessionKEK) {
            $script:sessionKEK = $null
            Write-Log "Session KEK cleared from memory" "INFO"
        }

        if ($loginResult.Connection -and $loginResult.Connection.State -eq 'Open') {
            $loginResult.Connection.Close()
            $loginResult.Connection.Dispose()
            Write-Log "Database connection closed" "INFO"
        }

        Write-Log "User logged out, returning to login screen" "INFO"

        # Loop back to cryptic login form after logout
    } while ($true)

    return $true
}
