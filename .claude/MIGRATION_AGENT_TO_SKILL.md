# Migration Guide: Agent to Skill (i18n-translator)

## Overview

This document describes the migration of the `i18n-translator` agent to the new Claude Skills format, completed on **2025-10-28**.

## What Changed

The `i18n-translator` functionality has been redesigned from an **Agent** to a **Skill**, following Anthropic's new [Claude Skills framework](https://www.anthropic.com/news/skills).

### File Structure

**Before (Agent):**
```
.claude/agents/product/i18n-translator.md
```

**After (Skill):**
```
.claude/skills/i18n-translator/
├── SKILL.md        # Main skill instructions
├── REFERENCE.md    # Translation lookup tables and patterns
├── EXAMPLES.md     # Real-world before/after examples
└── README.md       # Documentation and usage guide
```

## Key Differences

| Aspect | Agent Format | Skill Format |
|--------|--------------|--------------|
| **Location** | `.claude/agents/product/` | `.claude/skills/` |
| **Structure** | Single `.md` file | Directory with multiple files |
| **YAML Frontmatter** | `name`, `description`, `tools` | `name`, `description` only |
| **Invocation** | Explicitly called by Claude | Auto-loaded based on task context |
| **Organization** | All content in one file | Progressive loading of resources |
| **Token Usage** | Entire agent loaded at once | Only relevant files loaded as needed |
| **Composability** | Standalone | Can work with other skills automatically |

## Benefits of Skills

### 1. Automatic Invocation

**Agent (old way):**
```
User: "Can you internationalize this file?"
Claude: "I'll use the i18n-translator agent..."
[Explicitly loads the agent]
```

**Skill (new way):**
```
User: "Can you internationalize this file?"
Claude: [Automatically loads i18n-translator skill based on context]
[Works seamlessly without explicit invocation]
```

### 2. Progressive Loading

Skills use **progressive disclosure** to optimize token usage:

1. **Startup**: Claude sees skill name + description
2. **Task match**: Loads `SKILL.md` when needed
3. **Reference lookup**: Loads `REFERENCE.md` only if translation tables needed
4. **Examples**: Loads `EXAMPLES.md` only for complex scenarios

This means you only pay tokens for what you actually need.

### 3. Better Organization

Content is separated by purpose:

- **SKILL.md**: Core workflow and instructions (≤5k words)
- **REFERENCE.md**: Common patterns, translation tables, commands
- **EXAMPLES.md**: Real-world before/after transformations
- **README.md**: Usage documentation

### 4. Composability

Skills can automatically work together. For example:

- `i18n-translator` + `frontend-developer` → Internationalize while building UI
- `i18n-translator` + `refactoring-developer` → Clean up code while adding i18n
- `i18n-translator` + `documentation-writer` → Document translation decisions

## Migration Details

### Content Transformation

The agent's content was reorganized as follows:

**SKILL.md** (from agent main content):
- Core workflow (7 steps)
- When to use the skill
- Output format expectations
- Basic examples

**REFERENCE.md** (new):
- Common gettext patterns
- Translation file structure
- Translation lookup tables (French/Italian)
- Pluralization rules
- Migration commands
- Best practices
- Debugging tips

**EXAMPLES.md** (new):
- 6 comprehensive before/after examples
- LiveView registration forms
- Error handling in controllers
- Validation messages
- Dashboard pluralization
- Dynamic notifications
- Email templates

**README.md** (new):
- Skill overview
- When Claude uses it
- Usage examples
- Progressive loading explanation
- Migration notes
- Best practices

### Backward Compatibility

The original agent file remains at `.claude/agents/product/i18n-translator.md` with:

- **Deprecation notice** in the frontmatter
- **Warning message** at the top of the file
- **Reference** to the new skill location
- **Original content** preserved (marked as archived)

This ensures:
- Existing references don't break
- Clear migration path documented
- Can be removed in a future cleanup

## Usage Comparison

### Before (Agent)

```markdown
User: I need to internationalize the session management module.

Claude: I'll use the i18n-translator agent to help with that.
[Loads entire agent (~2k tokens)]
[Processes the request]
```

### After (Skill)

```markdown
User: I need to internationalize the session management module.

Claude: [Automatically loads i18n-translator skill]
[Loads SKILL.md (~1k tokens)]
[Processes the request]
[Loads REFERENCE.md if translation lookup needed]
[Loads EXAMPLES.md if complex patterns needed]
```

