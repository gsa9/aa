# Security Documentation
**Clinical Database - Double PBKDF2 KEK Security**

---

## Overview

**Purpose**: Secure storage and validation of the master encryption key (KEK)

**Core Principle**: Database stores KEK verification hash ONLY - never the encryption key itself.

**Implementation**: PowerShell with .NET Framework cryptography (no admin rights required)

---

## Source of Truth

**Read source modules for current implementations:**
- **Crypto helpers** - All cryptographic functions (PBKDF2, double PBKDF2, AES-256)
- **Bootstrap UI** - Windows Forms bootstrap workflow (KEK + admin creation)
- **Login UI** - Windows Forms login workflow (user authentication + KEK validation)
- **Database helpers** - Database operations
- **User management** - User creation and authentication

This document provides security patterns only. Source files are authoritative for implementation details.

---

## Core Security Principle

**KEK (Key Encryption Key) is NEVER stored in database. Only verification hash is stored.**

**Why This Matters:**
- Database breach → attacker gets hash, not encryption key
- Attacker must crack PBKDF2 hash (100,000 iterations) to derive KEK
- Defense-in-depth: breach + successful crack required (not just breach)
- KEK stored in session-scoped variable only (memory only, never persisted)

**Attack Scenarios:**
1. **Database file stolen** → Attacker has KEK hash → Must crack 100k iterations → Time-intensive
2. **SQL injection** → Attacker reads KEK hash → Same as above, must crack
3. **Memory dump during session** → Could expose session KEK variable → Requires active session + memory access

**Risk Reduction:**
- High iteration count (100,000) makes cracking computationally expensive
- Session-only KEK storage limits exposure window
- No KEK in database = no permanent exposure

---

## Double PBKDF2 Pattern

**Setup (Bootstrap Workflow)**:

1. **Derive KEK and create verification hash** (double PBKDF2):
   - First PBKDF2: PBKDF2(password, salt, 100k iterations) → Derived KEK (32 bytes)
   - Second PBKDF2: PBKDF2(derived KEK, salt, 100k iterations) → KEK hash (32 bytes)

2. **Store verification hash and salt** in Config table:
   - INSERT ConfigKey='KEK_Hash', ConfigValue=<hash>, Description='Verification hash for KEK'
   - INSERT ConfigKey='KEK_Salt', ConfigValue=<salt>, Description='Salt for KEK derivation'

3. **CRITICAL**: Derived KEK is NOT stored in database

**Validation (Login Workflow)**:

1. **Retrieve hash and salt** from Config table:
   - Query KEK_Hash and KEK_Salt from database

2. **Validate user-provided password**:
   - First PBKDF2: PBKDF2(user input, stored salt, 100k) → Derived KEK
   - Second PBKDF2: PBKDF2(derived KEK, stored salt, 100k) → Computed hash
   - Constant-time comparison: Computed hash vs. stored hash

3. **Store KEK in session if valid**:
   - Success: Store derived KEK in session-scoped variable (memory only, never persisted)
   - Failure: Log error, reject authentication

**Session Cleanup**:

- On logout, timeout, or error: Clear session KEK variable (set to null)
- Ensures KEK is not left in memory after session ends
- Always clear in finally blocks

**Implementation**: See crypto helpers module for double PBKDF2 functions

---

## Critical Security Rules

### [NEVER]

- Store KEK in database (only hash)
- Store KEK in persistent files
- Use single PBKDF2 for both derivation and storage
- Skip salt generation (use cryptographic random number generator)
- Reuse salts across users/records
- Log or display KEK values

### [ALWAYS]

- Use double PBKDF2 (derive → hash)
- Store KEK in session-scoped variable only (memory only, never persisted)
- Generate unique random salt per KEK/user (32 bytes minimum)
- Clear session KEK on logout/timeout/error (in finally blocks)
- Use constant-time comparison for hash validation (timing attack prevention)
- Reference source files for current API and implementation

---

## Defense-in-Depth Architecture

**5-Layer Security Model:**

1. **Physical Security** - Practice environment access control
2. **Workgroup Security** - n.mdw authentication (if configured)
3. **Network Isolation** - Intranet-only, no remote access
4. **File System Security** - Windows permissions on db.mdb
5. **Cryptographic Security** - Double PBKDF2 + high iterations

