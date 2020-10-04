module vulpes.db;

public import monetdb.monetdb;

import std.conv : to;
import std.typecons : Flag, Yes, No;
import std.algorithm : map, joiner, filter, countUntil;
import std.variant : visit;
import std.datetime : Date, DateTime;
import std.exception : enforce;
import std.range : isInputRange, ElementType;


///Dedicated module `Exception`
class DatastoreException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}


///Contain all supported SQL types
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

alias IsUnique = Flag!"unique";
alias IsNullable = Flag!"nullable";
alias IfExists = Flag!"ifExists";
alias IsMerge = Flag!"merge";
alias IfNotExists = Flag!"ifNotExists";

/// An SQL table representation
struct MetaDataDefinition
{
private:
    string fieldName;
    SqlType fieldType;
    string fieldLength;
    IsNullable fieldNullable;
    IsUnique fieldUnique;

public:
    /**
    `MetaDataDefinition` constructor.
        Params:
            name = name of the column
            type = type of the column
            nullable = a `std.typecons.Flag` flag to indicate whether the column could be declared as nullable
            unique = a `std.typecons.Flag` flag to indicate whether the column could be declared as unique
            length = the length of the fields if needed (ex: VARCHAR)
    */
    @safe this(const string name, const SqlType type, const IsNullable nullable,
            const IsUnique unique, const uint length = 0,)
    {
        enforce!DatastoreException(
            (type == SqlType.VARCHAR && length > 0) || type != SqlType.VARCHAR,
            "VARCHAR must have a length greater than 0");
        fieldName = name;
        fieldType = type;
        fieldLength = length.to!string;
        fieldNullable = nullable;
        fieldUnique = unique;
    }

    ///
    @safe unittest
    {
        immutable m = MetaDataDefinition("myfield", SqlType.VARCHAR, IsNullable.no, IsUnique.no, 15);
        import std.exception : assertThrown;
        assertThrown!DatastoreException(
            MetaDataDefinition("foo", SqlType.VARCHAR, IsNullable.no, IsUnique.no));
    }

    ///Return the name of the field
    @safe string name() pure nothrow const
    {
        return fieldName;
    }

    ///Return the SQL field definition statement
    @safe string toSQL() pure nothrow const
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

    ///
    @safe unittest
    {
        immutable m = MetaDataDefinition("myfield", SqlType.VARCHAR, IsNullable.no, IsUnique.no, 15);
        assert(m.toSQL == "myfield VARCHAR(15) NOT NULL");

        assert(MetaDataDefinition("myfield", SqlType.VARCHAR, IsNullable.yes,
            IsUnique.no, 15).toSQL == "myfield VARCHAR(15)");
        assert(MetaDataDefinition("myfield", SqlType.DATE, IsNullable.no, IsUnique.no)
                .toSQL == "myfield DATE NOT NULL");
        assert(MetaDataDefinition("myfield", SqlType.INTEGER, IsNullable.no,
                IsUnique.yes).toSQL == "myfield INTEGER NOT NULL UNIQUE");
    }
}

alias MetaData = immutable(MetaDataDefinition)[];

private string createTableStmt(const string tableName, const MetaData metaDefs,
        const IfNotExists ifNotExists, const IsMerge merge) pure
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
        MetaDataDefinition("value", SqlType.VARCHAR, IsNullable.yes, IsUnique.no,
                15),
        MetaDataDefinition("id", SqlType.INTEGER, IsNullable.yes, IsUnique.no)
    ];
    assert(createTableStmt("mytable", meta, IfNotExists.no,
            IsMerge.no) == "CREATE TABLE mytable(value VARCHAR(15),id INTEGER);");
}

/**
Run a `CREATE TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
    metaDefs    = an immutable list of `MetaDataDefinition`
    ifNotExists = a `std.typecons.Flag` to indicate whether a `IF NOT EXISTS` statement should be added
Throws: monetdb.MonetDbException on failure
*/
void createTable(MonetDb conn, const string tableName, const MetaData metaDefs,
        const IfNotExists ifNotExists)
{
    auto stmt = createTableStmt(tableName, metaDefs, ifNotExists, IsMerge.no);
    conn.exec(stmt);
}

