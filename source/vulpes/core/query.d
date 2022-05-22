module vulpes.core.query;

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

    mixin(Generate);
}

