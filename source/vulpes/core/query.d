module vulpes.core.query;

import vulpes.lib.boilerplate : Generate;

struct QueryComponent
{
    uint position;
    string[] values;
    bool isWildcard;

    mixin(Generate);
}

QueryComponent[] parse(in string sQuery) @safe pure
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