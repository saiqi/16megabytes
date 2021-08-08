module vulpes.core.cube;
import std.typecons : Nullable, nullable, Flag;
import std.range;
import std.traits : Unqual;
import std.algorithm : filter, map;
import std.array : array;

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
    private:
    string language_;
    string shortName_;
    Nullable!string longName_;

    public:
    inout(string) language() @property inout pure nothrow @safe
    {
        return language_;
    }

    inout(string) shortName() @property inout pure nothrow @safe
    {
        return shortName_;
    }

    inout(Nullable!string) longName() @property inout pure nothrow @safe
    {
        return longName_;
    }
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

auto search(size_t threshold = 1u, R)(R resources, in string query) pure @safe nothrow
if(isForwardRange!R && isLabelized!(ElementType!R))
{
    import std.algorithm : map, filter;
    import std.array : array;
    import vulpes.lib.operations : sort;

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
    private:
    string id_;
    Label[] labels_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }
}

struct CubeDescription
{
    private:
    string providerId_;
    string id_;
    Label[] labels_;
    string definitionId_;
    string definitionProviderId_;
    string[] tagIds_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
        tagIds_ = tagIds_.dup;
    }

    inout(string) providerId() inout pure nothrow @safe
    {
        return providerId_;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }

    inout(string) definitionId() inout pure nothrow @safe
    {
        return definitionId_;
    }

    inout(string[]) tagIds() inout pure nothrow @safe
    {
        return tagIds_;
    }

    inout(string) definitionProviderId() inout pure nothrow @safe
    {
        return definitionProviderId_;
    }
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
    private:
    string providerId_;
    string id_;
    Dimension[] dimensions_;
    Attribute[] attributes_;
    Measure[] measures_;

    public:
    this(this) pure @safe nothrow
    {
        dimensions_ = dimensions_.dup;
        attributes_ = attributes_.dup;
        measures_ = measures_.dup;
    }

    inout(string) providerId() inout pure nothrow @safe
    {
        return providerId_;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Dimension[]) dimensions() inout pure nothrow @safe
    {
        return dimensions_;
    }

    inout(Attribute[]) attributes() inout pure nothrow @safe
    {
        return attributes_;
    }

    inout(Measure[]) measures() inout pure nothrow @safe
    {
        return measures_;
    }
}

alias TimeDimension = Flag!"timeDimension";
alias ObsDimension = Flag!"obsDimension";

struct Dimension
{
    private:
    Nullable!string id_;
    ObsDimension obsDimension_;
    TimeDimension timeDimension_;
    Nullable!Concept concept_;
    Nullable!string codelistId_;
    Nullable!string codelistProviderId_;

    public:
    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(ObsDimension) obsDimension() inout pure nothrow @safe
    {
        return obsDimension_;
    }

    inout(TimeDimension) timeDimension() inout pure nothrow @safe
    {
        return timeDimension_;
    }

    inout(Nullable!Concept) concept() inout pure nothrow @safe
    {
        return concept_;
    }

    inout(Nullable!string) codelistId() inout pure nothrow @safe
    {
        return codelistId_;
    }

    inout(Nullable!string) codelistProviderId() inout pure nothrow @safe
    {
        return codelistProviderId_;
    }
}

struct Attribute
{
    private:
    Nullable!string id_;
    Nullable!Concept concept_;
    Nullable!string codelistId_;
    Nullable!string codelistProviderId_;

    public:
    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Nullable!Concept) concept() inout pure nothrow @safe
    {
        return concept_;
    }

    inout(Nullable!string) codelistId() inout pure nothrow @safe
    {
        return codelistId_;
    }

    inout(Nullable!string) codelistProviderId() inout pure nothrow @safe
    {
        return codelistProviderId_;
    }
}

struct Code
{
    private:
    string id_;
    Label[] labels_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }
}

struct Concept
{
    private:
    string id_;
    Label[] labels_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }
}

struct Measure
{
    private:
    Nullable!string id_;
    Nullable!Concept concept_;

    public:
    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Nullable!Concept) concept() inout pure nothrow @safe
    {
        return concept_;
    }
}

struct DatasetMetadata
{
    private:
    string definitionId_;
    string descriptionId_;
    string providerId_;
    string[] dimensionIds_;
    string[] obsDimensionIds_;
    string[] measureIds_;

    public:
    this(this) pure nothrow @safe
    {
        dimensionIds_ = dimensionIds_.dup;
        obsDimensionIds_ = obsDimensionIds_.dup;
        measureIds_ = measureIds_.dup;
    }

    inout(string) definitionId() inout pure nothrow @safe
    {
        return definitionId_;
    }

    inout(string) descriptionId() inout pure nothrow @safe
    {
        return descriptionId_;
    }

    inout(string) providerId() inout pure nothrow @safe
    {
        return providerId_;
    }

    inout(string[]) dimensionIds() inout pure nothrow @safe
    {
        return dimensionIds_;
    }

    inout(string[]) obsDimensionIds() inout pure nothrow @safe
    {
        return obsDimensionIds_;
    }

    inout(string[]) measureIds() inout pure nothrow @safe
    {
        return measureIds_;
    }
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
    private:
    Nullable!T value_;
    string id_;

    public:
    inout(Nullable!T) value() inout pure nothrow @safe
    {
        return value_;
    }

    inout(string) id() inout pure nothrow @safe
    {
        return id_;
    }
}

auto makeValues(T)(const T[string] assocArray) pure @safe nothrow
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
    private:
    Value!T obsValue_;
    Value!string obsDimension_;
    Value!string[] attributes_;

    public:
    this(this) pure @safe nothrow
    {
        attributes_ = attributes_.dup;
    }

    inout(Value!T) obsValue() inout pure nothrow @safe
    {
        return obsValue_;
    }

    inout(Value!string) obsDimension() inout pure nothrow @safe
    {
        return obsDimension_;
    }

    inout(Value!string[]) attributes() inout pure nothrow @safe
    {
        return attributes_;
    }
}

struct Serie(T)
if(isValueType!T)
{
    private:
    Observation!T[] observations_;
    Value!string[] dimensions_;
    Value!string[] attributes_;

    public:
    this(this) pure @safe nothrow
    {
        observations_ = observations_.dup;
        dimensions_ = dimensions_.dup;
        attributes_ = attributes_.dup;
    }

    inout(Observation!T[]) observations() inout pure nothrow @safe
    {
        return observations_;
    }

    inout(Value!string[]) dimensions() inout pure nothrow @safe
    {
        return dimensions_;
    }

    inout(Value!string[]) attributes() inout pure nothrow @safe
    {
        return attributes_;
    }
}

struct Dataset(T)
if(isValueType!T)
{
    private:
    Serie!T[] series_;

    public:
    this(this) pure @safe nothrow
    {
        series_ = series_.dup;
    }

    inout(Serie!T[]) series() inout pure nothrow @safe
    {
        return series_;
    }
}
