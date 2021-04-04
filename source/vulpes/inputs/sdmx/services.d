module vulpes.inputs.sdmx.services;

import std.algorithm : map, filter;
import std.exception : enforce;
import std.format : format;
import std.typecons : Nullable, nullable;
import vibe.core.log;
import sumtype : match;
import vulpes.inputs.sdmx.types;
import vulpes.inputs.sdmx.client;
import vulpes.inputs.sdmx.mapper;
import vulpes.core.cube;
import vulpes.core.query;
import vulpes.lib.xml : deserializeAsRangeOf, deserializeAs;

///
class SDMXServiceException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Return a range of `CubeDescription` given a provider ID
auto getCubeDescriptions(alias fetcher)(const string providerId)
{
    return fetchStructure!fetcher(providerId, StructureType.dataflow)
        .deserializeAsRangeOf!SDMXDataflow
        .map!toDescription
        .filter!(d => !d.isNull)
        .map!(d => d.get);
}

unittest
{
    import vibe.inet.url : URL;
    import std.file : readText;
    import vulpes.core.cube : CubeDescription;
    import std.exception : assertThrown;
    import std.typecons : tuple;

    auto mockerFetcher(const URL url, const string[string] headers)
    {
        return tuple(200, readText("./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml"));
    }

    auto res = getCubeDescriptions!mockerFetcher("IMF");
    assert(!res.empty);

    const CubeDescription desc = res.front;
    assert(desc.providerId == "IMF");

    assertThrown!SDMXClientException(getCubeDescriptions!mockerFetcher("Unknown"));

}

/// Return a `CubeDefinition` given a provider ID, a description ID and a definition ID
auto getCubeDefinition(alias fetcher)(
    const string providerId,
    const string descriptionId,
    const string definitionId)
{
    import vibe.core.concurrency : async;
    import vulpes.lib.futures : getResultOrFail, getResultOrNullable;

    auto fetchDSDMessage = async({
        return fetchStructure!fetcher(
            providerId,
            StructureType.datastructure,
            definitionId,
        ).deserializeAs!SDMXStructures;
    });

    auto fetchDataflowMessages = async({
        return fetchStructure!fetcher(
            providerId,
            StructureType.dataflow,
            descriptionId,
            "latest",
            "all",
            StructureDetail.full,
            StructureReferences.contentconstraint
        ).deserializeAs!SDMXStructures;
    });

    const dsdStructures = fetchDSDMessage.getResultOrFail!SDMXClientException;
    const dataflowStructures = fetchDataflowMessages.getResultOrNullable;

    enforce!SDMXServiceException(
        !dsdStructures.dataStructures.isNull,
        "The current structure message does not contain a datastructure!");

    enforce!SDMXServiceException(
        dsdStructures.dataStructures.get.dataStructures.length == 1,
        "Structures having multiple DSDs are not supported yet!"
    );

    const currentDataStructure = dsdStructures.dataStructures.get.dataStructures[0];

    import std.array : array, join;

    const(SDMXCodelist)[] codelists = !dsdStructures.codelists.isNull
        ? dsdStructures.codelists.get.codelists
        : [];

    auto flattenConcepts(const SDMXStructures structures)
    {
        assert(!structures.concepts.isNull);
        return structures.concepts.get.conceptSchemes
            .map!(cs => cs.concepts)
            .array
            .join;
    }

    const(SDMXConcept)[] concepts = !dsdStructures.concepts.isNull
        ? flattenConcepts(dsdStructures)
        : [];

    auto fetchCodelists()
    {
        logDebug("Codelists not provided in the artefact, fetching them");
        return gatherCodelistIds(dsdStructures.dataStructures.get)
            .map!((t) => async({
                return fetchStructure!fetcher(t.agencyId, StructureType.codelist, t.referenceId)
                    .deserializeAsRangeOf!SDMXCodelist;
            }))
            .array;
    }

    auto fetchConcepts()
    {
        logDebug("Concepts not provided in the artefact, fetching them");
        return async({
            return fetchStructure!fetcher(providerId, StructureType.conceptscheme)
                .deserializeAsRangeOf!SDMXConcept
                .array;
        });
    }

    auto constraints = dataflowStructures.isNull
        ? (Nullable!SDMXConstraints).init
        : dataflowStructures.get.constraints;

    // Got everything we need, return the definition
    if(codelists && concepts)
    {
        return toDefinition(
            currentDataStructure, codelists, concepts, constraints);
    // Everything is missing, fetch all additional resources
    } else if(!codelists && !concepts) {
        auto fetchConcepts_ = fetchConcepts();
        auto fetchCodelists_ = fetchCodelists();
        return toDefinition(
            currentDataStructure, fetchCodelists_.map!(p => p.getResultOrFail!SDMXClientException).array.join,
            fetchConcepts_.getResultOrFail!SDMXClientException, constraints);
    } else if(!codelists) {
        return toDefinition(
            currentDataStructure, fetchCodelists().map!(p => p.getResultOrFail!SDMXClientException).array.join,
            concepts, constraints);
    } else {
        return toDefinition(
            currentDataStructure, codelists,
            fetchConcepts().getResultOrFail!SDMXClientException, constraints);
    }
}

