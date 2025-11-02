# Documentation Maintenance
**Anti-Drift Principles for PowerShell Clinical Database**

---

## Core Principle

**Documentation is for Claude (AI assistant), not humans. Token-efficient, pitfall-focused, never verbose.**

**Purpose**: Guide future development, avoid known mistakes, document high-level principles.

**NOT for**: Explaining what code does (code is self-documenting), complete API references, implementation details.

**Rule**: Each concept lives in EXACTLY ONE location.

Violation symptoms: contradictory guidance, sync issues, token bloat, explaining what code already shows.

---

## What Documentation Should Contain

**AI Guidance Focus**: Documentation steers Claude toward correct patterns and away from known pitfalls.

**Essential Content**:
1. **Critical Constraints**: Requirements that cannot be inferred (32-bit PowerShell, ASCII-only encoding)
2. **Known Gotchas**: Errors Claude has made before (Export-ModuleMember in .ps1 files)
3. **Non-Obvious Patterns**: Project-specific decisions (dot-sourcing vs modules, session scope usage)
4. **Security Requirements**: Patterns that must never be violated (parameterized queries, KEK clearing)
5. **Architectural Principles**: High-level decisions that guide implementation choices
6. **Troubleshooting Shortcuts**: Common error symptoms and solutions

**Content to AVOID**:
1. **Explaining Code**: If code is clear, don't duplicate it in docs
2. **Standard Practices**: PowerShell/Windows conventions Claude already knows
3. **Implementation Details**: Specific function signatures, variable names, complete code examples
4. **Exhaustive Lists**: All files, all functions, all tables (creates maintenance burden)
5. **Verbose Instructions**: Claude is efficient; brief, direct guidance is better

**Test**: If removing the documentation would cause Claude to repeat a known mistake → Keep it. Otherwise → Remove it.

---

## Single Source of Truth Rule

**Each concept has ONE authoritative location:**
- Project identity, file structure, commands → CLAUDE.md
- Security architecture, KEK patterns → docs/sec.md
- Bootstrap, state machine, first-run → docs/boot.md
- Function signatures, implementation → source .ps1 files

**Cross-reference rather than duplicate.**

---

## Update Protocol

### Before ANY Documentation Update
**MANDATORY**: Re-read this file (docs/dm.md) to internalize anti-drift rules.

### Adding New Content
1. **Identify domain** - Which doc owns this concept?
2. **Update domain file** - Never add to CLAUDE.md unless core identity/workflow
3. **Add cross-reference** - Point from CLAUDE.md to domain doc
4. **Validate no redundancy** - Grep for duplicates before committing

### Modifying Existing Content
1. **Find single source** - Grep if unsure where concept lives
2. **Update in place** - Change once, not everywhere
3. **Check cross-refs** - Ensure pointers still valid
4. **Update index** - If context changed, update CLAUDE.md doc table

### Main File Scope (CLAUDE.md)
**What belongs:**
- Mission statement
- File structure
- Quick reference card
- Command list
- Documentation index
- Cross-references to domain docs

**What does NOT belong:**
- Implementation patterns (→ domain docs)
- Detailed specs (→ domain docs)
- Code examples (→ source files)
- Troubleshooting (→ domain docs)

---

## Size Constraints

**Target limits:**
- **CLAUDE.md**: <400 lines (main file must be scannable)
- **Domain docs**: <400 lines each (split if exceeded)
- **Total documentation**: Prioritize clarity over brevity, but eliminate duplication

**When CLAUDE.md exceeds 400 lines:**
1. Identify largest sections
2. Create/expand domain doc
3. Move content
4. Replace with cross-reference

---

## Documentation Structure

**Current files:**
```
CLAUDE.md          # Main project documentation
next_session.md    # Session state (incomplete work only)
docs/
├── dm.md          # This file - documentation maintenance
├── boot.md        # Bootstrap architecture, state machine
└── sec.md         # Security architecture, KEK patterns
```

**Planned domain docs** (create when needed):
- docs/db.md - Database operations, connection strings, CRUD patterns
- docs/crypto.md - Cryptography functions, PBKDF2, AES-256
- docs/user.md - User management patterns
- docs/patient.md - Patient data encryption/decryption

---

## Domain Creation Rules

**Create new domain doc when:**
- Distinct concept (not part of existing domain)
- Content exceeds ~100 lines
- Specific task triggers (user questions repeatedly about this topic)
- Reduces main file or other domain docs

**Expand existing domain when:**
- Related content
- <50 lines addition
- Same triggers/use cases

---

## Cross-Reference Protocol

**Format**: `See docs/{name}.md for {topic}`

**Examples:**
- "See docs/sec.md for KEK security patterns"
- "See docs/boot.md for bootstrap state machine"
- "Read crypto-helpers.ps1 for current function signatures"

