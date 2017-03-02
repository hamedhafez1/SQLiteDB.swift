# SQLiteDB.swift
OpenSource SQLite Library in Swift

### Setup 

##### 1.Add ```libsqlite3.0.tbd``` to project
##### 2.Create ```Objectiv-C``` header file, import sqlitelib to header file
##### 3.Then copy ```SQLiteDB_v*.swift``` in project.

####note : 
  SQLiteDB_v2.1.swift based on Swift  2.1 
  
  SQLiteDB_v3.0.swift based on Swift  3.0

----
### Usage
``` swift
let db = DB.getInstance()
let column =
        [
            "id INTEGER NOT NULL PRIMARY KEY  AUTOINCREMENT",
            "firstname TEXT NOT NULL",
            "lastname TEXT NOT NULL",
            "age INTEGER NOT NULL",
            "studentNumber TEXT NOT NULL"
        ]

db.createTable(tableName: "student", withColumnNamesAndParam: column)
db.executeChange("INSERT INTO student (firstname, lastname, age, studentNumber) VALUES('Mohsen', 'Jahangiri', 30, '9150535')")

let records:[DB.DBRow] = db.executeQuery(sqlStr: "SELECT * FROM student ORDER BY studentNumber ASC")   

for record in records {
            print(record.column["firstname"]?.asString())
            print(record.column["lastname"]?.asString())
            print(record.column["age"]?.asInt())
            print(record.column["studentNumber"]?.asString())
            print("===============================")
        }
```

#### External DB
``` swift
let db = DB.getInstance()
db.copyDBFromBundle(dbName: "database")
```

----
### Developer
#### [Mohammad Hossein Kashizadeh](mailto:mh.kashizadeh@gmail.com)

----
### License
```
Copyright 2016 MH.Kashizadeh
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
