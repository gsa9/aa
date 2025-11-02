# Bootstrap Architecture
**PowerShell Clinical Database - State Machine & First-Run (Windows Forms)**

---

## Windows Forms Architecture

**Application Entry Point**: VBScript/batch launcher (Windows Forms-only, NO console windows)

**Launch Flow**:
1. User double-clicks launcher (.vbs for production, .bat for debugging)
2. Launcher starts main orchestrator (VBScript with zero console flash, or batch with hidden console)
3. Main orchestrator hides console programmatically (Win32 API)
4. Main orchestrator detects database state (state detection function)
5. Main orchestrator routes to appropriate Windows Forms UI:
   - VirginDatabase -> Bootstrap UI (first-run setup)
   - ProductionReady -> Login UI (authentication + main menu)
   - Other states -> Error MessageBox

**Critical**: ALL user interaction via Windows Forms (MessageBox, forms, dialogs). NO console output for users.

---

## State Management Philosophy

**Scripts determine state fresh every execution (no caching, query database).**

**Complete schema**: Bootstrap creates ALL tables in single transaction:
- Core: Config table (KEK hash/salt)
- Application: Users, Patients, ClinicalRecords tables

**Single Source of Truth**: Bootstrap UI script creates ALL tables (invoked by main orchestrator). No other script creates tables.

---

## Bootstrap States

**PowerShell State Model (Windows Forms Architecture):**

| State | Description | Action (Main orchestrator automatic routing) |
|-------|-------------|-----------------------------------------------|
| **VirginDatabase** | No tables, no KEK, no users | Shows Bootstrap UI (Windows Forms first-run setup) |
| **KekNoAdmin** | Tables + KEK exist, zero admins | Shows error dialog (admin creation not yet implemented) |
| **ProductionReady** | Tables + KEK + admin(s) exist | Shows Login UI (Windows Forms login + main menu) |

**Note**: User launches application (double-click .vbs or .bat), state detection and routing are automatic. NO console windows visible.

**State Meanings:**

**VirginDatabase**:
- Database file exists but empty (no Users table)
- No KEK configuration
- No admin users
- Needs: Full bootstrap (schema + KEK + first admin)

**KekNoAdmin**:
- Tables present
- KEK_Hash + KEK_Salt in Config table
- Zero admin users (recovery scenario)
- Needs: Admin creation only

**ProductionReady**:
- Tables present
- KEK configured
- At least one active admin user
- Needs: Normal login workflow

---

## State Determination Pattern

**State Detection Logic**:

1. **Check Users table existence**:
   - If table doesn't exist → VirginDatabase

2. **Check KEK configuration**:
   - Query Config table for KEK_Hash
   - If not found or empty → VirginDatabase

3. **Check admin users**:
   - Count active admin users
   - If zero → KekNoAdmin

4. **All checks passed** → ProductionReady

**Implementation Characteristics**:
- Fresh query every call (no caching)
- Early exit on first failure (performance optimization)
- Returns string enum value (VirginDatabase | KekNoAdmin | ProductionReady)
- Handles database connection failures gracefully (returns VirginDatabase)
- Proper connection cleanup in finally block

**Implementation**: See database helpers module for current state detection function

---

## Script Routing Pattern

**Main Orchestrator Logic**:

1. **Detect current state** using state detection function
2. **Route to appropriate UI** based on state:
   - VirginDatabase → Load and execute Bootstrap UI script
   - KekNoAdmin → Show error dialog (feature not yet implemented)
   - ProductionReady → Load and execute Login UI script

**Routing Characteristics**:
- Switch/case pattern for state handling
- Script dot-sourcing for UI module loading
- Windows Forms dialogs for all user interaction
- Console remains hidden throughout execution

**Implementation**: See main orchestrator script for current routing logic

---

## Pre-Bootstrap Validation

**Environment Validation Checks**:

1. **Database file existence**:
   - Verify db.mdb exists in parent directory
   - Fail with error if not found (scripts do NOT create db.mdb files)

2. **PowerShell architecture**:
   - Verify 32-bit PowerShell (required for Jet 4.0 driver)
   - Fail with error if 64-bit process detected

3. **File system access**:
   - Test write permissions for log file
   - Fail with error if cannot write

**Validation Pattern**:
- Boolean return (true = all checks passed, false = validation failed)
- Early exit on first failure
- Clear error messages via Windows Forms dialogs
- Logging of validation failures

**Implementation**: See bootstrap UI script for current validation function

---

## Schema Bootstrap (Transactional)

**Schema Creation Pattern**:

