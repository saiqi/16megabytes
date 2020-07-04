module vulpes.db;

public import monetdb.monetdb;

import std.conv : to;
import std.typecons : Flag, Yes, No;
import std.algorithm : map, joiner, filter, countUntil;
import std.variant : visit;
import std.datetime : Date, DateTime;
import std.exception : enforce;
import std.range : isInputRange, ElementType;

/**
Dedicated module `Exception`
*/
class DatastoreException : Exception
{
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/**
An enum that contains all supported SQL types
*/
enum SqlType : string
{
    INTEGER = "INTEGER",
    DOUBLE = "DOUBLE",
    VARCHAR = "VARCHAR",
    DATE = "DATE",
    TIMESTAMP = "TIMESTAMP",
    JSON = "JSON",
    TEXT = "TEXT"
}

/**
A struct that represents a SQL table metadata.
`MetaDataDefinition` constructor.
    Params:
        name = name of the column
        type = type of the column
        nullable = a `std.typecons.Flag` flag to indicate whether the column could be declared as nullable
        unique = a `std.typecons.Flag` flag to indicate whether the column could be declared as unique
        length = the length of the fields if needed (ex: VARCHAR)
    Examples:
    -------------------------------------------------------------------------------------
    auto m = MetaDataDefinition("myfield", SqlType.VARCHAR, No.nullable, No.unique, 15); // myfield VARCHAR(15) NOT NULL
    -------------------------------------------------------------------------------------
*/
struct MetaDataDefinition
{
private:
    string fieldName;
    SqlType fieldType;
    string fieldLength;
    Flag!"nullable" fieldNullable;
    Flag!"unique" fieldUnique;

public:
    ///ditto
    this(const string name, const SqlType type, const Flag!"nullable" nullable,
            const Flag!"unique" unique, const uint length = 0,) pure
    {
        fieldName = name;
        fieldType = type;
        fieldLength = length.to!string;
        fieldNullable = nullable;
        fieldUnique = unique;
    }

    /**
        Returns the name of the field
        */
    string name() pure const
    {
        return fieldName;
    }

