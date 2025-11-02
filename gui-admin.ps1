# gui-admin.ps1
# Windows Forms UI for admin user management
# CRUD operations for user accounts

#Requires -Version 5.1

# ============================================================================
# Dependencies
# ============================================================================

. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")
. (Join-Path $PSScriptRoot "user-functions.ps1")
. (Join-Path $PSScriptRoot "dev-mode-helpers.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# User List Retrieval
# ============================================================================

function Get-AllUsers {
    <#
    .SYNOPSIS
        Retrieves all users from database
    .PARAMETER connection
        Open OleDbConnection
    .OUTPUTS
        Array of user hashtables
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    $reader = $null
    try {
        $query = @"
SELECT UserID, Username, FullName, Role, IsActive, CreatedDate, LastLogin, FailedLoginAttempts
FROM Users
ORDER BY Username
"@

        $reader = Invoke-ReaderQuery -connection $connection -query $query
        $users = @()

        while ($reader -and $reader.Read()) {
            $user = @{
                UserID = $reader["UserID"]
                Username = $reader["Username"]
                FullName = if ($reader["FullName"] -is [DBNull]) { "" } else { $reader["FullName"] }
                Role = $reader["Role"]
                IsActive = $reader["IsActive"]
                CreatedDate = $reader["CreatedDate"]
                LastLogin = if ($reader["LastLogin"] -is [DBNull]) { $null } else { $reader["LastLogin"] }
                FailedLoginAttempts = $reader["FailedLoginAttempts"]
            }
            $users += $user
        }

        return $users
    }
    catch {
        Write-Log "Get-AllUsers error: $($_.Exception.Message)" "ERROR"
        return @()
    }
    finally {
        if ($reader) {
            try {
                $reader.Close()
                $reader.Dispose()
            }
            catch {
                Write-Log "Reader cleanup warning: $($_.Exception.Message)" "WARNING"
            }
        }
    }
}

# ============================================================================
# User Creation/Edit Dialog
# ============================================================================

function Show-UserDialog {
    <#
    .SYNOPSIS
        Shows dialog for creating or editing a user
    .PARAMETER mode
        "Create" or "Edit"
    .PARAMETER existingUser
        User hashtable for edit mode (optional)
    .OUTPUTS
        Hashtable with user data or $null if cancelled
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Create", "Edit")]
        [string]$mode,

        [Parameter(Mandatory = $false)]
        [hashtable]$existingUser = $null
    )

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Clinical Database - $mode User"
    $form.Size = New-Object System.Drawing.Size(450, 350)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $yPos = 10

    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $titleLabel.Size = New-Object System.Drawing.Size(410, 30)
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Text = "$mode User Account"
    $form.Controls.Add($titleLabel)
    $yPos += 40

    # Username
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $userLabel.Size = New-Object System.Drawing.Size(120, 20)
    $userLabel.Text = "Username:"
    $form.Controls.Add($userLabel)

    $userBox = New-Object System.Windows.Forms.TextBox
    $userBox.Location = New-Object System.Drawing.Point(140, $yPos)
    $userBox.Size = New-Object System.Drawing.Size(280, 20)
    $form.Controls.Add($userBox)
    $yPos += 30

    # Full Name
    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $nameLabel.Size = New-Object System.Drawing.Size(120, 20)
    $nameLabel.Text = "Full Name:"
    $form.Controls.Add($nameLabel)

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Location = New-Object System.Drawing.Point(140, $yPos)
    $nameBox.Size = New-Object System.Drawing.Size(280, 20)
    $form.Controls.Add($nameBox)
    $yPos += 30

    # Role
    $roleLabel = New-Object System.Windows.Forms.Label
    $roleLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $roleLabel.Size = New-Object System.Drawing.Size(120, 20)
    $roleLabel.Text = "Role:"
    $form.Controls.Add($roleLabel)

    $roleCombo = New-Object System.Windows.Forms.ComboBox
    $roleCombo.Location = New-Object System.Drawing.Point(140, $yPos)
    $roleCombo.Size = New-Object System.Drawing.Size(280, 20)
    $roleCombo.DropDownStyle = "DropDownList"
    $roleCombo.Items.AddRange(@("admin", "md"))
    $form.Controls.Add($roleCombo)
    $yPos += 30

    # Password (Create mode only or optional for Edit)
    $passLabel = New-Object System.Windows.Forms.Label
    $passLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $passLabel.Size = New-Object System.Drawing.Size(120, 20)
    if ($mode -eq "Create") {
        $passLabel.Text = "Password:"
    }
    else {
        $passLabel.Text = "New Password:"
    }
    $form.Controls.Add($passLabel)

    $passBox = New-Object System.Windows.Forms.TextBox
    $passBox.Location = New-Object System.Drawing.Point(140, $yPos)
    $passBox.Size = New-Object System.Drawing.Size(280, 20)
    $passBox.PasswordChar = '*'
    $form.Controls.Add($passBox)
    $yPos += 30

    # Password hint for Edit mode
    if ($mode -eq "Edit") {
        $hintLabel = New-Object System.Windows.Forms.Label
        $hintLabel.Location = New-Object System.Drawing.Point(140, $yPos)
        $hintLabel.Size = New-Object System.Drawing.Size(280, 15)
        $hintLabel.Text = "(Leave blank to keep existing password)"
        $hintLabel.Font = New-Object System.Drawing.Font("Arial", 8, [System.Drawing.FontStyle]::Italic)
        $form.Controls.Add($hintLabel)
        $yPos += 20
    }

    # Active checkbox
    $activeCheck = New-Object System.Windows.Forms.CheckBox
    $activeCheck.Location = New-Object System.Drawing.Point(140, $yPos)
    $activeCheck.Size = New-Object System.Drawing.Size(280, 20)
    $activeCheck.Text = "Active"
    $activeCheck.Checked = $true
    $form.Controls.Add($activeCheck)
    $yPos += 40

    # Populate fields in Edit mode
    if ($mode -eq "Edit" -and $existingUser) {
        $userBox.Text = $existingUser.Username
        $userBox.ReadOnly = $true  # Cannot change username
        $nameBox.Text = $existingUser.FullName
        $roleCombo.SelectedItem = $existingUser.Role
        $activeCheck.Checked = $existingUser.IsActive
    }
    else {
        $roleCombo.SelectedIndex = 0  # Default to admin
    }

    # Save button
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Location = New-Object System.Drawing.Point(230, $yPos)
    $saveButton.Size = New-Object System.Drawing.Size(90, 30)
    $saveButton.Text = "Save"
    $saveButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($saveButton)
    $form.AcceptButton = $saveButton

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(330, $yPos)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    # Show form
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Validate inputs
        $username = $userBox.Text.Trim()
        $fullName = $nameBox.Text.Trim()
        $password = $passBox.Text
        $role = $roleCombo.SelectedItem
        $isActive = $activeCheck.Checked

        if ([string]::IsNullOrWhiteSpace($username)) {
            [System.Windows.Forms.MessageBox]::Show("Username cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($role)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a role.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        # Password validation
        if ($mode -eq "Create" -and [string]::IsNullOrWhiteSpace($password)) {
            [System.Windows.Forms.MessageBox]::Show("Password cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        # Return user data
        $form.Dispose()
        return @{
            Username = $username
            FullName = $fullName
            Password = if ([string]::IsNullOrWhiteSpace($password)) { $null } else { $password }
            Role = $role
            IsActive = $isActive
        }
    }

    $form.Dispose()
    return $null
}

# ============================================================================
# User Update Function
# ============================================================================

function Update-User {
    <#
    .SYNOPSIS
        Updates an existing user
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER userID
        User ID to update
    .PARAMETER fullName
        Updated full name
    .PARAMETER role
        Updated role
    .PARAMETER isActive
        Updated active status
    .PARAMETER newPassword
        New password (optional)
    .OUTPUTS
        Hashtable with success status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [int]$userID,

        [Parameter(Mandatory = $true)]
        [string]$fullName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("admin", "md")]
        [string]$role,

        [Parameter(Mandatory = $true)]
        [bool]$isActive,

        [Parameter(Mandatory = $false)]
        [string]$newPassword = $null
    )

    try {
        # Build update query
        $updates = @(
            "FullName = '$fullName'",
            "Role = '$role'",
            "IsActive = $isActive"
        )

        # Add password update if provided
        if (-not [string]::IsNullOrWhiteSpace($newPassword)) {
            $passwordResult = New-PasswordHash -password $newPassword -iterations 10000
            $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $updates += "PasswordHash = '$($passwordResult.Hash)'"
            $updates += "PasswordSalt = '$($passwordResult.Salt)'"
            $updates += "PasswordChangedAt = #$now#"
        }

        $query = "UPDATE Users SET " + ($updates -join ", ") + " WHERE UserID = $userID"

        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            Write-Log "User updated: UserID $userID (Role: $role)" "SUCCESS"
            return @{ Success = $true; Message = "User updated successfully" }
        }
        else {
            Write-Log "User update failed: No rows affected (UserID: $userID)" "ERROR"
            return @{ Success = $false; Message = "Failed to update user" }
        }
    }
    catch {
        Write-Log "User update error: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Message = "Error updating user: $($_.Exception.Message)" }
    }
}

