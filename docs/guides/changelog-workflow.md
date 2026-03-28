# Changelog Workflow Guide

This guide explains how to use Claude to keep your CHANGELOG.md up to date with the latest commits.

## Quick Start

To update the changelog with recent commits:

```bash
claude "Update changelog with the latest unprocessed commits"
```

Claude will:
1. Check which commits have been processed (files in `changelog_work/`)
2. Analyze each unprocessed commit via git diff
3. Write intermediate files for each commit in `changelog_work/`
4. Regenerate `CHANGELOG.md` organized by month
5. Deduplicate and consolidate related changes

## How It Works

### Intermediate Files

The changelog generation uses intermediate files stored in `changelog_work/` to track what's been processed:

```
changelog_work/
├── <hash>_<YYYY-MM-DD>.md     # One file per processed commit
├── PROMPT.md                   # The original prompt (instructions)
└── messages.md                 # Discord conversation history
```

Each intermediate file contains:
- **Hash & date**: `<hash> — <YYYY-MM-DD> — <commit message>`
- **Category**: Feature | Fix | Improvement | Internal | Removed | Skipped
- **Entry**: One-sentence user-facing description
- **Notes**: Optional technical context from the diff

### Persisting Progress

Since intermediate files are git-tracked, you can always:
- **Pause mid-work**: Restart later, Claude resumes from the first unprocessed commit
- **Audit changes**: Review the intermediate files to see what Claude categorized
- **Re-generate**: Run the prompt again to regenerate `CHANGELOG.md` if formatting changes

### Working with Discord Context

If you have Discord conversations about features (stored in `changelog_work/messages.md`), Claude can reference them to understand:
- Feature requests and bug reports
- User-facing intent behind vague commits
- Why certain decisions were made

## Claude Prompts

### Process all unprocessed commits

```
Update changelog with all unprocessed commits since the last processed one
```

### Process specific commit range

```
Update changelog for commits from 2026-03-20 to 2026-03-28
```

### Regenerate the final changelog (without re-processing)

```
Regenerate the changelog from existing intermediate files in changelog_work/
```

### Process a single commit

```
Analyze commit <hash> and add it to the changelog
```

## Commit Classification

| Category | When to use |
|----------|-----------|
| **Feature** | New capability added to the application |
| **Fix** | Bug or regression resolved |
| **Improvement** | Enhancement to existing feature (performance, UX, reliability) |
| **Internal** | Refactoring, dependency update, tooling (only if significant) |
| **Removed** | Feature or behavior intentionally removed |
| **Skipped** | Trivial changes (typos, minor translations, whitespace) |

## Example Workflow

```bash
# 1. Do some development and make commits
git commit -m "Add 'Pick both' button in duel mode"
git commit -m "Update translations for new UI"
git commit -m "Bump Oban to v14"

# 2. Update changelog when ready
claude "Update changelog with the latest unprocessed commits"

# 3. Review the changes
git diff CHANGELOG.md

# 4. Commit the changelog
git add CHANGELOG.md changelog_work/
git commit -m "Update changelog for March 28"

# 5. Push
git push
```

## User-Facing Language

When writing changelog entries, write for the **project owner** (someone who uses the app but doesn't read code):

❌ "Add OBS overlay component refactoring"
✅ "OBS overlay now shows live scores in real time"

❌ "Refactor handler registry with persistent_term"
✅ "Command/event bus performance improved with O(1) lookup optimization"

❌ "Fix Spotify API rate limit edge case"
✅ "Spotify rate limiting now handled gracefully with auto-retry"

## Tips & Tricks

- **Batch similar features**: If multiple commits build one feature, group them in a single intermediate file
- **Cross-reference messages.md**: Use Discord context to understand intent behind vague commits
- **Deduplication**: When generating the final changelog, remove duplicate entries for the same user-visible change
- **Order within month**: Features first, then Improvements, Fixes, Removed
