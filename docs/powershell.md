# PowerShell Implementation Patterns
**Windows PowerShell 5.1 (32-bit) - Clinical Database Project**

**Purpose**: Critical constraints, known gotchas, and non-obvious patterns for this project. NOT a PowerShell tutorial.

**Focus**: Mistakes to avoid, project-specific decisions, troubleshooting shortcuts.

---

## Core Requirements

**Environment**: Windows PowerShell 5.1 (32-bit) ONLY
- NOT 64-bit PowerShell
- NOT PowerShell 7+
- Reason: Jet 4.0 OLE DB driver (32-bit only)

**Path**: `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`

---

## Script Architecture Patterns

### Dot-Sourcing vs. Module Import

**Project uses dot-sourcing** (NOT module import):

```
# Main script (db.ps1)
. (Join-Path $PSScriptRoot "database-helpers.ps1")
. (Join-Path $PSScriptRoot "crypto-helpers.ps1")
```

**Effect**: All functions from sourced scripts become available in caller's scope.

**CRITICAL**: Do NOT use `Export-ModuleMember` in dot-sourced .ps1 files.

---

## Common Gotchas

### [GOTCHA] Export-ModuleMember in .ps1 Files

**Error**: "Export-ModuleMember can only be called from within a module"

**Cause**: Using `Export-ModuleMember` in .ps1 files that are dot-sourced.

**Rule**: `Export-ModuleMember` ONLY valid in `.psm1` module files. Dot-sourced `.ps1` scripts expose all functions automatically.

**Solution**: Remove all `Export-ModuleMember` lines from .ps1 files.

---

## Session-Scoped Variables

**Pattern**: Use `$script:` scope for module-level variables that persist across function calls within one script execution.

**Use case**: One-time initialization flags (e.g., log clearing on first write, then append).

**Behavior**: Session = one script execution. Flag resets on rerun.

**Implementation**: See logging-helpers.ps1 for session initialization flag pattern.

---

## Encoding Rules

**CRITICAL**: ASCII-only in source files (no Unicode symbols).

**Reason**: PowerShell parser errors with Unicode in syntax positions.

**FORBIDDEN**: Checkmarks, bullets, arrows, emoji (non-ASCII 0x20-0x7E)

**REQUIRED**: ASCII status messages only
- `[OK]` not checkmark
- `[ERROR]` not X symbol
- `[WARN]` not warning triangle
- `[INFO]` not info circle
- `- * + >` not Unicode arrows/bullets

**File encoding by type**:
- .ps1: UTF-8 no BOM (ASCII content only)
- .bat: ANSI/ASCII only
- .md: ASCII preferred

---

## OLE DB / Jet 4.0 Patterns

**Connection Management**: Always close connections in finally blocks. Disposal order: reverse creation order (Command -> Connection).

**SQL Injection Prevention**: Parameterized queries ALWAYS. NEVER string concatenation with user input.

**Implementation**: See database-helpers.ps1 for connection management pattern.

---

## Error Handling Patterns

**Critical Security Requirement**: Clear sensitive session variables (KEK) in finally blocks.

**Windows Forms Architecture Requirement**: NO console-based error messages in production scripts. Use MessageBox for all user-facing errors.

**Database Operations**: See database-helpers.ps1 for try/catch/finally pattern.

---

## Troubleshooting

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Provider cannot be found" | 64-bit PowerShell | Use 32-bit path |
| "Export-ModuleMember" error | Invalid in .ps1 file | Remove export statement |
| Unicode syntax errors | Non-ASCII in source | Replace with ASCII |
| Database locked | Access window open | Close all Access instances |

**Log location**: `log.txt` in project root (check with `rl` command).

---

## Launcher Selection Guide

**Production application**: VBScript (.vbs) - zero console flash
**Production debugging**: Batch (.bat) with -WindowStyle Hidden - shows PowerShell errors if launch fails
**Test scripts**: Batch (.bat) without -WindowStyle Hidden - shows console output

**Implementation**: See existing launcher files in project root for templates.

---

**See source .ps1 files for implementation examples.**