**Token savings**: ~30-50% depending on task complexity

## For Users

### What You Need to Do

**Nothing!** The skill will be automatically loaded when you:

- Request internationalization work
- Mention gettext or translations
- Work with `.heex` templates that need i18n
- Ask for French or Italian translations

### What Changed for You

- **Faster responses**: Less token usage = faster processing
- **Better context**: Relevant examples loaded automatically
- **Seamless experience**: No need to explicitly invoke the skill
- **Composable**: Works with other skills automatically

## For Maintainers

### Updating the Skill

To update skill content:

1. **Core workflow changes**: Edit `SKILL.md`
2. **Add translation patterns**: Update `REFERENCE.md`
3. **Add examples**: Add to `EXAMPLES.md`
4. **Update documentation**: Modify `README.md`

### Best Practices

- Keep `SKILL.md` focused and concise (≤5k words)
- Add common translations to `REFERENCE.md` tables
- Include real-world examples in `EXAMPLES.md`
- Document changes in `README.md`
- Add `AIDEV-NOTE` comments for complex decisions

### Future Migrations

If migrating other agents to skills, follow this pattern:

1. Create skill directory: `.claude/skills/[skill-name]/`
2. Create `SKILL.md` with simplified frontmatter
3. Extract references to `REFERENCE.md`
4. Create comprehensive `EXAMPLES.md`
5. Document in `README.md`
6. Deprecate old agent with notice
7. Test the skill works correctly

## Technical Details

### YAML Frontmatter Changes

**Agent format:**
```yaml
---
name: i18n-translator
description: Use this agent when you need to internationalize code...
tools: Task, Glob, Grep, LS, ExitPlanMode, Read, Edit, MultiEdit, Write...
---
```

**Skill format:**
```yaml
---
name: i18n-translator
description: Internationalization specialist for Phoenix/Elixir applications. Use when you need to extract hardcoded strings and replace them with gettext calls...
---
```

**Key changes:**
- Removed `tools` field (handled automatically)
- Simplified description (focuses on capabilities, not examples)
- No need for invocation examples in frontmatter

### File Loading Mechanism

Skills use **progressive loading**:

1. **Initialization**: All skill names + descriptions loaded into system prompt
2. **Context matching**: Claude determines if skill is relevant
3. **Primary load**: `SKILL.md` loaded when skill is needed
4. **Secondary load**: Supporting files loaded on-demand

This is more efficient than loading entire agents upfront.

## Testing

To verify the skill migration:

### Test 1: Basic Invocation

```
User: Can you internationalize lib/premiere_ecoute_web/live/session_live/show.ex?
Expected: Claude loads i18n-translator skill and processes the file
```

### Test 2: Translation Request

```
User: Add French translations for the donation tracking feature
Expected: Claude loads skill + REFERENCE.md for translation tables
```

### Test 3: Complex Example

```
User: Help me internationalize the user registration flow with proper pluralization
Expected: Claude loads skill + EXAMPLES.md for registration form patterns
```

## Rollback Plan

If issues arise with the skill format:

1. Remove deprecation notice from agent file
2. Restore original agent description
3. Keep skill directory for reference
4. Document issues encountered

The original agent content is preserved, so rollback is straightforward.

## Timeline

- **2025-10-28**: Migration completed
- **Current**: Both agent (deprecated) and skill available
- **Future**: Agent file may be removed after validation period

## Resources

- [Claude Skills Documentation](https://docs.claude.com/en/docs/claude-code/skills)
- [Anthropic Skills Announcement](https://www.anthropic.com/news/skills)
- [Claude Skills GitHub Repository](https://github.com/anthropics/skills)
- [Skill Structure Blog Post](https://skywork.ai/blog/ai-agent/claude-skills-skill-md-resources-runtime-loading/)

## Questions?

For questions or issues:

1. Check the skill's `README.md` for usage examples
2. Review `EXAMPLES.md` for similar use cases
3. Consult `REFERENCE.md` for patterns and translations
4. Ask Claude to explain the skill's capabilities

---

**AIDEV-NOTE:** This migration establishes the pattern for future agent-to-skill migrations. Follow this structure when converting other agents.
