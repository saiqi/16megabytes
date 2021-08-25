module vulpes.core.cube;
import std.typecons : Nullable, nullable;
import std.range;
import std.traits : Unqual;
import std.algorithm : filter, map;
import std.array : array;
import vulpes.lib.boilerplate : Generate, getter;

enum ResourceType : string
{
    taglist = "taglist",
    descriptionlist = "descriptionlist",
    definition = "definition",
    dimension = "dimension",
    attribute = "attribute",
    codelist = "codelist",
    dataset = "dataset"
}

struct Label
{
    @getter("language")
    private string language_;

    @getter("shortName")
    private string shortName_;

    @getter("longName")
    private Nullable!string longName_;

    mixin(Generate);
}

private auto searchScore(size_t default_)(in Label label, in string query) pure @safe nothrow
{
    scope(failure) return default_;

    import std.algorithm : min;
    import std.uni : toLower;
    import vulpes.lib.text : fuzzySearch;

    auto score = fuzzySearch(query.toLower, label.shortName.toLower).get(default_);
    if(label.longName.isNull) return score;
    return min(score, fuzzySearch(query.toLower, label.longName.get.toLower).get(default_));
}

unittest
{
    auto l1 = Label("en", "Wonderful", (Nullable!string).init);
    auto l2 = Label("en", "Far away", (Nullable!string).init);
    auto l3 = Label("en", "", "Wonderful".nullable);
    auto q = "WONDER";
    assert(l1.searchScore!(1024)(q) < l2.searchScore!(1024)(q));
    assert(l1.searchScore!(1024)(q) == l3.searchScore!(1024)(q));
}

enum isLabelized(T) = is(Unqual!(typeof(T.labels.init[0])) == Label);

static assert(isLabelized!CubeDescription);
static assert(isLabelized!Concept);
static assert(isLabelized!Tag);

private auto computeLabelsSearchScore(size_t default_ = size_t.max, T)(in T resource,
                                                                       in string query) pure @safe nothrow
if(isLabelized!T)
{
    scope(failure) return default_;
    import std.algorithm : min, map, fold;
    if(!resource.labels) return default_;
    return resource.labels.map!(l => l.searchScore!default_(query)).fold!min;
}

unittest
{
    static struct Foo
    {
        Label[] labels;
    }

    auto q = "wonder";
    auto l1 = Label("en", "Wonderful");
    auto l2 = Label("en", "Far away");
    auto foo = Foo([l1, l2]);
    assert(foo.computeLabelsSearchScore(q) == l1.searchScore!(size_t.max)(q));
    assert(foo.computeLabelsSearchScore(q) < q.length);
    auto empty = Foo([]);
    assert(empty.computeLabelsSearchScore(q) == size_t.max);
}

auto search(size_t threshold = 1u, R)(R resources, in string query) pure
if(isForwardRange!R && isLabelized!(ElementType!R))
{
    import std.algorithm : map, filter;
    import std.array : array;
    import vulpes.core.operations : sort;

    return zip(resources.map!(r => computeLabelsSearchScore(r, query)), resources)
        .filter!(a => a[0] <= threshold)
        .array
        .sort!"a[0] < b[0]"
        .map!"a[1]";
}

unittest
{
    static struct Foo
    {
        uint id;
        Label[] labels;
    }

    import std.array : array;
    auto q = "wonder";
    auto foos = [
        Foo(1u, [Label("en", "abcfgh")]),
        Foo(0u, [Label("en", "Wondarful")]),
        Foo(2u, [Label("en", "eordw")])
    ];
    auto r = search(foos, q).array;
    assert(r.length == 1);
    assert(r[0].id == 0u);
}

unittest
{
    auto cs = [
        CubeDescription("P", "1", [Label("en", "Bar")], "P", "1", []),
        CubeDescription("P", "0", [Label("en", "Foo")], "P", "0", [])
    ];
    auto r = search(cs, "foo");
    assert(r.length == 1);
    assert(r[0].id == "0");
}

struct Tag
{
    @getter("id")
    private string id_;

    @getter("labels")
    private Label[] labels_;

    mixin(Generate);
}

struct CubeDescription
{
    @getter("providerId")
    private string providerId_;

    @getter("id")
    private string id_;

    @getter("labels")
    private Label[] labels_;

    @getter("definitionId")
    private string definitionId_;

    @getter("definitionProviderId")
    private string definitionProviderId_;

    @getter("tagIds")
    private string[] tagIds_;

    mixin(Generate);
}

bool containsTags(in CubeDescription desc, in string[] tagIds) pure nothrow @safe
{
    import std.algorithm : canFind;
    auto r = desc.tagIds.filter!(i => tagIds.canFind(i));
    return !r.empty;
}

