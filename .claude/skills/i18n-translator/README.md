# i18n-translator Skill

A Claude Skill for internationalizing Phoenix/Elixir applications using Gettext.

## Overview

This skill helps you extract hardcoded strings from Phoenix applications and replace them with proper `gettext()` calls, then provides accurate French and Italian translations.

## Structure

```
.claude/skills/i18n-translator/
├── SKILL.md        # Main skill instructions and workflow
├── REFERENCE.md    # Common patterns and translation lookup tables
├── EXAMPLES.md     # Real-world before/after examples
└── README.md       # This file
```

## When Claude Uses This Skill

Claude will automatically load this skill when you:

- Add new UI text that needs to be translatable
- Work with Phoenix templates (.heex files)
- Need to internationalize existing code
- Update or manage translation files (POT/PO)
- Request French or Italian translations

## Skill Capabilities

### String Detection & Replacement

- Scans templates, controllers, and LiveViews for hardcoded text
- Replaces strings with appropriate `gettext()` calls
- Handles interpolation, pluralization, and domain-specific translations
- Preserves code structure and formatting

### Translation Management

- Executes `mix gettext.extract` to update POT files
- Runs `mix gettext.merge` to sync PO files
- Provides French and Italian translations
- Ensures proper pluralization rules for each language

### Code Quality

- Follows project coding standards from `CLAUDE.md`
- Adds `AIDEV-NOTE` comments for complex decisions
- Handles edge cases (empty strings, nil values)
- Maintains existing functionality

## Usage Examples

### Example 1: Internationalize a New Feature

**Your request:**
> "I just added a new user settings page. Can you internationalize all the text?"

**What Claude will do:**
1. Load the i18n-translator skill
2. Scan the settings page files for hardcoded strings
3. Replace strings with `gettext()` calls
4. Run mix gettext commands to update translation files
5. Provide French and Italian translations
6. Add AIDEV-NOTE comments where needed

### Example 2: Fix Specific Strings

**Your request:**
> "The error messages in `lib/premiere_ecoute_web/controllers/user_controller.ex` need to be translatable"

**What Claude will do:**
1. Load the i18n-translator skill
2. Read the controller file
3. Identify and replace error message strings
4. Update translation files
5. Provide translations for both languages

### Example 3: Add Translations

**Your request:**
> "Add French and Italian translations for the login form"

**What Claude will do:**
1. Load the i18n-translator skill
2. Check if gettext calls are already in place
3. If not, add them first
4. Update PO files with French and Italian translations
5. Verify pluralization if needed

## Progressive Loading

The skill uses **progressive loading** to optimize token usage:

1. **Initial load**: Claude sees the skill name and description
2. **Task match**: When your task requires i18n work, Claude loads `SKILL.md`
3. **Reference lookup**: `REFERENCE.md` is loaded if Claude needs translation tables or patterns
4. **Examples**: `EXAMPLES.md` is loaded when working on complex scenarios

This means you only use tokens for the information needed for your specific task.

## Supporting Files

### REFERENCE.md

Contains:
- Common gettext patterns (basic, interpolation, pluralization)
- Translation lookup tables (UI elements, forms, messages, time/dates)
- Pluralization rules for French and Italian
- Migration commands reference
- Best practices and debugging tips

### EXAMPLES.md

Provides complete before/after examples for:
- LiveView registration forms
- Error handling in controllers
- Validation messages with interpolation
- Pluralization in dashboards
- Dynamic content with context
- Email templates

## Migration from Agent

This skill replaces the previous `i18n-translator` agent located at:
`.claude/agents/product/i18n-translator.md`

### Key Differences

| Aspect | Agent | Skill |
|--------|-------|-------|
| **Location** | `.claude/agents/product/` | `.claude/skills/` |
| **Structure** | Single `.md` file | Directory with multiple files |
| **Format** | YAML frontmatter with tools list | Simplified YAML (name + description only) |
| **Loading** | Loaded when explicitly invoked | Auto-loaded based on task context |
| **Resources** | All content in one file | Progressive loading of references |
| **Token usage** | Full agent loaded | Only relevant files loaded |

### Benefits of Skill Format

1. **Automatic invocation**: No need to explicitly call the skill
2. **Better organization**: Supporting files separated by purpose
3. **Token efficiency**: Progressive loading reduces context size
4. **Easier maintenance**: Update references without changing core logic
5. **Composability**: Can work with other skills automatically

## Best Practices

### For Users

- Be specific about which files or features need internationalization
- Mention if you want just extraction or also translations
- Specify target languages if different from default (French, Italian)
- Review translations for accuracy and context

### For Maintainers

- Keep `SKILL.md` focused on workflow (≤5k words)
- Update `REFERENCE.md` with new common translations
- Add complex real-world examples to `EXAMPLES.md`
- Maintain `AIDEV-NOTE` comments for context

## Testing the Skill

To verify the skill works:

1. **Ask Claude to internationalize a file:**
   ```
   Please internationalize lib/premiere_ecoute_web/live/session_live/show.ex
   ```

2. **Request specific translations:**
   ```
   Add French and Italian translations for the donation tracking feature
   ```

3. **Check for hardcoded strings:**
   ```
   Are there any hardcoded strings in the authentication module that need translation?
   ```

If Claude loads this skill (you'll see it mentioned in the response), the migration was successful!

## Resources

- [Gettext Documentation](https://hexdocs.pm/gettext/Gettext.html)
- [Phoenix I18n Guide](https://hexdocs.pm/phoenix/Phoenix.Controller.html#module-i18n)
- [Claude Skills Documentation](https://docs.claude.com/en/docs/claude-code/skills)
- [Anthropic Skills Announcement](https://www.anthropic.com/news/skills)

---

**AIDEV-NOTE:** This skill was migrated from the i18n-translator agent format to the new Claude Skills format on 2025-10-28. The agent file remains in place for backward compatibility but may be deprecated in the future.
