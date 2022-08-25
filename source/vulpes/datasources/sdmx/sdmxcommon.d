module vulpes.datasources.sdmx.sdmxcommon;

import std.typecons : Nullable, nullable;
import std.traits : Unqual, ReturnType;
import std.range : isInputRange, ElementType, InputRange;
import vulpes.lib.xml : isForwardRangeOfChar, deserializeAsRangeOf;
import vulpes.core.model;

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

enum bool isConvertible(Source, Target) = is(Unqual!(ReturnType!(Source.init.convert)) == Nullable!Target);

InputRange!Target buildRangeFromXml(Source, Target, Range)(in Range xml) @trusted // TODO: check if deserializeAsRangeOf could be safe
if(isForwardRangeOfChar!Range && isConvertible!(Source, Target))
{
    import std.algorithm : map, joiner;
    import std.range : inputRangeObject;

    return xml
        .deserializeAsRangeOf!Source
        .map!"a.convert"
        .joiner
        .inputRangeObject;
}

unittest
{
    import vulpes.lib.xml : text, xmlRoot;

    static struct Out
    {
        string v;
    }

    @xmlRoot("In")
    static struct In
    {
        @text
        string value;

        Nullable!Out convert()
        {
            return Out(value).nullable;
        }
    }

    auto xml = "<Root><In>foo</In></Root>";
    auto r = buildRangeFromXml!(In, Out)(xml);
    assert(r.front.v == "foo");
}

Nullable!Target convertIdentifiableItem(Source, Target)(in ref Source item)
{
    auto cNames = item.names.dup;
    auto name = getLabel(cNames);

    if(name.isNull) return typeof(return).init;

    auto cDescs = item.descriptions.dup;
    Nullable!Target r = Target(
        item.id,
        name.get,
        getIntlLabels(cNames),
        getLabel(cDescs),
        getIntlLabels(cDescs));

    return r;
}

Nullable!Target convertListOfItems(Source, Target, alias listName)(in ref Source resource)
if(is(Unqual!Target == Codelist) || is(Unqual!Target == ConceptScheme) || is(Unqual!Target == CategoryScheme))
{
    import std.range : ElementType;
    import std.algorithm : any, joiner;
    import std.array : array;
    import vulpes.lib.monadish : fallbackMap, isNullable;

    alias SourceItemT = Unqual!(ElementType!(typeof(__traits(getMember, Source, listName))));

    static if(is(Unqual!Target == Codelist))
    {
        alias TargetItemT = Code;
    }
    else static if(is(Unqual!Target == ConceptScheme))
    {
        alias TargetItemT = Concept;
    }
    else
    {
        alias TargetItemT = Category;

    }

    static assert(isConvertible!(SourceItemT, TargetItemT),
                  "Cannot find converter from " ~ SourceItemT.stringof ~ " to " ~ TargetItemT.stringof);

    auto cNames = resource.names.dup;
    auto name = getLabel(cNames);

    if(name.isNull) return typeof(return).init;

    auto items = fallbackMap!"a.convert"(__traits(getMember, resource, listName));

    if(items.any!"a.isNull") return typeof(return).init;

    auto cDescs = resource.descriptions.dup;

    static if(isNullable!(typeof(Source.init.version_)))
    {
        auto v = resource.version_.get(DefaultVersion);
    }
    else
    {
        auto v = resource.version_;
    }

    Nullable!Target r = Target(
        resource.id,
        v,
        resource.agencyId,
        true,
        true,
        name.get,
        getIntlLabels(cNames),
        getLabel(cDescs),
        getIntlLabels(cDescs),
        false,
        items.joiner.array);

    return r;
}
