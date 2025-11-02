# Documentation Triggers
**Keyword-to-Doc Mapping for Context-Aware Loading**

---

## Purpose

Map user keywords → relevant documentation files for automatic context loading.

Claude reads this file at conversation start to enable on-demand doc loading.

---

## Trigger Mapping

### Bootstrap & Initialization
**Keywords**: bootstrap, first run, initialization, setup, virgin database, state machine, first admin
**Load**: docs/boot.md
**Why**: State machine, transactional schema, recovery scenarios

### Security & Cryptography
**Keywords**: security, KEK, PBKDF2, encryption, AES, double PBKDF2, crypto, hash, salt, session key
**Load**: docs/sec.md
**Why**: Security architecture, double PBKDF2 pattern, threat model

### Documentation Maintenance
**Keywords**: update docs, documentation drift, single source of truth, doc split, cross-reference
**Load**: docs/dm.md
**Why**: Anti-drift principles, update protocols, size constraints

---

## Usage Pattern

**User says**: "How does the bootstrap work?"
**Claude**: Detects "bootstrap" → loads docs/boot.md → answers with complete context

**User says**: "Explain the KEK security"
**Claude**: Detects "KEK" → loads docs/sec.md → answers with security patterns

**User says**: "I want to update the documentation"
**Claude**: Detects "update docs" → loads docs/dm.md → follows anti-drift principles

---

## Command Overrides

**Explicit commands always take precedence:**
- `rboot` → Always load docs/boot.md
- `rsec` → Always load docs/sec.md
- `rdm` → Always load docs/dm.md

---

## Adding New Triggers

**When creating new domain docs:**
1. Create domain doc (e.g., docs/db.md)
2. Add trigger section here
3. Add command to CLAUDE.md (e.g., `rdb`)
4. Add to response footer in CLAUDE.md

**Keep triggers specific and actionable** - avoid vague keywords