unittest
{
    import std.exception : assertThrown;
    import std.file : readText;
    import std.typecons : tuple;
    import std.algorithm : canFind;
    import vibe.inet.url : URL;
    import vulpes.core.cube : CubeDefinition, Concept, Label;

    auto mockFetcherDSD(const URL url, const string[string] headers)
    {
        if(url.toString.canFind("datastructure"))
            return tuple(200, readText("./fixtures/sdmx/structure_dsd.xml"));
        if(url.toString.canFind("conceptscheme"))
            return tuple(200, readText("./fixtures/sdmx/structure_conceptscheme.xml"));
        if(url.toString.canFind("dataflow"))
            return tuple(200, readText("./fixtures/sdmx/structure_dataflow.xml"));
        return tuple(200, readText("./fixtures/sdmx/structure_codelist.xml"));
    }

    auto def = getCubeDefinition!mockFetcherDSD("FR1", "BALANCE-PAIEMENTS", "BALANCE-PAIEMENTS");
    assert(def.id == "BALANCE-PAIEMENTS");

    assert(def.measures.length == 1);
    assert(def.measures[0].id == "OBS_VALUE");
    assert(def.measures[0].concept.isNull);
    assert(def.measures[0].labels == []);

    assert(def.dimensions.length == 2);
    assert(def.dimensions[0].id == "FREQ");
    assert(!def.dimensions[0].isObsDimension);
    assert(!def.dimensions[0].concept.isNull);
    assert(def.dimensions[0].concept.get.id == "FREQ");
    assert(def.dimensions[0].codes.length == 5);

    assert(def.dimensions[1].id == "TIME_PERIOD");
    assert(def.dimensions[1].isObsDimension);
    assert(def.dimensions[1].concept.isNull);
    assert(def.dimensions[1].codes.length == 0);

    assert(def.attributes.length == 2);
    assert(!def.attributes[0].concept.isNull);
    assert(def.attributes[0].codes.length == 0);
}

