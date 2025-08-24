# CLAUDE.md

> **purpose** – This file is the onboarding manual for every AI assistant (Claude, Cursor, GPT, etc.) and every human who edits this repository.
> It encodes our coding standards, guard-rails, and workflow tricks so the *human 30 %* (architecture, tests, domain judgment) stays in human hands.
> This principle emphasizes human oversight for critical aspects like architecture, testing, and domain-specific decisions, ensuring AI assists rather than fully dictates development.

@docs/README.md
@docs/coding_standards.md
@docs/guides/development.md

---

## Non-negotiable golden rules

AI may do:

1. Whenever unsure, ask the developer for clarification before making changes.
2. Generate code only inside relevant source directories or explicitly pointed files.
3. Add/update AIDEV-NOTE: anchor comments near non-trivial edited code.
4. Follow lint/style configs. Use the project's formatter, if available, instead of manually re-formatting code.
5. For changes >300 LOC or >3 files, ask for confirmation.
6. Stay within the current task context. Inform the dev if it'd be better to start afresh.

AI must NOT do:

0. Write changes or use tools when you are not sure about something project specific, or if you don't have context for a particular feature/decision.
1. Edit any unit tests (human own tests).
2. Delete or mangle existing AIDEV- comments.
3. Re-format code to any other style.
4. Refactor large modules without human guidance.
5. Continue work from a prior prompt after "new task" – start a fresh session.

---

## Anchor comments

Add specially formatted comments throughout the codebase, where appropriate, for yourself as inline knowledge that can be easily `grep`ped for.

### Guidelines:

- Use `AIDEV-NOTE:`, `AIDEV-TODO:`, or `AIDEV-QUESTION:` (all-caps prefix) for comments aimed at AI and developers.
- Keep them concise (≤ 120 chars).
- **Important:** Before scanning files, always first try to **locate existing anchors** `AIDEV-*` in relevant subdirectories.
- **Update relevant anchors** when modifying associated code.
- **Do not remove `AIDEV-NOTE`s** without explicit human instruction.
- Make sure to add relevant anchor comments, whenever a file or piece of code is:
  * too long, or
  * too complex, or
  * very important, or
  * confusing, or
  * could have a bug unrelated to the task you are currently working on.

Example:
```elixir
# AIDEV-NOTE: perf-hot-path; avoid extra allocations (see ADR-24)
def render_feed(...) do
    ...
```

---

## AI Assistant Workflow: Step-by-Step Methodology

When responding to user instructions, the AI assistant (Claude, Cursor, GPT, etc.) should follow this process to ensure clarity, correctness, and maintainability:

1. **Consult Relevant Guidance**: When the user gives an instruction, consult the relevant instructions from `AGENTS.md` files (both root and directory-specific) for the request.
2. **Clarify Ambiguities**: Based on what you could gather, see if there's any need for clarifications. If so, ask the user targeted questions before proceeding.
3. **Break Down & Plan**: Break down the task at hand and chalk out a rough plan for carrying it out, referencing project conventions and best practices.
4. **Trivial Tasks**: If the plan/request is trivial, go ahead and get started immediately.
5. **Non-Trivial Tasks**: Otherwise, present the plan to the user for review and iterate based on their feedback.
6. **Track Progress**: Use a to-do list (internally, or optionally in a `TODOS.md` file) to keep track of your progress on multi-step or complex tasks.
7. **If Stuck, Re-plan**: If you get stuck or blocked, return to step 3 to re-evaluate and adjust your plan.
8. **Update Documentation**: Once the user's request is fulfilled, update relevant anchor comments (`AIDEV-NOTE`, etc.) and `AGENTS.md` files in the files and directories you touched.
9. **User Review**: After completing the task, ask the user to review what you've done, and repeat the process as needed.
10. **Session Boundaries**: If the user's request isn't directly related to the current context and can be safely started in a fresh session, suggest starting from scratch to avoid context confusion.