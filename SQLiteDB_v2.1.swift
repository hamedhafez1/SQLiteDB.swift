//
//  SQLiteDB.swift
//  SQLiteDB Library
//
//  Created by Mohammad Hossein Kashizadeh on 10/7/15.
//  Copyright © 2015 uncox. All rights reserved.
//

import Foundation

public class DB {
    
    private static var db:DB?
    private var dbHandler: COpaquePointer = nil
    
    internal static func getInstance() -> DB{
        if(db != nil){
            return db!
        }else {
            db = DB()
            return db!
        }
    }
    
    private init(){}
    
    private func openDB()->Int?{
        let documents = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        
        let dbPath = documents.URLByAppendingPathComponent("db.sqlite")
        
        let status = sqlite3_open(dbPath.path!, &dbHandler)
        if status != SQLITE_OK {
            print("Database Error  -> During: Opening Database")
            print("                -> Code: \(status) - " + Error.errorMessageFromCode(Int(status)))
            if let errMsg = String.fromCString(sqlite3_errmsg(dbHandler)) {
                print("                -> Details: \(errMsg)")
            }
            return Int(status)
        }
        return nil
    }
    
    
    private func closeDB(withError:Bool = false, during:String = "", status:Int32 = -1){
        if(withError){
            print("Database Error  -> During: \(during)")
            print("                -> Code: \(status) - " + Error.errorMessageFromCode(Int(status)))
            if let errMsg = String.fromCString(sqlite3_errmsg(dbHandler)) {
                print("                -> Details: \(errMsg)")
            }
        }
        
        if sqlite3_close(dbHandler) != SQLITE_OK {
            print("error closing database")
        }
        dbHandler = nil
    }
    
    
    public func createTable(tableName:String, withColumnNamesAndParam columns: [String])->Int?{
        var status:Int?
        if let error = openDB() {
            status = error
            return status
        }
        
        var sqlStr = "CREATE TABLE IF NOT EXISTS \(tableName) ("
        var firstColumn = true
        
        for column in columns {
            if firstColumn {
                sqlStr += column
                firstColumn = false
            } else {
                sqlStr += ", \(column)"
            }
        }
        sqlStr += ")"
        
        if sqlite3_exec(dbHandler, sqlStr, nil, nil, nil) != SQLITE_OK {
            let errmsg = String.fromCString(sqlite3_errmsg(dbHandler))
            print("error creating table: \(errmsg)")
        }
        closeDB()
        
        return status
    }
    
    
    public func deleteTable(table: String) {
        let sqlStr = "DROP TABLE \(table)"
        if(executeChange(sqlStr) == nil){
            print("Table deleted")
        }
    }
    
    public func lastInsertedRowID() -> Int {
        let id = sqlite3_last_insert_rowid(dbHandler)
        return Int(id)
    }
    
    public func executeChange(sqlStr: String) -> Int? {
        if let error = openDB() {
            closeDB()
            return error
        }
        
        var pStmt: COpaquePointer = nil
        var status = sqlite3_prepare_v2(dbHandler, sqlStr, -1, &pStmt, nil)
        
        if status != SQLITE_OK {
            sqlite3_finalize(pStmt)
            closeDB(true, during: "SQL Prepare", status: status)
            return Int(status)
        }
        
        status = sqlite3_step(pStmt)
        if status != SQLITE_DONE && status != SQLITE_OK {
            sqlite3_finalize(pStmt)
            closeDB(true, during: "SQL Step", status: status)
            return Int(status)
        }
        
        sqlite3_finalize(pStmt)
        closeDB()
        return nil
    }
    
    
    public func executeQuery(sqlStr: String) -> [DBRow] {
        var pStmt: COpaquePointer = nil
        var resultSet = [DBRow]()
        
        if let error = openDB() {
            closeDB()
            return resultSet
        }
        
        var status = sqlite3_prepare_v2(dbHandler, sqlStr, -1, &pStmt, nil)
        if status != SQLITE_OK {
            sqlite3_finalize(pStmt)
            closeDB(true, during: "SQL Prepare", status: status)
            return resultSet
        }
        
        var columnCount: Int32 = 0
        var next = true
        while next {
            status = sqlite3_step(pStmt)
            if status == SQLITE_ROW {
                columnCount = sqlite3_column_count(pStmt)
                let row = DBRow()
                for var i:Int32=0; i<columnCount; ++i {
                    let columnName = String.fromCString(sqlite3_column_name(pStmt, i))!
                    if let columnType = String.fromCString(sqlite3_column_decltype(pStmt, i))?.uppercaseString {
                        if let columnValue: AnyObject = getColumnValue(pStmt, index: i, type: columnType) {
                            row[columnName] = DBColumn(obj: columnValue)
                        }
                    } else {
                        var columnType = ""
                        switch sqlite3_column_type(pStmt, i) {
                        case SQLITE_INTEGER:
                            columnType = "INTEGER"
                        case SQLITE_FLOAT:
                            columnType = "FLOAT"
                        case SQLITE_TEXT:
                            columnType = "TEXT"
                        case SQLITE3_TEXT:
                            columnType = "TEXT"
                        case SQLITE_BLOB:
                            columnType = "BLOB"
                        case SQLITE_NULL:
                            columnType = "NULL"
                        default:
                            columnType = "NULL"
                        }
                        if let columnValue: AnyObject = getColumnValue(pStmt, index: i, type: columnType) {
                            row[columnName] = DBColumn(obj: columnValue)
                        }
                    }
                }
                resultSet.append(row)
            } else if status == SQLITE_DONE {
                next = false
            } else {
                sqlite3_finalize(pStmt)
                closeDB(true, during: "SQL Step", status: status)
                return resultSet
            }
        }
        
        sqlite3_finalize(pStmt)
        closeDB()
        return resultSet
    }
    
    
    public class DBRow {
        
