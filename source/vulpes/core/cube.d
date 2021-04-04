module vulpes.core.cube;
import std.typecons : Nullable, nullable, Flag;
import std.range : isInputRange, ElementType;
import std.traits : TemplateOf;
import std.algorithm : filter, map;
import std.array : array;

enum Language: string
{
    fr = "fr",
    en = "en",
    de = "de",
    es = "es"
}

struct Label
{
    private:
    Language language_;
    string shortName_;
    Nullable!string longName_;

    public:
    inout(Language) language() inout pure nothrow @safe
    {
        return language_;
    }

    inout(string) shortName() inout pure nothrow @safe
    {
        return shortName_;
    }

    inout(Nullable!string) longName() inout pure nothrow @safe
    {
        return longName_;
    }
}

struct Provider
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
    string[] tags_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
        tags_ = tags_.dup;
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

    inout(string[]) tags() inout pure nothrow @safe
    {
        return tags_;
    }
}

alias NoConstraint = Flag!"noConstraint";
alias MissingMeasureId = Flag!"missingMeasureId";
alias MissingDimensionId = Flag!"missingDimensionId";

struct CubeDefinition
{
    private:
    string providerId_;
    string id_;
    Dimension[] dimensions_;
    Attribute[] attributes_;
    Measure[] measures_;
    NoConstraint noConstraint_;
    MissingMeasureId missingMeasureId_;
    MissingDimensionId missingDimensionId_;

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

    inout(NoConstraint) noConstraint() inout pure nothrow @safe
    {
        return noConstraint_;
    }

    inout(MissingMeasureId) missingMeasureId() inout pure nothrow @safe
    {
        return missingMeasureId_;
    }

    inout(MissingDimensionId) missingDimensionId() inout pure nothrow @safe
    {
        return missingDimensionId_;
    }
}

struct Dimension
{
    private:
    Nullable!string id_;
    Label[] labels_;
    bool isObsDimension_;
    Code[] codes_;
    Nullable!Concept concept_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
        codes_ = codes_.dup;
    }

    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }

    inout(bool) isObsDimension() inout pure nothrow @safe
    {
        return isObsDimension_;
    }

    inout(Code[]) codes() inout pure nothrow @safe
    {
        return codes_;
    }

    inout(Nullable!Concept) concept() inout pure nothrow @safe
    {
        return concept_;
    }
}

struct Attribute
{
    private:
    Nullable!string id_;
    Label[] labels_;
    Code[] codes_;
    Nullable!Concept concept_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
        codes_ = codes_.dup;
    }

    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
    }

    inout(Code[]) codes() inout pure nothrow @safe
    {
        return codes_;
    }

    inout(Nullable!Concept) concept() inout pure nothrow @safe
    {
        return concept_;
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
    Label[] labels_;
    Nullable!Concept concept_;

    public:
    this(this) pure @safe nothrow
    {
        labels_ = labels_.dup;
    }

    inout(Nullable!string) id() inout pure nothrow @safe
    {
        return id_;
    }

    inout(Label[]) labels() inout pure nothrow @safe
    {
        return labels_;
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
    if(def.missingDimensionId || def.missingMeasureId)
        return typeof(return).init;

    auto dimensionIds = def.dimensions
        .filter!(d => !d.isObsDimension)
        .map!(d => d.id.get)
        .array;

    auto obsDimensionIds = def.dimensions
        .filter!(d => d.isObsDimension)
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
