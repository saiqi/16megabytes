module vulpes.resources;

import std.typecons : Nullable, tuple;
import std.range : ElementType, isInputRange;
import std.traits : isSomeString, Unqual;
import vulpes.core.cube;
import vulpes.core.providers : Provider;

enum Unknown = "unknown";

struct ProviderResource
{
    string id;
}

ProviderResource providerToResource(in Provider p)
{
    return ProviderResource(p.id);
}

struct NameResource
{
    string shortName;
    Nullable!string longName;
}

auto toNamesAA(R)(in R range) pure @safe nothrow
if(isInputRange!R && is(Unqual!(ElementType!R) == Label))
{
    import std.array : assocArray;
    import std.algorithm : map;
    alias ET = ElementType!R;

    static if(__traits(hasMember, ET, "longName"))
    {
        return range
            .map!(e => tuple(e.language, NameResource(e.shortName, e.longName)))
            .assocArray;
    }
    else
    {
        return range
            .map!(e => tuple(e.language, NameResource(e.shortName, (Nullable!string).init)))
            .assocArray;
    }
}

unittest
{
    static struct Foo
    {
        private:
        string id_;
        Label[] labels_;

        public:
        this(this)
        {
            labels_ = labels_.dup;
        }

        inout(Label[]) labels() @property inout pure nothrow @safe
        {
            return labels_;
        }
    }

    auto f = Foo("foo", [Label("en", "Foo", (Nullable!string).init)]);
    auto labels = f.labels.toNamesAA;
    assert("en" in labels);
    assert(labels["en"].shortName == "Foo");
    assert(labels["en"].longName.isNull);
}

struct TagResource
{
    string id;
    NameResource[string] labels;
}

TagResource tagToResource(Tag tag)
{
    return TagResource(tag.id, tag.labels.toNamesAA);
}

struct DescriptionResource
{
    string id;
    string providerId;
    NameResource[string] labels;
    string[] tagIds;
}

DescriptionResource descriptionToResource(CubeDescription desc) pure nothrow @safe
{
    return DescriptionResource(
        desc.id,
        desc.providerId,
        desc.labels.toNamesAA,
        desc.tagIds
    );
}

struct CountResource
{
    size_t count;
}

struct ConceptResource
{
    string id;
    NameResource[string] labels;
}

ConceptResource conceptToResource(Concept c) pure nothrow @safe
{
    return ConceptResource(c.id, c.labels.toNamesAA);
}

struct AttributeResource
{
    string id;
    Nullable!ConceptResource concept;
    Nullable!string codelistId;
    Nullable!string codelistProviderId;
}

AttributeResource attributeToResource(Attribute a) pure nothrow @safe
{
    import std.typecons : apply;
    return AttributeResource(
        a.id.get(Unknown),
        a.concept.apply!conceptToResource,
        a.codelistId,
        a.codelistProviderId
    );
}

struct MeasureResource
{
    string id;
    Nullable!ConceptResource concept;
}

MeasureResource measureToResource(Measure m) pure nothrow @safe
{
    import std.typecons : apply;
    return MeasureResource(m.id.get(Unknown), m.concept.apply!conceptToResource);
}

struct DimensionResource
{
    string id;
    bool obsDimension;
    bool timeDimension;
    Nullable!ConceptResource concept;
    Nullable!string codelistId;
    Nullable!string codelistProviderId;
}

DimensionResource dimensionToResource(Dimension d) pure nothrow @safe
{
    import std.typecons : apply;
    return DimensionResource(
        d.id.get(Unknown),
        d.obsDimension,
        d.timeDimension,
        d.concept.apply!conceptToResource,
        d.codelistId,
        d.codelistProviderId
    );
}

struct DefinitionResource
{
    string id;
    string providerId;
    DimensionResource[] dimensions;
    AttributeResource[] attributes;
    MeasureResource[] measures;
}

DefinitionResource definitionToResource(CubeDefinition def) pure nothrow @safe
{
    import std.array : array;
    import std.algorithm : map;

    return DefinitionResource(
        def.id,
        def.providerId,
        def.dimensions.map!dimensionToResource.array,
        def.attributes.map!attributeToResource.array,
        def.measures.map!measureToResource.array
    );
}

struct CodeResource
{
    string id;
    NameResource[string] labels;
}

CodeResource codeToResource(Code c) pure nothrow @safe
{
    return CodeResource(c.id, c.labels.toNamesAA);
}