1. **Begin transaction** (Jet/Access supports DDL transactions)
2. **Execute CREATE TABLE statements** for all tables:
   - Config table
   - Users table
   - Patients table
   - ClinicalRecords table
3. **Commit transaction** if all succeed
4. **Rollback transaction** on any error

**Transaction Characteristics**:
- All-or-nothing approach (partial schema = rollback)
- Single transaction for all DDL operations
- Each CREATE TABLE statement uses same transaction
- Error handling with full rollback
- Logging of success/failure

**Table Creation Rules**:
- Schema created during bootstrap only (NOT on every run)
- Single location for ALL table definitions (schema definitions module)
- No incremental schema changes (all tables created together)

**Implementation**: See schema definitions module and bootstrap UI script

---

## Phase Transitions

**Normal Flow:**
```
VirginDatabase
  ↓ (Bootstrap UI completes successfully)
  Creates: Schema + KEK Hash + First Admin
  ↓
ProductionReady
```

**Recovery Flow:**
```
VirginDatabase
  ↓ (Bootstrap UI creates KEK but admin creation fails)
  Creates: Schema + KEK Hash only
  ↓
KekNoAdmin
  ↓ (Admin creation UI - not yet implemented)
  Creates: First Admin
  ↓
ProductionReady
```

**Transition Rules:**
- VirginDatabase → ProductionReady (normal path)
- VirginDatabase → KekNoAdmin (partial failure, recoverable)
- KekNoAdmin → ProductionReady (recovery completion)
- ProductionReady → (no transition, operational state)

---

## Bootstrap Workflow

**Complete first-run sequence:**

**PREREQUISITE** (BEFORE running bootstrap):
- Create empty db.mdb file manually in parent directory
- Methods: Access UI (File > New > Blank Database), external ADOX script, or copy template
- NO SCRIPT creates db.mdb files (policy - production database)
- File must exist before bootstrap
- Test database: Create test.mdb in project root for testing (dev mode only)

**Database File Policies**:
- **Production (db.mdb)**: NEVER deleted by scripts, created manually only
  - Location: Parent directory (one level above project root)
  - Created manually via Access UI or ADOX script
  - NO SCRIPT creates or deletes production db.mdb (absolute rule)
- **Test (test.mdb)**: CAN be deleted/created by test utilities, but ONLY in dev mode
  - Location: Project root
  - Created by test database creation utility
  - Requires dev mode at startup (fails if not in dev mode)
  - Automatically deletes existing test.mdb to recycle bin
  - Uses workgroup connection for proper object ownership
- **Dev Mode Required**: Test utilities check dev mode status at start
- **Workgroup Security**: test.mdb created via workgroup connection (proper ownership)
- **Rationale**: Tests must use workgroup to emulate production security model
- **Enforcement**: Dev mode requirement + test-* naming convention

**Bootstrap Phases**:

0. **Dev mode configuration logging**
   - Log dev mode status (enabled/disabled)
   - Log enabled features: workgroup security, auto-login, test users
   - Log configuration paths and validation status
   - Provides diagnostic context for bootstrap process

1. **Database file validation**
   - Verify db.mdb exists in parent directory (bootstrap does NOT create it)
   - Exit with error if not found

2. **Pre-flight checks**
   - Validate 32-bit PowerShell
   - Check file system access
   - Test database connectivity

3. **Schema creation**
   - Transaction: Create all tables
   - Rollback on any failure

4. **KEK initialization**
   - Prompt for KEK password (Windows Forms dialog)
   - Derive KEK using double PBKDF2 (100k iterations)
   - Store KEK hash + salt in Config table
   - NEVER store derived KEK

5. **First admin creation**
   - Prompt for username, password, full name (Windows Forms dialog)
   - Hash password using PBKDF2 (10k iterations)
   - Insert into Users table with admin role
   - Verify record created

6. **Verification**
   - Check state = ProductionReady (using state detection function)
   - Log success
   - Inform user to restart application for login

---

## Dev Mode Logging

**Dev mode configuration logging** occurs at:
1. **Application startup** (main entry point) - logs current dev mode configuration
2. **Bootstrap process start** - logs dev mode configuration active during database initialization

**Logged Information**:
- Dev mode status (enabled/disabled)
- Configuration file path and existence
- Workgroup security (enabled/disabled, MDW path, user ID, file validation)
- Auto-login (enabled/disabled, default GUI, default username)
- Test users (enabled/disabled, user count, user list)
- Configuration errors (if any)

