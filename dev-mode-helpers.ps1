# dev-mode-helpers.ps1
# Development mode detection and configuration
# Part of Phase 5: Deployment & Diagnostics - Dev mode gate

#Requires -Version 5.1

# ============================================================================
# YAML Parser (Simple)
# ============================================================================

function ConvertFrom-SimpleYaml {
    <#
    .SYNOPSIS
        Parses simple YAML files into hashtable structure
    .DESCRIPTION
        Supports:
        - Simple key: value pairs
        - Nested sections (up to 3 levels deep via indentation)
        - Comments (# prefix)
        - Quoted strings
        Does NOT support:
        - Lists/arrays with - prefix
        - Multi-level nesting beyond 3 levels
        - Complex YAML features
    .PARAMETER Path
        Path to YAML file
    .OUTPUTS
        Hashtable with parsed YAML structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $content = Get-Content $Path -Raw -ErrorAction Stop
        $lines = $content -split "`r?`n", 0, 'RegexMatch'

        $result = @{}
        $currentSection = $null
        $currentSubSection = $null

        foreach ($line in $lines) {
            # Skip empty lines and comments
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) {
                continue
            }

            # Detect indentation level (count leading spaces)
            $indent = 0
            if ($line -match '^(\s*)') {
                $indent = $matches[1].Length
            }

            # Check for section header (key followed by colon, no value)
            if ($trimmed -match '^([a-zA-Z_][a-zA-Z0-9_]*):(\s*)$') {
                $sectionName = $matches[1]

                if ($indent -eq 0) {
                    # Top-level section
                    $currentSection = $sectionName
                    $currentSubSection = $null
                    $result[$currentSection] = @{}
                }
                elseif ($indent -eq 2 -and $currentSection) {
                    # Sub-section (nested under current section)
                    $currentSubSection = $sectionName
                    $result[$currentSection][$currentSubSection] = @{}
                }
                continue
            }

            # Check for key-value pair
            if ($trimmed -match '^([a-zA-Z_][a-zA-Z0-9_]*):(.+)$') {
                $key = $matches[1]
                $value = $matches[2].Trim()

                # Remove inline comments (anything after # outside of quotes)
                if ($value -match '^([^#]+)#') {
                    $value = $matches[1].Trim()
                }

                # Remove quotes if present
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }

                # Expand environment variables (%VARNAME% syntax)
                if ($value -match '%([A-Z_][A-Z0-9_]*)%') {
                    # Replace all %VARNAME% patterns with environment variable values
                    $value = [System.Text.RegularExpressions.Regex]::Replace(
                        $value,
                        '%([A-Z_][A-Z0-9_]*)%',
                        {
                            param($match)
                            $envVar = $match.Groups[1].Value
                            $envValue = [System.Environment]::GetEnvironmentVariable($envVar)
                            if ($envValue) { return $envValue } else { return $match.Value }
                        }
                    )
                }

                # Convert boolean strings to actual booleans
                if ($value -eq 'true') { $value = $true }
                elseif ($value -eq 'false') { $value = $false }

                # Add to appropriate level based on indentation and current context
                if ($currentSubSection -and $indent -ge 4) {
                    # 3rd level: Add to current subsection
                    $result[$currentSection][$currentSubSection][$key] = $value
                }
                elseif ($currentSection -and $indent -ge 2) {
                    # 2nd level: Add to current section
                    $result[$currentSection][$key] = $value
                }
                else {
                    # Root level
                    $result[$key] = $value
                }
            }
        }

        return $result
    }
    catch {
        throw "Failed to parse YAML file: $($_.Exception.Message)"
    }
}

# ============================================================================
# Dev Mode Detection
# ============================================================================

