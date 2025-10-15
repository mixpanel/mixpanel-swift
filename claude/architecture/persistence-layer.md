# Persistence Layer Architecture

## Overview
The Mixpanel SDK uses SQLite for persistent storage with a carefully designed schema to handle events, people updates, and groups data. The persistence layer ensures data survives app termination and provides efficient batch loading.

## Database Schema

### Core Tables

```sql
-- Events table
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    data BLOB NOT NULL,
    created_at REAL DEFAULT (datetime('now')),
    retry_count INTEGER DEFAULT 0,
    INDEX idx_token_created (token, created_at),
    INDEX idx_uuid (uuid)
);

-- People updates table  
CREATE TABLE IF NOT EXISTS people (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    data BLOB NOT NULL,
    created_at REAL DEFAULT (datetime('now')),
    operation TEXT NOT NULL,  -- 'set', 'unset', 'increment', etc.
    retry_count INTEGER DEFAULT 0
);

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    group_key TEXT NOT NULL,
    group_id TEXT NOT NULL,
    data BLOB NOT NULL,
    created_at REAL DEFAULT (datetime('now')),
    operation TEXT NOT NULL,
    UNIQUE(token, group_key, group_id)
);
```

### Metadata Storage
```sql
-- Configuration and metadata
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Version tracking
INSERT OR REPLACE INTO metadata (key, value) 
VALUES ('db_version', '2');
```

## Architecture Components

### MPDB Class
Central database manager handling all SQLite operations.

```swift
class MPDB {
    private let dbPath: String
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.mixpanel.db", attributes: .concurrent)
    
    init(path: String) throws {
        self.dbPath = path
        try openDatabase()
        try createTables()
        try migrateIfNeeded()
    }
}
```

### MixpanelPersistence Class
High-level interface for SDK components.

```swift
class MixpanelPersistence {
    private let mpdb: MPDB
    private let fileManager = FileManager.default
    
    func saveEntity(_ entity: InternalProperties,
                   type: EntityType,
                   data: Data,
                   metadata: PersistenceMetadata) {
        mpdb.insert(
            table: type.tableName,
            entity: entity,
            data: data,
            metadata: metadata
        )
    }
    
    func loadEntitiesInBatch(type: EntityType, 
                           limit: Int = 50) -> [Data] {
        return mpdb.select(
            from: type.tableName,
            limit: limit,
            orderBy: "created_at ASC"
        )
    }
}
```

## Data Flow

```
Track Event → Encode to JSON → Compress (optional) → Store in SQLite
                                                          ↓
Flush → Load Batch → Send to Network → On Success → Delete from SQLite
                                     ↘ On Failure → Update retry_count
```

## Key Design Decisions

### 1. BLOB Storage for JSON
Events are stored as BLOB (binary) data containing compressed JSON.

**Why?**
- Flexibility: Schema can evolve without migrations
- Performance: Single column read vs. multiple joins
- Compression: Can store gzipped data directly
- Compatibility: Easy to send to API

```swift
// Storing
let jsonData = try JSONSerialization.data(withJSONObject: eventDict)
let compressed = jsonData.gzipped()  // Optional
mpdb.insert(data: compressed)

// Loading
let compressed = mpdb.select(...)
let jsonData = compressed.gunzipped()
let event = try JSONSerialization.jsonObject(with: jsonData)
```

### 2. UUID for Deduplication
Each entity has a UUID to prevent duplicates.

```swift
extension InternalProperties {
    var uuid: String {
        // Generate deterministic UUID from content
        let data = try? JSONSerialization.data(withJSONObject: self)
        return data?.sha256Hash() ?? UUID().uuidString
    }
}
```

### 3. Batch Processing
Events are loaded in configurable batches for efficiency.

```swift
let batchSize = 50  // Default batch size

func flushBatch() {
    while true {
        // Load next batch
        let batch = persistence.loadEntitiesInBatch(
            type: .events,
            limit: batchSize
        )
        
        guard !batch.isEmpty else { break }
        
        // Process batch
        sendToNetwork(batch) { success in
            if success {
                // Delete successfully sent events
                persistence.deleteEntities(batch.map { $0.uuid })
            } else {
                // Update retry count
                persistence.updateRetryCount(batch.map { $0.uuid })
            }
        }
    }
}
```

## Error Handling

### 1. Database Corruption
```swift
func handleCorruption() {
    Logger.error("Database corrupted, recreating...")
    
    // 1. Close current connection
    sqlite3_close(db)
    
    // 2. Move corrupted file
    let backupPath = dbPath + ".corrupted.\(Date().timeIntervalSince1970)"
    try? FileManager.default.moveItem(atPath: dbPath, toPath: backupPath)
    
    // 3. Create new database
    try? openDatabase()
    try? createTables()
}
```

