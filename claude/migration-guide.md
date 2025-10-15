# Migration Guide: From Copilot/Cursor to Claude Code

This guide maps your previous AI assistant context to the new Claude Code structure.

## Migration Overview

### Previous Structure → New Structure

```
.github/copilot-instructions.md → CLAUDE.md (enhanced)
.github/instructions/*.md       → claude/patterns/, claude/architecture/
.github/prompts/*.md           → .claude/commands/
.cursor/rules/*.mdc            → Distributed across claude/ directories
```

## Detailed Migration Map

### From copilot-instructions.md

| Original Section | New Location | Enhancements |
|-----------------|--------------|--------------|
| Project Overview | CLAUDE.md (top) | Condensed to essential points |
| Architecture | CLAUDE.md + claude/architecture/ | Split between quick reference and deep dives |
| Coding Standards | CLAUDE.md | Focused on critical always-needed rules |
| Common Operations | .claude/commands/ | Converted to executable slash commands |
| Build/Test Commands | CLAUDE.md | Most frequently used commands only |
| Important Notes | CLAUDE.md (Critical Rules) | Elevated to prominent position |

### From .github/instructions/

| Original File | New Location | Changes |
|--------------|--------------|---------|
| thread-safety.instructions.md | claude/architecture/threading-model.md | Expanded with examples, patterns, testing |
| property-types.instructions.md | claude/patterns/type-safety-patterns.md | Added conversion patterns, ObjC bridging |
| testing.instructions.md | .claude/commands/write-test.md | Converted to actionable command |
| persistence.instructions.md | claude/architecture/persistence-layer.md | Added schema details, migration patterns |
| networking.instructions.md | Distributed in CLAUDE.md + commands | Core in CLAUDE.md, specifics in commands |
| api-design.instructions.md | CLAUDE.md (API Design section) | Condensed to essential patterns |

### From .github/prompts/

| Original Prompt | New Command | Improvements |
|----------------|-------------|--------------|
| add-event-property.prompt.md | /add-property | Streamlined steps, validation built-in |
| implement-new-api.prompt.md | /new-api | Added thread safety, documentation templates |
| fix-thread-safety.prompt.md | /fix-thread-safety | Common patterns included |
| write-unit-test.prompt.md | /write-test | Test templates for all scenarios |
| debug-issue.prompt.md | /debug-issue | Comprehensive debugging checklist |
| database-migration.prompt.md | /migrate-db | Safety checks, rollback procedures |

### From .cursor/rules/

| Original Rule | New Location | Rationale |
|--------------|--------------|-----------|
| architecture.mdc | CLAUDE.md (overview) + claude/architecture/ | Core in CLAUDE.md, details on-demand |
| thread-safety.mdc | claude/architecture/threading-model.md | Comprehensive guide with examples |
| property-types.mdc | claude/patterns/type-safety-patterns.md | Expanded with all type scenarios |
| commands.mdc | CLAUDE.md (Essential Commands) | Only most-used commands |
| platform-support.mdc | CLAUDE.md (Platform Matrix) | Quick reference format |
| release-process.mdc | claude/workflows/release-process.md | Step-by-step workflow |

## New Claude Code Capabilities

### 1. Slash Commands
**New Feature**: Execute common workflows with simple commands
```
/add-property $app_version
/new-api resetAnalytics()
/write-test People.increment
```

### 2. Contextual File References
**New Feature**: Load specific knowledge on-demand
```
@claude/architecture/threading-model.md
@claude/patterns/type-safety-patterns.md
```

### 3. Integrated Workflows
**New Feature**: Commands that combine multiple operations
- Commands read relevant files automatically
- Execute multiple steps in sequence
- Provide validation and testing

### 4. Hierarchical Context
**New Feature**: Efficient token usage
- CLAUDE.md: Always loaded (essential info only)
- Commands: Loaded when invoked
- Knowledge: Loaded when referenced

## What Didn't Migrate

### 1. Redundant Information
- Removed duplicate command listings
- Consolidated overlapping instructions
- Eliminated verbose explanations

### 2. Generic Patterns
- Removed obvious Swift patterns
- Excluded standard iOS development practices
- Focused on Mixpanel-specific knowledge

### 3. Outdated Content
- Updated deprecated patterns
- Modernized Swift syntax examples
- Removed references to old versions

## Usage Comparison

### Old Way (Copilot/Cursor)
```
# Had to read through long instructions
# Copy-paste relevant sections
# Manually adapt patterns
```

### New Way (Claude Code)
```
# Direct command execution
/add-property user_subscription_level

# Or reference specific guide
I need to make this thread-safe
@claude/architecture/threading-model.md
```

## Benefits of New Structure

1. **Faster Task Execution**: Slash commands encapsulate entire workflows
2. **Reduced Context Overhead**: Only load what's needed
3. **Better Organization**: Clear separation of concerns
4. **Improved Discoverability**: Commands and guides are self-documenting
5. **Enhanced Examples**: Real code from your codebase
6. **Workflow Automation**: Multi-step procedures automated

## Quick Start Guide

### For Common Tasks:
1. Check if a slash command exists: `/help`
2. Use the command: `/command-name parameters`
3. Follow the generated steps

### For Deep Understanding:
1. Reference specific guides: `@claude/architecture/guide-name.md`
2. Combine multiple references for complex tasks

### For Everything Else:
1. CLAUDE.md has core principles
2. Use `/debug-issue` for troubleshooting
3. Check context-map.md for navigation

## Migration Checklist

- [x] Core instructions consolidated in CLAUDE.md
- [x] Common operations converted to slash commands
- [x] Deep technical guides organized in claude/
- [x] Workflows documented step-by-step
- [x] Context map created for navigation
- [x] All original content preserved or enhanced

The new structure is designed specifically for Claude Code's strengths in:
- Multi-file operations
- Workflow automation
- Contextual understanding
- Efficient token usage