# Testing Documentation
**Clinical Database - Test Design & Implementation**

---

## Overview

**Purpose**: Design and implement production-compliant tests for a clinical database system.

**Core Principle**: Tests must use workgroup security to emulate production environment.

**Test Database**: test.mdb in project root (dev mode only)

---

## Test Philosophy

### Production Compliance

**Tests MUST emulate production environment as closely as possible:**

1. **Workgroup Security**:
   - Production db.mdb created with workgroup connection (authenticated user becomes owner)
   - Test test.mdb MUST be created with same workgroup connection
   - Tests validate that workgroup security layer works correctly
   - Without workgroup, tests are NOT production-compliant

2. **Isolation**:
   - Tests use isolated workgroup (custom System.mdw)
   - Prevents contamination of production workgroup
   - Enables safe testing without affecting production users/permissions

3. **Security Layers**:
   - Tests validate ALL security layers (cryptography + workgroup)
   - Workgroup is Layer 2 (defense-in-depth)
   - Cryptography (KEK + PBKDF2 + AES-256) is Layer 1

### Dev Mode Requirement

**All tests MUST run in dev mode:**

**Why**:
- Ensures test database created with workgroup connection
- Prevents accidental operations on production database
- Isolates test environment from production
- Validates production security model in controlled environment

**Implementation Pattern**:
- Source dev mode helpers module first
- Call dev mode check function at start of every test script
- Fail fast with error message if dev mode not enabled
- Error message explains dev mode requirement (workgroup security for production compliance)

**Implementation**: See dev-mode-helpers module for current dev mode check function

---

## Test Design Principles

### 1. Naming Convention

**ALL test files follow test-* naming convention:**

| Type | Pattern | Purpose |
|------|---------|---------|
| Test Scripts | test-*.ps1 | Automated test suites (module, integration, authentication, etc.) |
| Test Launchers | test-*.bat | Batch launchers for test scripts |
| Test Database | test.mdb | Isolated test database (ONLY, never production database) |
| Test Helpers | bootstrap-test-*.ps1 | Test database initialization and credential setup utilities |

**Rationale**:
- Immediately identifiable as test code
- Prevents confusion with production scripts
- Clear separation of concerns
- Easy to exclude from production deployment

**Current test suites**: See project root for test-*.ps1 files

### 2. Test Database Creation

**test.mdb creation is handled by dedicated TEST UTILITY:**

**Test Database Creation Utility**:
- Creates ONLY test.mdb (never production db.mdb)
- Requires dev mode at startup (fails immediately if not in dev mode)
- Automatically deletes existing test.mdb (to recycle bin)
- Uses workgroup connection for proper object ownership
- Never touches production db.mdb

**Usage Workflow**:
1. Ensure dev mode enabled (configuration file in user profile)
2. Run test database creation utility
3. Run test suites as needed

**Implementation**: See test-create-database script for current implementation

### 3. Test Structure

**Standard test script structure:**

**Setup Phase**:
- Source dev mode helpers first
- Dev mode validation (REQUIRED - fail fast if not in dev mode)
- Source dependencies (database helpers, crypto helpers, etc.)
- Initialize test counters

**Execution Phase**:
- Test 1: Feature description and validation
  - Use test database (not production)
  - Create connection to test.mdb
  - Execute test logic
  - Record pass/fail status
- Test 2: Next feature...
- Test N: Continue sequentially

**Cleanup Phase**:
- Close database connections
- Clear sensitive data (session variables)
- Report test results (passed/failed counts)

**Implementation Patterns**:
        Write-Host "         [FAIL] Test failed" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "         [FAIL] Exception: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}
finally {
    if ($connection -and $connection.State -eq 'Open') {
        $connection.Close()
        $connection.Dispose()
    }
}

# ============================================================================
# Results
# ============================================================================

