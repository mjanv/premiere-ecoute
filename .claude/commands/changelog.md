---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*)
description: Write a changelog
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the last 3 commit message, create a CHANGELOG.md summarizing all commits in a single changelog. Be simple and human-oriented in your writing. Changelog should be under the template:

```
<release name>

<summary description, do not list every bullet point>

# Features

<bullet list>

# Improvements

<bullet list>

# Bugs

<bullet list>
```

If a section is empty, do not write its title. Do NOT add a `Co-Authored-By: Claude`.