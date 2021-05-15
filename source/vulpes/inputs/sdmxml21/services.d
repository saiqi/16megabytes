module vulpes.inputs.sdmxml21.services;

import std.conv : to;
import std.typecons : Nullable, nullable, Tuple, apply;
import vulpes.lib.requests;
import vulpes.lib.xml : deserializeAs, deserializeAsRangeOf;
import vulpes.inputs.sdmxml21.types;
import vulpes.core.cube;

private auto toLabel(in SDMXName name) pure nothrow @safe
{
    return Label(name.lang, name.content, (Nullable!string).init);
}

package:
enum StructureType: string
{
    dataflow = "dataflow",
    codelist = "codelist",
    conceptscheme = "conceptscheme",
    datastructure = "datastructure",
    categoryscheme = "categoryscheme",
    categorisation = "categorisation",
    contentconstraint = "contentconstraint"
}

enum StructureDetail: string
{
    allstubs = "allstubs",
    referencestubs = "referencestubs",
    allcompletestubs = "allcompletestubs",
    referencecompletestubs = "referencecompletestubs",
    referencepartial = "referencepartial",
    full = "full"
}

enum StructureReferences: string
{
    none = "none",
    parents = "parents",
    parentsandsiblings = "parentsandsiblings",
    children = "children",
    descendants = "descendants",
    all = "all",
    codelist = "codelist",
    conceptscheme = "conceptscheme",
    contentconstraint = "contentconstraint",
    categorisation = "categorisation"
}

auto buildTags(in string[StructureType] messages)
{
    assert(StructureType.categorisation in messages);

    import vulpes.lib.operations : innerjoin;
    import std.algorithm : map;
    import std.array : array;

    auto msg = messages[StructureType.categorisation];
    auto categorisations = msg.deserializeAsRangeOf!SDMXCategorisation;
    auto categories = msg.deserializeAsRangeOf!SDMXCategory;

    alias categorisationId = c => c.target.ref_.id;
    alias categoryId = c => c.id;

    return categorisations
        .innerjoin!(categorisationId, categoryId)(categories)
        .map!(t => Tag(t.right.id,
                       t.right.names.map!toLabel.array));
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.algorithm : filter;
    auto messages = [StructureType.categorisation : readText("./fixtures/sdmx/structure_category_categorisation.xml")];
    auto tags = buildTags(messages);
    assert(!tags.empty);

    auto cat = tags.filter!(t => t.id == "CARAC_ENTRP");
    assert(!cat.empty);
    assert(cat.front.id == "CARAC_ENTRP");
    assert(cat.front.labels[0].language == "fr");
    assert(cat.front.labels[0].shortName == "Caractéristiques des entreprises");
    assert(cat.front.labels[1].language == "en");
    assert(cat.front.labels[1].shortName == "Characteristics of enterprises");
}

auto buildDescriptions(in string[StructureType] messages)
{
    assert(StructureType.dataflow in messages);

    import vulpes.lib.operations : leftouterjoin;
    import std.algorithm : map, filter;
    import std.array : array;

    auto msg = messages[StructureType.dataflow];
    auto dataflows = msg.deserializeAsRangeOf!SDMXDataflow;
    auto categorisations = msg.deserializeAsRangeOf!SDMXCategorisation;

    alias dataflowId = d => d.id.get;
    alias categorisationId = c => c.source.ref_.id;

    return dataflows
        .filter!(d => !d.id.isNull && !d.structure.isNull)
        .leftouterjoin!(dataflowId, categorisationId)(categorisations)
        .map!((t) {
            auto df = t.left;
            auto cat = t.right;

            return CubeDescription(df.agencyId.get("Unknown"),
                                   df.id.get,
                                   df.names.map!toLabel.array,
                                   df.structure.get.ref_.id,
                                   df.structure.get.ref_.agencyId,
                                   cat.isNull ? [] : [cat.get.target.ref_.id]);
        });
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;

    auto messages = [StructureType.dataflow : readText("./fixtures/sdmx/structure_dataflow_categorisation.xml")];
    auto descriptions = buildDescriptions(messages);
    assert(!descriptions.empty);
    assert(descriptions.walkLength == 1);
    assert(descriptions.front.id == "BALANCE-PAIEMENTS");
    assert(descriptions.front.providerId == "FR1");
    assert(descriptions.front.labels.length == 2);
    assert(descriptions.front.labels[0].language == "fr");
    assert(descriptions.front.labels[0].shortName == "Balance des paiements");
    assert(descriptions.front.definitionId == "BALANCE-PAIEMENTS");
    assert(descriptions.front.definitionProviderId == "FR1");
    assert(descriptions.front.tagIds.length == 1);
    assert(descriptions.front.tagIds[0] == "COMMERCE_EXT");
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.algorithm : filter;

    auto messages = [StructureType.dataflow : readText("./fixtures/sdmx/structure_dataflow.xml")];
    auto descriptions = buildDescriptions(messages);
    assert(!descriptions.empty);
    assert(descriptions.walkLength == 195);

    auto desc = descriptions.filter!(d => d.id == "BALANCE-PAIEMENTS").front;
    assert(desc.id == "BALANCE-PAIEMENTS");
    assert(desc.providerId == "FR1");
    assert(desc.labels.length == 2);
    assert(desc.labels[0].language == "fr");
    assert(desc.labels[0].shortName == "Balance des paiements");
    assert(desc.definitionId == "BALANCE-PAIEMENTS");
    assert(desc.definitionProviderId == "FR1");
    assert(desc.tagIds.length == 0);
}

