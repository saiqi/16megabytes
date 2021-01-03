module vulpes.inputs.sdmx.services;

import std.algorithm : map, filter;
import std.exception : enforce;
import std.format : format;
import vibe.core.log;
import vulpes.inputs.sdmx.types;
import vulpes.inputs.sdmx.client;
import vulpes.inputs.sdmx.mapper;
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
    import vulpes.core.models : CubeDescription;
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
            StructureReferences.parentsandsiblings
        ).deserializeAs!SDMXStructures;
    });

    const dsdStructures = fetchDSDMessage.getResult;
    const dataflowStructures = fetchDataflowMessages.getResult;

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
        : !dataflowStructures.codelists.isNull
            ? dataflowStructures.codelists.get.codelists
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
        : !dataflowStructures.concepts.isNull
            ? flattenConcepts(dataflowStructures)
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

    // Got everything we need, return the definition
    if(codelists && concepts)
    {
        return toDefinition(
            currentDataStructure, codelists, concepts, dataflowStructures.constraints);
    // Everything is missing, fetch all additional resources
    } else if(!codelists && !concepts) {
        auto fetchConcepts_ = fetchConcepts();
        auto fetchCodelists_ = fetchCodelists();
        return toDefinition(
            currentDataStructure, fetchCodelists_.map!(p => p.getResult).array.join,
            fetchConcepts_.getResult, dataflowStructures.constraints);
    } else if(!codelists) {
        return toDefinition(
            currentDataStructure, fetchCodelists().map!(p => p.getResult).array.join,
            concepts, dataflowStructures.constraints);
    } else {
        return toDefinition(
            currentDataStructure, codelists,fetchConcepts().getResult, dataflowStructures.constraints);
    }
}

unittest
{
    import std.exception : assertThrown;
    import std.file : readText;
    import std.typecons : tuple;
    import std.algorithm : canFind;
    import vibe.inet.url : URL;
    import vulpes.core.models : CubeDefinition, Concept, Label;

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
    assert(!def.dimensions[0].isTimeDimension);
    assert(!def.dimensions[0].concept.isNull);
    assert(def.dimensions[0].concept.get.id == "FREQ");
    assert(def.dimensions[0].codes.length == 5);

    assert(def.dimensions[1].id == "TIME_PERIOD");
    assert(def.dimensions[1].isTimeDimension);
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
    import std.algorithm : canFind, all, any;
    import vibe.inet.url : URL;

    auto mockFetcherDSD(const URL url, const string[string] headers)
    {
        if(url.toString.canFind("datastructure"))
            return tuple(200, readText("./fixtures/sdmx/structure_dsd.xml"));
        if(url.toString.canFind("conceptscheme"))
            return tuple(200, readText("./fixtures/sdmx/structure_conceptscheme.xml"));
        return tuple(500, readText("./fixtures/sdmx/error.xml"));
    }

    // auto def = getCubeDefinition!mockFetcherDSD("FR1", "BALANCE-PAIEMENTS", "BALANCE-PAIEMENTS");
}
