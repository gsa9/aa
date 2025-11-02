#Requires -Version 5.1

# ============================================================================
# Clinical Patient Management GUI
# ============================================================================
# Provides Windows Forms interface for patient CRUD operations
# Displays decrypted patient names, manages AES-256 encryption/decryption
# ============================================================================

# Dependencies
. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# Patient Retrieval Functions
# ============================================================================

function Get-AllPatients {
    <#
    .SYNOPSIS
        Retrieves all patients from database with decrypted names
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    $reader = $null
    try {
        $query = @"
SELECT PatientID, EncryptedName, EncryptedNameIV, DateOfBirth, Gender, CreatedDate, ModifiedDate
FROM Patients
ORDER BY CreatedDate DESC
"@

        $reader = Invoke-ReaderQuery -connection $connection -query $query
        $patients = @()

        while ($reader -and $reader.Read()) {
            # Decrypt patient name using session KEK
            $encryptedName = $reader["EncryptedName"]
            $iv = $reader["EncryptedNameIV"]
            $decryptedName = Unprotect-Text `
                -encryptedDataBase64 $encryptedName `
                -ivBase64 $iv `
                -keyBase64 $script:sessionKEK

            $patient = @{
                PatientID = $reader["PatientID"]
                Name = $decryptedName
                DateOfBirth = if ($reader["DateOfBirth"] -is [DBNull]) { $null } else { $reader["DateOfBirth"] }
                Gender = if ($reader["Gender"] -is [DBNull]) { "" } else { $reader["Gender"] }
                CreatedDate = $reader["CreatedDate"]
                ModifiedDate = if ($reader["ModifiedDate"] -is [DBNull]) { $null } else { $reader["ModifiedDate"] }
            }
            $patients += $patient
        }

        Write-Log "Retrieved $($patients.Count) patients from database" "INFO"
        return $patients
    }
    catch {
        Write-Log "Get-AllPatients error: $($_.Exception.Message)" "ERROR"
        return @()
    }
    finally {
        if ($reader) {
            $reader.Close()
            $reader.Dispose()
        }
    }
}

# ============================================================================
# Patient Dialog (Create/Edit)
# ============================================================================

function Show-PatientDialog {
    <#
    .SYNOPSIS
        Shows patient creation or editing dialog
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Create", "Edit")]
        [string]$mode,

        [Parameter(Mandatory = $false)]
        [hashtable]$existingPatient = $null
    )

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Clinical Database - $mode Patient"
    $form.Size = New-Object System.Drawing.Size(450, 400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $yPos = 10

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $titleLabel.Size = New-Object System.Drawing.Size(410, 30)
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Text = "$mode Patient"
    $form.Controls.Add($titleLabel)
    $yPos += 40

    # Patient Name
    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $nameLabel.Size = New-Object System.Drawing.Size(120, 20)
    $nameLabel.Text = "Patient Name:"
    $form.Controls.Add($nameLabel)

    $nameTextBox = New-Object System.Windows.Forms.TextBox
    $nameTextBox.Location = New-Object System.Drawing.Point(140, $yPos)
    $nameTextBox.Size = New-Object System.Drawing.Size(280, 20)
    if ($existingPatient) {
        $nameTextBox.Text = $existingPatient.Name
    }
    $form.Controls.Add($nameTextBox)
    $yPos += 30

    # Date of Birth
    $dobLabel = New-Object System.Windows.Forms.Label
    $dobLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $dobLabel.Size = New-Object System.Drawing.Size(120, 20)
    $dobLabel.Text = "Date of Birth:"
    $form.Controls.Add($dobLabel)

    $dobPicker = New-Object System.Windows.Forms.DateTimePicker
    $dobPicker.Location = New-Object System.Drawing.Point(140, $yPos)
    $dobPicker.Size = New-Object System.Drawing.Size(280, 20)
    $dobPicker.Format = "Short"
    $dobPicker.ShowCheckBox = $true
    $dobPicker.Checked = $false
    if ($existingPatient -and $existingPatient.DateOfBirth) {
        $dobPicker.Value = $existingPatient.DateOfBirth
        $dobPicker.Checked = $true
    }
    $form.Controls.Add($dobPicker)
    $yPos += 30

    # Gender
    $genderLabel = New-Object System.Windows.Forms.Label
    $genderLabel.Location = New-Object System.Drawing.Point(10, $yPos)
    $genderLabel.Size = New-Object System.Drawing.Size(120, 20)
    $genderLabel.Text = "Gender:"
    $form.Controls.Add($genderLabel)

    $genderComboBox = New-Object System.Windows.Forms.ComboBox
    $genderComboBox.Location = New-Object System.Drawing.Point(140, $yPos)
    $genderComboBox.Size = New-Object System.Drawing.Size(280, 20)
    $genderComboBox.DropDownStyle = "DropDownList"
    $genderComboBox.Items.AddRange(@("", "Male", "Female", "Other"))
    if ($existingPatient -and $existingPatient.Gender) {
        $genderComboBox.SelectedItem = $existingPatient.Gender
    }
    else {
        $genderComboBox.SelectedIndex = 0
    }
    $form.Controls.Add($genderComboBox)
    $yPos += 50

    # Buttons
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Location = New-Object System.Drawing.Point(230, $yPos)
    $saveButton.Size = New-Object System.Drawing.Size(90, 30)
    $saveButton.Text = "Save"
    $saveButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($saveButton)
    $form.AcceptButton = $saveButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(330, $yPos)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    # Show dialog
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Validation
        $name = $nameTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Patient name cannot be empty.",
                "Validation Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            $form.Dispose()
            return $null
        }

        # Gather data
        $patientData = @{
            Name = $name
            DateOfBirth = if ($dobPicker.Checked) { $dobPicker.Value } else { $null }
            Gender = $genderComboBox.SelectedItem
        }

        $form.Dispose()
        return $patientData
    }

    $form.Dispose()
    return $null
}

# ============================================================================
# Patient CRUD Functions
# ============================================================================

function New-Patient {
    <#
    .SYNOPSIS
        Creates new patient with encrypted name
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [hashtable]$patientData
    )

    try {
        # Encrypt patient name
        $encryptionResult = Protect-Text -plainText $patientData.Name -keyBase64 $script:sessionKEK

        # Prepare values
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $dobValue = if ($patientData.DateOfBirth) {
            "#$($patientData.DateOfBirth.ToString('yyyy-MM-dd'))#"
        }
        else {
            "NULL"
        }
        $genderValue = if ([string]::IsNullOrWhiteSpace($patientData.Gender)) { "" } else { $patientData.Gender }

        # Build query
        $query = @"
INSERT INTO Patients (EncryptedName, EncryptedNameIV, DateOfBirth, Gender, CreatedDate)
VALUES ('$($encryptionResult.EncryptedData)', '$($encryptionResult.IV)', $dobValue, '$genderValue', #$now#)
"@

        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            $patientID = Invoke-ScalarQuery -connection $connection -query "SELECT @@IDENTITY"
            Write-Log "Patient created: ID $patientID" "SUCCESS"
            return @{ Success = $true; PatientID = $patientID; Message = "Patient created successfully" }
        }
        else {
            Write-Log "New-Patient: No rows affected" "WARNING"
            return @{ Success = $false; Message = "Failed to create patient" }
        }
    }
    catch {
        Write-Log "New-Patient error: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

function Update-Patient {
    <#
    .SYNOPSIS
        Updates existing patient with encrypted name
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [int]$patientID,

        [Parameter(Mandatory = $true)]
        [hashtable]$patientData
    )

    try {
        # Encrypt patient name
        $encryptionResult = Protect-Text -plainText $patientData.Name -keyBase64 $script:sessionKEK

        # Prepare values
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $dobValue = if ($patientData.DateOfBirth) {
            "#$($patientData.DateOfBirth.ToString('yyyy-MM-dd'))#"
        }
        else {
            "NULL"
        }
        $genderValue = if ([string]::IsNullOrWhiteSpace($patientData.Gender)) { "" } else { $patientData.Gender }

        # Build query
        $query = @"
UPDATE Patients
SET EncryptedName = '$($encryptionResult.EncryptedData)',
    EncryptedNameIV = '$($encryptionResult.IV)',
    DateOfBirth = $dobValue,
    Gender = '$genderValue',
    ModifiedDate = #$now#
WHERE PatientID = $patientID
"@

        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            Write-Log "Patient updated: ID $patientID" "SUCCESS"
            return @{ Success = $true; Message = "Patient updated successfully" }
        }
        else {
            Write-Log "Update-Patient: No rows affected for ID $patientID" "WARNING"
            return @{ Success = $false; Message = "Failed to update patient" }
        }
    }
    catch {
        Write-Log "Update-Patient error: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

function Remove-Patient {
    <#
    .SYNOPSIS
        Deletes patient from database
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [int]$patientID
    )

    try {
        $query = "DELETE FROM Patients WHERE PatientID = $patientID"
        $affectedRows = Invoke-NonQuery -connection $connection -query $query

        if ($affectedRows -eq 1) {
            Write-Log "Patient deleted: ID $patientID" "SUCCESS"
            return @{ Success = $true; Message = "Patient deleted successfully" }
        }
        else {
            Write-Log "Remove-Patient: No rows affected for ID $patientID" "WARNING"
            return @{ Success = $false; Message = "Failed to delete patient" }
        }
    }
    catch {
        Write-Log "Remove-Patient error: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

# ============================================================================
# Main Patient Panel
# ============================================================================

function Show-PatientPanel {
    <#
    .SYNOPSIS
        Shows main patient management panel with DataGridView
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$user,

        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    # Create main form
    $mainForm = New-Object System.Windows.Forms.Form
    $mainForm.Text = "Clinical Database - Patient Management"
    $mainForm.Size = New-Object System.Drawing.Size(1000, 600)
    $mainForm.StartPosition = "CenterScreen"
    $mainForm.FormBorderStyle = "FixedDialog"
    $mainForm.MaximizeBox = $false
    $mainForm.MinimizeBox = $true

    # User info label
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10, 10)
    $userLabel.Size = New-Object System.Drawing.Size(960, 30)
    $userLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $userLabel.Text = "Logged in as: $($user.FullName) ($($user.Username))"
    $mainForm.Controls.Add($userLabel)

    # DataGridView
    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Location = New-Object System.Drawing.Point(10, 50)
    $dataGrid.Size = New-Object System.Drawing.Size(960, 420)
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.AllowUserToDeleteRows = $false
    $dataGrid.ReadOnly = $true
    $dataGrid.SelectionMode = "FullRowSelect"
    $dataGrid.MultiSelect = $false
    $dataGrid.AutoSizeColumnsMode = "Fill"
    $mainForm.Controls.Add($dataGrid)

    # Load data function
    $loadData = {
        try {
            $patients = Get-AllPatients -connection $connection
            $dataTable = New-Object System.Data.DataTable

            # Define columns
            [void]$dataTable.Columns.Add("PatientID", [int])
            [void]$dataTable.Columns.Add("Name", [string])
            [void]$dataTable.Columns.Add("Date of Birth", [string])
            [void]$dataTable.Columns.Add("Gender", [string])
            [void]$dataTable.Columns.Add("Created", [datetime])

            # Populate rows
            foreach ($patient in $patients) {
                $row = $dataTable.NewRow()
                $row["PatientID"] = $patient.PatientID
                $row["Name"] = $patient.Name
                $row["Date of Birth"] = if ($patient.DateOfBirth) { $patient.DateOfBirth.ToString("yyyy-MM-dd") } else { "" }
                $row["Gender"] = $patient.Gender
                $row["Created"] = $patient.CreatedDate
                $dataTable.Rows.Add($row)
            }

            $dataGrid.DataSource = $dataTable

            # Hide PatientID column
            $dataGrid.Columns["PatientID"].Visible = $false

            Write-Log "Patient data loaded into grid: $($patients.Count) patients" "INFO"
        }
        catch {
            Write-Log "Error loading patient data: $($_.Exception.Message)" "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                "Error loading patient data: $($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    # Load initial data
    & $loadData

    # Button panel
    $buttonY = 480

    # Add button
    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Location = New-Object System.Drawing.Point(10, $buttonY)
    $addButton.Size = New-Object System.Drawing.Size(120, 35)
    $addButton.Text = "Add Patient"
    $addButton.Add_Click({
        $patientData = Show-PatientDialog -mode "Create"
        if ($patientData) {
            $result = New-Patient -connection $connection -patientData $patientData
            if ($result.Success) {
                [System.Windows.Forms.MessageBox]::Show(
                    $result.Message,
                    "Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                & $loadData
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    $result.Message,
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    })
    $mainForm.Controls.Add($addButton)

    # Edit button
    $editButton = New-Object System.Windows.Forms.Button
    $editButton.Location = New-Object System.Drawing.Point(140, $buttonY)
    $editButton.Size = New-Object System.Drawing.Size(120, 35)
    $editButton.Text = "Edit Patient"
    $editButton.Add_Click({
        if ($dataGrid.SelectedRows.Count -gt 0) {
            $selectedRow = $dataGrid.SelectedRows[0]
            $existingPatient = @{
                PatientID = $selectedRow.Cells["PatientID"].Value
                Name = $selectedRow.Cells["Name"].Value
                DateOfBirth = if ([string]::IsNullOrWhiteSpace($selectedRow.Cells["Date of Birth"].Value)) {
                    $null
                }
                else {
                    [datetime]::Parse($selectedRow.Cells["Date of Birth"].Value)
                }
                Gender = $selectedRow.Cells["Gender"].Value
            }

            $patientData = Show-PatientDialog -mode "Edit" -existingPatient $existingPatient
            if ($patientData) {
                $result = Update-Patient -connection $connection -patientID $existingPatient.PatientID -patientData $patientData
                if ($result.Success) {
                    [System.Windows.Forms.MessageBox]::Show(
                        $result.Message,
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                    & $loadData
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show(
                        $result.Message,
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a patient to edit.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    })
    $mainForm.Controls.Add($editButton)

    # Delete button
    $deleteButton = New-Object System.Windows.Forms.Button
    $deleteButton.Location = New-Object System.Drawing.Point(270, $buttonY)
    $deleteButton.Size = New-Object System.Drawing.Size(120, 35)
    $deleteButton.Text = "Delete Patient"
    $deleteButton.Add_Click({
        if ($dataGrid.SelectedRows.Count -gt 0) {
            $selectedRow = $dataGrid.SelectedRows[0]
            $patientID = $selectedRow.Cells["PatientID"].Value
            $patientName = $selectedRow.Cells["Name"].Value

            # Confirm deletion
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "Are you sure you want to delete patient '$patientName'?`n`nWARNING: This will also delete all associated clinical records.",
                "Confirm Deletion",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                $result = Remove-Patient -connection $connection -patientID $patientID
                if ($result.Success) {
                    [System.Windows.Forms.MessageBox]::Show(
                        $result.Message,
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                    & $loadData
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show(
                        $result.Message,
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a patient to delete.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    })
    $mainForm.Controls.Add($deleteButton)

    # Refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(400, $buttonY)
    $refreshButton.Size = New-Object System.Drawing.Size(120, 35)
    $refreshButton.Text = "Refresh"
    $refreshButton.Add_Click({
        & $loadData
        [System.Windows.Forms.MessageBox]::Show(
            "Patient list refreshed.",
            "Refreshed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    })
    $mainForm.Controls.Add($refreshButton)

    # Back button
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Location = New-Object System.Drawing.Point(850, $buttonY)
    $backButton.Size = New-Object System.Drawing.Size(120, 35)
    $backButton.Text = "Back"
    $backButton.Add_Click({
        $mainForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $mainForm.Close()
    })
    $mainForm.Controls.Add($backButton)

    # Show form
    Write-Log "Patient management panel opened by: $($user.Username)" "INFO"
    $mainForm.ShowDialog() | Out-Null
    $mainForm.Dispose()
    Write-Log "Patient management panel closed by: $($user.Username)" "INFO"
}