auto buildDefinition(in string[StructureType] messages)
{
    import std.array : array;
    import std.algorithm : map, sort;
    import std.range : chain;
    import vulpes.lib.operations : leftouterjoin;
    assert(StructureType.datastructure in messages);

    auto dsd = messages[StructureType.datastructure].deserializeAs!SDMXDataStructure;
    auto cs = messages[StructureType.datastructure].deserializeAsRangeOf!SDMXConcept;

    auto concepts = !cs.empty
        ? cs.array
        : (StructureType.conceptscheme in messages)
            ? messages[StructureType.conceptscheme].deserializeAsRangeOf!SDMXConcept.array
            : [];

    alias conceptIdentityId = d => d.conceptIdentity.isNull ? "" : d.conceptIdentity.get.ref_.id;
    alias conceptId = c => c.id;

    auto dimensions = dsd.dataStructureComponents.dimensionList.dimensions
        .leftouterjoin!(conceptIdentityId, conceptId)(concepts)
        .array
        .sort!((a, b) => a.left.position.apply!(to!int) < b.left.position.apply!(to!int))
        .map!((t) {
            auto d = t.left;
            auto c = t.right;

            auto concept = c.apply!(cc => Concept(cc.id, cc.names.map!toLabel.array));

            auto codelist = d.localRepresentation
                .apply!(lr => lr.enumeration)
                .apply!(e => e.ref_);

            return Dimension(d.id,
                             ObsDimension.no,
                             TimeDimension.no,
                             concept,
                             codelist.apply!(c => c.id),
                             codelist.apply!(c => c.agencyId));
        });
    auto timeDimension = [dsd.dataStructureComponents.dimensionList.timeDimension]
        .leftouterjoin!(conceptIdentityId, conceptId)(concepts)
        .map!((t) {
            auto td = t.left;
            auto c = t.right;

            auto concept = c.apply!(cc => Concept(cc.id, cc.names.map!toLabel.array));

            return Dimension(td.id,
                             ObsDimension.yes,
                             TimeDimension.yes,
                             concept,
                             (Nullable!string).init,
                             (Nullable!string).init);
        });
    auto attributes = dsd.dataStructureComponents.attributeList.attributes
        .leftouterjoin!(conceptIdentityId, conceptId)(concepts)
        .map!((t) {
            auto a = t.left;
            auto c = t.right;

            auto concept = c.apply!(cc => Concept(cc.id, cc.names.map!toLabel.array));

            auto codelist = a.localRepresentation
                .apply!(lr => lr.enumeration)
                .apply!(e => e.ref_);

            return Attribute(a.id,
                             concept,
                             codelist.apply!(c => c.id),
                             codelist.apply!(c => c.agencyId));
        });
    auto measures = [dsd.dataStructureComponents.measureList.primaryMeasure]
        .leftouterjoin!(conceptIdentityId, conceptId)(concepts)
        .map!((t) {
            auto m = t.left;
            auto c = t.right;

            auto concept = c.apply!(cc => Concept(cc.id, cc.names.map!toLabel.array));

            return Measure(m.id, concept);
        });
    return CubeDefinition(dsd.agencyId,
                          dsd.id,
                          dimensions.chain(timeDimension).array,
                          attributes.array,
                          measures.array);
}