# ============================================================================
# User Deletion Function
# ============================================================================

function Remove-User {
    <#
    .SYNOPSIS
        Deletes a user from the database
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER userID
        User ID to delete
    .OUTPUTS
        Hashtable with success status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [int]$userID
    )

    try {
        $query = "DELETE FROM Users WHERE UserID = $userID"
        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            Write-Log "User deleted: UserID $userID" "SUCCESS"
            return @{ Success = $true; Message = "User deleted successfully" }
        }
        else {
            Write-Log "User deletion failed: No rows affected (UserID: $userID)" "ERROR"
            return @{ Success = $false; Message = "Failed to delete user" }
        }
    }
    catch {
        Write-Log "User deletion error: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Message = "Error deleting user: $($_.Exception.Message)" }
    }
}

# ============================================================================
# Main Admin Form
# ============================================================================

function Show-AdminPanel {
    <#
    .SYNOPSIS
        Shows admin user management panel
    .PARAMETER user
        Authenticated admin user
    .PARAMETER connection
        Open database connection
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$user,

        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    Write-Log "Admin panel opened by: $($user.Username)" "INFO"

    # Create main form
    $adminForm = New-Object System.Windows.Forms.Form
    $adminForm.Text = "Clinical Database - User Management"
    $adminForm.Size = New-Object System.Drawing.Size(900, 600)
    $adminForm.StartPosition = "CenterScreen"
    $adminForm.FormBorderStyle = "FixedDialog"
    $adminForm.MaximizeBox = $false
    $adminForm.MinimizeBox = $true

    # User info label
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10, 10)
    $userLabel.Size = New-Object System.Drawing.Size(860, 30)
    $userLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $userLabel.Text = "Admin: $($user.FullName) ($($user.Username))"
    $adminForm.Controls.Add($userLabel)

    # DataGridView for users
    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Location = New-Object System.Drawing.Point(10, 50)
    $dataGrid.Size = New-Object System.Drawing.Size(860, 400)
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.AllowUserToDeleteRows = $false
    $dataGrid.ReadOnly = $true
    $dataGrid.SelectionMode = "FullRowSelect"
    $dataGrid.MultiSelect = $false
    $dataGrid.AutoSizeColumnsMode = "Fill"
    $adminForm.Controls.Add($dataGrid)

    # Function to load users into grid
    $loadUsers = {
        $users = Get-AllUsers -connection $connection
        $dataTable = New-Object System.Data.DataTable

        # Define columns
        [void]$dataTable.Columns.Add("UserID", [int])
        [void]$dataTable.Columns.Add("Username", [string])
        [void]$dataTable.Columns.Add("Full Name", [string])
        [void]$dataTable.Columns.Add("Role", [string])
        [void]$dataTable.Columns.Add("Active", [bool])
        [void]$dataTable.Columns.Add("Created", [datetime])
        [void]$dataTable.Columns.Add("Last Login", [string])
        [void]$dataTable.Columns.Add("Failed Logins", [int])

        # Populate rows
        foreach ($u in $users) {
            $row = $dataTable.NewRow()
            $row["UserID"] = $u.UserID
            $row["Username"] = $u.Username
            $row["Full Name"] = $u.FullName
            $row["Role"] = $u.Role
            $row["Active"] = $u.IsActive
            $row["Created"] = $u.CreatedDate
            $row["Last Login"] = if ($u.LastLogin) { $u.LastLogin.ToString() } else { "Never" }
            $row["Failed Logins"] = $u.FailedLoginAttempts
            $dataTable.Rows.Add($row)
        }

        $dataGrid.DataSource = $dataTable

        # Hide UserID column
        $dataGrid.Columns["UserID"].Visible = $false
    }

    # Load initial data
    & $loadUsers

    # Button panel
    $buttonY = 460

    # Add User button
    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Location = New-Object System.Drawing.Point(10, $buttonY)
    $addButton.Size = New-Object System.Drawing.Size(120, 35)
    $addButton.Text = "Add User"
    $addButton.Add_Click({
        $userData = Show-UserDialog -mode "Create"
        if ($userData) {
            $createResult = New-User `
                -connection $connection `
                -username $userData.Username `
                -password $userData.Password `
                -fullName $userData.FullName `
                -role $userData.Role

            if ($createResult.Success) {
                # Update active status if needed
                if (-not $userData.IsActive) {
                    Update-User `
                        -connection $connection `
                        -userID $createResult.UserID `
                        -fullName $userData.FullName `
                        -role $userData.Role `
                        -isActive $userData.IsActive | Out-Null
                }

                [System.Windows.Forms.MessageBox]::Show("User created successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                & $loadUsers
            }
            else {
                [System.Windows.Forms.MessageBox]::Show($createResult.Message, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })
    $adminForm.Controls.Add($addButton)

    # Edit User button
    $editButton = New-Object System.Windows.Forms.Button
    $editButton.Location = New-Object System.Drawing.Point(140, $buttonY)
    $editButton.Size = New-Object System.Drawing.Size(120, 35)
    $editButton.Text = "Edit User"
    $editButton.Add_Click({
        if ($dataGrid.SelectedRows.Count -gt 0) {
            $selectedRow = $dataGrid.SelectedRows[0]
            $existingUser = @{
                UserID = $selectedRow.Cells["UserID"].Value
                Username = $selectedRow.Cells["Username"].Value
                FullName = $selectedRow.Cells["Full Name"].Value
                Role = $selectedRow.Cells["Role"].Value
                IsActive = $selectedRow.Cells["Active"].Value
            }

            $userData = Show-UserDialog -mode "Edit" -existingUser $existingUser
            if ($userData) {
                $updateResult = Update-User `
                    -connection $connection `
                    -userID $existingUser.UserID `
                    -fullName $userData.FullName `
                    -role $userData.Role `
                    -isActive $userData.IsActive `
                    -newPassword $userData.Password

                if ($updateResult.Success) {
                    [System.Windows.Forms.MessageBox]::Show("User updated successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    & $loadUsers
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show($updateResult.Message, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please select a user to edit.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $adminForm.Controls.Add($editButton)

    # Delete User button
    $deleteButton = New-Object System.Windows.Forms.Button
    $deleteButton.Location = New-Object System.Drawing.Point(270, $buttonY)
    $deleteButton.Size = New-Object System.Drawing.Size(120, 35)
    $deleteButton.Text = "Delete User"
    $deleteButton.Add_Click({
        if ($dataGrid.SelectedRows.Count -gt 0) {
            $selectedRow = $dataGrid.SelectedRows[0]
            $username = $selectedRow.Cells["Username"].Value
            $userID = $selectedRow.Cells["UserID"].Value

            # Confirm deletion
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "Are you sure you want to delete user '$username'?",
                "Confirm Deletion",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                $deleteResult = Remove-User -connection $connection -userID $userID

                if ($deleteResult.Success) {
                    [System.Windows.Forms.MessageBox]::Show("User deleted successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    & $loadUsers
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show($deleteResult.Message, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please select a user to delete.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $adminForm.Controls.Add($deleteButton)

    # Refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(400, $buttonY)
    $refreshButton.Size = New-Object System.Drawing.Size(120, 35)
    $refreshButton.Text = "Refresh"
    $refreshButton.Add_Click({
        & $loadUsers
    })
    $adminForm.Controls.Add($refreshButton)

    # Logout button
    $logoutButton = New-Object System.Windows.Forms.Button
    $logoutButton.Location = New-Object System.Drawing.Point(750, $buttonY)
    $logoutButton.Size = New-Object System.Drawing.Size(120, 35)
    $logoutButton.Text = "Logout"
    $logoutButton.Add_Click({
        $adminForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $adminForm.Close()
    })
    $adminForm.Controls.Add($logoutButton)

    # Show form
    $adminForm.ShowDialog() | Out-Null
    $adminForm.Dispose()

    Write-Log "Admin panel closed by: $($user.Username)" "INFO"
}

# ============================================================================
# Entry Point
# ============================================================================

function Start-AdminPanel {
    <#
    .SYNOPSIS
        Entry point for admin panel
    .PARAMETER user
        Authenticated admin user
    .PARAMETER connection
        Open database connection
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$user,

        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    # Verify admin role
    if ($user.Role -ne "admin") {
        [System.Windows.Forms.MessageBox]::Show("Access denied. Admin role required.", "Access Denied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-Log "Admin panel access denied: $($user.Username) (Role: $($user.Role))" "WARNING"
        return
    }

    Show-AdminPanel -user $user -connection $connection
}