        var column = [String: DBColumn]()
        public subscript(key: String) -> DBColumn? {
            get {
                return column[key]
            }
            set(newValue) {
                column[key] = newValue
            }
        }
        
    }
    
    public class DBColumn {
        
        var value: AnyObject
        init(obj: AnyObject) {
            value = obj
        }
        
        public func asString() -> String? {
            return value as? String
        }
        
        public func asInt() -> Int? {
            return value as? Int
        }
        
        public func asDouble() -> Double? {
            return value as? Double
        }
        
        public func asBool() -> Bool? {
            return value as? Bool
        }
        
        public func asData() -> NSData? {
            return value as? NSData
        }
        
        public func asDate() -> NSDate? {
            return value as? NSDate
        }
        
        public func asAnyObject() -> AnyObject? {
            return value
        }
    }
    
    private func getColumnValue(statement: COpaquePointer, index: Int32, type: String) -> AnyObject? {
        
        switch type {
        case "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT", "BIGINT", "UNSIGNED BIG INT", "INT2", "INT8":
            if sqlite3_column_type(statement, index) == SQLITE_NULL {
                return nil
            }
            return Int(sqlite3_column_int(statement, index))
        case "CHARACTER(20)", "VARCHAR(255)", "VARYING CHARACTER(255)", "NCHAR(55)", "NATIVE CHARACTER", "NVARCHAR(100)", "TEXT", "CLOB":
            let text = UnsafePointer<Int8>(sqlite3_column_text(statement, index))
            return String.fromCString(text)
        case "BLOB", "NONE":
            let blob = sqlite3_column_blob(statement, index)
            if blob != nil {
                let size = sqlite3_column_bytes(statement, index)
                return NSData(bytes: blob, length: Int(size))
            }
            return nil
        case "REAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT", "NUMERIC", "DECIMAL(10,5)":
            if sqlite3_column_type(statement, index) == SQLITE_NULL {
                return nil
            }
            return Double(sqlite3_column_double(statement, index))
        case "BOOLEAN":
            if sqlite3_column_type(statement, index) == SQLITE_NULL {
                return nil
            }
            return sqlite3_column_int(statement, index) != 0
        case "DATE", "DATETIME":
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let text = UnsafePointer<Int8>(sqlite3_column_text(statement, index))
            if let string = String.fromCString(text) {
                return dateFormatter.dateFromString(string)
            }
            print("Database Warning -> The text date at column: \(index) could not be cast as a String, returning nil")
            return nil
        default:
            print("Database Warning -> Column: \(index) is of an unrecognized type, returning nil")
            return nil
        }
        
    }
    
    class Error {
        
        private static func errorMessageFromCode(errorCode: Int) -> String {
            
            switch errorCode {
                
            case -1:
                return "No error"
            case 0:
                return "Successful result"
            case 1:
                return "SQL error or missing database"
            case 2:
                return "Internal logic error in SQLite"
            case 3:
                return "Access permission denied"
            case 4:
                return "Callback routine requested an abort"
            case 5:
                return "The database file is locked"
            case 6:
                return "A table in the database is locked"
            case 7:
                return "A malloc() failed"
            case 8:
                return "Attempt to write a readonly database"
            case 9:
                return "Operation terminated by sqlite3_interrupt()"
            case 10:
                return "Some kind of disk I/O error occurred"
            case 11:
                return "The database disk image is malformed"
            case 12:
                return "Unknown opcode in sqlite3_file_control()"
            case 13:
                return "Insertion failed because database is full"
            case 14:
                return "Unable to open the database file"
            case 15:
                return "Database lock protocol error"
            case 16:
                return "Database is empty"
            case 17:
                return "The database schema changed"
            case 18:
                return "String or BLOB exceeds size limit"
            case 19:
                return "Abort due to constraint violation"
            case 20:
                return "Data type mismatch"
            case 21:
                return "Library used incorrectly"
            case 22:
                return "Uses OS features not supported on host"
            case 23:
                return "Authorization denied"
            case 24:
                return "Auxiliary database format error"
            case 25:
                return "2nd parameter to sqlite3_bind out of range"
            case 26:
                return "File opened that is not a database file"
            case 27:
                return "Notifications from sqlite3_log()"
            case 28:
                return "Warnings from sqlite3_log()"
            case 100:
                return "sqlite3_step() has another row ready"
            case 101:
                return "sqlite3_step() has finished executing"
            case 201:
                return "Not enough objects to bind provided"
            case 202:
                return "Too many objects to bind provided"
            case 203:
                return "Object to bind as identifier must be a String"
            case 301:
                return "A custom connection is already open"
            case 302:
                return "Cannot open a custom connection inside a transaction"
            case 303:
                return "Cannot open a custom connection inside a savepoint"
            case 304:
                return "A custom connection is not currently open"
            case 305:
                return "Cannot close a custom connection inside a transaction"
            case 306:
                return "Cannot close a custom connection inside a savepoint"
            case 401:
                return "At least one column name must be provided"
            case 402:
                return "Error extracting index names from sqlite_master"
            case 403:
                return "Error extracting table names from sqlite_master"
            case 501:
                return "Cannot begin a transaction within a savepoint"
            case 502:
                return "Cannot begin a transaction within another transaction"
            default:
                return "Unknown error"
            }
        }
    }
}

