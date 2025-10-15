---
applyTo: "**/MixpanelPersistence.swift,**/MPDB.swift"
---
# Persistence Layer Instructions

## SQLite Usage
- All database operations go through MPDB class
- Use parameterized queries to prevent SQL injection
- Handle migrations gracefully with version checks
- Close database connections properly

## Entity Storage Patterns
```swift
// Saving entities
let data = JSONHandler.encodeAPIData(entity.apiProperties())
persistence.saveEntity(entity, type: .events, data: data, metadata: metadata)

// Loading entities
let entities = persistence.loadEntitiesInBatch(type: .events, limit: 50)
```

## UserDefaults Storage
Used for lightweight metadata:
- distinctId, anonymousId, userId, alias
- superProperties, timedEvents
- optOutStatus

## Data Types
- Events: InternalProperties with event data
- People: Set, unset, increment operations  
- Groups: Group-specific operations

## Performance Considerations
- Batch operations (limit 50 per batch)
- Use transactions for multiple operations
- Index on important columns (TOKEN, UUID)
- Regular cleanup of old data

## Migration Support
- Check fileExists before migrations
- Migrate from archive files to SQLite
- Preserve data integrity during migration
- Log migration progress

## Error Handling
- Log SQLite errors but don't crash
- Return empty results on read errors
- Skip corrupted entities
- Implement retry logic for transient errors