unittest
{
    assert(CubeDescription("FOO", "BAR", [], "FOO", "BAR", ["A", "B", "C"]).containsTags(["A", "B"]));
    assert(!CubeDescription("FOO", "BAR", [], "FOO", "BAR", ["A", "B", "C"]).containsTags(["D"]));
    assert(!CubeDescription("FOO", "BAR", [], "FOO", "BAR", ["A", "B", "C"]).containsTags([]));
    assert(!CubeDescription("FOO", "BAR", [], "FOO", "BAR", []).containsTags(["A", "B"]));
}

struct CubeDefinition
{
    @getter("providerId")
    private string providerId_;

    @getter("id")
    private string id_;

    @getter("dimensions")
    private Dimension[] dimensions_;

    @getter("attributes")
    private Attribute[] attributes_;

    @getter("measures")
    private Measure[] measures_;

    mixin(Generate);

}

struct Dimension
{

    @getter("id")
    private Nullable!string id_;

    @getter("obsDimension")
    private bool obsDimension_;

    @getter("timeDimension")
    private bool timeDimension_;

    @getter("concept")
    private Nullable!Concept concept_;

    @getter("codelistId")
    private Nullable!string codelistId_;

    @getter("codelistProviderId")
    private Nullable!string codelistProviderId_;

    mixin(Generate);
}

struct Attribute
{

    @getter("id")
    private Nullable!string id_;

    @getter("concept")
    private Nullable!Concept concept_;

    @getter("codelistId")
    private Nullable!string codelistId_;

    @getter("codelistProviderId")
    private Nullable!string codelistProviderId_;

    mixin(Generate);
}

struct Code
{
    @getter("id")
    private string id_;

    @getter("labels")
    private Label[] labels_;

    mixin(Generate);
}

struct Concept
{
    @getter("id")
    private string id_;

    @getter("labels")
    private Label[] labels_;

    mixin(Generate);
}

struct Measure
{

    @getter("id")
    private Nullable!string id_;

    @getter("concept")
    private Nullable!Concept concept_;

    mixin(Generate);
}

struct DatasetMetadata
{

    @getter("definitionId")
    private string definitionId_;

    @getter("descriptionId")
    private string descriptionId_;

    @getter("providerId")
    private string providerId_;

    @getter("dimensionIds")
    private string[] dimensionIds_;

    @getter("obsDimensionIds")
    private string[] obsDimensionIds_;

    @getter("measureIds")
    private string[] measureIds_;

    mixin(Generate);
}

Nullable!DatasetMetadata toDatasetMetadata(CubeDefinition def, const string descriptionId) pure nothrow @safe
{
    auto dimensionIds = def.dimensions
        .filter!(d => !d.obsDimension)
        .map!(d => d.id.get)
        .array;

    auto obsDimensionIds = def.dimensions
        .filter!(d => d.obsDimension)
        .map!(d => d.id.get)
        .array;

    auto measureIds = def.measures
        .map!(m => m.id.get)
        .array;

    return DatasetMetadata(def.id, descriptionId, def.providerId, dimensionIds, obsDimensionIds, measureIds).nullable;
}

import std.traits : isScalarType, isSomeString;
private enum isValueType(T) = isScalarType!T || isSomeString!T;

struct Value(T)
if(isValueType!T)
{
    @getter("value")
    private Nullable!T value_;

    @getter("id")
    private string id_;

    mixin(Generate);
}

auto makeValues(T)(in T[string] assocArray) pure @safe nothrow
{
    import std.array : byPair, array;
    import std.algorithm : map;
    import std.typecons : nullable;
    import std.conv : to;

    return assocArray.byPair
        .map!(t => Value!T(t.value.to!T.nullable, t.key))
        .array;
}

unittest
{
    const a = ["foo": 1, "bar": 2];
    auto values = a.makeValues;
    assert(values.length == 2);
    assert(values[0].value.get == a[values[0].id]);
}

struct Observation(T)
if(isValueType!T)
{
    @getter("obsValue")
    private Value!T obsValue_;

    @getter("obsDimension")
    private Value!string obsDimension_;

    @getter("attributes")
    private Value!string[] attributes_;

    mixin(Generate);
}

struct Serie(T)
if(isValueType!T)
{
    @getter("observations")
    private Observation!T[] observations_;

    @getter("dimensions")
    private Value!string[] dimensions_;

    @getter("attributes")
    private Value!string[] attributes_;

    mixin(Generate);
}

struct Dataset(T)
if(isValueType!T)
{
    @getter("series")
    private Serie!T[] series_;

    mixin(Generate);
}