**Log Format**:
```
================================
Dev Mode Configuration Report
================================
Dev Mode: ENABLED
  Config Path: [path to dev_mode.yaml]

Feature Status:
  [ENABLED] Workgroup Security
    - User ID: [username]
    - MDW Path: [path to System.mdw]
    - MDW File: EXISTS
  [DISABLED] Auto-Login
  [ENABLED] Test Users (3 configured)
    - Users: admin, doctor, receptionist
================================
```

**Purpose**:
- Diagnostics: Understand what dev features were active during bootstrap
- Troubleshooting: Identify configuration issues early
- Audit trail: Record dev mode settings in log.txt

**Implementation**: See `Write-DevModeLog` function in dev-mode-helpers.ps1

---

## Script State Guards

**State Validation Pattern**:

- **Main orchestrator** validates state before routing to UI scripts
- **State detection** occurs fresh on every application launch
- **UI scripts** (bootstrap, login) are invoked AFTER state is validated
- **Error handling** for unexpected states (Windows Forms error dialog)

**Validation Characteristics**:
- No state caching (query database every time)
- Switch/case pattern for state handling
- Early exit with error for unexpected states
- Logging of state transitions

**Implementation**: See main orchestrator script for state validation logic

---

## Database Schema Overview

**Core Tables**:

**Config Table** - System configuration:
- Primary key: Auto-increment ID
- Unique constraint: ConfigKey
- Purpose: Stores KEK hash/salt and application settings
- Bootstrap data: KEK_Hash and KEK_Salt entries

**Users Table** - User authentication and authorization:
- Primary key: Auto-increment ID
- Unique constraint: Username
- Purpose: Stores password hashes, salts, roles, and user metadata
- Key fields: Username, PasswordHash, PasswordSalt, Role, IsActive

**Patients Table** - Patient data (encrypted):
- Primary key: Auto-increment ID
- Purpose: Stores encrypted patient names and demographics
- Key fields: EncryptedName, IV (initialization vector), DateOfBirth, Gender

**ClinicalRecords Table** - Clinical data:
- Primary key: Auto-increment ID
- Foreign key: PatientID (links to Patients table)
- Performance index: PatientID
- Purpose: Stores diagnoses, treatments, notes
- Key fields: PatientID, RecordType, Diagnosis, Treatment, Notes

**Schema Authority**: All DDL statements live in schema definitions module. See that module for current CREATE TABLE and CREATE INDEX statements.

---

## Error Recovery Strategies

**Scenario 1: Bootstrap fails during table creation**
- Transaction rollback ensures no partial tables
- User re-launches application (state still VirginDatabase, bootstrap UI appears again)

**Scenario 2: Bootstrap creates tables but KEK creation fails**
- State remains VirginDatabase (no KEK hash in Config table)
- User re-launches application (bootstrap UI appears again)
- Script detects partial tables and skips table creation if already exist

**Scenario 3: KEK created but admin creation fails**
- State becomes KekNoAdmin
- User launches application (error dialog appears - admin creation UI not yet implemented)
- Manual database recovery required

**Scenario 4: User forgets KEK password**
- No recovery possible (by design for security)
- Must drop database and restart bootstrap
- Document this clearly to users

---

## Development Testing Helpers

**Database Reset Utility** (dev only, never deploy):
- Deletes database file to allow clean re-initialization
- Requires user to manually recreate db.mdb (policy compliance)
- Triggers bootstrap workflow on next application launch

**State Checker Utility** (diagnostic tool):
- Displays current database state with color coding
- Shows detailed checks: table existence, user counts, KEK configuration, admin counts
- Useful for troubleshooting bootstrap issues
- Uses state detection function for consistency

**Implementation**: See dev utility scripts in project root (if present)

---

## Quick Reference

**State Detection**: State detection function returns VirginDatabase | KekNoAdmin | ProductionReady

**State Guards**: Main orchestrator validates state before routing to UI scripts

**Transitions**: VirginDatabase → KekNoAdmin → ProductionReady (or skip KekNoAdmin on success)

**Transaction Pattern**: All tables created in single transaction (rollback on failure)

**Recovery**: KekNoAdmin state enables recovery from partial bootstrap

---

## Cross-References

**Related documentation:**
- Security patterns and KEK management: docs/sec.md
- Test design and dev mode: docs/testing.md
- Documentation maintenance: docs/dm.md

**Source modules:**
- Database helpers: Connection management, state detection, CRUD operations
- Crypto helpers: Password hashing, KEK management
- User management: User creation, authentication
- Schema definitions: All CREATE TABLE and CREATE INDEX statements

**Implementation**: See project root for current script organization
