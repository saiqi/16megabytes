module vulpes.core.query;

import std.typecons : Nullable, nullable;
import std.algorithm : map, filter, canFind;
import std.exception : enforce;
import std.format : format;
import std.array : array;
import sumtype : SumType, match;
import vulpes.core.cube : Dataset, Serie, Observation, DatasetMetadata;

class QueryException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

enum isStatement(T) = is(typeof(T.init.key));

struct EqualsStatement
{
    string key;
    string eq;
}

struct NotEqualsStatement
{
    string key;
    string neq;
}

struct InStatement
{
    string key;
    string[] in_;
}

struct NotInStatement
{
    string key;
    string[] nin;
}

struct GreaterThanStatement
{
    string key;
    string gt;
}

struct GreaterOrEqualThanStatement
{
    string key;
    string gte;
}

struct LowerThanStatement
{
    string key;
    string lt;
}

struct LowerOrEqualThanStatement
{
    string key;
    string lte;
}

alias Statement = SumType!(
    EqualsStatement,
    NotEqualsStatement,
    InStatement,
    NotInStatement,
    GreaterThanStatement,
    GreaterOrEqualThanStatement,
    LowerThanStatement,
    LowerOrEqualThanStatement
);

private auto getDimensionValue(T, S)(Serie!T serie, S statement)
if(isStatement!S)
{
    auto d = serie.dimensions
        .filter!(d => d.id == statement.key);

    enforce!QueryException(!d.empty,
        format!"Cannot find %s in serie dimensions"(statement.key));

    auto v = d.front.value;

    enforce!QueryException(!v.isNull, format!"Dimension %s value is null"(statement.key));

    return v.get;
}

private auto applyStatementToObsValue(T)(Serie!T serie, Statement statement)
{
    import std.conv : to;
    import std.range : tee;
    void checkType(T)(string s)
    {
        try
        {
            s.to!T;
        }
        catch(Exception e)
        {
            enforce!QueryException(false, format!"Cannot convert %s as %s"(s, T.stringof));
        }
    }

    auto pred = statement.match!(
        (EqualsStatement s) => (const Observation!T o) {
                checkType!T(s.eq);
                return !o.obsValue.value.isNull && o.obsValue.value.get == s.eq.to!T;
            },
        (NotEqualsStatement s) => (const Observation!T o) {
                checkType!T(s.neq);
                return !o.obsValue.value.isNull && o.obsValue.value.get != s.neq.to!T;
            },
        (InStatement s) => (const Observation!T o) {
                s.in_.tee!(checkType!T);
                return !o.obsValue.value.isNull && s.in_.map!(v => v.to!T).canFind(o.obsValue.value.get);
            },
        (NotInStatement s) => (const Observation!T o) {
                s.nin.tee!(checkType!T);
                return !o.obsValue.value.isNull && !s.nin.map!(v => v.to!T).canFind(o.obsValue.value.get);
            },
        (GreaterThanStatement s) => (const Observation!T o) {
                checkType!T(s.gt);
                return !o.obsValue.value.isNull && o.obsValue.value.get > s.gt.to!T;
            },
        (GreaterOrEqualThanStatement s) => (const Observation!T o) {
                checkType!T(s.gte);
                return !o.obsValue.value.isNull && o.obsValue.value.get >= s.gte.to!T;
            },
        (LowerThanStatement s) => (const Observation!T o) {
                checkType!T(s.lt);
                return !o.obsValue.value.isNull && o.obsValue.value.get < s.lt.to!T;
            },
        (LowerOrEqualThanStatement s) => (const Observation!T o) {
                checkType!T(s.lte);
                return !o.obsValue.value.isNull && o.obsValue.value.get <= s.lte.to!T;
            }
    );

    return Serie!T(
        serie.observations
            .filter!pred
            .array,
        serie.dimensions.dup,
        serie.attributes.dup);
}