Write-Host ""
Write-Host "==================================\" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "==================================\" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "[FAILURE] Some tests failed" -ForegroundColor Red
    exit 1
}
```

### 4. Test Isolation

**Each test MUST be isolated:**

**Database Isolation**:
- Always use test.mdb (never production db.mdb)
- Specify DatabasePath explicitly: `New-DatabaseConnection -DatabasePath $testDbPath`
- Never assume default database path

**Data Isolation**:
- Tests should clean up after themselves (delete test records)
- Use unique identifiers (test-specific usernames, patient IDs)
- Consider resetting test.mdb between test phases (delete and recreate)

**State Isolation**:
- Clear sensitive variables in finally blocks (`$script:sessionKEK = $null`)
- Close all connections
- Release COM objects

---

## Test Phases

### Phase 1: Module Testing (test-phase1.ps1)

**Purpose**: Validate individual helper functions

**Tests**:
- crypto-helpers.ps1 functions (PBKDF2, AES-256)
- database-helpers.ps1 functions (connections, queries)
- dev-mode-helpers.ps1 functions (Test-DevMode, Get-WorkgroupConnectionString)

**Pattern**:
```powershell
# Test individual functions without database
$result = New-PasswordHash -password "TestPassword123" -iterations 10000
if ($result.Hash.Length -gt 0 -and $result.Salt.Length -gt 0) {
    Write-Host "[OK] New-PasswordHash works" -ForegroundColor Green
}
```

### Phase 2: Schema & Bootstrap Testing (test-phase2.ps1)

**Purpose**: Validate database schema creation and bootstrap workflow

**Tests**:
- State detection (VirginDatabase, KekNoAdmin, ProductionReady)
- Schema creation (Initialize-DatabaseSchema)
- Schema idempotence (run twice, no errors)
- Table existence verification
- KEK configuration
- Admin user creation
- State transitions

**Critical**:
- Uses test.mdb (created by test-create-database.ps1)
- Validates complete bootstrap workflow
- Tests state machine transitions

### Phase 3: Authentication Testing (test-phase3.ps1)

**Purpose**: Validate user authentication and session management

**Tests**:
- Admin login (correct password)
- Admin login (wrong password)
- KEK validation (correct KEK password)
- KEK validation (wrong KEK password)
- Session KEK loading
- Failed login attempt tracking
- Account lockout

**Critical**:
- Tests security mechanisms
- Validates double PBKDF2 KEK pattern
- Session management

---

## Common Test Patterns

### Pattern 1: Connection Management

```powershell
$connection = $null
try {
    $testDbPath = Join-Path $PSScriptRoot "test.mdb"
    $connection = New-DatabaseConnection -DatabasePath $testDbPath

    # Test operations...
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}
finally {
    if ($connection -and $connection.State -eq 'Open') {
        $connection.Close()
        $connection.Dispose()
    }
}
```

### Pattern 2: Sensitive Data Cleanup

```powershell
try {
    # Operations with sensitive data
    $password = "TestPassword123"
    $result = New-PasswordHash -password $password

    # Use result...
}
finally {
    # Clear sensitive variables
    $password = $null
    $result = $null
}
```

### Pattern 3: Test Database Deletion (Dev Mode)

```powershell
# Delete test.mdb if it exists (dev mode already validated)
$testDbPath = Join-Path $PSScriptRoot "test.mdb"
if (Test-Path $testDbPath) {
    Write-Host "Removing existing test.mdb (to recycle bin)..." -ForegroundColor Gray
    try {
        $shell = New-Object -ComObject Shell.Application
        $item = $shell.NameSpace(0).ParseName($testDbPath)
        if ($item) {
            $item.InvokeVerb("delete")
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
            Start-Sleep -Milliseconds 500  # Wait for file system
        }
    }
    catch {
        Write-Host "[WARN] Could not delete to recycle bin: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

---

## Test Utilities

### test-create-database.ps1

**Purpose**: Create test.mdb with workgroup connection

**Usage**:
```batch
REM Run from batch file:
test-create-database.bat

REM Creates: test.mdb (in project root)
REM Requires: Dev mode (dev_mode.yaml with workgroup configuration)
```

**Features**:
- Requires dev mode at startup
- Deletes existing test.mdb automatically
- Uses workgroup connection
- Proper object ownership

### bootstrap-test-credentials.ps1

**Purpose**: Bootstrap test.mdb with known credentials

**Usage**:
```powershell
# Creates complete test database with:
# Username: testadmin
# Password: AdminPass123!
# KEK Password: TestKEK123!
```

**Use Case**:
- Automated testing
- Consistent test credentials
- No user interaction required

---

## Workgroup Security in Tests

### Why Workgroup Security Matters for Tests

**Production database**:
- Created with workgroup connection
- Authenticated user becomes database owner
- All objects inherit ownership
- Workgroup provides Layer 2 security

**Test database MUST match**:
- Created with workgroup connection (test-create-database.ps1)
- Same ownership model as production
- Tests validate workgroup security layer
- Without workgroup: tests are NOT production-compliant

### Dev Mode Configuration

**dev_mode.yaml** (parent directory of project root):
```yaml
dev_mode:
  enabled: true

workgroup:
  mdw_path: "%USERPROFILE%\_mdw\m.mdw"
  user_id: "Admin"
  password: "YourPassword"
```

**Format**:
- YAML structure with workgroup section
- mdw_path: Path to custom System.mdw file
- user_id: Custom admin user
- password: User password (can be empty string)

**Environment Variables**:
- Supports %VARNAME% syntax (e.g., %USERPROFILE%, %APPDATA%, %TEMP%)
- Expanded automatically when YAML is parsed
- Avoids hardcoded usernames in paths

**Validation**:
- Test-DevMode function checks dev_mode.enabled flag
- Get-WorkgroupConnectionString reads workgroup configuration
- See dev-mode-helpers.ps1 for implementation

### Workgroup Connection String

**Dev mode** (tests):
```
Provider=Microsoft.Jet.OLEDB.4.0;
Data Source=[project-root]\test.mdb;
Jet OLEDB:System Database=[path-to-System.mdw];
User Id=[workgroup-user-id];
Password=[workgroup-password];
```

**Production mode**:
```
Provider=Microsoft.Jet.OLEDB.4.0;
Data Source=[parent-dir]\db.mdb;
```

**Note**: Get-WorkgroupConnectionString constructs these programmatically using $PSScriptRoot

---

## Test Deployment

### Development Environment Setup

**Prerequisites**:
1. Windows PowerShell 5.1 (32-bit)
2. Jet 4.0 OLEDB driver (pre-installed)
3. Custom workgroup file (System.mdw)
4. dev_mode.yaml configuration

**Setup Steps**:
```
1. Create custom workgroup file (System.mdw)
   - Use Access UI: Tools > Security > Workgroup Administrator
   - Create new workgroup file
   - Add custom admin user

2. Configure dev mode
   - Create dev_mode.yaml in parent directory of project root
   - Set dev_mode.enabled: true
   - Configure workgroup section (mdw_path, user_id, password)

3. Create test database
   - Run: test-create-database.bat
   - Verify: test.mdb created in project root

4. Run tests
   - test-phase1.bat (module tests)
   - test-phase2.bat (schema/bootstrap tests)
   - test-phase3.bat (authentication tests)
```

### Production Deployment

**Tests are NOT deployed to production:**
- Exclude test-*.ps1 files
- Exclude test-*.bat files
- Exclude test.mdb file
- Exclude bootstrap-test-*.ps1 files

**Production only includes**:
- Main entry: db.ps1, __________.vbs
- Windows Forms UI: gui_bootstrap.ps1, gui_login.ps1
- Helper scripts (crypto-helpers.ps1, database-helpers.ps1, user-functions.ps1, etc.)
- Documentation (CLAUDE.md, docs/)
- NO test files

---

## Test Best Practices

### 1. Always Use test.mdb

```powershell
# GOOD: Explicit test database
$testDbPath = Join-Path $PSScriptRoot "test.mdb"
$connection = New-DatabaseConnection -DatabasePath $testDbPath

# BAD: Assumes default (production) database
$connection = New-DatabaseConnection
```

### 2. Validate Dev Mode First

```powershell
# GOOD: Check dev mode before ANY operations
if (-not (Test-DevMode)) {
    Write-Host "[ERROR] Tests require dev mode" -ForegroundColor Red
    exit 1
}

# BAD: Assume dev mode enabled
$connection = New-DatabaseConnection -DatabasePath "test.mdb"
```

### 3. Clean Up Resources

```powershell
# GOOD: Cleanup in finally block
try {
    $connection = New-DatabaseConnection -DatabasePath $testDbPath
    # operations...
}
finally {
    if ($connection -and $connection.State -eq 'Open') {
        $connection.Close()
        $connection.Dispose()
    }
    if ($script:sessionKEK) {
        $script:sessionKEK = $null
    }
}

# BAD: No cleanup (resource leak, security risk)
$connection = New-DatabaseConnection -DatabasePath $testDbPath
# operations...
# (connection never closed, sessionKEK never cleared)
```

### 4. Meaningful Test Messages

```powershell
# GOOD: Descriptive messages
Write-Host "[Test 5] Checking state after KEK setup..." -ForegroundColor Yellow
# test...
Write-Host "         [OK] State: KekNoAdmin (KEK exists, no admin)" -ForegroundColor Green

# BAD: Generic messages
Write-Host "Test 5" -ForegroundColor Yellow
# test...
Write-Host "OK" -ForegroundColor Green
```

### 5. Fail Fast on Dev Mode

```powershell
# GOOD: Fail immediately if not in dev mode
if (-not (Test-DevMode)) {
    Write-Host "[ERROR] Tests require dev mode" -ForegroundColor Red
    exit 1
}
# Continue with tests...

# BAD: Check dev mode inside each test
foreach ($test in $tests) {
    if (Test-DevMode) {
        # run test
    }
}
```

---

## Troubleshooting Tests

### Common Issues

**"Tests require dev mode"**:
- Create dev_mode.yaml in parent directory of project root
- Set dev_mode.enabled to true
- See docs/sec.md for configuration details

**"Database file not found"**:
- Run test-create-database.bat first
- Verify test.mdb exists in project root
- Check dev mode enabled

**"Must run 32-bit PowerShell"**:
- Use: %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe
- Jet 4.0 OLEDB driver only available in 32-bit

**"Invalid workgroup file path"**:
- Verify .mdw file exists at mdw_path in dev_mode.yaml
- Check file path is absolute
- Verify .mdw file is valid Access workgroup file

**"Incorrect workgroup credentials"**:
- Verify User Id exists in .mdw file
- Verify Password is correct
- Check credentials in dev_mode.yaml workgroup section

---

## Quick Reference

**Test Workflow**:
```
1. Enable dev mode (dev_mode.yaml)
2. Run test-create-database.bat (creates test.mdb)
3. Run test-phase1.bat (module tests)
4. Run test-phase2.bat (schema/bootstrap tests)
5. Run test-phase3.bat (authentication tests)
```

**Test Naming**:
- Scripts: test-*.ps1
- Launchers: test-*.bat
- Database: test.mdb (only)
- Helpers: bootstrap-test-*.ps1

**Dev Mode Check**:
```powershell
. (Join-Path $PSScriptRoot "dev-mode-helpers.ps1")
if (-not (Test-DevMode)) {
    Write-Host "[ERROR] Tests require dev mode" -ForegroundColor Red
    exit 1
}
```

**Test Database**:
```powershell
$testDbPath = Join-Path $PSScriptRoot "test.mdb"
$connection = New-DatabaseConnection -DatabasePath $testDbPath
```

---

## Cross-References

**Related documentation:**
- Security architecture: docs/sec.md
- Bootstrap workflow: docs/boot.md
- Main project docs: CLAUDE.md

**Source files:**
- test-phase1.ps1 - Module testing
- test-phase2.ps1 - Schema/bootstrap testing
- test-phase3.ps1 - Authentication testing
- test-create-database.ps1 - Test database creation utility
- bootstrap-test-credentials.ps1 - Automated test bootstrap
