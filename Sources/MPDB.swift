//
//  MPDB.swift
//  Mixpanel
//
//  Created by Jared McFarland on 7/2/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

import Foundation
import SQLite3

class MPDB {
    private var connection: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let DB_FILE_NAME: String = "MPDB.sqlite"

    let apiToken: String

    init(token: String) {
        // token can be instanceName which can be any string so we strip all non-alhpanumeric characters to prevent SQL errors
        apiToken = String(token.unicodeScalars.filter({ CharacterSet.alphanumerics.contains($0) }))
        open()
    }

    deinit {
        close()
    }

    private func pathToDb() -> String? {
        let manager = FileManager.default
        #if os(iOS)
        let url = manager.urls(for: .libraryDirectory, in: .userDomainMask).last
        #else
        let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).last
        #endif  // os(iOS)

        guard let urlUnwrapped = url?.appendingPathComponent(apiToken + "_" + DB_FILE_NAME).path else {
            return nil
        }
        return urlUnwrapped
    }

    private func tableNameFor(_ persistenceType: PersistenceType) -> String {
        return "mixpanel_\(apiToken)_\(persistenceType)"
    }

    private func reconnect() {
        MixpanelLogger.warn(message: "No database connection found. Calling MPDB.open()")
        open()
    }

    func open() {
        if apiToken.isEmpty {
            MixpanelLogger.error(message: "Project token must not be empty. Database cannot be opened.")
            return
        }
        if let dbPath = pathToDb() {
            // On iOS (excluding Mac Catalyst and simulator), use SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION
            // so the database and its WAL/SHM files remain accessible in the background after first
            // unlock. Without this, WAL file fsync/pwrite can hang indefinitely when the screen is
            // locked during background execution, causing a watchdog kill.
            // Mac Catalyst and the simulator use macOS/host file systems with no Data Protection,
            // so the flag is unnecessary and can cause issues there.
            #if os(iOS) && !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
            let openFlags =
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
                | SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION
            #else
            let openFlags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
            #endif
            if sqlite3_open_v2(dbPath, &connection, openFlags, nil)
                != SQLITE_OK
            {
                logSqlError(message: "Error opening or creating database at path: \(dbPath)")
                close()
            } else {
                MixpanelLogger.info(
                    message: "Successfully opened connection to database at path: \(dbPath)")
                if let db = connection {
                    let pragmaString = "PRAGMA journal_mode=WAL;"
                    var pragmaStatement: OpaquePointer?
                    if sqlite3_prepare_v2(db, pragmaString, -1, &pragmaStatement, nil) == SQLITE_OK {
                        if sqlite3_step(pragmaStatement) == SQLITE_ROW {
                            let res = String(cString: sqlite3_column_text(pragmaStatement, 0))
                            MixpanelLogger.info(message: "SQLite journal mode set to \(res)")
                        } else {
                            logSqlError(message: "Failed to enable journal_mode=WAL")
                        }
                    } else {
                        logSqlError(message: "PRAGMA journal_mode=WAL statement could not be prepared")
                    }
                    sqlite3_finalize(pragmaStatement)
                } else {
                    reconnect()
                }
                createTablesAndIndexes()
            }
        }
    }

    func close() {
        sqlite3_close(connection)
        connection = nil
        MixpanelLogger.info(message: "Connection to database closed.")
    }

    private func recreate() {
        close()
        if let dbPath = pathToDb() {
            do {
                let manager = FileManager.default
                if manager.fileExists(atPath: dbPath) {
                    try manager.removeItem(atPath: dbPath)
                    MixpanelLogger.info(message: "Deleted database file at path: \(dbPath)")
                }
            } catch let error {
                MixpanelLogger.error(
                    message: "Unable to remove database file at path: \(dbPath), error: \(error)")
            }
        }
        reconnect()
    }

    private func createTableFor(_ persistenceType: PersistenceType) {
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let createTableString =
                "CREATE TABLE IF NOT EXISTS \(tableName)(id integer primary key autoincrement,data blob,time real,flag integer);"
            var createTableStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    MixpanelLogger.info(message: "\(tableName) table created")
                } else {
                    logSqlError(message: "\(tableName) table create failed")
                }
            } else {
                logSqlError(message: "CREATE statement for table \(tableName) could not be prepared")
            }
            sqlite3_finalize(createTableStatement)
        } else {
            reconnect()
        }
    }

    private func createIndexFor(_ persistenceType: PersistenceType) {
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let indexName = "idx_\(persistenceType)_time"
            let createIndexString = "CREATE INDEX IF NOT EXISTS \(indexName) ON \(tableName) (time);"
            var createIndexStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, createIndexString, -1, &createIndexStatement, nil) == SQLITE_OK {
                if sqlite3_step(createIndexStatement) == SQLITE_DONE {
                    MixpanelLogger.info(message: "\(indexName) index created")
                } else {
                    logSqlError(message: "\(indexName) index creation failed")
                }
            } else {
                logSqlError(message: "CREATE statement for index \(indexName) could not be prepared")
            }
            sqlite3_finalize(createIndexStatement)
        } else {
            reconnect()
        }
    }

    private func createTablesAndIndexes() {
        createTableFor(PersistenceType.events)
        createIndexFor(PersistenceType.events)
        createTableFor(PersistenceType.people)
        createIndexFor(PersistenceType.people)
        createTableFor(PersistenceType.groups)
        createIndexFor(PersistenceType.groups)
    }

    func insertRow(_ persistenceType: PersistenceType, data: Data, flag: Bool = false) {
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let insertString = "INSERT INTO \(tableName) (data, flag, time) VALUES(?, ?, ?);"
            var insertStatement: OpaquePointer?
            data.withUnsafeBytes { rawBuffer in
                if let pointer = rawBuffer.baseAddress {
                    if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
                        sqlite3_bind_blob(insertStatement, 1, pointer, Int32(rawBuffer.count), SQLITE_TRANSIENT)
                        sqlite3_bind_int(insertStatement, 2, flag ? 1 : 0)
                        sqlite3_bind_double(insertStatement, 3, Date().timeIntervalSince1970)
                        if sqlite3_step(insertStatement) == SQLITE_DONE {
                            MixpanelLogger.info(message: "Successfully inserted row into table \(tableName)")
                        } else {
                            logSqlError(message: "Failed to insert row into table \(tableName)")
                            recreate()
                        }
                    } else {
                        logSqlError(message: "INSERT statement for table \(tableName) could not be prepared")
                        recreate()
                    }
                    sqlite3_finalize(insertStatement)
                }
            }
        } else {
            reconnect()
        }
    }

    func deleteRows(_ persistenceType: PersistenceType, ids: [Int32] = [], isDeleteAll: Bool = false) {
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let deleteString =
                "DELETE FROM \(tableName)\(isDeleteAll ? "" : " WHERE id IN \(idsSqlString(ids))")"
            var deleteStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    MixpanelLogger.info(message: "Successfully deleted rows from table \(tableName)")
                } else {
                    logSqlError(message: "Failed to delete rows from table \(tableName)")
                    recreate()
                }
            } else {
                logSqlError(message: "DELETE statement for table \(tableName) could not be prepared")
                recreate()
            }
            sqlite3_finalize(deleteStatement)
        } else {
            reconnect()
        }
    }

    private func idsSqlString(_ ids: [Int32] = []) -> String {
        var sqlString = "("
        for id in ids {
            sqlString += "\(id),"
        }
        sqlString = String(sqlString.dropLast())
        sqlString += ")"
        return sqlString
    }

    func updateRowsFlag(_ persistenceType: PersistenceType, newFlag: Bool) {
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let updateString = "UPDATE \(tableName) SET flag = \(newFlag) where flag = \(!newFlag)"
            var updateStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    MixpanelLogger.info(message: "Successfully updated rows from table \(tableName)")
                } else {
                    logSqlError(message: "Failed to update rows from table \(tableName)")
                    recreate()
                }
            } else {
                logSqlError(message: "UPDATE statement for table \(tableName) could not be prepared")
                recreate()
            }
            sqlite3_finalize(updateStatement)
        } else {
            reconnect()
        }
    }

    func readRows(
        _ persistenceType: PersistenceType, numRows: Int, flag: Bool = false,
        byteBudget: Int = APIConstants.maxReadBatchByteSize
    )
        -> [InternalProperties]
    {
        var rows: [InternalProperties] = []
        if let db = connection {
            let tableName = tableNameFor(persistenceType)
            let selectString = """
                SELECT id, data FROM \(tableName) WHERE flag = \(flag ? 1 : 0) \
                ORDER BY time LIMIT \(numRows)
                """
            var selectStatement: OpaquePointer?
            var rowsRead: Int = 0
            // Cumulative blob bytes handed to the deserializer. Reading stops before the row that
            // would push this past `byteBudget`, bounding the read in bytes as well as rows.
            // Dropped oversized and malformed rows never count toward it.
            var bytesRead: Int = 0
            var byteBudgetExhausted = false
            // Rows too large to parse safely or that fail deserialization. Collected here and
            // deleted once the statement is finalized rather than mid-iteration, so the delete
            // never runs against a live SELECT.
            var droppedIds: [Int32] = []
            if sqlite3_prepare_v2(db, selectString, -1, &selectStatement, nil) == SQLITE_OK {
                while !byteBudgetExhausted, sqlite3_step(selectStatement) == SQLITE_ROW {
                    autoreleasepool {
                        if let blob = sqlite3_column_blob(selectStatement, 1) {
                            let blobLength = sqlite3_column_bytes(selectStatement, 1)
                            let id = sqlite3_column_int(selectStatement, 0)

                            // Checked before the blob is copied or parsed: an oversized row can
                            // exhaust memory during deserialization, which Foundation raises as an
                            // uncatchable NSMallocException. See APIConstants.maxRowByteSize.
                            if blobLength > APIConstants.maxRowByteSize {
                                MixpanelLogger.error(
                                    message:
                                        "Dropping oversized row \(id) from table \(tableName): \(blobLength) bytes exceeds the \(APIConstants.maxRowByteSize) byte limit"
                                )
                                droppedIds.append(id)
                                return
                            }

                            // The first row is always read regardless of budget — the per-row cap
                            // above bounds it — so a budget smaller than one row can never stall
                            // the queue.
                            if rowsRead > 0, bytesRead + Int(blobLength) > byteBudget {
                                byteBudgetExhausted = true
                                return
                            }

                            let data = Data(bytes: blob, count: Int(blobLength))
                            if let jsonObject = JSONHandler.deserializeData(data) as? InternalProperties {
                                var entity = jsonObject
                                entity["id"] = id
                                rows.append(entity)
                                rowsRead += 1
                                bytesRead += Int(blobLength)
                            } else {
                                MixpanelLogger.warn(
                                    message:
                                        "Dropping malformed row \(id) from table \(tableName): JSON deserialization failed"
                                )
                                droppedIds.append(id)
                            }
                        } else {
                            logSqlError(message: "No blob found in data column for row in \(tableName)")
                        }
                    }
                }
                if rowsRead > 0 {
                    MixpanelLogger.info(message: "Successfully read \(rowsRead) from table \(tableName)")
                }
            } else {
                logSqlError(message: "SELECT statement for table \(tableName) could not be prepared")
            }
            sqlite3_finalize(selectStatement)
            if !droppedIds.isEmpty {
                deleteRows(persistenceType, ids: droppedIds)
            }
        } else {
            reconnect()
        }
        return rows
    }

    private func logSqlError(message: String? = nil) {
        if let db = connection {
            if let msg = message {
                MixpanelLogger.error(message: msg)
            }
            let sqlError = String(cString: sqlite3_errmsg(db)!)
            MixpanelLogger.error(message: sqlError)
        } else {
            reconnect()
        }
    }
}
