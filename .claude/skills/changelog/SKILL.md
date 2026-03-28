---
name: changelog
description: Update CHANGELOG.md with recent commits. Analyze git history, classify changes (Feature/Fix/Improvement/Internal/Removed/Skipped), and organize by month with user-facing descriptions for non-technical owners.
---

# Changelog Update Skill

## CHANGELOG.md Structure

The document is organized by **month sections** (newest at top, oldest at bottom):

```markdown
# Changelog

<!-- Last analyzed commit: d71db94 (2026-03-28) -->

## March 2026

* [Feature] Description of new capability
* [Improvement] Enhancement to existing feature
* [Fix] Bug resolution
* [Removed] Feature intentionally removed

## February 2026

* [Feature] ...
```

**Key rules:**
- **Newest month at top** — Latest analyzed commits appear first in the document
- **HTML comment at top** — Document the last analyzed commit hash and date: `<!-- Last analyzed commit: <hash> (<date>) -->`
  - When resuming, start from the next commit after this hash
  - Update this comment each time new commits are processed
- **Within each month, order entries:** Features → Improvements → Fixes → Removed (omit Internal/Skipped)
- Always add new entries to the top month section (create if needed)

## Commit Classification

| Category | Include? | Examples |
|----------|----------|----------|
| **Feature** | ✓ | New button, new API, new page |
| **Fix** | ✓ | Bug resolved, error handled |
| **Improvement** | ✓ | Performance, UX refinement, reliability |
| **Internal** | Only if significant | Refactoring, major dependency upgrade, new infrastructure |
| **Removed** | ✓ | Feature deleted, deprecated API removed |
| **Skipped** | ✗ | Typos, comments, translations-only, whitespace |

## Entry Format

```
* [Category] One-sentence user-facing description of what changed and why it matters.
```

**Examples (good):**
- `[Feature] Collection sessions: take two playlists and build a new one by choosing between pairs of tracks.`
- `[Fix] OAuth flash issue fixed: misleading error no longer appears during successful Twitch redirect.`
- `[Improvement] Handler registry optimized from O(n) to O(1) lookup using persistent_term caching.`

**Anti-patterns (too technical):**
- ✗ `[Internal] Refactor handler registry with persistent_term`
- ✗ `[Fix] Fix click event handling on nested span elements`
- ✗ `[Internal] Update Oban to v14`

Write for the **project owner** (uses the app, doesn't read code).

## Process

1. **Find unprocessed commits** — Compare git log hashes against current CHANGELOG.md
2. **Analyze each commit** — `git show <hash> --stat`, then `git show <hash>` if message is vague
3. **Classify** — Assign one category (Feature/Fix/Improvement/Internal/Removed/Skipped)
4. **Write description** — One sentence, user-facing, explain impact not implementation
5. **Add to month section** — Create section if needed (## Month YYYY), add under appropriate category
6. **Deduplicate** — If multiple commits build one feature, combine into single entry
7. **Announce progress** — Print `✅ <hash> — <date> — <category> — <summary>` for each
