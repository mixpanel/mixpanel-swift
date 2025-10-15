# Claude Code Context Map

This document explains how the Mixpanel Swift SDK context is organized for Claude Code.

## Directory Structure

```
mixpanel-swift/
├── CLAUDE.md                    # Always-loaded core context
├── .claude/
│   └── commands/               # Slash commands for common operations
│       ├── add-property.md     # /add-property - Add automatic event property
│       ├── new-api.md          # /new-api - Create public API method
│       ├── fix-thread-safety.md # /fix-thread-safety - Fix concurrency issues
│       ├── write-test.md       # /write-test - Generate unit tests
│       ├── debug-issue.md      # /debug-issue - Debug SDK problems
│       └── migrate-db.md       # /migrate-db - Database schema changes
└── claude/                     # Knowledge cache (loaded on demand)
    ├── architecture/           # System design documentation
    │   ├── threading-model.md  # Deep dive into concurrency
    │   └── persistence-layer.md # Database architecture
    ├── patterns/               # Reusable code patterns
    │   └── type-safety-patterns.md # MixpanelType system
    ├── technologies/           # Technology-specific guides
    │   └── swift-features.md   # Swift language features usage
    └── workflows/              # Multi-step procedures
        └── release-process.md  # Complete release workflow
```

## What Lives Where

### CLAUDE.md (Always Available)
**Purpose**: Core information needed for every coding task
- Critical architecture principles
- Thread safety rules
- Type system requirements
- Essential commands
- Core coding standards
- Key file references
- Platform support matrix

**When to use**: Automatically loaded, always available

### Slash Commands (.claude/commands/)
**Purpose**: Streamline common development tasks
- `/add-property` - Add new automatic event properties
- `/new-api` - Implement public API methods
- `/fix-thread-safety` - Fix concurrency issues
- `/write-test` - Generate comprehensive tests
- `/debug-issue` - Debug SDK problems
- `/migrate-db` - Implement database migrations

**When to use**: Type `/command-name` in chat to execute

### Architecture Guides (claude/architecture/)
**Purpose**: Deep understanding of system design
- **threading-model.md**: Complete guide to concurrency, queues, and thread safety
- **persistence-layer.md**: SQLite schema, data flow, and storage patterns

**When to use**: Reference with `@claude/architecture/threading-model.md` when working on complex system changes

### Pattern Library (claude/patterns/)
**Purpose**: Reusable implementation patterns
- **type-safety-patterns.md**: MixpanelType protocol, validation, and conversion patterns

**When to use**: Reference when implementing new features that need type validation

### Technology Guides (claude/technologies/)
**Purpose**: Language and framework-specific knowledge
- **swift-features.md**: Advanced Swift features and how they're used in the SDK

**When to use**: When exploring new Swift features or optimizations

### Workflows (claude/workflows/)
**Purpose**: Step-by-step procedures for complex tasks
- **release-process.md**: Complete release checklist and automation

**When to use**: When preparing releases or need detailed procedural guidance

## How to Use This Structure

### 1. Starting a Task
- CLAUDE.md is automatically loaded
- Check if a slash command exists for your task
- Use `/help` to see available commands

### 2. Needing Specific Knowledge
Reference files directly:
```
@claude/architecture/threading-model.md
```

### 3. Complex Tasks
Combine multiple resources:
```
I need to add a new API method that's thread-safe.
/new-api trackBatch(events: [Event])
@claude/architecture/threading-model.md
```

### 4. Debugging
```
/debug-issue Events aren't persisting
@claude/architecture/persistence-layer.md
```

## Best Practices

1. **Start with slash commands** - They encapsulate common workflows
2. **Reference specific guides** - Use @ mentions for detailed knowledge
3. **CLAUDE.md is your foundation** - Core principles always apply
4. **Combine resources** - Complex tasks often need multiple guides

## Quick Reference

| Need to... | Use... |
|------------|--------|
| Add event property | `/add-property` |
| Create new API | `/new-api` |
| Fix thread issues | `/fix-thread-safety` |
| Write tests | `/write-test` |
| Debug problems | `/debug-issue` |
| Update database | `/migrate-db` |
| Understand threading | `@claude/architecture/threading-model.md` |
| Understand storage | `@claude/architecture/persistence-layer.md` |
| Validate types | `@claude/patterns/type-safety-patterns.md` |
| Use Swift features | `@claude/technologies/swift-features.md` |
| Release version | `@claude/workflows/release-process.md` |

## Context Philosophy

- **CLAUDE.md**: Minimum viable context for any task
- **Commands**: Encapsulated workflows for efficiency
- **Knowledge Cache**: Deep dives loaded on demand
- **Separation**: Keeps token usage efficient while maintaining depth