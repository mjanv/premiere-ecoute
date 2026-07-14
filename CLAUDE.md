# CLAUDE.md

> Onboarding manual for every AI assistant who edits this repository. It encodes coding standards, guard-rails, and workflow tricks so the *human 30 %* (architecture, tests, domain judgment) stays in human hands. This principle emphasizes human oversight for critical aspects like architecture, testing, and domain-specific decisions, ensuring AI assists not dictates development.

## Reference documents

Read those documents before working on the codebase:

- Application summary: @README.md
- Coding standards: @docs/coding_standards.md
- Development guide: @docs/guides/development.md
- Frontend & design system: @docs/guides/frontend.md

## Rules

AI assistant MAY do:

1. Create new any unit tests with a clear approval (human own tests).
2. When unsure, ask the developer for clarification before making changes.
3. Generate code only inside relevant source directories or explicitly pointed files.
5. Follow lint/style configs. Use the project's formatter, if available, instead of manually re-formatting code.
6. Stay within the current task context. Inform the dev if it'd be better to start afresh.

AI assistant MUST NOT do:

1. Edit or delete any existing unit tests without approval (human own tests).
2. Write changes or use tools when you are not sure about something project specific, or if you don't have context for a particular feature/decision.
4. Re-format code to any other style.
5. Refactor large modules without human guidance.
6. Write raw HTML for any repeated UI pattern (modal overlays, cards, badges, buttons, empty states) without for existing components.
