module vulpes.datasources.sdmx.common;

import std.typecons : Nullable, nullable;
import std.range : isInputRange, ElementType;
import vulpes.core.model : DefaultLanguage, Language;

enum bool isLabelizable(T) = is(typeof(T.init.lang) : string) && is(typeof(T.init.content) : string);

Nullable!string getLabel(T)(in T resources) pure @safe
if(isInputRange!T && isLabelizable!(ElementType!T))
{
    import std.algorithm : map, filter;
    import std.conv : to;

    auto r = resources
        .filter!(a => a.lang.to!Language == DefaultLanguage)
        .map!(a => a.content);

    if(r.empty) return typeof(return).init;

    return r.front.nullable;
}

unittest
{
    static struct Name
    {
        string lang;
        string content;
    }

    auto l1 = getLabel([Name(DefaultLanguage, "Foo"), Name("fr", "Fou")]);
    assert(!l1.isNull);
    assert(l1.get == "Foo");

    Name[] eNames;
    assert(getLabel(eNames).isNull);

    auto l2 = getLabel([Name("de", "Foo"), Name("fr", "Fou")]);
    assert(l2.isNull);
}

Nullable!(string[Language]) getIntlLabels(T)(in T resources) pure @safe nothrow
if(isInputRange!T && isLabelizable!(ElementType!T))
{
    import std.array : assocArray;
    import std.typecons : tuple;
    import std.algorithm : map;
    import std.conv : to;
    import std.range;

    scope(failure) return typeof(return).init;

    if(resources.empty) return typeof(return).init;

    return resources
        .map!(a => tuple(a.lang.to!Language, a.content))
        .assocArray
        .nullable;
}

unittest
{
    import std.algorithm : equal;

    static struct Name
    {
        string lang;
        string content;
    }

    const names = [Name("en", "Foo"), Name("fr", "Fou")];
    auto r = getIntlLabels(names).get;
    assert(equal(r[Language.en], "Foo"));
    assert(equal(r[Language.fr], "Fou"));

    assert(getIntlLabels([Name("unknown", "")]).isNull);
}