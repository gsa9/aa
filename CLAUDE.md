# CLAUDE.md
**Clinical Patient Data Management System - Windows PowerShell + Access 2003**

---

## Meta: Documentation Architecture

**Philosophy**: Token-efficient AI guidance. Steer Claude toward correct patterns, away from pitfalls. Never explain what code already shows.

**Purpose**: Help Claude avoid mistakes, not provide complete reference. Code is self-documenting.

**MANDATORY**: Read `docs/dm.md` before any doc work (anti-drift principles, AI guidance focus)

**File Responsibilities**:
- **CLAUDE.md**: Project identity, structure, commands, quick reference
- **docs/dm.md**: Documentation philosophy (MANDATORY before doc updates)
- **docs/boot.md**: Bootstrap state machine, workflow gotchas
- **docs/sec.md**: Security patterns, KEK principles, double PBKDF2
- **docs/testing.md**: Test patterns, dev mode, workgroup testing
- **docs/powershell.md**: PowerShell gotchas, critical constraints, non-obvious patterns
- **docs/ui.md**: Windows Forms patterns, layout standards
- **next_session.md**: Incomplete work only (delete completed items)
- **Source files**: Authoritative for implementation (read these, not docs)

---

## Commands & Session Management

**Keywords**: resume | rl | rsec | rboot | rdm | rtest | rps | rui | ud

| Command | Action |
|---------|--------|
| **resume/continue** | Read next_session.md, continue work (MAIN) |
| **rl** | Read log.txt, troubleshoot |
| **rsec** | Read docs/sec.md (security) |
| **rboot** | Read docs/boot.md (bootstrap) |
| **rtest** | Read docs/testing.md (test design) |
| **rdm** | Read docs/dm.md (doc maintenance) |
| **rps** | Read docs/powershell.md (PowerShell patterns) |
| **rui** | Read docs/ui.md (Windows Forms UI guidelines) |
| **ud** | Update docs (reads dm.md, reviews context, updates docs) |

**next_session.md**: Contains ONLY incomplete work. Update on: session end, milestone, blocker, user request.

**Resume Protocol**: Read next_session.md → Review next steps → Check blockers → Begin work

---

## Critical Policies

### File Deletion (ABSOLUTE RULE)

**Claude Code Environment: Use bash rm -f ONLY.** Simple, direct, effective in this environment.

**REQUIRED for Claude**:
```bash
bash rm -f file1.ps1 file2.bat file3.txt
```

**Multiple files**:
```bash
bash rm -f test-*.ps1 cleanup-*.bat temp*.txt
```

**Rationale**:
- Works reliably in Claude Code interface
- Simple single command
- No complex PowerShell COM objects needed
- Direct file system access

**Note**: This rule applies to Claude in the Claude Code interface. PowerShell scripts themselves may use Shell.Application COM object for recycle bin deletion when run normally. However, Claude should ONLY use bash rm -f when deleting files in the Claude Code environment.

**Zero exceptions** - All file types (.ps1, .bat, .mdb, .txt, .md, temp)

### Character Encoding (ABSOLUTE RULE)

**ASCII/ANSI ONLY. NO Unicode symbols in source files.** Prevents PowerShell syntax errors.

**FORBIDDEN**: Checkmarks, bullets, arrows, symbols, emoji (any non-ASCII 0x20-0x7E)

**REQUIRED**: `[OK]` `[ERROR]` `[WARN]` `[INFO]` `[SUCCESS]` `[FAIL]` `- * + > < ^ v ->`

**Encoding by file type**:
- .ps1: UTF-8 no BOM (ASCII content only)
- .bat: ANSI/ASCII only
- .md: ASCII preferred
- All code: ASCII 0x20-0x7E only

**Zero exceptions** - Use plain text status messages in all scripts.

### Windows Forms UI Architecture (ABSOLUTE RULE)

**Application is Windows Forms-only. NO console windows visible at any time.** User-friendly GUI application with no terminal exposure.

**FORBIDDEN**: Console-based user interaction (Read-Host, Write-Host for UI, console prompts)

**REQUIRED**:
- VBScript launcher (production) or batch launcher (debugging)
- VBScript provides zero console flash (no window at all)
- Batch launcher shows -WindowStyle Hidden flag (brief flash on some systems)
- Main orchestrator hides console programmatically (Win32 API ShowWindow)
- Bootstrap and login workflows use dedicated Windows Forms UI scripts
- All user interaction through Windows Forms (MessageBox, forms, dialogs)
- All error messages via MessageBox (NOT console output)
- Logging function for background logging (log file in project root)

**Architecture Flow**:
- VBScript/Batch launcher -> Main orchestrator (state detection) -> Route to appropriate UI workflow
- First-run: Bootstrap UI (schema creation, KEK setup, admin creation)
- Subsequent: Login UI (user authentication, KEK validation, role-based routing)
- Logout: Returns to login UI (session cleanup, KEK clearing, connection closure)