**Justification for 100,000 iterations:**
- PowerShell/.NET can handle high iteration counts (~200-300ms per operation)
- Industry standard for password-based key derivation (OWASP recommendations)
- Provides strong protection against brute-force attacks
- Defense-in-depth compensates for any single layer compromise
- Acceptable performance trade-off for security-critical operation

---

## Workgroup Security (Dev Mode & Testing)

**Purpose**: Separate development and production environments using Access workgroup security (.mdw files).

### Overview

**Access Workgroup Security** is a user-level security system in Microsoft Access that:
- Controls database and object access
- Assigns permissions to users and groups
- Uses a separate workgroup file (System.mdw) for authentication
- Provides Layer 2 defense-in-depth (see above)

**Important**: Workgroup security is **optional** and **supplementary**. Primary security comes from cryptography (KEK + PBKDF2 + AES-256).

### Production vs Development

**Production Mode** (Default):
- Uses Windows default System.mdw (standard Access installation)
- Default "Admin" user with empty password
- Custom .mdw configured Admin user with READ/WRITE DATA permissions only
- No schema modification permissions for production users
- Connection string: `Provider=Microsoft.Jet.OLEDB.4.0;Data Source=db.mdb;`
- No dev_mode.yaml required

**Development Mode** (Optional):
- Uses custom System.mdw file (isolated from production)
- Custom admin user with full permissions (schema creation/modification)
- Requires workgroup credentials (User Id + Password)
- Enables safe testing without affecting production workgroup
- Connection string: `Provider=Microsoft.Jet.OLEDB.4.0;Data Source=db.mdb;Jet OLEDB:System Database=path\to\System.mdw;User Id=...;Password=...;`
- Requires dev_mode.yaml configuration

### Database Creation with Workgroup

**Critical for Object Ownership:**

When creating a database file (.mdb) through a workgroup connection:
1. The authenticated user becomes the database **creator/owner**
2. All objects created inherit ownership from the authenticated user
3. Permissions are based on workgroup security model
4. Database is "bound" to that workgroup for security

**Why This Matters**:
- test.mdb MUST be created with workgroup connection in dev mode
- Ensures proper object ownership (tables, queries, etc.)
- Tests emulate production security model with isolated workgroup
- Without workgroup, tests are not production-compliant

**Example** (ADOX with workgroup):
```powershell
# Get workgroup connection string (dev mode)
$connectionString = Get-WorkgroupConnectionString -dbPath $dbPath

# Create database with ADOX (authenticated user becomes owner)
$catalog = New-Object -ComObject ADOX.Catalog
$catalog.Create($connectionString)  # Database now has proper ownership
```

### dev_mode.yaml Configuration

**Location**: Parent directory of project root (alongside db.mdb)

**Format** (YAML structure):
```yaml
dev_mode:
  enabled: true

workgroup:
  mdw_path: "%USERPROFILE%\_mdw\m.mdw"
  user_id: "Admin"
  password: "YourPassword"
```

**Workgroup Section**:
- mdw_path: Path to custom System.mdw (must exist)
- user_id: Custom admin user
- password: User password (can be empty string)

**Environment Variables**:
- Supports %VARNAME% syntax (e.g., %USERPROFILE%, %APPDATA%, %TEMP%)
- Expanded automatically when YAML is parsed
- Use environment variables to avoid hardcoded usernames in paths

**Test-DevMode Function** (dev-mode-helpers.ps1):
- Checks if dev_mode.yaml exists in parent directory
- Returns `$true` if file exists AND dev_mode.enabled is true
- Returns `$false` otherwise (production mode)
- Used by scripts to determine connection type

**Get-WorkgroupConnectionString Function** (dev-mode-helpers.ps1):
- Production mode: Returns basic connection string (Access uses default System.mdw)
- Dev mode: Reads dev_mode.yaml and builds workgroup connection string
- Uses $PSScriptRoot for path resolution (no hardcoded paths)
- Validates .mdw file exists (fails early if misconfigured)
- Requires workgroup section with mdw_path, user_id, and password

### Test Scripts & Dev Mode

**Test scripts MUST run in dev mode:**

1. **Pre-flight check**:
   ```powershell
   if (-not (Test-DevMode)) {
       Write-Host "[ERROR] Tests require dev mode (dev_mode.yaml with workgroup configuration)" -ForegroundColor Red
       exit 1
   }
   ```

2. **Workgroup connection for test.mdb**:
   ```powershell
   $connection = New-DatabaseConnection -DatabasePath $testDbPath
   # Uses Get-WorkgroupConnectionString internally (dev mode)
   ```

