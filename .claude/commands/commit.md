---
allowed-tools: Bash(git status:*), Bash(git commit:*)
disallowed-tools: Bash(git add:*)
description: Create a git commit
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the above changes, create a single git commit from files in the staging area. Do NOT add or removed any new files to the staging area. Do NOT add a Claude `Co-Authored-By`. Display the message after committing it. Commit message should be under the template:

```
# <title>

<summary description, do not list every bullet point>

## Features

<bullet list or Level 3 sec>

## Improvements

<bullet list>

## Bugs

<bullet list>
```

If a section is empty, do not write its title. Be simple and human-oriented in your writing, you can left out micro-changes. If a point of the bullet list is considered major and require more explanation, it can be written under its own subsection, above the bullet list like this (with a blank line below titles):

```
### <feature/improvement title>

<summary>

### Others

<bullet list>
```