unittest
{
    import vulpes.core.testing : buildTestDataset;
    import std.exception : assertThrown;
    auto dataset = buildTestDataset(
        7, "INDEX", "OBS", [["FOO": "FOO"]], [["BAR": "BAR"]], ["BAZ": "BAZ"], 2).dataset;

    Statement badStmt = EqualsStatement("OBS", "NotConvertible");
    assertThrown!QueryException(dataset.series[0].applyStatementToObsValue(badStmt));

    Statement eqStmt = EqualsStatement("OBS", "7");
    assert(dataset.series[0].applyStatementToObsValue(eqStmt).observations.length == 2);

    Statement neqStmt = NotEqualsStatement("OBS", "6");
    assert(dataset.series[0].applyStatementToObsValue(neqStmt).observations.length == 2);

    Statement inStmt = InStatement("OBS", ["6", "7"]);
    assert(dataset.series[0].applyStatementToObsValue(inStmt).observations.length == 2);

    Statement ninStmt = NotInStatement("OBS", ["8", "9"]);
    assert(dataset.series[0].applyStatementToObsValue(ninStmt).observations.length == 2);

    Statement gtStmt = GreaterThanStatement("OBS", "1");
    assert(dataset.series[0].applyStatementToObsValue(gtStmt).observations.length == 2);

    Statement gteStmt = GreaterOrEqualThanStatement("OBS", "7");
    assert(dataset.series[0].applyStatementToObsValue(gteStmt).observations.length == 2);

    Statement ltStmt = LowerThanStatement("OBS", "1");
    assert(dataset.series[0].applyStatementToObsValue(ltStmt).observations.length == 0);

    Statement lteStmt = LowerOrEqualThanStatement("OBS", "1");
    assert(dataset.series[0].applyStatementToObsValue(lteStmt).observations.length == 0);
}

private auto applyStatementToObsDimension(T)(Serie!T serie, Statement statement)
{
    auto pred = statement.match!(
        (EqualsStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get == s.eq;
            },
        (NotEqualsStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get != s.neq;
            },
        (InStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && s.in_.canFind(o.obsDimension.value.get);
            },
        (NotInStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && !s.nin.canFind(o.obsDimension.value.get);
            },
        (GreaterThanStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get > s.gt;
            },
        (GreaterOrEqualThanStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get >= s.gte;
            },
        (LowerThanStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get < s.lt;
            },
        (LowerOrEqualThanStatement s) => (const Observation!T o) {
                return !o.obsDimension.value.isNull && o.obsDimension.value.get <= s.lte;
            }
    );

    return Serie!T(
        serie.observations
            .filter!pred
            .array,
        serie.dimensions.dup,
        serie.attributes.dup);
}

unittest
{
    import vulpes.core.testing : buildTestDataset;
    auto dataset = buildTestDataset(
        7, "INDEX", "OBS", [["FOO": "FOO"]], [["BAR": "BAR"]], ["BAZ": "BAZ"], 2).dataset;

    Statement eqStmt = EqualsStatement("INDEX", "1");
    assert(dataset.series[0].applyStatementToObsDimension(eqStmt).observations.length == 1);

    Statement neqStmt = NotEqualsStatement("INDEX", "6");
    assert(dataset.series[0].applyStatementToObsDimension(neqStmt).observations.length == 2);

    Statement inStmt = InStatement("INDEX", ["6", "7"]);
    assert(dataset.series[0].applyStatementToObsDimension(inStmt).observations.length == 0);

    Statement ninStmt = NotInStatement("INDEX", ["8", "9"]);
    assert(dataset.series[0].applyStatementToObsDimension(ninStmt).observations.length == 2);

    Statement gtStmt = GreaterThanStatement("INDEX", "1");
    assert(dataset.series[0].applyStatementToObsDimension(gtStmt).observations.length == 0);

    Statement gteStmt = GreaterOrEqualThanStatement("INDEX", "1");
    assert(dataset.series[0].applyStatementToObsDimension(gteStmt).observations.length == 1);

    Statement ltStmt = LowerThanStatement("INDEX", "1");
    assert(dataset.series[0].applyStatementToObsDimension(ltStmt).observations.length == 1);

    Statement lteStmt = LowerOrEqualThanStatement("INDEX", "1");
    assert(dataset.series[0].applyStatementToObsDimension(lteStmt).observations.length == 2);
}

Nullable!(Serie!T) applyStatement(T)(
    Serie!T serie,
    const string obsDimensionId,
    const string measureId,
    Statement statement)
{

    if(statement.match!(_ => _.key == measureId))
        return applyStatementToObsValue(serie, statement).nullable;

    if(statement.match!(_ => _.key == obsDimensionId))
        return applyStatementToObsDimension(serie, statement).nullable;

    auto matched = statement.match!(
        (EqualsStatement s) => s.eq == getDimensionValue(serie, s),
        (NotEqualsStatement s) => s.neq != getDimensionValue(serie, s),
        (InStatement s) => s.in_.canFind(getDimensionValue(serie, s)),
        (NotInStatement s) => !s.nin.canFind(getDimensionValue(serie, s)),
        (GreaterThanStatement s) => getDimensionValue(serie, s) > s.gt,
        (GreaterOrEqualThanStatement s) => getDimensionValue(serie, s) >= s.gte,
        (LowerThanStatement s) => getDimensionValue(serie, s) < s.lt,
        (LowerOrEqualThanStatement s) => getDimensionValue(serie, s) <= s.lte
    );

    return matched ? serie.nullable : typeof(return).init;
}