3. **test.mdb deletion/creation**:
   - ONLY allowed in dev mode
   - Test utilities check dev mode at startup
   - Tests fail if not in dev mode (not production-compliant)
   - test-create-database.ps1 is dedicated TEST UTILITY

**Test Database Creation** (test-create-database.ps1):
   - TEST UTILITY: Only creates test.mdb (project root)
   - Requires dev mode at startup (fails immediately if not in dev mode)
   - Automatically deletes existing test.mdb to recycle bin
   - Uses workgroup connection for proper object ownership
   - Never touches production db.mdb (not its concern)
   - Follows test-* naming convention (clearly identifiable as test utility)

**Rationale**:
- Tests emulate production security with isolated workgroup
- Workgroup connection ensures proper object ownership
- Dev mode prevents accidental production database operations
- Tests verify workgroup security layer works correctly
- Test utilities isolated by dev mode requirement and test-* naming

### Security Implications

**Workgroup Security is Layer 2** (see Defense-in-Depth above):
- **Primary Security**: KEK + PBKDF2 + AES-256 (cryptographic)
- **Secondary Security**: Workgroup access control (database engine)

**What Workgroup Security Provides**:
- Prevents unauthorized database file opening in Access UI
- Controls schema modification permissions
- Separates dev/test/production environments
- Adds access control at database engine level

**What Workgroup Security Does NOT Provide**:
- **Does NOT** protect data at rest (cryptography does)
- **Does NOT** replace KEK-based encryption
- **Does NOT** secure passwords (PBKDF2 does)
- **Is NOT** the primary security mechanism

**Production Security Model**:
- Default "Admin" user: READ/WRITE DATA only (in custom .mdw)
- Cannot modify schema or create new objects
- Can perform CRUD operations on existing tables
- Database was created with custom admin (proper ownership)
- Production users connect with default System.mdw (no custom .mdw needed)

### Deployment Considerations

**Production Deployment**:
- No workgroup configuration needed on production machines
- No dev_mode.yaml required
- Access uses Windows default System.mdw automatically
- Custom .mdw file configured to allow default Admin user read/write data
- Scripts use basic connection string (no workgroup parameters)

**Development Environment**:
- Create custom System.mdw with custom admin user
- Create dev_mode.yaml in parent directory with workgroup configuration
- Test scripts verify dev mode before running
- test.mdb created/deleted as needed (dev mode only)

**Testing Production Mode**:
- Set dev_mode.enabled to false in dev_mode.yaml
- Test-DevMode returns `$false` (production mode)
- Scripts use basic connection string
- Tests will fail (as designed - dev mode required)

### Best Practices

1. **Never commit dev_mode.yaml** - User-specific configuration with credentials
2. **Keep custom .mdw secure** - Contains dev environment security
3. **Document .mdw setup** - Assume .mdw exists, configure path in dev_mode.yaml
4. **Test both modes** - Production (no workgroup) and dev (with workgroup)
5. **Fail early** - Tests should check dev mode immediately
6. **Use workgroup for test.mdb creation** - Ensures proper ownership
7. **Isolate environments** - Separate .mdw files for dev/test/production

### Cross-References

- **dev-mode-helpers.ps1** - Test-DevMode, Get-WorkgroupConnectionString functions
- **database-helpers.ps1** - New-DatabaseConnection uses workgroup connection string
- **CLAUDE.md** - Test Database Policy (Dev Mode Only) section
- **docs/boot.md** - Database File Policies section

---

## Credential Systems

**Two separate authentication systems:**

### User Passwords (Per-User Authentication)

**Purpose**: Login authentication, access control

**Storage**: tblUsers table (PasswordHash, Salt columns)

**Algorithm**: Single PBKDF2 (10,000 iterations)

**Setup:**
```powershell
$result = New-PasswordHash -password $userPassword -iterations 10000
# Returns: @{Hash = "base64...", Salt = "base64..."}

INSERT INTO Users (Username, PasswordHash, PasswordSalt, FullName, Role)
VALUES ($username, $result.Hash, $result.Salt, $fullName, $role)
```

**Validation:**
```powershell
$isValid = Test-Password `
    -password $userInput `
    -storedHash $user.PasswordHash `
    -storedSalt $user.PasswordSalt `
    -iterations 10000
```

### KEK Password (Shared System Key)

