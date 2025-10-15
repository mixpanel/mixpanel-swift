---
mode: agent
tools: [codebase]
description: Implement database schema migration
---
# Implement Database Migration

Create a database migration for: ${input:migrationDescription:Describe the schema change needed}

## Migration Steps

1. **Update MPDB.swift**:
   - Increment database version
   - Add migration logic in appropriate method
   - Ensure backward compatibility

2. **Migration pattern**:
   ```swift
   if oldVersion < newVersion {
       // Perform migration
       // Handle errors gracefully
       // Log migration progress
   }
   ```

3. **Schema changes to handle**:
   - Adding new columns (use ALTER TABLE)
   - Creating new tables
   - Adding indexes for performance
   - Data transformation if needed

4. **Safety requirements**:
   - Never lose user data
   - Handle partial migrations
   - Test with corrupted databases
   - Support rollback if possible

5. **Follow existing patterns**:
   - Reference existing migrations in MPDB
   - Use SQLite best practices
   - Maintain data integrity

6. **Testing migration**:
   - Test upgrade from all previous versions
   - Test with large datasets
   - Verify performance impact
   - Test concurrent access during migration

## Persistence patterns from [persistence instructions](../.github/instructions/persistence.instructions.md)

## Important tables:
- EVENTS_TABLE: Event storage
- PEOPLE_TABLE: User profile updates
- GROUPS_TABLE: Group updates
- AUTOMATIC_EVENTS_TABLE: Automatic event tracking