**When to cross-ref:**
- Domain A needs Domain B context → minimal pointer only
- Excessive cross-refs (>3 per doc) = poor domain boundaries

**Never duplicate:** Except in documentation index table

---

## Session State Management

**File**: `next_session.md`

**Contains ONLY:**
- Incomplete work (current tasks)
- Immediate next steps
- Known blockers
- Context from last session

**Does NOT contain:**
- Completed work (delete when done)
- Historical decisions (move to appropriate domain doc)
- Implementation details (those go in source files)

**Update triggers:**
- End of work session (user requests)
- Major milestone completion
- Switching development phases
- User says "save session" or similar

---

## Staleness Indicators

**Rebalance documentation if:**
- CLAUDE.md exceeds 400 lines
- Multiple domains needed for single task
- Vague/overlapping triggers between docs
- >3 cross-refs per domain doc
- Updates consistently touch multiple files
- User asks "where's X?" repeatedly

---

## Quality Checklist

**Run monthly or after major additions:**

### Content Quality:
- [ ] No duplication across docs
- [ ] Clear triggers for each domain
- [ ] Index covers all use cases
- [ ] No orphaned cross-references
- [ ] Valid cross-refs (files exist)
- [ ] Source files referenced, not duplicated

### Size Constraints:
- [ ] CLAUDE.md <400 lines
- [ ] Domain docs <400 lines each

### Drift Risk Metrics (CRITICAL):
- [ ] File reference test: Count specific .ps1 file names per doc (target: 0)
- [ ] Function reference test: Count specific function names per doc (target: 0)
- [ ] SQL statement test: Count SQL code blocks in docs (target: 0)
- [ ] Code example test: All examples are concept/pattern descriptions, not implementations
- [ ] Hardcoded path test: Count absolute paths in docs (target: <5, only in critical policies)
- [ ] Rename impact test: If renaming any file requires >0 doc updates → OVER-SPECIFIED

### Practical Drift Tests:

**File Rename Test**: Simulate renaming gui_bootstrap.ps1 to bootstrap-ui.ps1
- How many documentation locations require updates?
- Target: ZERO (all references should be abstract like "bootstrap UI script")

**Function Addition Test**: Simulate adding new function to crypto-helpers.ps1
- Do any docs need updates to remain "complete"?
- Target: NO (docs should never claim to be complete function reference)

**Schema Change Test**: Simulate adding column to Config table
- Do any docs need updates?
- Target: ZERO (schema lives in schema-definitions.ps1 only)

---

## Command System

**Convention**: `r{docname}` for "read {docname}.md"

**Examples:**
- `rsec` → docs/sec.md
- `rboot` → docs/boot.md
- `rdm` → docs/dm.md (this file)

**Purpose**: Quick access to domain docs without full path

---

## Response Footer

**Every Claude response should end with:**

```
---
**Commands**: resume (continue work) | rl (read log) | ud (update docs)
**Docs**: rsec (security) | rboot (bootstrap) | rps (powershell) | rui (ui) | rdm (doc-maint)
```

**Purpose**: Discoverability - user knows all magic keywords and how to access them

**Format**:
- Commands: Action keywords (session, logging, documentation)
- Docs: Domain documentation keywords (with brief topic hints)

---

## Abstraction Level Guidelines

**CRITICAL**: Documentation describes CONCEPTS and PATTERNS, never IMPLEMENTATIONS.

### What Documentation SHOULD Contain:

**Principles and Rationale (WHY):**
- Why was this architectural decision made?
- What problem does this pattern solve?
- What are the security/design principles?

**Concepts and Workflows (WHAT):**
- What are the system layers/components?
- What is the state machine flow?
- What are the data protection strategies?

**Patterns and Standards (WHEN/WHERE):**
- When do you use this pattern?
- Where do specific details live?
- How do you find current implementations?

### What Documentation MUST NOT Contain:

**PROHIBITED - Specific File Names:**
- NEVER: "gui_bootstrap.ps1 handles first-run setup"
- INSTEAD: "Bootstrap UI script handles first-run setup (see project root)"

**PROHIBITED - Function Signatures:**
- NEVER: "New-PasswordHash returns @{Hash, Salt}"
- INSTEAD: "Password hashing function returns hash and salt (see crypto-helpers.ps1)"

**PROHIBITED - Code Examples:**
- NEVER: PowerShell/SQL code blocks in documentation
- INSTEAD: "See source .ps1 files for implementation examples"

**PROHIBITED - Schema Definitions:**
- NEVER: Complete CREATE TABLE statements in docs
- INSTEAD: "Config table stores KEK hash/salt (see schema-definitions.ps1)"

