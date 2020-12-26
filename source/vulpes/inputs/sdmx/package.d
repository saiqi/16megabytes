module vulpes.inputs.sdmx;

import std.algorithm : map, filter;
import std.exception : enforce;
import std.format : format;
import vibe.core.log;
import vulpes.inputs.sdmx.types;
import vulpes.inputs.sdmx.client;
import vulpes.inputs.sdmx.mapper;
import vulpes.lib.xml : deserializeAsRangeOf;

class SDMXException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

auto getCubeDescriptions(const string providerId)
{
    return fetch(providerId, StructureType.dataflow)
        .deserializeAsRangeOf!SDMXDataflow
        .map!toDescription
        .filter!(d => d.isNull);
}

auto getCubeDefinition(const string providerId, const string definitionId)
{
    auto structures = fetch(
        providerId,
        StructureType.datastructure,
        definitionId,
        "latest",
        "all",
        StructureDetail.full,
        StructureReferences.contentconstraint
    ).deserializeAsRangeOf!SDMXStructures;

    enforce!SDMXException(!structures.empty, format!"DSD %s not found"(definitionId));

    const currentStructures = structures.front;

    enforce!SDMXException(
        !currentStructures.dataStructures.isNull,
        "The current structure message does not contains a datastructure!");

    enforce!SDMXException(
        !currentStructures.dataStructures.get.dataStructures == 1,
        "Structures having multiple DSDs are not supported yet!"
    );

    const currentDataStructure = currentStructures.dataStructures.get.dataStructures[0];

    import std.array : array, join;

    auto getCodelists()
    {
        logInfo("Codelists not provided in the artefact, fetching them");
        return gatherCodelistIds(currentStructures.dataStructures.get)
            .map!(id =>
                fetch(id[0], StructureType.codelist, id[1])
                    .deserializeAsRangeOf!SDMXCodelist)
            .array
            .join;
    }

    auto getConcepts()
    {
        logInfo("Concepts not provided in the artefact, fetching them");
        return fetch(providerId, StructureType.conceptscheme)
            .deserializeAsRangeOf!SDMXConcept
            .array;
    }

    // Check whether current feed contains already codelists and conceptscheme
    import std.array : join;
    return currentStructures.codelists.isNull && currentStructures.concepts.isNull
        ? toDefinition(currentDataStructure, getCodelists(), getConcepts())
        : toDefinition(
            currentDataStructure,
            currentStructures.codelists.get.codelists,
            currentStructures.concepts.get.conceptSchemes
                .map!(cs => cs.concepts)
                .array
                .join);
}