# database-helpers.ps1
# Database connectivity, CRUD operations, state detection, and logging
# Part of Phase 1: Foundation Layer - Phased Implementation Plan

#Requires -Version 5.1

# Source dev mode helpers for connection string logic
. (Join-Path $PSScriptRoot "dev-mode-helpers.ps1")

# ============================================================================
# Database Connection
# ============================================================================

function New-DatabaseConnection {
    <#
    .SYNOPSIS
        Creates and returns a connection to the db.mdb database
    .DESCRIPTION
        Opens a Jet 4.0 OleDb connection to db.mdb.
        DOES NOT create db.mdb - file must exist before calling this function.
    .PARAMETER DatabasePath
        Optional custom database path (for testing). Defaults to production db.mdb one level up.
    .OUTPUTS
        System.Data.OleDb.OleDbConnection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = $null
    )

    try {
        # Get absolute path to db.mdb (production database one level up, unless overridden)
        if ([string]::IsNullOrEmpty($DatabasePath)) {
            $dbPath = Join-Path (Split-Path $PSScriptRoot -Parent) "db.mdb"
        }
        else {
            $dbPath = $DatabasePath
        }

        # Verify database file exists (NEVER auto-create - FAIL EARLY)
        if (-not (Test-Path $dbPath)) {
            $errorMsg = "Database file not found: $dbPath`n" +
                        "Create db.mdb manually before running any scripts.`n" +
                        "Methods: Access UI, external ADOX script, or copy template file."
            Write-Log "Database file not found: $dbPath" "ERROR"
            throw $errorMsg
        }

        # Get connection string (dev mode: workgroup security, production: basic)
        $connectionString = Get-WorkgroupConnectionString -dbPath $dbPath

        # Create and open connection
        $connection = New-Object System.Data.OleDb.OleDbConnection($connectionString)
        $connection.Open()

        Write-Log "Database connection opened (Mode: $(if (Test-DevMode) {'DEV'} else {'PROD'}))" "INFO"
        return $connection
    }
    catch {
        Write-Log "Failed to create database connection: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# ============================================================================
# CRUD Operations
# ============================================================================

function Invoke-NonQuery {
    <#
    .SYNOPSIS
        Executes INSERT, UPDATE, or DELETE query
    .DESCRIPTION
        Executes a non-query SQL statement and returns the number of affected rows.
        Supports transactional execution.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER query
        SQL query to execute
    .PARAMETER transaction
        Optional transaction object for transactional execution
    .OUTPUTS
        Int32 - Number of affected rows
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$query,

        [Parameter(Mandatory = $false)]
        [System.Data.OleDb.OleDbTransaction]$transaction = $null
    )

    $command = $null
    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        if ($transaction) {
            $command.Transaction = $transaction
        }

        $affectedRows = $command.ExecuteNonQuery()
        return $affectedRows
    }
    catch {
        Write-Log "Invoke-NonQuery failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        if ($command) {
            $command.Dispose()
        }
    }
}

function Invoke-ScalarQuery {
    <#
    .SYNOPSIS
        Executes a query and returns a single value
    .DESCRIPTION
        Executes a SELECT query and returns the first column of the first row.
        Use for COUNT(*), single value lookups, etc.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER query
        SQL query to execute
    .OUTPUTS
        Single value (first column of first row) or $null if no results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$query
    )

    $command = $null
    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        $result = $command.ExecuteScalar()
        return $result
    }
    catch {
        Write-Log "Invoke-ScalarQuery failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        if ($command) {
            $command.Dispose()
        }
    }
}

function Invoke-ReaderQuery {
    <#
    .SYNOPSIS
        Executes a query and returns a data reader
    .DESCRIPTION
        Executes a SELECT query and returns an OleDbDataReader for forward-only traversal.
        IMPORTANT: Caller must call .Close() on the reader when done.
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER query
        SQL query to execute
    .OUTPUTS
        System.Data.OleDb.OleDbDataReader
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$query
    )

    $command = $null
    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        # Return reader (caller must close it)
        # Use comma operator to prevent PowerShell from unrolling the reader
        $reader = $command.ExecuteReader()
        return ,$reader
    }
    catch {
        Write-Log "Invoke-ReaderQuery failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    # Note: Don't dispose command here - reader needs it
}

# ============================================================================
# Schema Validation
# ============================================================================

