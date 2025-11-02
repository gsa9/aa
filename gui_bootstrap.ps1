# gui_bootstrap.ps1
# Windows Forms UI for first-run bootstrap
# Creates schema, KEK configuration, and first admin user

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
# Bootstrap Form
# ============================================================================

function Show-BootstrapForm {
    <#
    .SYNOPSIS
        Shows Windows Forms UI for bootstrap credential collection
    .OUTPUTS
        Hashtable with credentials or $null if cancelled
    #>
    param()

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Clinical Database - First-Time Setup"
    $form.Size = New-Object System.Drawing.Size(500, 450)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(460, 40)
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Text = "First-Time Setup"
    $form.Controls.Add($titleLabel)

    # Info label
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(10, 50)
    $infoLabel.Size = New-Object System.Drawing.Size(460, 30)
    $infoLabel.Text = "Create the first admin account and KEK password."
    $form.Controls.Add($infoLabel)

    # Warning label
    $warningLabel = New-Object System.Windows.Forms.Label
    $warningLabel.Location = New-Object System.Drawing.Point(10, 80)
    $warningLabel.Size = New-Object System.Drawing.Size(460, 20)
    $warningLabel.ForeColor = [System.Drawing.Color]::Red
    $warningLabel.Text = "WARNING: The KEK password cannot be recovered if lost!"
    $form.Controls.Add($warningLabel)

    # Admin section
    $yPos = 110

    # Admin username
    $adminUserLabel = New-Object System.Windows.Forms.Label
    $adminUserLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $adminUserLabel.Size = New-Object System.Drawing.Size(150, 20)
    $adminUserLabel.Text = "Admin Username:"
    $form.Controls.Add($adminUserLabel)

    $adminUserBox = New-Object System.Windows.Forms.TextBox
    $adminUserBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $adminUserBox.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($adminUserBox)

    $yPos += 30

    # Admin password
    $adminPassLabel = New-Object System.Windows.Forms.Label
    $adminPassLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $adminPassLabel.Size = New-Object System.Drawing.Size(150, 20)
    $adminPassLabel.Text = "Admin Password:"
    $form.Controls.Add($adminPassLabel)

    $adminPassBox = New-Object System.Windows.Forms.TextBox
    $adminPassBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $adminPassBox.Size = New-Object System.Drawing.Size(300, 20)
    $adminPassBox.PasswordChar = '*'
    $form.Controls.Add($adminPassBox)

    $yPos += 30

    # Admin password confirm
    $adminPassConfirmLabel = New-Object System.Windows.Forms.Label
    $adminPassConfirmLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $adminPassConfirmLabel.Size = New-Object System.Drawing.Size(150, 20)
    $adminPassConfirmLabel.Text = "Confirm Password:"
    $form.Controls.Add($adminPassConfirmLabel)

    $adminPassConfirmBox = New-Object System.Windows.Forms.TextBox
    $adminPassConfirmBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $adminPassConfirmBox.Size = New-Object System.Drawing.Size(300, 20)
    $adminPassConfirmBox.PasswordChar = '*'
    $form.Controls.Add($adminPassConfirmBox)

    $yPos += 30

    # Admin full name
    $adminNameLabel = New-Object System.Windows.Forms.Label
    $adminNameLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $adminNameLabel.Size = New-Object System.Drawing.Size(150, 20)
    $adminNameLabel.Text = "Full Name (optional):"
    $form.Controls.Add($adminNameLabel)

    $adminNameBox = New-Object System.Windows.Forms.TextBox
    $adminNameBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $adminNameBox.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($adminNameBox)

    $yPos += 40

    # KEK section separator
    $kekSeparator = New-Object System.Windows.Forms.Label
    $kekSeparator.Location = New-Object System.Drawing.Point(10, $yPos)
    $kekSeparator.Size = New-Object System.Drawing.Size(460, 20)
    $kekSeparator.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $kekSeparator.Text = "KEK Password (for patient data encryption)"
    $form.Controls.Add($kekSeparator)

    $yPos += 25

    # KEK password
    $kekPassLabel = New-Object System.Windows.Forms.Label
    $kekPassLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $kekPassLabel.Size = New-Object System.Drawing.Size(150, 20)
    $kekPassLabel.Text = "KEK Password:"
    $form.Controls.Add($kekPassLabel)

    $kekPassBox = New-Object System.Windows.Forms.TextBox
    $kekPassBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $kekPassBox.Size = New-Object System.Drawing.Size(300, 20)
    $kekPassBox.PasswordChar = '*'
    $form.Controls.Add($kekPassBox)

    $yPos += 30

    # KEK password confirm
    $kekPassConfirmLabel = New-Object System.Windows.Forms.Label
    $kekPassConfirmLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $kekPassConfirmLabel.Size = New-Object System.Drawing.Size(150, 20)
    $kekPassConfirmLabel.Text = "Confirm KEK Password:"
    $form.Controls.Add($kekPassConfirmLabel)

    $kekPassConfirmBox = New-Object System.Windows.Forms.TextBox
    $kekPassConfirmBox.Location = New-Object System.Drawing.Point(170, $yPos)
    $kekPassConfirmBox.Size = New-Object System.Drawing.Size(300, 20)
    $kekPassConfirmBox.PasswordChar = '*'
    $form.Controls.Add($kekPassConfirmBox)

    $yPos += 40

    # OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(280, $yPos)
    $okButton.Size = New-Object System.Drawing.Size(90, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(380, $yPos)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    # Show form
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Validate inputs
        $adminUsername = $adminUserBox.Text.Trim()
        $adminPassword = $adminPassBox.Text
        $adminPasswordConfirm = $adminPassConfirmBox.Text
        $adminFullName = $adminNameBox.Text.Trim()
        $kekPassword = $kekPassBox.Text
        $kekPasswordConfirm = $kekPassConfirmBox.Text

        # Validation
        if ([string]::IsNullOrWhiteSpace($adminUsername)) {
            [System.Windows.Forms.MessageBox]::Show("Admin username cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        if ($adminPassword -ne $adminPasswordConfirm) {
            [System.Windows.Forms.MessageBox]::Show("Admin passwords do not match.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        if ($adminPassword.Length -lt 8) {
            [System.Windows.Forms.MessageBox]::Show("Admin password must be at least 8 characters.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        if ($kekPassword -ne $kekPasswordConfirm) {
            [System.Windows.Forms.MessageBox]::Show("KEK passwords do not match.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        if ($kekPassword.Length -lt 8) {
            [System.Windows.Forms.MessageBox]::Show("KEK password must be at least 8 characters.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        # Return credentials
        $form.Dispose()
        return @{
            AdminUsername = $adminUsername
            AdminPassword = $adminPassword
            AdminFullName = $adminFullName
            KekPassword = $kekPassword
        }
    }

    $form.Dispose()
    return $null
}

# ============================================================================
# Bootstrap Execution with Progress
# ============================================================================

function Invoke-BootstrapWithProgress {
    <#
    .SYNOPSIS
        Runs bootstrap with progress dialog
    .PARAMETER credentials
        Hashtable with admin and KEK credentials
    .OUTPUTS
        Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$credentials
    )

    # Create progress form
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "First-Time Setup"
    $progressForm.Size = New-Object System.Drawing.Size(450, 200)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.MaximizeBox = $false
    $progressForm.MinimizeBox = $false
    $progressForm.ControlBox = $false

    # Status label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, 20)
    $statusLabel.Size = New-Object System.Drawing.Size(410, 60)
    $statusLabel.Text = "Initializing database..."
    $progressForm.Controls.Add($statusLabel)

    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 90)
    $progressBar.Size = New-Object System.Drawing.Size(410, 30)
    $progressBar.Style = "Continuous"
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $progressForm.Controls.Add($progressBar)

    # Show form non-blocking
    $progressForm.Show()
    [System.Windows.Forms.Application]::DoEvents()

    $connection = $null
    $success = $false

    try {
        # Phase 0: Log dev mode configuration
        Write-Log "================================" "INFO"
        Write-Log "Bootstrap Process Started" "INFO"
        Write-Log "================================" "INFO"
        Write-DevModeLog

        # Phase 1: Open connection
        $statusLabel.Text = "Opening database connection..."
        $progressBar.Value = 10
        [System.Windows.Forms.Application]::DoEvents()

        $connection = New-DatabaseConnection
        Write-Log "Database connection opened for bootstrap" "INFO"

        # Phase 2: Create schema
        $statusLabel.Text = "Creating database schema..." + [Environment]::NewLine + "This may take a few seconds..."
        $progressBar.Value = 30
        [System.Windows.Forms.Application]::DoEvents()

        $schemaResult = Initialize-DatabaseSchema -connection $connection

        if (-not $schemaResult.Success) {
            throw "Schema creation failed: $($schemaResult.Message)"
        }

        Write-Log "Database schema created successfully" "SUCCESS"

        # Phase 3: Create KEK
        $statusLabel.Text = "Deriving KEK using double PBKDF2..." + [Environment]::NewLine + "(100,000 iterations - this may take a few seconds)"
        $progressBar.Value = 50
        [System.Windows.Forms.Application]::DoEvents()

        $kekResult = New-KekWithHash -password $credentials.KekPassword -iterations 100000

        # Store KEK hash and salt
        $kekHashQuery = @"
INSERT INTO Config (ConfigKey, ConfigValue, Description, ModifiedDate)
VALUES ('KEK_Hash', '$($kekResult.KEKHash)', 'KEK verification hash (double PBKDF2 - 100k iterations)', #$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')#)
"@
        $kekSaltQuery = @"
INSERT INTO Config (ConfigKey, ConfigValue, Description, ModifiedDate)
VALUES ('KEK_Salt', '$($kekResult.Salt)', 'Salt for KEK derivation and hashing', #$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')#)
"@

        Invoke-NonQuery -connection $connection -query $kekHashQuery | Out-Null
        Invoke-NonQuery -connection $connection -query $kekSaltQuery | Out-Null

        Write-Log "KEK configuration created (double PBKDF2 - 100k iterations)" "SUCCESS"

        # Phase 4: Create admin user
        $statusLabel.Text = "Creating admin user..."
        $progressBar.Value = 80
        [System.Windows.Forms.Application]::DoEvents()

        $userResult = New-User `
            -connection $connection `
            -username $credentials.AdminUsername `
            -password $credentials.AdminPassword `
            -fullName $credentials.AdminFullName `
            -role "admin"

        if (-not $userResult.Success) {
            throw "Failed to create admin user: $($userResult.Message)"
        }

        Write-Log "Admin user created: $($credentials.AdminUsername) (ID: $($userResult.UserID))" "SUCCESS"

        # Complete
        $statusLabel.Text = "Setup complete!"
        $progressBar.Value = 100
        [System.Windows.Forms.Application]::DoEvents()

        Start-Sleep -Milliseconds 500

        $success = $true
    }
    catch {
        Write-Log "Bootstrap failed: $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Bootstrap failed:`n`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $success = $false
    }
    finally {
        # Clear credentials
        $credentials.AdminPassword = $null
        $credentials.KekPassword = $null

        # Close connection
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
            $connection.Dispose()
        }

        $progressForm.Close()
        $progressForm.Dispose()
    }

    return $success
}

# ============================================================================
# Main Entry Point
# ============================================================================

function Start-Bootstrap {
    <#
    .SYNOPSIS
        Main entry point for bootstrap UI
    .OUTPUTS
        Boolean - $true if bootstrap successful
    #>
    param()

    Write-Log "Bootstrap UI started" "INFO"

    # Show credential collection form
    $credentials = Show-BootstrapForm

    if (-not $credentials) {
        Write-Log "Bootstrap cancelled by user" "INFO"
        return $false
    }

    # Run bootstrap with progress
    $success = Invoke-BootstrapWithProgress -credentials $credentials

    if ($success) {
        [System.Windows.Forms.MessageBox]::Show("Database initialized successfully!`n`nYou can now log in with your admin credentials.", "Setup Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Write-Log "Bootstrap completed successfully - Database is ProductionReady" "SUCCESS"
        return $true
    }
    else {
        return $false
    }
}