**Implementation**: See entry point scripts for console hiding and routing patterns

**UI Design Standards**: Read docs/ui.md (rui) BEFORE creating or modifying Windows Forms UI. Only read once per conversation (context persists). Not needed for business logic changes.

**Rationale**:
- Professional user experience (no terminal windows)
- VBScript completely eliminates console window flash
- Batch launcher useful for debugging (shows errors if PowerShell fails)
- Consistent Windows application behavior
- User-friendly error messages and dialogs

**Zero exceptions** - All production scripts MUST use Windows Forms for user interaction.

### No Legacy Code (ABSOLUTE RULE)

**NO legacy code in codebase. Deleted code is better than commented code.** Clean, forward-looking codebase only.

**FORBIDDEN**:
- Keeping old/unused scripts "for reference"
- Commented-out code blocks
- Deprecated functions marked with warnings
- "Legacy" or "Old" prefix/suffix on files
- Version suffixes on files (file_v1.ps1, file_v2.ps1, file_old.ps1)

**REQUIRED**:
- Delete unused scripts immediately (use bash rm -f per File Deletion policy)
- Remove all references from documentation when deleting code
- Update all cross-references to point to new implementations
- Source control is the history - no need to keep old code in working directory

**Development Process**:
1. Identify obsolete code (replaced by new implementation)
2. Delete file (bash rm -f filename.ps1)
3. Search all documentation for references (CLAUDE.md, docs/*.md)
4. Remove/update all references found
5. Verify no broken cross-references remain

**Rationale**:
- Clean codebase = easier to understand and maintain
- No confusion about which version to use
- Documentation stays current and accurate
- Source control provides history if needed
- Forces intentional code evolution

**Exception for Utilities**: Utility scripts with specific ongoing purposes (like remove_nul.bat for Windows edge cases) are NOT legacy code. See "Windows-Specific Utilities" section for documented utilities.

**Zero exceptions for unused code** - Legacy code is deleted code. No "just in case" archives in working directory.

### Database File Creation (ABSOLUTE RULE)

**NO SCRIPT creates db.mdb files. Database file must exist before running ANY script.** Clinical project = explicit external database creation only.

**FORBIDDEN**: Auto-creation of db.mdb in ANY script (bootstrap, helpers, tests, etc.)

**REQUIRED**:
- Production database (db.mdb) created MANUALLY before launching application
- Methods: Access UI (File > New > Blank Database) or external ADOX script
- Save to: db.mdb in parent directory (one level above project root)
- Bootstrap script validates file exists, then creates SCHEMA only
- Database connection function MUST fail if db.mdb does not exist
- Error message must direct user to create db.mdb manually

**Test Database Creation**:
- TEST UTILITY for creating test.mdb ONLY (not production db.mdb)
- Requires dev mode (configuration file with workgroup settings)
- Creates test.mdb in project root with workgroup connection
- Automatically deletes existing test.mdb (to recycle bin)
- Ensures proper object ownership (production-compliant testing)
- See test-create-database script for implementation

**Rationale**:
- Prevents accidental database file creation by any script
- User has explicit control over production database file creation
- Clear separation: external tool creates file, bootstrap creates schema
- Test utility isolated to dev mode only

**Zero exceptions** - NO script creates db.mdb files.

### Test Script Creation (ABSOLUTE RULE)

**DO NOT create test scripts unless explicitly requested by the user.** Tests are created only on user demand.

**Details**: See docs/testing.md for test policies, dev mode requirements, and test design patterns.

### Path Handling (ABSOLUTE RULE)

**NEVER hardcode usernames in paths. ALWAYS use environment variables or relative paths.** Ensures portability and prevents environment-specific code.

**FORBIDDEN**: Hardcoded usernames in paths (`C:\Users\<username>\...`)

**REQUIRED**:
- Use `$env:USERPROFILE` for user profile directory
- Use `$PSScriptRoot` for paths relative to script location
- Use `Split-Path -Parent $PSScriptRoot` for parent directory
- Use `Join-Path` to construct paths programmatically

**Examples**:
```powershell
# WRONG - Hardcoded username
$dbPath = "C:\Users\<username>\some_project\db.mdb"

# CORRECT - Relative to script location
$parentDir = Split-Path -Parent $PSScriptRoot
$dbPath = Join-Path $parentDir "db.mdb"

# WRONG - Hardcoded in documentation
Location: C:\Users\<username>\project_dir\dev_mode.yaml

# CORRECT - Abstract documentation
Location: Parent directory of project root (dev_mode.yaml)
```

**Rationale**:
- Code works on any machine without modification
- Documentation doesn't expose specific environment details
- No assumptions about user account names
- Easier to share and deploy code

**Zero exceptions** - All paths MUST be environment-agnostic.

---

## Mission & Structure

**Primary**: Windows PowerShell clinical database, encrypted patient data
**Database**: Access 2003 (.mdb), Jet 4.0
**Security**: Double PBKDF2 KEK + AES-256 (no admin rights)
**Authority**: Single source of truth for development

**Project Root Structure**:
```
log.txt, CLAUDE.md, next_session.md
docs/ (dm.md, boot.md, sec.md)
*.ps1 (all scripts in root, NEVER subfolders)
*.bat (batch launchers)
*.vbs (VBScript launchers - production use, no console flash)
test.mdb (test database, in project root - dev mode only)
dev_mode.yaml (optional - dev mode configuration, in parent directory)
```

**Production Database**: `db.mdb` (one level above project root)

---

## PowerShell Environment

**CRITICAL**: Windows PowerShell 5.1 (32-bit) ONLY - NOT 64-bit, NOT PowerShell 7

| Requirement | Value |
|-------------|-------|
| Version | Windows PowerShell 5.1 |
| Architecture | 32-bit (Jet 4.0 driver requirement) |
| Path | `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe` |
| Test command | `%SystemRoot%\SysWOW64\...\powershell.exe -ExecutionPolicy Bypass -File script.ps1` |

**Launcher Templates**: See docs/powershell.md for VBScript and Batch launcher templates

---

## Windows-Specific Utilities

**remove_nul.bat**: Deletes literal 'nul' files (Windows reserved device name edge case). Run if 'nul' file appears in project root.

---

## Security Architecture

| Component | Algorithm | Iterations | Storage |
|-----------|-----------|------------|---------|
| User Passwords | PBKDF2 | 10,000 | Users table (hash + salt) |
| KEK Password | Double PBKDF2 | 100,000 | Config table (hash + salt ONLY) |
| Patient Names | AES-256-CBC | N/A | Patients table (encrypted + IV) |

**Details**: See docs/sec.md for double PBKDF2 pattern, KEK management, and implementation

---

## Database Operations

**Connection**: Jet 4.0 OLE DB provider

**Core Tables**: Config, Users, Patients, ClinicalRecords

**User Roles**: admin (user management) | md (medical doctor, clinical features)

**Security Requirements**: Parameterized queries, connection cleanup in finally blocks, clear session KEK in finally blocks

**Details**: See docs/boot.md for schema, docs/powershell.md for patterns

---

## Script Architecture

**Production Layers**:
- Entry Point: VBScript/Batch launcher + Main orchestrator (state detection and routing)
- UI Layer: Windows Forms scripts for bootstrap, login, and role-based interfaces
- Helper Modules: Cryptography, database operations, user management, schema definitions
- Utilities: Platform-specific helper scripts

**Role-Based Routing** (after login):
- admin role → Admin panel (user management CRUD)
- md role → Clinical interface (patient and records management)

**Test Infrastructure** (test-* naming, dev mode only):
- Database creation utilities, phase-based test suites, credential bootstrapping
- See docs/testing.md for test design and patterns

**Logging**: Log file in project root (INFO, SUCCESS, WARNING, ERROR levels). DO NOT log passwords, keys, or sensitive data.

**Error Handling**: try/catch/finally blocks, close connections in finally, clear session KEK in finally blocks

---

## Development Workflow

**Production Scripts**:
1. Write .ps1 in project root (ASCII only, no Unicode symbols)
2. Add error handling, logging, state validation (if database interaction)
3. Create launcher (.vbs for production, .bat for debugging)
4. Test with 32-bit PowerShell

**Test Scripts**: See docs/testing.md for test creation workflow and standards

**Dev Mode Features** (dev_mode.yaml in parent directory):
- Workgroup security: Custom .mdw for production-compliant testing (requires valid .mdw file)
- Auto-login: Bypass login screen with configured credentials (independent of workgroup security)
- Each feature can be enabled/disabled independently
- Details: See dev-mode-helpers.ps1

**Doc Updates**: Read docs/dm.md FIRST (anti-drift principles)

---

## Quick Start & Troubleshooting

**PREREQUISITE**: Create empty db.mdb manually in parent directory (one level above project root) BEFORE first launch

**Application Launch**: Double-click VBScript launcher (.vbs) for production or batch launcher (.bat) for debugging
  - VBScript: Zero console flash (recommended for normal use)
  - Batch: Shows errors if PowerShell fails to launch (debugging)
  - First-time: Automatically detects VirginDatabase state, shows Windows Forms bootstrap UI
  - Subsequent launches: Shows Windows Forms login UI
  - State detection: VirginDatabase | KekNoAdmin | ProductionReady (see rboot)

**Testing**: Create test.mdb (dev mode only), run test utilities (see rtest)

**Troubleshooting**: Check log.txt for error details. See docs/powershell.md for common issues.

---

**Commands**: resume | rl | ud

**Docs**: rsec | rboot | rtest | rps | rui | rdm
