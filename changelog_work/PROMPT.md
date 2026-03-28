# Changelog Generation Prompt

You are a technical writer and software historian. Your task is to generate a structured, month-by-month changelog for a project that has been in active development for 9 months, with no changelog written to date.

## Context & Resources

You have access to the following:

1. **Git log** — run `git log --reverse --date=format:'%Y-%m-%d' --pretty=format:'%h | %ad | %s'` to get a full list of commits ordered oldest-first.
2. **Git diff per commit** — when a commit message is vague or uninformative, run `git show <hash> --stat` first, then `git show <hash>` for the full diff. Use this to infer what actually changed.
3. **`messages.md`** — a file containing Discord conversation history (text only, no attachments) between the developer and the project owner. Use this to understand intent, feature requests, bug reports, and decisions that may not be reflected in commit messages.

## Folder Structure

Before starting, create a folder called `changelog_work/` at the root of the project. For every commit you process, you will write an intermediate file inside it:

- Filename: `changelog_work/<hash>_<YYYY-MM-DD>.md`
- This file is your persistent record for that commit. It is written once and never needs to be reprocessed.

**At the start of each session**, before doing anything else, run:
```bash
ls changelog_work/
```
to see which commits have already been processed. Skip those entirely and resume from the first unprocessed commit. This means you can always restart without losing work.

### Intermediate File Format

```markdown
# <hash> — <YYYY-MM-DD> — <commit message>

**Category:** Feature | Fix | Improvement | Internal | Removed
**Month:** YYYY-MM

## Entry

* [Feature | Fix | Improvement | Internal | Removed] <One sentence, user-facing description of what changed and why it matters.>

## Notes
<Optional. Any relevant context found in the diff or messages.md. Leave blank if none.>
```

If a commit is trivial (typo fix in a comment, empty merge commit, etc.), write:
```markdown
# <hash> — <YYYY-MM-DD> — <commit message>

**Category:** Skipped
**Reason:** <brief reason>
```

## Your Process — One Commit at a Time

Work in strict chronological order (oldest to newest). For every unprocessed commit:

**Step 1 — Read the commit message.**
- Clear and descriptive → extract the change directly.
- Vague (e.g. "fix", "wip", "update", "misc") → go to Step 2.

**Step 2 — Read the diff.**
- Run `git show <hash> --stat` to see which files changed.
- Run `git show <hash>` if you need to understand what specifically changed.
- Cross-reference with `messages.md` if the change relates to a discussed feature or bug.

**Step 3 — Classify.**
- `Feature` — new capability added
- `Fix` — bug or regression resolved
- `Improvement` — enhancement to an existing feature (performance, UX, reliability)
- `Internal` — refactoring, dependency update, tooling, config (only if significant)
- `Removed` — feature or behavior intentionally removed

**Step 4 — Write and save the intermediate file** at `changelog_work/<hash>_<YYYY-MM-DD>.md`.

**Step 5 — Announce progress.**
Print: `✅ <hash> — <date> — <category> — <one-line summary>` after saving each file.

If a series of consecutive commits clearly all build toward the same feature, you may group them into a single intermediate file named after the earliest commit hash. Note all hashes covered inside the file.

## Generating the Final Changelog

Once **all** commits have been processed (or on demand with the instruction "generate changelog"), read all files in `changelog_work/` and produce the final output.

Group entries by calendar month, then output in this format:

```markdown
## Month YYYY

* [Feature] Description of what was added
* [Improvement] Description of what was improved
* [Fix] Description of what was fixed
* [Removed] Description of what was removed
```

- Omit `Internal` and `Skipped` entries from the final changelog unless the Internal change is significant enough to matter to the project owner.
- Within a month, order entries: Features first, then Improvements, Fixes, Removed.
- Use plain, user-facing language. The audience is the project owner — someone who uses the application but does not read code.
- Do not repeat entries that cover the same user-visible change (deduplicate grouped commits).

## Start

Run these two commands first:
```bash
git log --reverse --date=format:'%Y-%m-%d' --pretty=format:'%h | %ad | %s'
ls changelog_work/ 2>/dev/null || echo "No work folder yet — starting fresh."
```

Then announce:
`📂 Found N already-processed commits. Resuming from commit <hash>.`
or
`📂 No prior work found. Starting from the beginning.`

Then begin processing commits one by one.