function Test-TableExists {
    <#
    .SYNOPSIS
        Checks if a table exists in the database
    .DESCRIPTION
        Queries the database schema to determine if a table exists.
        Uses GetOleDbSchemaTable (Jet 4.0 doesn't support INFORMATION_SCHEMA).
    .PARAMETER connection
        Open OleDbConnection
    .PARAMETER tableName
        Name of the table to check
    .OUTPUTS
        Boolean - $true if table exists, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection,

        [Parameter(Mandatory = $true)]
        [string]$tableName
    )

    try {
        # Get schema information for tables
        $schemaTable = $connection.GetOleDbSchemaTable(
            [System.Data.OleDb.OleDbSchemaGuid]::Tables,
            @($null, $null, $null, "TABLE")
        )

        # Check if our table exists
        foreach ($row in $schemaTable.Rows) {
            if ($row["TABLE_NAME"] -eq $tableName) {
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Log "Test-TableExists failed for table '$tableName': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Initialize-DatabaseSchema {
    <#
    .SYNOPSIS
        Creates database schema in atomic transaction (all-or-nothing)
    .DESCRIPTION
        VBA equivalent: modKekBootstrap.Bootstrap() Phase 2
        Creates all tables and indexes in single transaction
        Rolls back on ANY failure (no partial schema)
    .PARAMETER connection
        Open OleDbConnection
    .OUTPUTS
        Hashtable - @{ Success = $true/$false; TablesCreated = @(); Message = ""; Phase = "" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    # Source table definitions
    . (Join-Path $PSScriptRoot "schema-definitions.ps1")

    $result = @{
        Success = $false
        TablesCreated = @()
        Message = ""
        Phase = ""
    }

    # Begin transaction
    $transaction = $null

    try {
        $transaction = $connection.BeginTransaction()
        $result.Phase = "PHASE_2_SCHEMA_CREATION"

        # Create tables in dependency order
        $tables = @(
            @{ Name = "Config"; SQL = $script:TABLE_CONFIG }
            @{ Name = "Users"; SQL = $script:TABLE_USERS }
            @{ Name = "Patients"; SQL = $script:TABLE_PATIENTS }
            @{ Name = "ClinicalRecords"; SQL = $script:TABLE_CLINICAL_RECORDS }
        )

        foreach ($table in $tables) {
            # Skip if table already exists (idempotent)
            if (-not (Test-TableExists -connection $connection -tableName $table.Name)) {
                $cmd = $connection.CreateCommand()
                $cmd.Transaction = $transaction
                $cmd.CommandText = $table.SQL
                $cmd.ExecuteNonQuery() | Out-Null
                $cmd.Dispose()

                $result.TablesCreated += $table.Name
                Write-Log "Table created: $($table.Name)" "INFO"
            }
        }

        # Create indexes (skip if already exist - idempotent)
        $indexes = @(
            @{ Name = "idx_Config_ConfigKey"; SQL = $script:INDEX_CONFIG_KEY; Table = "Config" }
            @{ Name = "idx_Users_Username"; SQL = $script:INDEX_USERS_USERNAME; Table = "Users" }
            @{ Name = "idx_ClinicalRecords_Patient"; SQL = $script:INDEX_CLINICAL_RECORDS_PATIENT; Table = "ClinicalRecords" }
        )

        foreach ($index in $indexes) {
            # Only create indexes for tables that were just created (or if table exists but index might not)
            # Jet 4.0 will error if index already exists - catch and skip
            try {
                $cmd = $connection.CreateCommand()
                $cmd.Transaction = $transaction
                $cmd.CommandText = $index.SQL
                $cmd.ExecuteNonQuery() | Out-Null
                $cmd.Dispose()

                Write-Log "Index created: $($index.Name)" "INFO"
            }
            catch {
                # Index already exists - skip silently (idempotent behavior)
                if ($_.Exception.Message -match "already has an index") {
                    Write-Log "Index already exists (skipped): $($index.Name)" "INFO"
                }
                else {
                    # Different error - rethrow
                    throw
                }
            }
        }

        # Commit transaction
        $transaction.Commit()
        $result.Success = $true
        $result.Message = "Schema created successfully"
        $result.Phase = "PHASE_2_COMPLETE"
        Write-Log "Database schema creation complete (transactional)" "SUCCESS"
    }
    catch {
        # Rollback on ANY error
        if ($transaction) {
            $transaction.Rollback()
        }
        $result.Success = $false
        $result.Message = "Schema creation failed (rolled back): $($_.Exception.Message)"
        $result.Phase = "PHASE_2_ROLLBACK"
        Write-Log "Schema creation rolled back: $($_.Exception.Message)" "ERROR"
    }
    finally {
        if ($transaction) {
            $transaction.Dispose()
        }
    }

    return $result
}

# ============================================================================
# State Detection
# ============================================================================

function Get-DatabaseState {
    <#
    .SYNOPSIS
        Determines the current state of the database
    .DESCRIPTION
        Implements state machine logic from VBA modKekBootstrap.
        Returns one of six states based on database schema and data.
    .PARAMETER DatabasePath
        Optional custom database path (for testing). Defaults to production db.mdb one level up.
    .OUTPUTS
        String - One of: VirginDatabase, BootstrapIncomplete, KekNoAdmin, ProductionReady, Corrupted, Error
    .NOTES
        State Machine (VBA-inspired):
        - VirginDatabase: db.mdb doesn't exist or no tables
        - BootstrapIncomplete: Some tables exist but not all
        - KekNoAdmin: Schema complete, KEK configured, but no active admin users
        - ProductionReady: Schema complete, KEK configured, active admin exists
        - Corrupted: Schema integrity issues
        - Error: Unable to determine state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DatabasePath = $null
    )

    $connection = $null

    try {
        # Check if db.mdb exists (production database one level up, unless overridden)
        if ([string]::IsNullOrEmpty($DatabasePath)) {
            $dbPath = Join-Path (Split-Path $PSScriptRoot -Parent) "db.mdb"
        }
        else {
            $dbPath = $DatabasePath
        }

        if (-not (Test-Path $dbPath)) {
            return "VirginDatabase"
        }

        # Open connection
        $connection = New-DatabaseConnection -DatabasePath $dbPath

        # Define required tables
        $requiredTables = @("Config", "Users", "Patients", "ClinicalRecords")
        $existingTables = @()

        # Check which tables exist
        foreach ($table in $requiredTables) {
            if (Test-TableExists -connection $connection -tableName $table) {
                $existingTables += $table
            }
        }

        # No tables exist → VirginDatabase
        if ($existingTables.Count -eq 0) {
            return "VirginDatabase"
        }

        # Some but not all tables → BootstrapIncomplete
        if ($existingTables.Count -ne $requiredTables.Count) {
            Write-Log "Database incomplete: Found $($existingTables.Count) of $($requiredTables.Count) required tables" "WARNING"
            return "BootstrapIncomplete"
        }

        # All tables exist - check KEK configuration
        $kekHashExists = $false
        try {
            $kekHash = Invoke-ScalarQuery -connection $connection -query "SELECT ConfigValue FROM Config WHERE ConfigKey = 'KEK_Hash'"
            $kekHashExists = ($null -ne $kekHash -and $kekHash -ne "")
        }
        catch {
            # Config table might not have the row yet
            $kekHashExists = $false
        }

        # No KEK configured → VirginDatabase (needs bootstrap)
        if (-not $kekHashExists) {
            return "VirginDatabase"
        }

        # KEK configured - check for active admin users
        try {
            $adminCount = Invoke-ScalarQuery -connection $connection -query @"
SELECT COUNT(*) FROM Users
WHERE Role = 'admin' AND IsActive = True
"@

            if ($null -eq $adminCount -or $adminCount -eq 0) {
                return "KekNoAdmin"
            }
            else {
                return "ProductionReady"
            }
        }
        catch {
            Write-Log "Failed to query admin users: $($_.Exception.Message)" "WARNING"
            return "Corrupted"
        }
    }
    catch {
        Write-Log "Get-DatabaseState error: $($_.Exception.Message)" "ERROR"
        return "Error"
    }
    finally {
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
            $connection.Dispose()
        }
    }
}

# ============================================================================
# Logging
# ============================================================================

# Session-scoped flag to track first log write (persists across module reloads via Test-Path check)
# Do not initialize here - let Test-Path variable: check determine if truly first write

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry to log.txt
    .DESCRIPTION
        Appends a timestamped log entry to log.txt in the script directory.
        Automatically clears log file on first write of each session.
        Creates the file if it doesn't exist.
    .PARAMETER message
        Log message text
    .PARAMETER level
        Log level (INFO, SUCCESS, WARNING, ERROR)
    .NOTES
        Format: [2025-11-01 14:23:15] [LEVEL] message
        VBA inspiration: Logger module (dev mode gate optional)
        Session behavior: First write clears log, subsequent writes append
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$level = "INFO"
    )

    try {
        $logPath = Join-Path $PSScriptRoot "log.txt"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"

        # Clear log file on first write of session (fresh start for each run)
        # Only clear if variable is truly uninitialized (not just $false)
        if (-not (Test-Path variable:script:LogSessionInitialized)) {
            if (Test-Path $logPath) {
                Clear-Content -Path $logPath -ErrorAction SilentlyContinue
            }
            $script:LogSessionInitialized = $true
        }

        # Append to log file (creates if doesn't exist)
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    }
    catch {
        # If logging fails, write to console but don't throw
        Write-Warning "Failed to write to log: $($_.Exception.Message)"
    }
}

# ============================================================================
# Module Initialization
# ============================================================================

Write-Verbose "database-helpers.ps1 loaded successfully"