unittest
{
    import vulpes.core.testing : buildTestDataset;
    import std.exception : assertThrown;
    auto dataset = buildTestDataset(
        3.14, "INDEX", "OBS", [["FOO": "FOO"]], [["BAR": "BAR"]], ["BAZ": "BAZ"], 2).dataset;

    auto obsDimensionId = "INDEX";
    auto measureId = "OBS";

    Statement badStmt = EqualsStatement("OTHR", "FOO");
    assertThrown!QueryException(dataset.series[0].applyStatement(obsDimensionId, measureId, badStmt));

    Statement valueStmt = EqualsStatement("OBS", "3.14");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, valueStmt).isNull);

    Statement obsStmt = EqualsStatement("INDEX", "0");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, obsStmt).isNull);

    Statement eqStmt = EqualsStatement("FOO", "FOO");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, eqStmt).isNull);

    Statement neqStmt = NotEqualsStatement("FOO", "OTHR");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, neqStmt).isNull);

    Statement inStmt = InStatement("FOO", ["OTHR", "FOO"]);
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, inStmt).isNull);

    Statement ninStmt = NotInStatement("FOO", ["OTHR", "BAR"]);
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, ninStmt).isNull);

    Statement gtStmt = GreaterThanStatement("FOO", "AAA");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, gtStmt).isNull);

    Statement gteStmt = GreaterOrEqualThanStatement("FOO", "AAA");
    assert(!dataset.series[0].applyStatement(obsDimensionId, measureId, gteStmt).isNull);

    Statement ltStmt = LowerThanStatement("FOO", "AAA");
    assert(dataset.series[0].applyStatement(obsDimensionId, measureId, ltStmt).isNull);

    Statement lteStmt = LowerOrEqualThanStatement("FOO", "AAA");
    assert(dataset.series[0].applyStatement(obsDimensionId, measureId, lteStmt).isNull);
}

auto evaluate(T)(Dataset!T dataset, DatasetMetadata metadata, Statement[] statements)
{
    import std.algorithm : fold;
    auto reducer = (ref Dataset!T dataset, Statement s)
    {
        enforce!QueryException(
            metadata.obsDimensionIds.length == 1, "Dataset must contain exactly one observation dimension");

        enforce!QueryException(
            metadata.measureIds.length == 1, "Dataset must contain exactly one measure");

        return Dataset!T(
            dataset.series
                .map!(serie => serie.applyStatement(metadata.obsDimensionIds[0], metadata.measureIds[0], s))
                .filter!(serie => !serie.isNull)
                .map!(serie => serie.get)
                .array);
    };
    return statements.fold!reducer(dataset);
}


unittest
{
    import vulpes.core.testing : buildTestDataset;
    auto t = buildTestDataset(3.14, "INDEX", "OBS", [["FOO": "FOO"]], [["BAR": "BAR"]], ["BAZ": "BAZ"], 2);

    Statement[] stmts;
    Statement stmt = EqualsStatement("INDEX", "0");
    stmts ~= stmt;

    auto r = evaluate(t.dataset, t.metadata, stmts);
    assert(r.series.length == 1);
    assert(r.series[0].observations.length < t.dataset.series[0].observations.length);
}

auto key(Statement statement) pure nothrow @safe
{
    return statement.match!(_ => _.key);
}

@safe unittest
{
    Statement s = EqualsStatement("KEY", "VALUE");
    assert(s.key == "KEY");
}

auto value(Statement statement) pure nothrow @safe
{
    return statement.match!(
        (EqualsStatement s) => s.eq.nullable,
        (NotEqualsStatement s) => s.neq.nullable,
        (GreaterOrEqualThanStatement s) => s.gte.nullable,
        (GreaterThanStatement s) => s.gt.nullable,
        (LowerOrEqualThanStatement s) => s.lte.nullable,
        (LowerThanStatement s) => s.lt.nullable,
        _ => (Nullable!string).init
    );
}

@safe unittest
{
    Statement s1 = EqualsStatement("KEY", "VALUE");
    assert(s1.value.get == "VALUE");

    Statement s2 = InStatement("KEY", ["V1", "V2"]);
    assert(s2.value.isNull);
}

auto values(Statement statement) pure nothrow @safe
{
    return statement.match!(
        (InStatement s) => s.in_.nullable,
        (NotInStatement s) => s.nin.nullable,
        _ => (Nullable!(string[])).init
    );
}

@safe unittest
{
    Statement s1 = EqualsStatement("KEY", "VALUE");
    assert(s1.values.isNull);

    Statement s2 = InStatement("KEY", ["V1", "V2"]);
    assert(s2.values.get == ["V1", "V2"]);
}