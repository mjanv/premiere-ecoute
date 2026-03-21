# CLAUDE

> **Purpose** – This file is the onboarding manual for every Claude AI assistant who edits this repository.
> It encodes coding standards, guard-rails, and workflow tricks so the *human 30 %* (architecture, tests, domain judgment) stays in human hands. This principle emphasizes human oversight for critical aspects like architecture, testing, and domain-specific decisions, ensuring AI assists not dictates development.

## Reference documents

Read those documents before working on the codebase:

- Application summary: @README.md
- Coding standards: @docs/coding_standards.md
- Development guide: @docs/guides/development.md

---

## Non-negotiable golden rules

AI assistant may do:

1. When unsure, ask the developer for clarification before making changes.
2. Generate code only inside relevant source directories or explicitly pointed files.
3. Add/update AIDEV-NOTE: anchor comments near non-trivial edited code.
4. Follow lint/style configs. Use the project's formatter, if available, instead of manually re-formatting code.
5. Stay within the current task context. Inform the dev if it'd be better to start afresh.

AI assistant MUST NOT do:

1. Edit, create or delete any unit tests without approval (human own tests).
2. Write changes or use tools when you are not sure about something project specific, or if you don't have context for a particular feature/decision.
3. Delete or mangle existing AIDEV- comments.
4. Re-format code to any other style.
5. Refactor large modules without human guidance.

---

## Anchor comments

Add specially formatted comments throughout the codebase, where appropriate, whenever a file or piece of code is too long, too complex, very important, confusing, or could have a bug unrelated to the task you are currently working on. for yourself as inline knowledge that can be easily `grep`ped for.

1. Use concise (≤ 120 chars) `AIDEV-NOTE:` (all-caps prefix) for comments aimed at AI and developers.
2. Do not remove `AIDEV-NOTE`s without explicit human instruction.
3. Important: Before scanning files, always first try to locate existing anchors `AIDEV-*` in relevant subdirectories.
4. Update relevant anchors when modifying associated code.

```elixir
# AIDEV-NOTE: perf-hot-path; avoid extra allocations (see ADR-24)
def render_feed(...) do
    ...
```