unittest
{
    import std.file : readText;
    import std.typecons : tuple;
    import vibe.inet.url : URL;

    auto mockFetcherAll(const URL url, const string[string] headers)
    {
        return tuple(200, readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml"));
    }

    auto def2 = getCubeDefinition!mockFetcherAll("ESTAT", "nama_10_gdp", "DSD_nama_10_gdp");
    assert(!def2.dimensions[0].concept.isNull);
    assert(def2.dimensions[0].codes.length > 0);
    assert(!def2.attributes[0].concept.isNull);
    assert(def2.attributes[0].codes.length > 0);
}

unittest
{
    import std.file : readText;
    import std.typecons : tuple;
    import std.algorithm : canFind;
    import std.exception : assertThrown;
    import vibe.inet.url : URL;

    auto mockFetcherDSD(const URL url, const string[string] headers)
    {
        if(url.toString.canFind("datastructure"))
            return tuple(200, readText("./fixtures/sdmx/structure_dsd.xml"));
        if(url.toString.canFind("conceptscheme"))
            return tuple(200, readText("./fixtures/sdmx/structure_conceptscheme.xml"));
        return tuple(500, readText("./fixtures/sdmx/error.xml"));
    }

    assertThrown!SDMXClientException(
        getCubeDefinition!mockFetcherDSD("FR1", "BALANCE-PAIEMENTS", "BALANCE-PAIEMENTS"));
}

private auto toKeys(DatasetMetadata metadata, Statement[] statements) pure nothrow @safe
{
    import std.array : join;

    return metadata.dimensionIds
        .map!((dimId) {
            auto s = statements
                .filter!(stmt => stmt.key == dimId);

            return s.empty
                ? ""
                : s.front.match!(
                    (EqualsStatement s) => s.eq,
                    (InStatement s) => s.in_.join("+"),
                    _ => "");
        })
        .array
        .join(".");
}


@safe unittest
{
    Statement[] statements;
    Statement eq = EqualsStatement("COUNTRY", "GB");
    Statement in_ = InStatement("CITY", ["LONDON", "BRIGHTON"]);
    Statement obsEq = EqualsStatement("TIME_PERIOD", "2021-Q3");
    Statement nin = NotInStatement("CITY", ["MANCHESTER"]);
    statements ~= eq;
    statements ~= in_;
    statements ~= obsEq;
    statements ~= nin;

    auto meta = DatasetMetadata("DEF", "DESC", "FOO", ["COUNTRY", "CITY"], ["TIME_PERIOD"], ["OBS_VALUE"]);

    assert(meta.toKeys(statements) == "GB.LONDON+BRIGHTON");
    assert(meta.toKeys([]) == ".");
}

private Nullable!string toPeriod(string period)(DatasetMetadata metadata, Statement[] statements) pure nothrow @safe
if(period == "start" || period == "end")
{
    if(!metadata.obsDimensionIds.length)
        return typeof(return).init;

    auto obsDimensionId = metadata.obsDimensionIds[0];

    static if(period == "start")
    {
        auto statement = statements
            .filter!(s => s.match!(
                (GreaterOrEqualThanStatement gte) => gte.key == obsDimensionId,
                _ => false));
    }
    else static if(period == "end")
    {
        auto statement = statements
            .filter!(s => s.match!(
                (LowerOrEqualThanStatement lte) => lte.key == obsDimensionId,
                _ => false));
    }
    return statement.empty
        ? typeof(return).init
        : statement.front.value;
}

@safe unittest
{
    Statement[] statements;
    Statement eq = EqualsStatement("COUNTRY", "GB");
    Statement in_ = InStatement("CITY", ["LONDON", "BRIGHTON"]);
    Statement obsGte = GreaterOrEqualThanStatement("TIME_PERIOD", "2021-Q3");
    Statement obsLte = LowerOrEqualThanStatement("TIME_PERIOD", "2021-Q4");
    Statement nin = NotInStatement("CITY", ["MANCHESTER"]);
    statements ~= eq;
    statements ~= in_;
    statements ~= obsGte;
    statements ~= obsLte;
    statements ~= nin;

    auto meta = DatasetMetadata("DEF", "DESC", "FOO", ["COUNTRY", "CITY"], ["TIME_PERIOD"], ["OBS_VALUE"]);

    assert(meta.toPeriod!"start"(statements).get == "2021-Q3");
    assert(meta.toPeriod!"end"(statements).get == "2021-Q4");
    assert(meta.toPeriod!"start"([]).isNull);
}

@safe unittest
{
    Statement[] statements;
    Statement eq = EqualsStatement("COUNTRY", "GB");
    Statement in_ = InStatement("CITY", ["LONDON", "BRIGHTON"]);
    Statement obsGt = GreaterThanStatement("TIME_PERIOD", "2021-Q3");
    Statement nin = NotInStatement("CITY", ["MANCHESTER"]);
    statements ~= eq;
    statements ~= in_;
    statements ~= obsGt;
    statements ~= nin;

    auto meta = DatasetMetadata("DEF", "DESC", "FOO", ["COUNTRY", "CITY"], ["TIME_PERIOD"], ["OBS_VALUE"]);

    assert(meta.toPeriod!"start"(statements).isNull);
}

auto getDataset(alias fetcher)(DatasetMetadata metadata, Statement[] statements)
{
    enforce!SDMXServiceException(
        metadata.measureIds.length == 1, "Dataset must contain exactly one measure");

    enforce!SDMXServiceException(
        metadata.obsDimensionIds.length == 1, "Dataset must contain exactly one observation dimension");

    auto keys = metadata.toKeys(statements);
    auto startPeriod = metadata.toPeriod!"start"(statements);
    auto endPeriod = metadata.toPeriod!"end"(statements);

    string payload;
    try
    {
        payload = fetchData!fetcher(
            DataRequestFormat.generic,
            metadata.descriptionId,
            keys,
            metadata.providerId,
            startPeriod,
            endPeriod);
    }
    catch(SDMXClientException e)
    {
        payload = fetchData!fetcher(
            DataRequestFormat.structurespecific,
            metadata.descriptionId,
            keys,
            metadata.providerId,
            startPeriod,
            endPeriod);
    }
    return payload
        .deserializeAs!SDMXDataSet
        .toDataset(metadata.measureIds[0],
            metadata.obsDimensionIds[0],
            metadata.dimensionIds);
}

auto getDataset(alias fetcher)(CubeDefinition def, CubeDescription desc, Statement[] statements)
{
    auto meta = def.toDatasetMetadata(desc.id);
    enforce!SDMXServiceException(!meta.isNull, "Cannot build dataset metadata");
    return getDataset!fetcher(meta.get, statements);
}

unittest
{
    import std.file : readText;
    import std.typecons : tuple;
    import vibe.inet.url : URL;

    auto codelists = readText("./fixtures/sdmx/structure_codelist.xml")
        .deserializeAsRangeOf!SDMXCodelist
        .array;

    auto concepts = readText("./fixtures/sdmx/structure_conceptscheme.xml")
        .deserializeAsRangeOf!SDMXConcept
        .array;

    auto dsd = readText("./fixtures/sdmx/structure_dsd.xml")
        .deserializeAs!SDMXDataStructure;

    auto def = toDefinition(dsd, codelists, concepts, (Nullable!SDMXConstraints).init);

    auto mockFetcherDataset(const URL url, const string[string] headers)
    {
        if(headers["Accept"] == "application/vnd.sdmx.genericdata+xml;version=2.1")
            return tuple(200, readText("./fixtures/sdmx/data_generic.xml"));
        return tuple(500, "");
    }

    auto ds = getDataset!mockFetcherDataset(def.toDatasetMetadata(def.id).get, []);
    assert(ds.series.length == 3);
}

unittest
{
    import std.file : readText;
    import std.typecons : tuple;
    import vibe.inet.url : URL;

    auto structure = readText("./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml");

    auto codelists = structure.deserializeAsRangeOf!SDMXCodelist.array;

    auto concepts = structure.deserializeAsRangeOf!SDMXConcept.array;

    auto dsd = structure.deserializeAs!SDMXDataStructure;

    auto constraint = structure.deserializeAs!SDMXConstraints.nullable;

    auto dataflow = structure.deserializeAs!SDMXDataflow;

    auto def = toDefinition(dsd, codelists, concepts, constraint);

    auto desc = toDescription(dataflow);

    auto mockFetcherDataset(const URL url, const string[string] headers)
    {
        if(headers["Accept"] != "application/vnd.sdmx.genericdata+xml;version=2.1")
            return tuple(200, readText("./fixtures/sdmx/data_specific.xml"));
        return tuple(500, "");
    }

    auto ds = getDataset!mockFetcherDataset(def, desc.get, []);
    assert(ds.series.length == 3);
}