unittest
{
    import std.file : readText;
    import std.algorithm : canFind, map, all;
    auto messages = [StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd.xml")];
    auto def = buildDefinition(messages);
    assert(def.id == "BALANCE-PAIEMENTS");
    assert(def.providerId == "FR1");
    assert(def.dimensions[0].id == "FREQ");
    assert(!def.dimensions[0].obsDimension);
    assert(!def.dimensions[0].timeDimension);
    assert(def.dimensions[0].concept.isNull);
    assert(def.dimensions[0].codelistId.get == "CL_PERIODICITE");
    assert(def.dimensions[0].codelistProviderId.get == "FR1");
    assert(def.dimensions[1].id == "TIME_PERIOD");
    assert(def.dimensions[1].obsDimension);
    assert(def.dimensions[1].timeDimension);
    assert(def.dimensions[1].codelistId.isNull);
    assert(def.dimensions[1].codelistProviderId.isNull);
    assert(def.attributes.all!(a => ["UNIT_MULT", "IDBANK"].canFind(a.id.get)));
    assert(def.attributes.all!(a => a.concept.isNull));
    assert(def.attributes.all!(a => a.codelistId.isNull && a.codelistProviderId.isNull));
    assert(def.measures.length == 1);
    assert(def.measures[0].id.get == "OBS_VALUE");
    assert(def.measures[0].concept.isNull);
}

unittest
{
    import std.file : readText;
    import std.algorithm : any, map;
    auto messages = [
        StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd.xml"),
        StructureType.conceptscheme: readText("./fixtures/sdmx/structure_conceptscheme.xml")
    ];
    auto def = buildDefinition(messages);
    assert(def.dimensions[0].concept.get.id == "FREQ");
    assert(def.dimensions[0].concept.get.labels.length == 2);
    assert(def.dimensions[1].concept.isNull);
    assert(def.attributes.any!(a => !a.concept.isNull));
    assert(def.measures[0].concept.isNull);
}

unittest
{
    import std.file : readText;
    import std.algorithm : equal, map, all;
    auto messages = [
        StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")];
    auto def = buildDefinition(messages);
    assert(def.dimensions.map!(d => d.id).equal(["FREQ", "UNIT", "NA_ITEM", "GEO", "TIME_PERIOD"]));
    assert(def.dimensions[0].concept.get.id == "FREQ");
    assert(def.dimensions[4].concept.get.id == "TIME");
    assert(def.attributes.all!(a => !a.concept.isNull));
    assert(def.attributes.all!(a => !a.codelistId.isNull && !a.codelistProviderId.isNull));
    assert(!def.measures[0].concept.isNull);
}

auto extractCodelistIds(in string[StructureType] messages, in string resourceId)
{
    import std.algorithm : filter, map;
    import std.exception : enforce;
    import std.format : format;
    import vulpes.errors : NotFound;

    assert(StructureType.datastructure in messages);
    auto dsd = messages[StructureType.datastructure].deserializeAs!SDMXDataStructure;
    auto dimensions = dsd.dataStructureComponents.dimensionList.dimensions
        .filter!(d => d.id == resourceId);
    auto attributes = dsd.dataStructureComponents.attributeList.attributes
        .filter!(a => a.id == resourceId);

    enforce!NotFound(!dimensions.empty || !attributes.empty,
                     format!"Cannot find %s in neither dimensions nor attributes in dsd %s"(resourceId, dsd.id));

    alias Result = Tuple!(string, "id", string, "agencyId");

    alias extractId = r => r.localRepresentation
        .apply!(lr => lr.enumeration)
        .apply!(e => Result(e.ref_.id, e.ref_.agencyId.get(dsd.agencyId)));

    auto result = dimensions.empty
        ? attributes.map!extractId.front
        : dimensions.map!extractId.front;

    enforce!NotFound(!result.isNull,
                    format!"Cannot find codelist related to resource %s"(resourceId));

    return result.get;
}

unittest
{
    import std.file : readText;
    import std.exception : assertThrown;
    import vulpes.errors : NotFound;

    auto messages = [StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd.xml")];
    auto dimIds = extractCodelistIds(messages, "FREQ");
    assert(dimIds.id == "CL_PERIODICITE");
    assert(dimIds.agencyId == "FR1");
    assertThrown!NotFound(extractCodelistIds(messages, "UNIT_MULT"));
    assertThrown!NotFound(extractCodelistIds(messages, "UNKNOWN"));
}

auto buildCodes(in string[StructureType] messages, in string resourceId)
{
    import std.array : array;
    import std.algorithm : filter, map, joiner;
    import vulpes.lib.operations : leftouterjoin;
    assert(StructureType.codelist in messages);

    auto codes = messages[StructureType.codelist].deserializeAsRangeOf!SDMXCode;

    auto constraints = (StructureType.dataflow in messages)
        ? messages[StructureType.dataflow]
            .deserializeAsRangeOf!SDMXKeyValue
            .filter!(kv => kv.id == resourceId)
            .map!(kv => kv.values)
            .joiner
            .filter!(v => !v.content.isNull)
            .map!(v => v.content.get)
            .array
        : [];

    return codes
        .leftouterjoin!(c => c.id, c => c)(constraints)
        .filter!(t => (constraints.length > 0 && !t.right.isNull) || constraints.length == 0)
        .map!(t => Code(t.left.id, t.left.names.map!toLabel.array));
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;

    auto messages = [
        StructureType.codelist : readText(
            "./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml"),
        StructureType.dataflow : readText(
            "./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")];
    auto codes = buildCodes(messages, "DATA_DOMAIN");
    assert(!codes.empty);
    assert(codes.walkLength == 1);
    assert(codes.front.id == "01R");
    assert(codes.front.labels.length);
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;

    auto messages = [StructureType.codelist : readText("./fixtures/sdmx/structure_codelist.xml")];
    auto codes = buildCodes(messages, "FREQ");
    assert(!codes.empty);
    assert(codes.walkLength == 5);
}