**Purpose**: Encrypting/decrypting patient data

**Storage**: Config table (KEK_Hash, KEK_Salt columns)

**Algorithm**: Double PBKDF2 (100,000 iterations)

**Setup:**
```powershell
$result = New-KekWithHash -password $kekPassword -iterations 100000
# Returns: @{DerivedKEK = "...", KEKHash = "...", Salt = "..."}

INSERT INTO Config (ConfigKey, ConfigValue) VALUES ('KEK_Hash', $result.KEKHash)
INSERT INTO Config (ConfigKey, ConfigValue) VALUES ('KEK_Salt', $result.Salt)
# DerivedKEK is NOT stored
```

**Validation:**
```powershell
$validation = Test-KekPassword -password $kekInput -storedHash $hash -storedSalt $salt
if ($validation.IsValid) {
    $script:sessionKEK = $validation.DerivedKEK
}
```

---

## Common Security Mistakes

### [WRONG] Single PBKDF2 Storage (INSECURE)

```powershell
# WRONG - stores encryption key in database
$kek = PBKDF2($password, $salt, 100000)
INSERT INTO Config (ConfigKey, ConfigValue) VALUES ('KEK_Master', $kek)
# Database breach = immediate data decryption!
```

### [CORRECT] Double PBKDF2 Storage (SECURE)

```powershell
# CORRECT - stores verification hash, not key
$derivedKek = PBKDF2($password, $salt, 100000)
$kekHash = PBKDF2($derivedKek, $salt, 100000)
INSERT INTO Config (ConfigKey, ConfigValue) VALUES ('KEK_Hash', $kekHash)
# Database breach requires hash cracking
```

### [WRONG] Mismatched Setup/Validation

```powershell
# Setup uses single PBKDF2
$kekHash = PBKDF2($password, $salt, 100000)
INSERT INTO Config VALUES ('KEK_Hash', $kekHash)

# Validation uses double PBKDF2 - WILL NEVER MATCH
$derivedKek = PBKDF2($userInput, $salt, 100000)
$computedHash = PBKDF2($derivedKek, $salt, 100000)
# computedHash ≠ kekHash (different derivation paths)
```

### [WRONG] Storing KEK in Form Variables

```powershell
# WRONG - persists beyond session
$form.Tag = $derivedKek  # Could leak if form serialized

# CORRECT - session variable only
$script:sessionKEK = $derivedKek  # Cleared on exit
```

---

## AES-256 Encryption (Patient Data)

**Purpose**: Encrypt patient names and sensitive fields

**Key Source**: `$script:sessionKEK` (derived KEK stored in session)

**Algorithm**: AES-256-CBC with random IV per record

### Encryption

```powershell
# Encrypt patient name using session KEK
$encrypted = Protect-Text -plainText $patientName -keyBase64 $script:sessionKEK

# Returns: @{EncryptedData = "base64...", IV = "base64..."}

INSERT INTO Patients (EncryptedName, IV, DateOfBirth, Gender)
VALUES ($encrypted.EncryptedData, $encrypted.IV, $dob, $gender)
```

### Decryption

```powershell
# Retrieve encrypted data and IV
$patient = ExecuteReader "SELECT EncryptedName, IV FROM Patients WHERE PatientID = $id"

# Decrypt using session KEK
$plainName = Unprotect-Text `
    -encryptedDataBase64 $patient.EncryptedName `
    -ivBase64 $patient.IV `
    -keyBase64 $script:sessionKEK
```

**Security Notes:**
- Each record has unique random IV (initialization vector)
- IV stored alongside encrypted data (not secret)
- KEK must be loaded in `$script:sessionKEK` before encryption/decryption
- Without valid KEK, encrypted data is unreadable

---

## Performance Considerations

**PBKDF2 Timings (PowerShell/.NET):**
- **User passwords** (10,000 iterations): ~30-50ms per operation
- **KEK** (100,000 iterations): ~200-300ms per operation

**Impact:**
- Bootstrap (first-time setup): One-time cost (~300ms for KEK derivation)
- Login: ~350ms total (user auth + KEK validation)
- Session operations: No PBKDF2 overhead (KEK already in memory)

**Optimization:**
- High iterations only during authentication (acceptable UX)
- Session KEK reused for all encryption/decryption (fast AES operations)
- No performance impact on patient data operations after login

---

## Implementation Checklist

**Before implementing authentication:**

1. [OK] Read crypto-helpers.ps1 for current function signatures
2. [OK] Read gui_bootstrap.ps1 for setup workflow example
3. [OK] Read gui_login.ps1 for validation workflow example
4. [OK] Use double PBKDF2 pattern (derive → hash)
5. [OK] Store hash only in database, never store KEK
6. [OK] Store KEK in `$script:sessionKEK` (session memory only)
7. [OK] Clear KEK on logout/error in finally block
8. [OK] Test setup → login → encryption → decryption workflow

---

## Database Schema

**Config Table:**
```sql
CREATE TABLE Config (
    ConfigID AUTOINCREMENT PRIMARY KEY,
    ConfigKey TEXT(50) NOT NULL,
    ConfigValue MEMO NOT NULL,
    Description TEXT(255),
    ModifiedDate DATETIME DEFAULT Now()
)

