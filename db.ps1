# db.ps1
# Clinical Database Application - Main Entry Point (Windows Forms Only)
# Smart orchestrator: detects state and routes to bootstrap or login UI
# NO CONSOLE OUTPUT - Pure Windows Forms application

#Requires -Version 5.1

# ============================================================================
# Console Window Hiding
# ============================================================================

# Hide PowerShell console window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

# ============================================================================
# Dependencies
# ============================================================================

. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")
. (Join-Path $PSScriptRoot "user-functions.ps1")
. (Join-Path $PSScriptRoot "dev-mode-helpers.ps1")

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# Pre-flight Checks
# ============================================================================

function Test-Environment {
    <#
    .SYNOPSIS
        Validates environment is ready
    .OUTPUTS
        Hashtable with check results
    #>
    param()

    $result = @{
        IsValid = $true
        Message = ""
    }

    # Check 1: 32-bit PowerShell (required for Jet 4.0)
    if ([Environment]::Is64BitProcess) {
        $result.IsValid = $false
        $result.Message = "Must run 32-bit PowerShell for Access 2003 compatibility.`n`nUse: %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
        return $result
    }

    # Check 2: Database file exists (for non-virgin state)
    $dbPath = Join-Path (Split-Path $PSScriptRoot -Parent) "db.mdb"
    $state = Get-DatabaseState

    if ($state -eq "VirginDatabase" -and -not (Test-Path $dbPath)) {
        $result.IsValid = $false
        $result.Message = "First-time setup required.`n`nPREREQUISITE: Create empty db.mdb file manually.`n`nLocation: $dbPath`nMethod: Access UI (File > New > Blank Database)"
        return $result
    }

    return $result
}

# ============================================================================
# Error Display
# ============================================================================

function Show-ErrorDialog {
    <#
    .SYNOPSIS
        Shows error message in Windows Forms dialog
    .PARAMETER message
        Error message to display
    .PARAMETER title
        Dialog title
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [string]$title = "Error"
    )

    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

function Show-InfoDialog {
    <#
    .SYNOPSIS
        Shows info message in Windows Forms dialog
    .PARAMETER message
        Info message to display
    .PARAMETER title
        Dialog title
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [string]$title = "Information"
    )

    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

function Show-ConfirmDialog {
    <#
    .SYNOPSIS
        Shows confirmation dialog
    .PARAMETER message
        Confirmation message
    .PARAMETER title
        Dialog title
    .OUTPUTS
        Boolean - $true if Yes, $false if No
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [string]$title = "Confirm"
    )

    $result = [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

# ============================================================================
# Main Entry Point
# ============================================================================

try {
    Write-Log "Application started (Windows Forms mode)" "INFO"

    # Log dev mode configuration
    Write-DevModeLog

    # Pre-flight checks
    $envCheck = Test-Environment

    if (-not $envCheck.IsValid) {
        Show-ErrorDialog -message $envCheck.Message -title "Environment Check Failed"
        Write-Log "Environment check failed: $($envCheck.Message)" "ERROR"
        exit 1
    }

    # Detect database state
    Write-Log "Detecting database state..." "INFO"
    $state = Get-DatabaseState
    Write-Log "Database state: $state" "INFO"

    # Route based on state
    switch ($state) {
        "VirginDatabase" {
            Write-Log "VirginDatabase state detected - routing to bootstrap" "INFO"

            $proceed = Show-ConfirmDialog -message "First-time setup required.`n`nThis will create the database schema, KEK configuration, and first admin user.`n`nProceed with setup?" -title "First-Time Setup"

            if ($proceed) {
                # Load and run bootstrap UI
                . (Join-Path $PSScriptRoot "gui_bootstrap.ps1")
                $success = Start-Bootstrap

                if ($success) {
                    Show-InfoDialog -message "Setup complete!`n`nYou can now log in with your admin credentials." -title "Setup Complete"
                    Write-Log "Bootstrap completed successfully" "SUCCESS"
                }
                else {
                    Write-Log "Bootstrap cancelled or failed" "WARNING"
                }
            }
            else {
                Write-Log "Bootstrap cancelled by user" "INFO"
            }

            exit 0
        }

        "KekNoAdmin" {
            Write-Log "KekNoAdmin state detected" "WARNING"
            Show-ErrorDialog -message "Database has KEK but no admin users.`n`nAdmin creation not yet implemented.`n`nContact administrator for assistance." -title "Database State: KekNoAdmin"
            exit 1
        }

        "ProductionReady" {
            Write-Log "ProductionReady state detected - routing to login" "INFO"

            # Load and run login UI
            . (Join-Path $PSScriptRoot "gui_login.ps1")
            $success = Start-Login

            if ($success) {
                Write-Log "Session ended normally" "INFO"
            }
            else {
                Write-Log "Login cancelled or failed" "INFO"
            }

            exit 0
        }

        "BootstrapIncomplete" {
            Write-Log "BootstrapIncomplete state detected" "ERROR"
            Show-ErrorDialog -message "Database is in an incomplete state.`n`nSome tables exist but schema is not complete.`n`nContact administrator for recovery." -title "Database State: Incomplete"
            exit 1
        }

        "Corrupted" {
            Write-Log "Corrupted state detected" "ERROR"
            Show-ErrorDialog -message "Database schema integrity issues detected.`n`nContact administrator for recovery." -title "Database State: Corrupted"
            exit 1
        }

        "Error" {
            Write-Log "Error state detected" "ERROR"
            Show-ErrorDialog -message "Unable to determine database state.`n`nCheck log.txt for details.`n`nContact administrator for assistance." -title "Database State: Error"
            exit 1
        }

        default {
            Write-Log "Unknown database state: $state" "ERROR"
            Show-ErrorDialog -message "Unknown database state: $state`n`nContact administrator for assistance." -title "Unknown State"
            exit 1
        }
    }
}
catch {
    Write-Log "Application error: $($_.Exception.Message)" "ERROR"
    Show-ErrorDialog -message "Application error:`n`n$($_.Exception.Message)`n`nCheck log.txt for details." -title "Application Error"
    exit 1
}