function Test-DevMode {
    <#
    .SYNOPSIS
        Determines if running in development mode
    .DESCRIPTION
        Dev mode enabled if:
        1. dev_mode.yaml exists in parent directory (alongside db.mdb) AND
        2. dev_mode.enabled is set to true

        If dev_mode.yaml doesn't exist or enabled is false → Production mode
    .OUTPUTS
        Boolean - $true if dev mode, $false if production
    .NOTES
        dev_mode.yaml location: Parent directory of project root (one level above project)
    #>
    [CmdletBinding()]
    param()

    try {
        # Look for dev_mode.yaml in parent directory (same location as db.mdb)
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"

        # File doesn't exist → Production mode
        if (-not (Test-Path $configPath)) {
            return $false
        }

        # Parse YAML and check enabled flag
        $config = ConvertFrom-SimpleYaml -Path $configPath

        if ($config.dev_mode -and $config.dev_mode.enabled -eq $true) {
            return $true
        }

        # File exists but dev mode not enabled → Production mode
        return $false
    }
    catch {
        # If detection fails, assume production mode (safe default)
        Write-Warning "Failed to parse dev_mode.yaml, assuming production mode: $($_.Exception.Message)"
        return $false
    }
}

function Get-WorkgroupConnectionString {
    <#
    .SYNOPSIS
        Returns appropriate connection string based on dev/production mode
    .DESCRIPTION
        Production mode: Basic connection string (Access uses default System.mdw)
        Dev mode: Workgroup security with custom System.mdw from dev_mode.yaml

        FAIL EARLY: If dev mode is true but .mdw path invalid, throw error
    .PARAMETER dbPath
        Full path to database file (db.mdb or test.mdb)
    .OUTPUTS
        String - OLE DB connection string
    .NOTES
        No hardcoded paths - dev_mode.yaml is single source of truth
        No fallbacks - fail early if dev mode misconfigured
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$dbPath
    )

    try {
        # Production mode: Basic connection string
        if (-not (Test-DevMode)) {
            $connectionString = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$dbPath;"
            Write-Verbose "Production mode: Basic connection (Access uses default System.mdw)"
            return $connectionString
        }

        # Dev mode: Read workgroup settings from dev_mode.yaml
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"
        $config = ConvertFrom-SimpleYaml -Path $configPath

        # Validate workgroup section exists
        if (-not $config.workgroup) {
            throw "Dev mode enabled but 'workgroup' section not found in dev_mode.yaml`n" +
                  "File: $configPath`n" +
                  "Fix: Add workgroup section with mdw_path, user_id, and password"
        }

        # Get workgroup settings
        $mdwPath = $config.workgroup.mdw_path
        $userId = $config.workgroup.user_id
        $password = $config.workgroup.password

        # Validate required fields
        if (-not $mdwPath) {
            throw "Dev mode enabled but 'mdw_path' not found in workgroup section`n" +
                  "File: $configPath`n" +
                  "Fix: Add 'mdw_path' to workgroup section"
        }

        if (-not $userId) {
            throw "Dev mode enabled but 'user_id' not found in workgroup section`n" +
                  "File: $configPath`n" +
                  "Fix: Add 'user_id' to workgroup section"
        }

        # Password can be empty string (null check only)
        if ($null -eq $password) {
            $password = ""
        }

        # Validate .mdw file exists (fail early)
        if (-not (Test-Path $mdwPath)) {
            throw "Dev mode enabled but System.mdw not found: $mdwPath`n" +
                  "File: $configPath`n" +
                  "Fix: Update 'mdw_path' in workgroup section with valid System.mdw path"
        }

        # Build workgroup connection string
        $connectionString = "Provider=Microsoft.Jet.OLEDB.4.0;" +
                            "Data Source=$dbPath;" +
                            "Jet OLEDB:System Database=$mdwPath;" +
                            "User Id=$userId;" +
                            "Password=$password;"

        Write-Verbose "Dev mode: Workgroup security enabled"
        Write-Verbose "  System.mdw: $mdwPath"
        Write-Verbose "  User Id: $userId"

        return $connectionString
    }
    catch {
        # Don't catch and fallback - rethrow to fail early
        throw "Failed to build connection string: $($_.Exception.Message)"
    }
}

function Get-DevModeAutoLogin {
    <#
    .SYNOPSIS
        Gets auto-login settings from configuration
    .DESCRIPTION
        Returns auto-login configuration from dev_mode.yaml (independent of dev_mode flag)
        Used to bypass login screen in development
    .OUTPUTS
        Hashtable with auto_login settings, or $null if config file missing or auto_login disabled
    .NOTES
        Auto-login is independent of dev_mode - can be used with or without workgroup security
        Returns hashtable with keys: enabled, default_username, kek_password
    #>
    [CmdletBinding()]
    param()

    try {
        # Check if config file exists
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"

        if (-not (Test-Path $configPath)) {
            return $null
        }

        $config = ConvertFrom-SimpleYaml -Path $configPath

        # Check if auto_login section exists and is enabled
        if (-not $config.auto_login -or $config.auto_login.enabled -ne $true) {
            return $null
        }

        # Return auto-login settings
        return @{
            enabled = $true
            default_username = $config.auto_login.default_username
            kek_password = $config.auto_login.kek_password
        }
    }
    catch {
        Write-Warning "Failed to read auto-login settings: $($_.Exception.Message)"
        return $null
    }
}