    /**
        Returns the SQL field definition sub statement
        Examples:
        ---------
        MetaDataDefinition("myfield", SqlType.VARCHAR, No.nullable, No.unique, 15).toSQL; // returns "myfield VARCHAR(15) NOT NULL"
        ---------
        */
    string toSQL() pure const
    {
        auto sqlStatement = fieldName ~ " " ~ fieldType;
        if (fieldType == SqlType.VARCHAR)
        {
            sqlStatement ~= "(" ~ fieldLength ~ ")";
        }
        if (!fieldNullable)
        {
            sqlStatement ~= " NOT NULL";
        }
        if (fieldUnique)
        {
            sqlStatement ~= " UNIQUE";
        }
        return sqlStatement;
    }
}

unittest
{
    assert(MetaDataDefinition("myfield", SqlType.VARCHAR, Yes.nullable,
            No.unique, 15).toSQL == "myfield VARCHAR(15)");
    assert(MetaDataDefinition("myfield", SqlType.DATE, No.nullable, No.unique)
            .toSQL == "myfield DATE NOT NULL");
    assert(MetaDataDefinition("myfield", SqlType.INTEGER, No.nullable,
            Yes.unique).toSQL == "myfield INTEGER NOT NULL UNIQUE");
}

alias MetaData = immutable(MetaDataDefinition)[];

private string createTableStmt(const string tableName, const MetaData metaDefs,
        const Flag!"ifNotExists" ifNotExists, const Flag!"merge" merge) pure
{
    auto stmt = merge ? "CREATE MERGE TABLE " : "CREATE TABLE ";
    if (ifNotExists)
        stmt ~= "IF NOT EXISTS ";
    stmt ~= tableName;
    auto fields = metaDefs.map!"a.toSQL".joiner(",").to!string;
    return stmt ~ "(" ~ fields ~ ");";
}

unittest
{
    const MetaData meta = [
        MetaDataDefinition("value", SqlType.VARCHAR, Yes.nullable, No.unique,
                15),
        MetaDataDefinition("id", SqlType.INTEGER, Yes.nullable, No.unique)
    ];
    assert(createTableStmt("mytable", meta, No.ifNotExists,
            No.merge) == "CREATE TABLE mytable(value VARCHAR(15),id INTEGER);");
}

/**
Runs a `CREATE TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
    metaDefs    = an immutable list of `MetaDataDefinition`
    ifNotExists = a `std.typecons.Flag` to indicate whether a `IF NOT EXISTS` statement should be added
*/
void createTable(MonetDb conn, const string tableName, const MetaData metaDefs,
        const Flag!"ifNotExists" ifNotExists)
{
    auto stmt = createTableStmt(tableName, metaDefs, ifNotExists, No.merge);
    conn.exec(stmt);
}

/**
Runs a `DROP TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
    ifExists    = a `std.typecons.Flag` to indicate whether a `IF EXISTS` statement should be added
*/
void dropTable(scope MonetDb conn, const string tableName, const Flag!"ifExists" ifExists)
{
    auto stmt = "DROP TABLE ";
    if (ifExists)
        stmt ~= "IF EXISTS ";
    stmt ~= tableName ~ ";";
    conn.exec(stmt);
}

/**
Runs a `TRUNCATE TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
*/
void truncateTable(scope MonetDb conn, const string tableName)
{
    conn.exec("TRUNCATE TABLE " ~ tableName ~ ";");
}

/**
Creates a table and append it to a merge table. See https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/DataPartitioning for more informations.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the merge table
    partitionName = the name of the underlying table
    metaDefs      = an immutable list of `MetaDataDefinition`
*/
void addPartition(MonetDb conn, const string tableName, const string partitionName,
        const MetaData metaDefs)
{
    auto mergeStmt = createTableStmt(tableName, metaDefs, Yes.ifNotExists, Yes.merge);
    conn.exec(mergeStmt);
    auto partStmt = createTableStmt(partitionName, metaDefs, Yes.ifNotExists, No.merge);
    conn.exec(partStmt);
    conn.exec("ALTER TABLE " ~ tableName ~ " ADD TABLE " ~ partitionName ~ ";");
}

/**
Drop a table and remove it from a merge table. See https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/DataPartitioning for more informations.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the merge table
    partitionName = the name of the underlying table
*/
void deletePartition(scope MonetDb conn, const string tableName, const string partitionName)
{
    conn.exec("ALTER TABLE " ~ tableName ~ " DROP TABLE " ~ partitionName ~ ";");
    conn.exec("DROP TABLE " ~ partitionName ~ ";");
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;

    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    scope (exit)
        conn.close();

    string tableName = "mytable";
    string mergeTableName = "mymergetable";
    string partitionName = "mypartition";
    MetaData metas = [
        MetaDataDefinition("myfield", SqlType.INTEGER, No.nullable, Yes.unique)
    ];
    createTable(conn, tableName, metas, Yes.ifNotExists);

    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYTABLE;"));
    assertNotThrown!MonetDbException(truncateTable(conn, tableName));
    assertNotThrown!MonetDbException(dropTable(conn, tableName, Yes.ifExists));

    addPartition(conn, mergeTableName, partitionName, metas);
    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYPARTITION;"));
    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYMERGETABLE;"));
    deletePartition(conn, mergeTableName, partitionName);
    assertThrown!MonetDbException(conn.query("SELECT * FROM MYPARTITION"));
    dropTable(conn, mergeTableName, Yes.ifExists);
}

private string getSQLValue(Record r)
{
    if (r.type == typeid(Date))
        return "'" ~ r.get!Date.toISOExtString ~ "'";
    if (r.type == typeid(char) || r.type == typeid(string))
        return "'" ~ r.toString ~ "'";
    return r.toString;
}

/**
From a given set of records, performs an insert for not existing once otherwise update.
This runs some `MERGE INTO` statements. See https://www.monetdb.org/blog/sql2003_merge_statements_now_supported for more informations.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    metaDefs      = an immutable list of `MetaDataDefinition`
    records       = a lisranget of records
    upsertKeys    = the list of the columns that are used to check whether the current record exists
Examples:
-----------
MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
const string tableName = "upserttable";
scope(exit) {
    conn.close();
}

const MetaData metaDefs = [
    MetaDataDefinition("id", SqlType.INTEGER, No.nullable, No.unique),
    MetaDataDefinition("tenant", SqlType.VARCHAR, No.nullable, No.unique, 5),
    MetaDataDefinition("value", SqlType.INTEGER, Yes.nullable, No.unique)
];
const string[] upsertKeys = ["id", "tenant"];
Record[string][] records = [
    ["id": Record(0), "value": Record(3), "tenant": Record("a")],
    ["id": Record(1), "value": Record(-1), "tenant": Record("a")]
];
upsertRecords(conn, tableName, metaDefs, records, upsertKeys);
-----------
*/
void upsertRecords(R)(scope MonetDb conn, const string tableName,
        const MetaData metaDefs, R records, const string[] upsertKeys)
if (isInputRange!R && is(ElementType!R == Record[string]))
{
    alias makeStatement = (const Record[string] r) {

        enforce!DatastoreException(r.keys.length > 1,
                "Upsert does not support single column records!");

        alias makeOnCondition = (string k) {
            return "T." ~ k ~ " = " ~ r[k].getSQLValue;
        };

        alias makeUpdateStmt = (immutable(MetaDataDefinition) m) {
            return m.name ~ " = " ~ r[m.name].getSQLValue;
        };

        alias isNotAnUpsertKey = (immutable(MetaDataDefinition) m) {
            return countUntil(upsertKeys, m.name) == -1;
        };

        alias makeInsertStmt = (immutable(MetaDataDefinition) m) {
            return r[m.name].getSQLValue;
        };

        alias columnNames = (immutable(MetaDataDefinition) m) => m.name;

        auto stmt = "MERGE INTO " ~ tableName ~ " T USING (SELECT 1 AS FAKE) F ON "
            ~ upsertKeys.map!makeOnCondition.joiner(" AND ")
            .to!string ~ " WHEN MATCHED THEN UPDATE SET " ~ metaDefs.filter!isNotAnUpsertKey
            .map!makeUpdateStmt
            .joiner(", ").to!string ~ " WHEN NOT MATCHED THEN INSERT (" ~ metaDefs.map!columnNames.joiner(", ")
            .to!string ~ ") VALUES (" ~ metaDefs.map!makeInsertStmt.joiner(", ").to!string ~ ")";
        return stmt;
    };

    auto statements = records.map!makeStatement.joiner(";").to!string;

    createTable(conn, tableName, metaDefs, Yes.ifNotExists);
    conn.exec(statements);
}

unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    const string tableName = "upserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }

    const MetaData metaDefs = [
        MetaDataDefinition("id", SqlType.INTEGER, No.nullable, No.unique),
        MetaDataDefinition("tenant", SqlType.VARCHAR, No.nullable, No.unique,
                5),
        MetaDataDefinition("value", SqlType.INTEGER, Yes.nullable, No.unique)
    ];
    const string[] upsertKeys = ["id", "tenant"];
    Record[string][] records = [
        ["id" : Record(0), "value" : Record(3), "tenant" : Record("a")],
        ["id" : Record(1), "value" : Record(-1), "tenant" : Record("a")]
    ];
    upsertRecords(conn, tableName, metaDefs, records, upsertKeys);

    auto res = conn.query("SELECT * FROM " ~ tableName ~ " ORDER BY ID;");
    assert(res.front["id"].get!int == 0);
    assert(res.front["value"].get!int == 3);

    Record[string][] newRecords = [
        ["id" : Record(0), "value" : Record(5), "tenant" : Record("a")],
        ["id" : Record(1), "value" : Record(-1), "tenant" : Record("a")]
    ];
    upsertRecords(conn, tableName, metaDefs, newRecords, upsertKeys);
    assert(conn.query("SELECT * FROM " ~ tableName ~ " WHERE ID = ?",
            [Record(0)]).front["value"].get!int == 5);
}

unittest
{
    import std.array : array;
    import std.range : iota;
    import std.exception : assertThrown;

    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    const string tableName = "singleupserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }
    const MetaData metaDefs = [
        MetaDataDefinition("v", SqlType.INTEGER, No.nullable, No.unique)
    ];
    const string[] upsertKeys = ["v"];
    Record[string][] records = iota(10).map!((int a) => ["v": Record(a)]).array;
    assertThrown!DatastoreException(upsertRecords(conn, tableName, metaDefs, records, upsertKeys));
}

/**
Runs a `DELETE FROM` statement that could have a `WHERE` clause or not.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    deleteKeys    = optional parameter that defines the delete condition. If this parameter is missing all the rows will be deleted.
Examples:
------------
MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
const string tableName = "deletetable";
scope(exit) {
    conn.close();
}
deleteRecords(conn, tableName, ["id": Record(0), "tenant": Record('a')]);
------------
*/
void deleteRecords(scope MonetDb conn, const string tableName, const Record[string] deleteKeys = null)
{
    auto stmt = "DELETE FROM " ~ tableName;
    if (deleteKeys !is null)
    {
        alias makeCondition = (string k) {
            return k ~ " = " ~ deleteKeys[k].getSQLValue;
        };
        stmt ~= " WHERE " ~ deleteKeys.byKey.map!makeCondition.joiner(" AND ").to!string;
    }
    conn.exec(stmt);
}

unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    const string tableName = "deletetable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }

    conn.exec(
            "CREATE TABLE IF NOT EXISTS " ~ tableName
            ~ " (ID INTEGER, TENANT VARCHAR(1), VALUE DOUBLE);");
    conn.exec("INSERT INTO " ~ tableName ~ " (ID, TENANT, VALUE) VALUES (0, 'a', 3.14);");
    conn.exec("INSERT INTO " ~ tableName ~ " (ID, TENANT, VALUE) VALUES (1, 'a', 6.58);");
    conn.exec("INSERT INTO " ~ tableName ~ " (ID, TENANT, VALUE) VALUES (2, 'b', 9.04);");

    deleteRecords(conn, tableName, ["id": Record(0), "tenant": Record('a')]);
    assert(conn.query("SELECT COUNT(*) AS C FROM " ~ tableName ~ ";").front["c"].get!long == 2);

    deleteRecords(conn, tableName);
    assert(conn.query("SELECT * FROM " ~ tableName).empty);
}

/**
Runs a `COPY INTO` statement that is built from a given set of records. See https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/LoadingBulkData for more informations.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    metaDefs      = an immutable list of `MetaDataDefinition`
    records       = a range of records
    chunkSize     = size of the chunk (default 1000)
Examples:
------------
MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
const string tableName = "bulkinserttable";
scope(exit) {
    conn.close();
}
const MetaData metaDefs = [
    MetaDataDefinition("id", SqlType.INTEGER, No.nullable, No.unique),
    MetaDataDefinition("tenant", SqlType.VARCHAR, No.nullable, No.unique, 5),
    MetaDataDefinition("value", SqlType.INTEGER, Yes.nullable, No.unique),
    MetaDataDefinition("creation_date", SqlType.DATE, Yes.nullable, No.unique)
];
Record[string][] records = [
    ["id": Record(0), "tenant": Record("a"), "value": Record(1052), "creation_date": Record(Date(2019, 11, 2))],
    ["id": Record(1), "tenant": Record("a"), "creation_date": Record(null), "value": Record(205)],
    ["id": Record(2), "value": Record(null), "tenant": Record("b"), "creation_date": Record(null)]
];
bulkInsertRecords(conn, tableName, metaDefs, records);
------------
*/
void bulkInsertRecords(R)(scope MonetDb conn, const string tableName,
        const MetaData metaDefs, R records, const size_t chunkSize = 1_000)
if (isInputRange!R && is(ElementType!R == Record[string]))
{
    alias makeData = (const Record[string] r) {

        alias columnNames = (immutable(MetaDataDefinition) m) => m.name;

        alias makeValue = (string k) {
            return r[k].visit!((Null a) => "", (Date a) => a.toISOExtString,
                    (DateTime a) => a.toISOExtString, (a) => a.to!string)();
        };

        return metaDefs.map!columnNames
            .map!makeValue
            .joiner("|").to!string;
    };

    import std.range : chunks;
    import std.array : array;

    createTable(conn, tableName, metaDefs, Yes.ifNotExists);
    foreach (c; records.chunks(chunkSize))
    {
        auto recs = c.array;
        auto stmt = "COPY " ~ recs.length.to!string ~ " RECORDS INTO " ~ tableName ~ " FROM STDIN NULL AS '';";
        stmt ~= recs.map!makeData.joiner("\n").to!string;
        conn.exec(stmt);
    }
}

unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    const string tableName = "bulkinserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }
    const MetaData metaDefs = [
        MetaDataDefinition("id", SqlType.INTEGER, No.nullable, No.unique),
        MetaDataDefinition("tenant", SqlType.VARCHAR, No.nullable, No.unique,
                5),
        MetaDataDefinition("value", SqlType.INTEGER, Yes.nullable, No.unique),
        MetaDataDefinition("creation_date", SqlType.DATE, Yes.nullable, No.unique),
        MetaDataDefinition("sysdate", SqlType.TIMESTAMP, Yes.nullable, No.unique)
    ];
    auto refDt = DateTime(1970, 1, 1, 0, 0, 0);
    Record[string][] records = [
        [
            "id" : Record(0), "tenant" : Record("a"), "value" : Record(1052),
            "creation_date" : Record(Date(2019, 11, 2)), "sysdate" : Record(refDt)
        ],
        [
            "id" : Record(1), "tenant" : Record("a"),
            "creation_date" : Record(null), "value" : Record(205),
            "sysdate" : Record(refDt)
        ],
        [
            "id" : Record(2), "value" : Record(null), "tenant" : Record("b"),
            "creation_date" : Record(null), "sysdate" : Record(refDt)
        ]
    ];
    bulkInsertRecords(conn, tableName, metaDefs, records);

    assert(conn.query("SELECT COUNT(*) AS V FROM " ~ tableName).front["v"].get!long == 3);

    auto res = conn.query("SELECT VALUE, CREATION_DATE, SYSDATE FROM " ~ tableName ~ " WHERE ID = 1");
    assert(res.front["value"].get!int == 205);
    assert(res.front["creation_date"].get!Null is null);
    assert(res.front["sysdate"].get!DateTime == refDt);
}