**PROHIBITED - Specific Variable Names:**
- NEVER: "$script:sessionKEK stores the derived key"
- INSTEAD: "Session-scoped variable stores derived key in memory"

**PROHIBITED - File/Function Enumeration:**
- NEVER: Lists of all files or all functions
- INSTEAD: "Helper modules in project root" or "See crypto-helpers.ps1"

---

## Over-Specification Anti-Patterns

### Why Over-Specification Is Dangerous:

**Documentation Drift**: When docs duplicate implementation details, every code change requires multi-file documentation updates. If docs aren't updated, they become stale and misleading.

**False Completeness**: Enumerating files/functions creates expectation that docs provide complete reference. When new files/functions are added, docs appear incomplete.

**Token Bloat**: Duplicating 70-line SQL schemas or 100-line code examples wastes tokens. Source files are the authoritative reference.

**Maintenance Burden**: Renaming a file shouldn't require updating 14 documentation locations.

### [ANTI-PATTERN] File Name Enumeration

**WRONG:**
```
Production Scripts:
- gui_bootstrap.ps1 (first-run setup)
- gui_login.ps1 (authentication)
- crypto-helpers.ps1 (password hashing)
- database-helpers.ps1 (connections, queries)
```

**Drift Risk**: 4 file renames = 4+ doc updates

**CORRECT:**
```
Script Architecture:
- UI Layer: Bootstrap and login workflows
- Helper Modules: Cryptography, database operations
- See project root for current files
```

**Drift Risk**: Zero - files can be renamed/reorganized without doc changes

### [ANTI-PATTERN] Function Signature Tables

**WRONG:**
```
| Function | Purpose | Returns |
|----------|---------|---------|
| New-PasswordHash | Hash password | @{Hash, Salt} |
| Test-Password | Validate password | $true/$false |
```

**Drift Risk**: Function rename/signature change = stale docs

**CORRECT:**
```
Cryptographic Operations:
- Password hashing (PBKDF2 algorithm)
- Password validation (constant-time comparison)

See crypto-helpers.ps1 for current function signatures.
```

**Drift Risk**: Zero - source files are authoritative

### [ANTI-PATTERN] SQL Schema Duplication

**WRONG:**
```
CREATE TABLE Config (
    ConfigID AUTOINCREMENT PRIMARY KEY,
    ConfigKey TEXT(50) NOT NULL,
    ConfigValue MEMO NOT NULL,
    Description TEXT(255),
    ModifiedDate DATETIME DEFAULT Now()
)
```

**Drift Risk**: Column addition = doc update required

**CORRECT:**
```
Config Table: System configuration storage
- Primary key: Auto-increment ID
- Unique constraint: ConfigKey
- Schema: See schema-definitions.ps1
```

**Drift Risk**: Zero - schema file is single source of truth

### [ANTI-PATTERN] Complete Code Examples

**WRONG:**
```powershell
try {
    $connection = New-DatabaseConnection
    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT * FROM Users WHERE Username = @username"
    # ... 20 more lines
}
```

**Drift Risk**: Implementation changes = stale examples

**CORRECT:**
```
Database Query Pattern:
1. Create connection using connection helper
2. Use parameterized queries (SQL injection prevention)
3. Close connections in finally blocks

See database-helpers.ps1 for implementation.
```

**Drift Risk**: Zero - concepts don't change, implementation can evolve

---

## Anti-Patterns

### [ANTI-PATTERN] Duplication
```
CLAUDE.md: "Bootstrap creates tables using..."
boot.md: "Bootstrap creates tables using..."
```
**Fix**: Remove from CLAUDE.md, add cross-ref to boot.md

### [ANTI-PATTERN] Orphaned Cross-Refs
```
"See docs/crypto.md for details"
# docs/crypto.md doesn't exist
```
**Fix**: Create docs/crypto.md or remove reference

### [ANTI-PATTERN] Main File Bloat
```
CLAUDE.md contains:
- Complete bootstrap workflow (50 lines)
- Complete security patterns (100 lines)
- Complete database CRUD (80 lines)
```
**Fix**: Move to domain docs, keep only index and cross-refs

### [ANTI-PATTERN] Stale Session State
```
next_session.md contains:
- Completed tasks from 3 sessions ago
- Implementation details now in source files
```
**Fix**: Delete completed work, keep only pending tasks

---

## Validation Protocol

**Before committing documentation changes:**

1. **Check for duplicates**: `Grep -pattern "unique concept phrase"` across all docs
2. **Verify cross-refs**: Ensure all referenced files exist
3. **Check size**: Count lines in CLAUDE.md and domain docs
4. **Test commands**: Verify r{docname} commands work
5. **Review footer**: Ensure all domain docs listed

---

**This file is the MANDATORY first read before any documentation work.**
