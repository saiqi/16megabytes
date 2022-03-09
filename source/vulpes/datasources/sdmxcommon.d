module vulpes.datasources.sdmxcommon;

import std.typecons : Nullable, nullable;
import std.range : isInputRange, ElementType;
import vulpes.core.model : DefaultLanguage, Language, enumMember;

enum bool isLabelizable(T) = is(typeof(T.init.lang) : string) && is(typeof(T.init.content) : string);

Nullable!string getLabel(T)(in T resources) pure @safe nothrow @nogc
if(isInputRange!T && isLabelizable!(ElementType!T))
{
    import std.algorithm : map, filter;

    auto r = resources
        .filter!((a) {
            auto l = a.lang.enumMember!Language;
            return !l.isNull && l.get == DefaultLanguage;
        })
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

    auto l3 = getLabel([Name("unknown", "Foo"), Name("fr", "Fou")]);
    assert(l3.isNull);
}

Nullable!(string[Language]) getIntlLabels(T)(in T resources) pure @safe
if(isInputRange!T && isLabelizable!(ElementType!T))
{
    import std.array : assocArray;
    import std.typecons : tuple;
    import std.algorithm : map, filter;
    import std.range;

    auto rs = resources
        .filter!(a => !a.lang.enumMember!Language.isNull)
        .map!(a => tuple(a.lang.enumMember!Language.get, a.content));
        
    if(rs.empty) return typeof(return).init;
        
    return rs.assocArray.nullable;
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
    const Name[] empty;
    assert(getIntlLabels(empty).isNull);
}