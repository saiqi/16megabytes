module vulpes.core.testing;

import std.typecons : nullable, Nullable, Tuple;
import std.conv : to;
import std.array : array;
import std.algorithm : map;
import vulpes.core.cube;

auto buildTestDataset(T)(
    T value,
    const string obsDimensionId,
    const string obsValueId,
    const string[string][] dimensionValues,
    const string[string][] serieAttributeValues,
    const string[string] obsAttributeValues,
    const size_t numberOfObservations)
{
    import std.range : iota;

    auto buildObservation(size_t idx) {
        auto obsDimension = Value!string(idx.to!string.nullable, obsDimensionId);
        auto attributes = makeValues(obsAttributeValues);
        auto obsValue = Value!T(value.nullable, obsValueId);
        return Observation!T(obsValue, obsDimension, attributes);
    }

    auto buildSerie(const string[string] currDimValues, const string[string] currSerieAttrValues) {
        auto obs = iota(numberOfObservations)
            .map!buildObservation
            .array;
        auto dimensions = makeValues(currDimValues);
        auto attributes = makeValues(currSerieAttrValues);
        return Serie!T(obs, dimensions, attributes);
    }

    auto dimensions = dimensionValues[0].keys
        .map!(k => Dimension(k.nullable, ObsDimension.no, TimeDimension.no, (Nullable!Concept).init))
        .array ~ [Dimension(obsDimensionId.nullable, ObsDimension.yes, TimeDimension.no, (Nullable!Concept).init)];

    auto attributes = serieAttributeValues[0].keys
        .map!(k => Attribute(k.nullable, (Nullable!Concept).init))
        .array
        ~ obsAttributeValues.keys
            .map!(k => Attribute(k.nullable, (Nullable!Concept).init))
            .array;

    auto measures = [Measure(obsValueId.nullable, (Nullable!Concept).init)];

    import std.algorithm : cartesianProduct;

    auto series = cartesianProduct(dimensionValues, serieAttributeValues)
        .map!(t => buildSerie(t[0], t[1]))
        .array;

    auto def = CubeDefinition(
        "TEST",
        "TEST",
        dimensions,
        attributes,
        measures);

    return Tuple!(CubeDefinition, "cubeDefinition", Dataset!T, "dataset", DatasetMetadata, "metadata")(
        def,
        Dataset!T(series),
        def.toDatasetMetadata("TEST").get);
}

unittest
{
    auto r = buildTestDataset(3.14, "INDEX", "OBS", [["FOO": "FOO"]], [["BAR": "BAR"]], ["BAZ": "BAZ"], 2);
    auto ds = r.dataset;

    assert(ds.series.length == 1);
    assert(ds.series[0].dimensions.length == 1);
    assert(ds.series[0].attributes.length == 1);
    assert(ds.series[0].observations.length == 2);
    assert(ds.series[0].observations[0].obsValue.value.get == 3.14);

    auto def = r.cubeDefinition;
    assert(def.dimensions.length == 2);
    assert(def.attributes.length == 2);
    assert(def.measures.length == 1);

    auto meta = r.metadata;
    assert(meta.dimensionIds.length == 1);
    assert(meta.obsDimensionIds.length == 1);
    assert(meta.measureIds.length == 1);
}