-- KEK storage (hash only)
INSERT INTO Config (ConfigKey, ConfigValue, Description)
VALUES ('KEK_Hash', '<base64-hash>', 'Verification hash for KEK (double PBKDF2 - 100k iterations)')

INSERT INTO Config (ConfigKey, ConfigValue, Description)
VALUES ('KEK_Salt', '<base64-salt>', 'Salt for KEK derivation and hashing')
```

**Users Table:**
```sql
CREATE TABLE Users (
    UserID AUTOINCREMENT PRIMARY KEY,
    Username TEXT(50) NOT NULL,
    PasswordHash TEXT(255) NOT NULL,
    PasswordSalt TEXT(255) NOT NULL,
    FullName TEXT(100),
    Role TEXT(20),
    IsActive BIT DEFAULT True,
    CreatedDate DATETIME DEFAULT Now(),
    LastLogin DATETIME
)

CREATE UNIQUE INDEX idx_Users_Username ON Users (Username)
```

**Patients Table:**
```sql
CREATE TABLE Patients (
    PatientID AUTOINCREMENT PRIMARY KEY,
    EncryptedName TEXT(255) NOT NULL,  -- AES-256 encrypted
    IV TEXT(255) NOT NULL,             -- Initialization vector (unique per record)
    DateOfBirth DATETIME,
    Gender TEXT(10),
    ContactInfo TEXT(255),
    CreatedBy INTEGER,
    CreatedDate DATETIME DEFAULT Now(),
    ModifiedDate DATETIME
)
```

---

## Quick Reference

**Security Function Categories:**

| Category | Purpose | Algorithm | Iterations |
|----------|---------|-----------|------------|
| **Password Hashing** | User authentication | PBKDF2 | 10,000 |
| **KEK Management** | Master key derivation/validation | Double PBKDF2 | 100,000 |
| **Data Encryption** | Patient data protection | AES-256-CBC | N/A |

**Implementation**: See crypto helpers module for current function signatures and usage

---

## Security Audit Checklist

**Verify your implementation:**

1. [OK] Is KEK stored in database? → **NO** (only verification hash)
2. [OK] Is KEK stored in persistent files? → **NO**
3. [OK] Is KEK cleared on logout? → **YES** (session variable set to null in finally blocks)
4. [OK] Does setup use double PBKDF2? → **YES** (KEK derivation + hash creation)
5. [OK] Does validation use double PBKDF2? → **YES** (KEK re-derivation + hash comparison)
6. [OK] Are iteration counts sufficient? → **YES** (10k for passwords, 100k for KEK)
7. [OK] Are salts unique per user/KEK? → **YES** (cryptographic RNG, 32 bytes minimum)
8. [OK] Is constant-time comparison used? → **YES** (timing attack prevention)
9. [OK] Are IVs unique per encrypted record? → **YES** (AES random IV generation)
10. [OK] Is error handling secure? → **YES** (KEK cleared in finally blocks)

---

## Cross-References

**Related Documentation:**
- Main project documentation: CLAUDE.md
- Bootstrap workflow and state machine: docs/boot.md
- Test design and dev mode: docs/testing.md
- Documentation maintenance: docs/dm.md

**Source Modules:**
- Crypto helpers: All cryptography functions (PBKDF2, double PBKDF2, AES-256)
- Bootstrap UI: Windows Forms first-run setup workflow
- Login UI: Windows Forms authentication workflow
- Database helpers: Connection management, CRUD operations
- User management: User creation, authentication, authorization

**Implementation**: See project root for current module organization