function Get-DevModeTestUser {
    <#
    .SYNOPSIS
        Gets user credentials from auto-login configuration
    .DESCRIPTION
        Returns password for a given username from auto_login.valid_users in dev_mode.yaml
        Used for auto-login and testing
    .PARAMETER Username
        Username to look up
    .OUTPUTS
        String password for the username, or $null if not found or config missing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username
    )

    try {
        # Check if config file exists
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"

        if (-not (Test-Path $configPath)) {
            return $null
        }

        $config = ConvertFrom-SimpleYaml -Path $configPath

        # Check if auto_login.valid_users section exists
        if (-not $config.auto_login -or -not $config.auto_login.valid_users) {
            return $null
        }

        # Return password for username (exact match lookup)
        foreach ($key in $config.auto_login.valid_users.Keys) {
            if ($key -eq $Username) {
                return $config.auto_login.valid_users[$key]
            }
        }

        return $null
    }
    catch {
        Write-Warning "Failed to read user credentials: $($_.Exception.Message)"
        return $null
    }
}

function Get-DevModeTestUsers {
    <#
    .SYNOPSIS
        Gets all user credentials from auto-login configuration
    .DESCRIPTION
        Returns hashtable of all username/password pairs from auto_login.valid_users section
        Used for displaying available test accounts or automated testing
    .OUTPUTS
        Hashtable with username/password pairs, or empty hashtable if none found or config missing
    #>
    [CmdletBinding()]
    param()

    try {
        # Check if config file exists
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"

        if (-not (Test-Path $configPath)) {
            return @{}
        }

        $config = ConvertFrom-SimpleYaml -Path $configPath

        # Return auto_login.valid_users hashtable or empty hashtable
        if ($config.auto_login -and $config.auto_login.valid_users) {
            return $config.auto_login.valid_users
        }

        return @{}
    }
    catch {
        Write-Warning "Failed to read valid users: $($_.Exception.Message)"
        return @{}
    }
}

function Get-DevModeConfiguration {
    <#
    .SYNOPSIS
        Gets comprehensive dev mode configuration report
    .DESCRIPTION
        Returns detailed report of all dev mode features and their status
        Used for logging and diagnostics during boot process
    .OUTPUTS
        Hashtable with dev mode status and feature configuration
    #>
    [CmdletBinding()]
    param()

    $report = @{
        DevModeEnabled = $false
        ConfigPath = $null
        Features = @{}
        RawConfig = $null
    }

    try {
        # Get config path
        $parentDir = Split-Path -Parent $PSScriptRoot
        $configPath = Join-Path $parentDir "dev_mode.yaml"
        $report.ConfigPath = $configPath

        # Check if config file exists
        if (-not (Test-Path $configPath)) {
            $report.Features["ConfigFileExists"] = $false
            return $report
        }

        $report.Features["ConfigFileExists"] = $true

        # Parse YAML
        $config = ConvertFrom-SimpleYaml -Path $configPath
        $report.RawConfig = $config

        # Check main dev mode flag
        if ($config.dev_mode -and $config.dev_mode.enabled -eq $true) {
            $report.DevModeEnabled = $true
        }

        # Workgroup security features
        if ($config.workgroup) {
            $report.Features["WorkgroupSecurity"] = $true
            $report.Features["WorkgroupMdwPath"] = if ($config.workgroup.mdw_path) { $config.workgroup.mdw_path } else { "[not configured]" }
            $report.Features["WorkgroupUserId"] = if ($config.workgroup.user_id) { $config.workgroup.user_id } else { "[not configured]" }
            $report.Features["WorkgroupMdwExists"] = if ($config.workgroup.mdw_path -and (Test-Path $config.workgroup.mdw_path)) { $true } else { $false }
        }
        else {
            $report.Features["WorkgroupSecurity"] = $false
        }

        # Auto-login features
        if ($config.auto_login -and $config.auto_login.enabled -eq $true) {
            $report.Features["AutoLogin"] = $true
            $report.Features["AutoLoginUsername"] = if ($config.auto_login.default_username) { $config.auto_login.default_username } else { "[not configured]" }

            # Valid users in auto_login section
            if ($config.auto_login.valid_users) {
                $userCount = ($config.auto_login.valid_users.Keys | Measure-Object).Count
                $report.Features["ValidUsers"] = $true
                $report.Features["ValidUserCount"] = $userCount
                $report.Features["ValidUserList"] = ($config.auto_login.valid_users.Keys -join ", ")
            }
            else {
                $report.Features["ValidUsers"] = $false
                $report.Features["ValidUserCount"] = 0
            }
        }
        else {
            $report.Features["AutoLogin"] = $false
            $report.Features["ValidUsers"] = $false
            $report.Features["ValidUserCount"] = 0
        }

        return $report
    }
    catch {
        Write-Warning "Failed to read dev mode configuration: $($_.Exception.Message)"
        $report.Features["Error"] = $_.Exception.Message
        return $report
    }
}