### 2. Disk Space
```swift
func checkDiskSpace() -> Bool {
    let attributes = try? FileManager.default.attributesOfFileSystem(
        forPath: NSHomeDirectory()
    )
    
    if let freeSpace = attributes?[.systemFreeSize] as? Int64 {
        let minRequired: Int64 = 10 * 1024 * 1024  // 10MB
        return freeSpace > minRequired
    }
    
    return false
}
```

### 3. Migration Failures
```swift
func migrateWithFallback() {
    do {
        try performMigration()
    } catch {
        Logger.error("Migration failed: \(error)")
        
        // Option 1: Start fresh (data loss)
        recreateDatabase()
        
        // Option 2: Continue with old schema (feature limited)
        // Mark migration as skipped
    }
}
```

## Performance Optimizations

### 1. Indexes
Strategic indexes for common queries:

```sql
-- For batch loading by token
CREATE INDEX idx_events_batch 
ON events(token, created_at)
WHERE retry_count < 3;

-- For UUID lookups (deduplication)
CREATE INDEX idx_events_uuid 
ON events(uuid);

-- For cleanup operations
CREATE INDEX idx_events_old 
ON events(created_at)
WHERE created_at < datetime('now', '-30 days');
```

### 2. Write-Ahead Logging (WAL)
```swift
// Enable WAL mode for better concurrency
sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)

// Checkpoint periodically
func checkpoint() {
    sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil)
}
```

### 3. Prepared Statements
```swift
// Cache frequently used statements
class StatementCache {
    private var statements: [String: OpaquePointer] = [:]
    
    func prepare(_ sql: String) -> OpaquePointer? {
        if let cached = statements[sql] {
            sqlite3_reset(cached)
            return cached
        }
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            statements[sql] = statement
            return statement
        }
        
        return nil
    }
}
```

## Testing Strategies

### 1. Database State Verification
```swift
func testPersistenceIntegrity() {
    // Store events
    let events = (0..<100).map { createTestEvent(id: $0) }
    events.forEach { persistence.save($0) }
    
    // Verify count
    let count = persistence.countEntities(type: .events)
    XCTAssertEqual(count, 100)
    
    // Load and verify content
    let loaded = persistence.loadAllEntities(type: .events)
    XCTAssertEqual(loaded.count, 100)
    
    // Verify order preserved
    let ids = loaded.compactMap { $0["id"] as? Int }
    XCTAssertEqual(ids, Array(0..<100))
}
```

### 2. Concurrent Access
```swift
func testConcurrentPersistence() {
    let queues = (0..<10).map { 
        DispatchQueue(label: "test.\($0)")
    }
    
    let expectation = XCTestExpectation(description: "Concurrent")
    expectation.expectedFulfillmentCount = 1000
    
    for i in 0..<1000 {
        queues[i % 10].async {
            self.persistence.save(createTestEvent(id: i))
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 10.0)
    
    // Verify all saved
    let count = persistence.countEntities(type: .events)
    XCTAssertEqual(count, 1000)
}
```

### 3. Corruption Recovery
```swift
func testCorruptionRecovery() {
    // Corrupt database file
    let dbPath = persistence.databasePath
    try? "corrupted data".write(toFile: dbPath, atomically: true, encoding: .utf8)
    
    // Attempt to use
    let newPersistence = MixpanelPersistence(token: testToken)
    
    // Should recover and work
    newPersistence.save(createTestEvent())
    XCTAssertEqual(newPersistence.countEntities(type: .events), 1)
}
```

## Maintenance Operations

### 1. Data Cleanup
```swift
// Remove old events
func cleanupOldData(daysToKeep: Int = 30) {
    let cutoffDate = Date().addingTimeInterval(
        -TimeInterval(daysToKeep * 24 * 60 * 60)
    )
    
    let sql = """
        DELETE FROM events 
        WHERE created_at < ? 
        AND retry_count >= 3
    """
    
    mpdb.execute(sql, parameters: [cutoffDate.timeIntervalSince1970])
}
```

### 2. Database Optimization
```swift
// Run periodically (e.g., on app launch)
func optimizeDatabase() {
    // Reclaim space
    sqlite3_exec(db, "VACUUM", nil, nil, nil)
    
    // Update statistics
    sqlite3_exec(db, "ANALYZE", nil, nil, nil)
    
    // Checkpoint WAL
    sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
}
```

### 3. Size Monitoring
```swift
func monitorDatabaseSize() {
    let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath)
    let size = attrs?[.size] as? Int64 ?? 0
    
    if size > 50_000_000 {  // 50MB warning threshold
        Logger.warning("Database size: \(size / 1_000_000)MB")
        
        // Trigger cleanup
        cleanupOldData()
        optimizeDatabase()
    }
}
```