/**
Run a `DROP TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
    ifExists    = a `std.typecons.Flag` to indicate whether a `IF EXISTS` statement should be added
Throws: monetdb.MonetDbException on failure
*/
void dropTable(scope MonetDb conn, const string tableName, const IfExists ifExists)
{
    auto stmt = "DROP TABLE ";
    if (ifExists)
        stmt ~= "IF EXISTS ";
    stmt ~= tableName ~ ";";
    conn.exec(stmt);
}

/**
Run a `TRUNCATE TABLE` statement
Params:
    conn        = a `monetdb.MonetDb` connection instance
    tableName   = the name of the table
Throws: monetdb.MonetDbException on failure
*/
void truncateTable(scope MonetDb conn, const string tableName)
{
    conn.exec("TRUNCATE TABLE " ~ tableName ~ ";");
}

/**
Create a table and append it to a merge table
See_Also: https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/DataPartitioning
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the merge table
    partitionName = the name of the underlying table
    metaDefs      = an immutable list of `MetaDataDefinition`
Throws: monetdb.MonetDbException on failure
*/
void addPartition(MonetDb conn, const string tableName, const string partitionName,
        const MetaData metaDefs)
{
    auto mergeStmt = createTableStmt(tableName, metaDefs, IfNotExists.yes, IsMerge.yes);
    conn.exec(mergeStmt);
    auto partStmt = createTableStmt(partitionName, metaDefs, IfNotExists.yes, IsMerge.no);
    conn.exec(partStmt);
    conn.exec("ALTER TABLE " ~ tableName ~ " ADD TABLE " ~ partitionName ~ ";");
}

/**
Drop a table and remove it from a merge table
See_Also: https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/DataPartitioning
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the merge table
    partitionName = the name of the underlying table
Throws: monetdb.MonetDbException on failure
*/
void deletePartition(scope MonetDb conn, const string tableName, const string partitionName)
{
    conn.exec("ALTER TABLE " ~ tableName ~ " DROP TABLE " ~ partitionName ~ ";");
    conn.exec("DROP TABLE " ~ partitionName ~ ";");
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;

    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "vulpes-test");
    scope (exit)
        conn.close();

    string tableName = "mytable";
    string mergeTableName = "mymergetable";
    string partitionName = "mypartition";
    MetaData metas = [
        MetaDataDefinition("myfield", SqlType.INTEGER, IsNullable.no, IsUnique.yes)
    ];
    createTable(conn, tableName, metas, IfNotExists.yes);

    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYTABLE;"));
    assertNotThrown!MonetDbException(truncateTable(conn, tableName));
    assertNotThrown!MonetDbException(dropTable(conn, tableName, IfExists.yes));

    addPartition(conn, mergeTableName, partitionName, metas);
    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYPARTITION;"));
    assertNotThrown!MonetDbException(conn.query("SELECT * FROM MYMERGETABLE;"));
    deletePartition(conn, mergeTableName, partitionName);
    assertThrown!MonetDbException(conn.query("SELECT * FROM MYPARTITION"));
    dropTable(conn, mergeTableName, IfExists.yes);
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
Upsert records on top of `MERGE INTO` statements
See_Also: https://www.monetdb.org/blog/sql2003_merge_statements_now_supported
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    metaDefs      = an immutable list of `MetaDataDefinition`
    records       = a lisranget of records
    upsertKeys    = the list of the columns that are used to check whether the current record exists
Throws: monetdb.MonetDbException on failure, DatastoreException on unsupported operation
*/
void upsertRecords(R)(scope MonetDb conn, const string tableName,
        const MetaData metaDefs, R records, const string[] upsertKeys)
