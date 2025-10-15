# /migrate-db

Implement database schema migrations for the Mixpanel SDK.

## Usage
```
/migrate-db Add retry_count column to events table
/migrate-db Create indexes for performance
```

## Migration Implementation Guide

### 1. Update Database Version
```swift
// In MPDB.swift
private let CURRENT_DB_VERSION = 3  // Increment this
```

### 2. Add Migration Logic

```swift
// In MPDB.swift, add to appropriate migration method
func migrateDatabase() {
    let oldVersion = getCurrentVersion()
    
    if oldVersion < 2 {
        migrateToV2()
    }
    
    if oldVersion < 3 {
        migrateToV3()
    }
    
    updateVersion(CURRENT_DB_VERSION)
}

private func migrateToV3() {
    do {
        // Start transaction
        try db.execute("BEGIN TRANSACTION")
        
        // Add new column
        try db.execute("""
            ALTER TABLE events 
            ADD COLUMN retry_count INTEGER DEFAULT 0
        """)
        
        // Add index for performance
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_events_retry 
            ON events(retry_count, created_at)
        """)
        
        // Update metadata
        try db.execute("""
            INSERT OR REPLACE INTO metadata (key, value)
            VALUES ('migration_v3_date', ?)
        """, Date().timeIntervalSince1970)
        
        // Commit
        try db.execute("COMMIT")
        
        Logger.info("Successfully migrated to v3")
        
    } catch {
        // Rollback on error
        try? db.execute("ROLLBACK")
        Logger.error("Migration to v3 failed: \(error)")
        throw error
    }
}
```

### 3. Common Migration Patterns

#### Add Column with Default
```swift
// Safe for existing data
ALTER TABLE events ADD COLUMN status TEXT DEFAULT 'pending'
```

#### Create New Table
```swift
CREATE TABLE IF NOT EXISTS event_metadata (
    event_id TEXT PRIMARY KEY,
    retry_count INTEGER DEFAULT 0,
    last_retry_at REAL,
    error_message TEXT,
    FOREIGN KEY (event_id) REFERENCES events(uuid)
)
```

#### Add Index for Performance
```swift
// For frequently queried columns
CREATE INDEX idx_events_token_created 
ON events(token, created_at)

// For WHERE clauses
CREATE INDEX idx_events_status 
ON events(status) 
WHERE status != 'sent'
```

#### Data Migration
```swift
// Transform existing data
UPDATE events 
SET new_column = CASE 
    WHEN old_column = 'value1' THEN 'new_value1'
    WHEN old_column = 'value2' THEN 'new_value2'
    ELSE 'default'
END
```

### 4. Safety Measures

```swift
private func safelyMigrate(from: Int, to: Int) throws {
    // Backup critical data first
    let backupPath = databasePath + ".backup.\(from)"
    try FileManager.default.copyItem(
        atPath: databasePath,
        toPath: backupPath
    )
    
    do {
        try performMigration(from: from, to: to)
    } catch {
        // Restore backup on failure
        Logger.error("Migration failed, restoring backup")
        try? FileManager.default.removeItem(atPath: databasePath)
        try? FileManager.default.moveItem(
            atPath: backupPath,
            toPath: databasePath
        )
        throw error
    }
    
    // Clean up backup after success
    try? FileManager.default.removeItem(atPath: backupPath)
}
```

### 5. Testing Migrations

```swift
func testMigrationFromV2ToV3() {
    // Create v2 database
    let v2db = createV2Database()
    
    // Insert test data
    v2db.insert(testEvents)
    
    // Close and reopen with new version
    v2db.close()
    let v3db = MPDB(path: v2db.path)
    
    // Verify migration
    XCTAssertTrue(v3db.columnExists("retry_count", in: "events"))
    XCTAssertEqual(v3db.version, 3)
    
    // Verify data integrity
    let events = v3db.loadEvents()
    XCTAssertEqual(events.count, testEvents.count)
}
```

### 6. Migration Checklist

- [ ] Increment `CURRENT_DB_VERSION`
- [ ] Add migration method `migrateToVX()`
- [ ] Use transactions for atomicity
- [ ] Handle errors gracefully
- [ ] Log migration progress
- [ ] Test upgrade paths from all versions
- [ ] Verify data integrity
- [ ] Add rollback capability
- [ ] Document schema changes

### 7. Schema Best Practices

```sql
-- Use appropriate data types
CREATE TABLE events (
    uuid TEXT PRIMARY KEY,
    token TEXT NOT NULL,
    data BLOB NOT NULL,  -- JSON data
    created_at REAL DEFAULT (datetime('now')),
    retry_count INTEGER DEFAULT 0
);

-- Add constraints
CREATE TABLE people (
    uuid TEXT PRIMARY KEY,
    token TEXT NOT NULL,
    data BLOB NOT NULL,
    UNIQUE(token, uuid)
);

-- Optimize with indexes
CREATE INDEX idx_events_flush 
ON events(token, created_at)
WHERE retry_count < 3;
```

### 8. Performance Considerations

```swift
// Run VACUUM periodically
func optimizeDatabase() {
    do {
        try db.execute("VACUUM")
        try db.execute("ANALYZE")
    } catch {
        Logger.warning("Database optimization failed: \(error)")
    }
}

// Monitor database size
func getDatabaseSize() -> Int64 {
    let attr = try? FileManager.default.attributesOfItem(atPath: databasePath)
    return attr?[.size] as? Int64 ?? 0
}
```

## Common Migration Scenarios

1. **Adding retry logic**: Add retry_count, last_retry columns
2. **Performance optimization**: Add indexes on frequently queried columns  
3. **New features**: Add tables for new data types
4. **Data cleanup**: Remove obsolete columns/tables
5. **Schema normalization**: Split large tables