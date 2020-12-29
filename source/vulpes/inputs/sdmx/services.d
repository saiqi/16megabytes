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
        return tuple(200, readText("./fixtures/sdmx/structure_dataflow_constraint.xml"));
    }

    auto res = getCubeDescriptions!mockerFetcher("IMF");
    assert(!res.empty);

    const CubeDescription desc = res.front;
    assert(desc.providerId == "IMF");

    assertThrown!SDMXClientException(getCubeDescriptions!mockerFetcher("Unknown"));

}

/// Return a `CubeDefinition` given a provider ID and a definition ID
auto getCubeDefinition(alias fetcher)(const string providerId, const string definitionId)
{
    auto structures = fetchStructure!fetcher(
        providerId,
        StructureType.datastructure,
        definitionId,
        "latest",
        "all",
        StructureDetail.full,
        StructureReferences.contentconstraint
    ).deserializeAs!SDMXStructures;

    enforce!SDMXServiceException(
        !structures.dataStructures.isNull,
        "The current structure message does not contain a datastructure!");

    enforce!SDMXServiceException(
        structures.dataStructures.get.dataStructures.length == 1,
        "Structures having multiple DSDs are not supported yet!"
    );

    const currentDataStructure = structures.dataStructures.get.dataStructures[0];

    import std.array : array, join;

    auto getCodelists()
    {
        logInfo("Codelists not provided in the artefact, fetching them");
        import vibe.core.core : runTask;
        import std.range : enumerate, tee;

        const codelistIds = gatherCodelistIds(structures.dataStructures.get);
        Nullable!string[] bodies = new Nullable!string[codelistIds.length];

        auto taskList = codelistIds
            .enumerate
            .map!((t) {
                const i = t[0];
                const provider = t[1][0];
                const definition = t[1][1];
                return runTask({
                    try
                    {
                        bodies[i] = fetchStructure!fetcher(provider, StructureType.codelist, definition)
                            .nullable;
                    }
                    catch(Exception e){}
                });
            }).array;

        taskList.tee!(t => t.join).array;

        return bodies
            .filter!(b => !b.isNull)
            .map!(b => b.get.deserializeAsRangeOf!SDMXCodelist)
            .array
            .join;
    }

    auto getConcepts()
    {
        logInfo("Concepts not provided in the artefact, fetching them");
        return fetchStructure!fetcher(providerId, StructureType.conceptscheme)
            .deserializeAsRangeOf!SDMXConcept
            .array;
    }

    // Check whether current feed contains already codelists and conceptscheme
    import std.array : join;
    if(structures.codelists.isNull && structures.concepts.isNull)
    {
        import vibe.core.core : runTask;
        const(SDMXCodelist)[] codelists;
        const(SDMXConcept)[] concepts;

        auto t1 = runTask({
            codelists = getCodelists();
        });

        auto t2 = runTask({
            try
            {
                concepts = getConcepts();
            }
            catch(Exception e) {}
        });

        t1.join();
        t2.join();

        return toDefinition(currentDataStructure, codelists, concepts);
    }
    return toDefinition(
            currentDataStructure,
            structures.codelists.get.codelists,
            structures.concepts.get.conceptSchemes
                .map!(cs => cs.concepts)
                .array
                .join);
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
        return tuple(200, readText("./fixtures/sdmx/structure_codelist.xml"));
    }

    const CubeDefinition def = getCubeDefinition!mockFetcherDSD("FR1", "BALANCE-PAIEMENTS");
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

    auto mockFetcherAll(const URL url, const string[string] headers)
    {
        return tuple(200, readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml"));
    }

    const CubeDefinition def2 = getCubeDefinition!mockFetcherAll("ESTAT", "DSD_nama_10_gdp");
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

    auto def = getCubeDefinition!mockFetcherDSD("FR1", "BALANCE-PAIEMENTS");
    assert(def.id == "BALANCE-PAIEMENTS");
    assert(def.dimensions.any!(d => !d.concept.isNull));
    assert(def.dimensions.all!(d => d.codes.length == 0));
}