if (isInputRange!R && is(ElementType!R == Record[string]))
{
    alias makeStatement = (const Record[string] r) {

        enforce!DatastoreException(r.keys.length > 1,
                "Upsert does not support single column records!");

        auto stmt = "MERGE INTO "
            ~ tableName
            ~ " T USING (VALUES ("
            ~ upsertKeys.map!(k => r[k].getSQLValue).joiner(",").to!string ~ ")) F ("
            ~ upsertKeys.map!(k => k).joiner(",").to!string
            ~ ") ON "
            ~ upsertKeys.map!(k => "T." ~ k ~ " = F." ~ k).joiner(" AND ").to!string
            ~ " WHEN MATCHED THEN UPDATE SET "
            ~ metaDefs
                .filter!(m => countUntil(upsertKeys, m.name) == -1)
                .map!(m => m.name ~ " = " ~ r[m.name].getSQLValue).joiner(", ").to!string
            ~ " WHEN NOT MATCHED THEN INSERT ("
            ~ metaDefs.map!(m => m.name).joiner(", ").to!string
            ~ ") VALUES ("
            ~ metaDefs.map!(m => r[m.name].getSQLValue).joiner(", ").to!string ~ ")";

        return stmt;
    };

    auto statements = records.map!makeStatement.joiner(";").to!string;

    createTable(conn, tableName, metaDefs, Yes.ifNotExists);
    conn.exec(statements);
}

///
unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "vulpes-test");
    const string tableName = "upserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }

    const MetaData metaDefs = [
        MetaDataDefinition("id", SqlType.INTEGER, IsNullable.no, IsUnique.no),
        MetaDataDefinition("tenant", SqlType.VARCHAR, IsNullable.no, IsUnique.no,
                5),
        MetaDataDefinition("value", SqlType.INTEGER, IsNullable.yes, IsUnique.no)
    ];
    const string[] upsertKeys = ["id", "tenant"];
    Record[string][] records = [
        ["id" : Record(0), "value" : Record(3), "tenant" : Record("a")],
        ["id" : Record(1), "value" : Record(-1), "tenant" : Record("a")]
    ];
    upsertRecords(conn, tableName, metaDefs, records, upsertKeys);

    auto res = conn.query("SELECT * FROM " ~ tableName ~ " ORDER BY ID;");
    assert(!res.empty);
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

    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "vulpes-test");
    const string tableName = "singleupserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }
    const MetaData metaDefs = [
        MetaDataDefinition("v", SqlType.INTEGER, IsNullable.no, IsUnique.no)
    ];
    const string[] upsertKeys = ["v"];
    Record[string][] records = iota(10).map!((int a) => ["v": Record(a)]).array;
    assertThrown!DatastoreException(upsertRecords(conn, tableName, metaDefs, records, upsertKeys));
}

/**
Run a `DELETE FROM` statement that might have a `WHERE` clause or not.
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    deleteKeys    = optional parameter that defines the delete condition. If this parameter is missing all the rows will be deleted.
Throws: monetdb.MonetDbException on failure
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

///
unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "vulpes-test");
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
Bulk insert on top of `COPY INTO` statements
See_Also: https://www.monetdb.org/Documentation/Cookbooks/SQLrecipes/LoadingBulkData
Params:
    conn          = a `monetdb.MonetDb` connection instance
    tableName     = the name of the table
    metaDefs      = an immutable list of `MetaDataDefinition`
    records       = a range of records
    chunkSize     = size of the chunk (default 1000)
Throws: monetdb.MonetDbException on failure
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

///
unittest
{
    MonetDb conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "vulpes-test");
    const string tableName = "bulkinserttable";
    scope (exit)
    {
        conn.exec("DROP TABLE IF EXISTS " ~ tableName);
        conn.close();
    }
    const MetaData metaDefs = [
        MetaDataDefinition("id", SqlType.INTEGER, IsNullable.no, IsUnique.no),
        MetaDataDefinition("tenant", SqlType.VARCHAR, IsNullable.no, IsUnique.no,
                5),
        MetaDataDefinition("value", SqlType.INTEGER, IsNullable.yes, IsUnique.no),
        MetaDataDefinition("creation_date", SqlType.DATE, IsNullable.yes, IsUnique.no),
        MetaDataDefinition("sysdate", SqlType.TIMESTAMP, IsNullable.yes, IsUnique.no)
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
