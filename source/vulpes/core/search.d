module vulpes.core.search;

import std.range : isInputRange, ElementType;
import vulpes.core.model : isNamed;

private string[] collectSearchItems(T)(in T resource) pure @safe nothrow
if(isNamed!T)
{
    import std.array : appender, array;
    import std.algorithm : uniq;
    import std.typecons : Nullable;
    import vulpes.core.model : Language;

    auto a = appender!(string[]);
    a.put(resource.name);

    static if(is(typeof(T.names.init) : Nullable!(string[Language])))
    {
        if(!resource.names.isNull)
            a.put(resource.names.get.byValue);
    }

    static if(is(typeof(T.description.init) : Nullable!string))
    {
        if(!resource.description.isNull)
            a.put(resource.description.get);
    }

    static if(is(typeof(T.descriptions.init) : Nullable!(string[Language])))
    {
        if(!resource.descriptions.isNull)
            a.put(resource.descriptions.get.byValue);
    }

    return a.data.uniq.array;
}

unittest
{
    import std.algorithm : equal, sort;
    import std.typecons : Nullable, nullable;
    import vulpes.core.model : Language;

    static struct OnlyName
    {
        string name;
    }

    static struct WithDesc
    {
        string name;
        Nullable!string description;
    }

    static struct WithNames
    {
        string name;
        Nullable!string description;
        Nullable!(string[Language]) names;
    }

    static struct WithDescriptions
    {
        string name;
        Nullable!string description;
        Nullable!(string[Language]) names;
        Nullable!(string[Language]) descriptions;
    }

    auto onlyName = OnlyName("foo");
    assert(equal(collectSearchItems(onlyName), ["foo"]));

    auto withDesc = WithDesc("foo", "Foo".nullable);
    assert(equal(collectSearchItems(withDesc).sort, ["foo", "Foo"].sort));
    auto withNullDesc = WithDesc("foo", (Nullable!string).init);
    assert(equal(collectSearchItems(withNullDesc), ["foo"]));

    auto withNames = WithNames("foo", "Foo".nullable, [Language.en : "foo", Language.fr: "fou"].nullable);
    assert(equal(collectSearchItems(withNames).sort, ["foo", "fou", "Foo"].sort));
    auto withNullNames = WithNames("foo", "Foo".nullable, Nullable!(string[Language]).init);
    assert(equal(collectSearchItems(withNullNames).sort, ["foo", "Foo"].sort));

    auto withDescriptions = WithDescriptions(
        "foo",
        "Foo".nullable,
        [Language.en : "foo", Language.fr: "fou"].nullable,
        [Language.en : "Foo", Language.fr: "Fou"].nullable
    );
    assert(equal(collectSearchItems(withDescriptions).sort, ["foo", "Foo", "fou", "Fou"].sort));
    auto withNullDescriptions = WithDescriptions(
        "foo",
        "Foo".nullable,
        [Language.en : "foo", Language.fr: "fou"].nullable,
        (Nullable!(string[Language])).init
    );
    assert(equal(collectSearchItems(withNullDescriptions).sort, ["foo", "Foo", "fou"].sort));

}

auto search(int threshold, R)(R resources, in string q) pure @safe
if(isInputRange!R && isNamed!(ElementType!R))
{
    import vulpes.lib.text : fuzzySearch;
    import std.typecons : Tuple;
    import std.array : array;
    import std.algorithm : map, filter, sort, min, reduce;
    import std.functional : partial;

    alias T = Tuple!(ElementType!R, "resource", int, "score");
    alias pSearch = partial!(fuzzySearch!(string, string), q);

    T computeScore(ElementType!R resource)
    {
        auto score = collectSearchItems(resource).map!pSearch;
        return T(resource, reduce!((a, b) => min(a, b))(int.max, score));
    }

    return resources.map!computeScore
        .filter!(a => a.score <= threshold)
        .array
        .sort!((a, b) => a.score < b.score)
        .map!"a.resource";
}

unittest
{
    import std.algorithm : equal;
    static struct WithName
    {
        string name;
    }

    auto wonderful = WithName("wonderful");
    auto unreachable = WithName("unreachable");
    auto wanderful = WithName("wanderful");
    auto withNames = [unreachable, wanderful, wonderful];

    assert(equal(search!1(withNames, "wonderful"), [wonderful, wanderful]));
}