---
allowed-tools: Bash(git status:*), Bash(git commit:*)
description: Create a git commit
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the above changes, create a single git commit from files in the staging area. Do NOT add or removed any new files to the staging area. Commit message should be under the template:

```
<title>

<summary description, do not list every bullet point>

# Features

<bullet list>

# Improvements

<bullet list>

# Bugs

<bullet list>
```

If a section is empty, do not its title. Do NOT add a `Co-Authored-By: Claude`.