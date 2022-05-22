module vulpes.core.query;

import std.typecons : Nullable;
import std.datetime.date : DateTime;
import vulpes.lib.boilerplate : Generate;

struct QueryComponent
{
    uint position;
    string[] values;
    bool isWildcard;

    mixin(Generate);
}

private QueryComponent[] parse(in string sQuery) @safe pure
{
    import std.string : split;
    import std.algorithm : map;
    import std.array : array;
    import std.range : enumerate;
    import std.conv : to;

    return sQuery
        .split(".")
        .enumerate
        .map!(a => a[1] == "*"
            ? QueryComponent(a[0].to!uint, [], true)
            : QueryComponent(a[0].to!uint, a[1].split("+"), false))
        .array;
}

unittest
{
    import std.algorithm : equal;

    const sQuery = "D.NOK.EUR.SP00.A";
    auto r = parse(sQuery);
    assert(r.length == 5);
    foreach (i, qc; r)
    {
        assert(r[i].position == i);
    }
    assert(r[0].isWildcard == false);
    assert(r[0].values.equal(["D"]));
}

unittest
{
    import std.algorithm : equal;

    const sQuery = "D.NOK+SEK.EUR.SP00.A";
    auto r = parse(sQuery);
    assert(r[1].values.equal(["NOK", "SEK"]));
    assert(r[1].isWildcard == false);
}

unittest
{
    const sQuery = "D.*.EUR.SP00.A";
    auto r = parse(sQuery);
    assert(!r[1].values.length);
    assert(r[1].isWildcard == true);
}

struct CFilter
{
    string key;
    string[][] values;
}

private CFilter[] parse(T)(T params) // TODO: implement a constraint on T
{
    import std.regex : matchFirst;
    import std.array : Appender, split, array;
    import std.algorithm : map;

    enum pattern = "^c\\[(?P<key>.+)\\]$";

    Appender!(CFilter[]) app;

    foreach (p; params.byKeyValue)
    {
        auto m = matchFirst(p.key, pattern);
        if(m.empty) continue;

        auto values = p.value
            .split(",")
            .map!(a => a.split("+"))
            .array;
        app.put(CFilter(m["key"], values));
    }

    return app.data;

}

unittest
{
    import std.algorithm : equal;

    auto p1 = ["c[FOO]" : "BAR"];
    auto r1 = parse(p1);
    assert(r1.length == 1);
    assert(r1[0].values[0][0] == "BAR");
    assert(r1[0].key == "FOO");

    auto p2 = ["c[FOO]" : "BAR", "other": "none"];
    assert(parse(p2).length == 1);

    auto p3 = ["c[FOO_0]" : "A,B", "c[FOO_1]": "C,D+E"];
    auto r3 = parse(p3);
    assert(r3.length == 2);
    assert(r3[0].values.equal([["A"], ["B"]]));
    assert(r3[1].values.equal([["C"], ["D", "E"]]));
}

struct DataQuery
{
    QueryComponent[] components;
    CFilter[] filters;
    Nullable!DateTime updatedAfter;
    Nullable!uint firstNObservations;
    Nullable!uint lastNObservations;
    Nullable!string dimensionAtObservation;
    Nullable!string attributes;
    Nullable!string measures;
    Nullable!bool includeHistory;

    mixin(Generate);
}

DataQuery buildDataQuery(T)(T params, in string key)
{
    import std.typecons : apply;
    import vulpes.lib.monadish : convertLookup;

    auto components = parse(key);
    auto cFilters = parse(params);

    Nullable!DateTime updatedAfter = params.convertLookup!(string, string)("updatedAfter")
        .apply!(DateTime.fromISOExtString);

    return DataQuery(
        components,
        cFilters,
        updatedAfter,
        params.convertLookup!(uint, string)("firstNObservations"),
        params.convertLookup!(uint, string)("lastNObservations"),
        params.convertLookup!(string, string)("dimensionAtObservation"),
        params.convertLookup!(string, string)("attributes"),
        params.convertLookup!(string, string)("measures"),
        params.convertLookup!(bool, string)("includeHistory"));
}

unittest
{
    string[string] p1 = null;
    auto dq1 = buildDataQuery(p1, "A.B.C");
    assert(dq1.filters.length == 0);
    assert(dq1.components.length == 3);

    string[string] p2 = ["c[FOO]": "BAR", "updatedAfter": "2022-05-22T11:38:00"];
    auto dq2 = buildDataQuery(p2, "A.B.C");
    assert(!dq2.updatedAfter.isNull);
    assert(dq2.filters.length == 1);

    string[string] p3 = ["firstNObservations": "50", "measures": "all", "includeHistory": "false"];
    auto dq3 = buildDataQuery(p3, "A.B.C");
    assert(dq3.updatedAfter.isNull);
    assert(dq3.components.length == 3);
    assert(dq3.filters.length == 0);
    assert(dq3.updatedAfter.isNull);
    assert(!dq3.firstNObservations.isNull);
    assert(dq3.lastNObservations.isNull);
    assert(dq3.dimensionAtObservation.isNull);
    assert(dq3.attributes.isNull);
    assert(!dq3.measures.isNull);
    assert(!dq3.includeHistory.isNull);
}