function Write-DevModeLog {
    <#
    .SYNOPSIS
        Writes dev mode configuration to log
    .DESCRIPTION
        Logs detailed dev mode configuration for diagnostics
        Called during boot process to record what features are enabled
    #>
    [CmdletBinding()]
    param()

    $config = Get-DevModeConfiguration

    Write-Log "================================" "INFO"
    Write-Log "Dev Mode Configuration Report" "INFO"
    Write-Log "================================" "INFO"

    if (-not $config.Features.ConfigFileExists) {
        Write-Log "Dev Mode: DISABLED (config file not found)" "INFO"
        Write-Log "  Config Path: $($config.ConfigPath)" "INFO"
        Write-Log "  Production mode active - no dev features enabled" "INFO"
        Write-Log "================================" "INFO"
        return
    }

    if (-not $config.DevModeEnabled) {
        Write-Log "Dev Mode: DISABLED (enabled flag set to false)" "INFO"
        Write-Log "  Config Path: $($config.ConfigPath)" "INFO"
        Write-Log "  Production mode active - no dev features enabled" "INFO"
        Write-Log "================================" "INFO"
        return
    }

    Write-Log "Dev Mode: ENABLED" "INFO"
    Write-Log "  Config Path: $($config.ConfigPath)" "INFO"
    Write-Log "Feature Status:" "INFO"

    # Workgroup security
    if ($config.Features.WorkgroupSecurity) {
        Write-Log "  [ENABLED] Workgroup Security" "INFO"
        Write-Log "    - User ID: $($config.Features.WorkgroupUserId)" "INFO"
        Write-Log "    - MDW Path: $($config.Features.WorkgroupMdwPath)" "INFO"
        if ($config.Features.WorkgroupMdwExists) {
            Write-Log "    - MDW File: EXISTS" "SUCCESS"
        }
        else {
            Write-Log "    - MDW File: NOT FOUND" "WARNING"
        }
    }
    else {
        Write-Log "  [DISABLED] Workgroup Security" "INFO"
    }

    # Auto-login
    if ($config.Features.AutoLogin) {
        Write-Log "  [ENABLED] Auto-Login" "INFO"
        Write-Log "    - Default User: $($config.Features.AutoLoginUsername)" "INFO"

        if ($config.Features.ValidUsers) {
            Write-Log "    - Valid Users: $($config.Features.ValidUserCount) configured" "INFO"
            Write-Log "    - Users: $($config.Features.ValidUserList)" "INFO"
        }
        else {
            Write-Log "    - Valid Users: None configured" "WARNING"
        }
    }
    else {
        Write-Log "  [DISABLED] Auto-Login" "INFO"
    }

    # Error reporting
    if ($config.Features.Error) {
        Write-Log "  [ERROR] Configuration parsing error: $($config.Features.Error)" "ERROR"
    }

    Write-Log "================================" "INFO"
}

# ============================================================================
# Module Initialization
# ============================================================================

Write-Verbose "dev-mode-helpers.ps1 loaded successfully"
