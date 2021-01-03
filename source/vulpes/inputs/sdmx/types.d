module vulpes.inputs.sdmx.types;

import std.typecons : Nullable, tuple, Tuple;
import std.range : isInputRange, ElementType;
import std.algorithm: map, filter, joiner;
import std.range : chain;
import std.array : array;
import vulpes.lib.xml;

enum SDMXProvider: string
{
    FR1 = "FR1",
    ESTAT = "ESTAT",
    ECB = "ECB",
    UNSD = "UNSD",
    IMF = "IMF",
    ILO = "ILO",
    WB = "WB",
    WITS = "WITS",
    IAEG = "IAEG",
    SDMX = "SDMX"
}

@xmlRoot("Text")
struct SDMXText
{
    @text
    Nullable!string content;
}

@xmlRoot("ErrorMessage")
struct SDMXErrorMessage
{
    @attr("code")
    Nullable!string code;

    @xmlElement("Text")
    Nullable!SDMXText text_;

}

@xmlRoot("Error")
struct SDMXError_
{
    @xmlElement("ErrorMessage")
    Nullable!SDMXErrorMessage errorMessage;
}

@xmlRoot("Dataflow")
struct SDMXDataflow
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("agencyID")
    Nullable!string agencyId;

    @attr("version")
    Nullable!string version_;

    @attr("isFinal")
    Nullable!bool isFinal;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElement("Structure")
    Nullable!SDMXStructure structure;

    @xmlElement("Ref")
    Nullable!SDMXRef ref_;
}

@xmlRoot("Name")
struct SDMXName
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Structure")
struct SDMXStructure
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("Ref")
struct SDMXRef
{
    @attr("id")
    string id;

    @attr("version")
    Nullable!string version_;

    @attr("maintainableParentID")
    Nullable!string maintainableParentId;

    @attr("maintainableParentVersion")
    Nullable!string maintainableParentVersion;

    @attr("agencyID")
    Nullable!string agencyId;

    @attr("package")
    Nullable!string package_;

    @attr("class")
    Nullable!string class_;
}

@xmlRoot("ConceptIdentity")
struct SDMXConceptIdentity
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("TextFormat")
struct SDMXTextFormat
{
    @attr("textType")
    Nullable!string textType;

    @attr("minValue")
    Nullable!string minValue;

    @attr("maxValue")
    Nullable!string maxValue;

    @attr("pattern")
    Nullable!string pattern;
}

@xmlRoot("Enumeration")
struct SDMXEnumeration
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("LocalRepresentation")
struct SDMXLocalRepresentation
{
    @xmlElement("TextFormat")
    Nullable!SDMXTextFormat textFormat;

    @xmlElement("Enumeration")
    Nullable!SDMXEnumeration enumeration;
}

@xmlRoot("TimeDimension")
struct SDMXTimeDimension
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("position")
    Nullable!int position;

    @xmlElement("ConceptIdentity")
    Nullable!SDMXConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMXLocalRepresentation localRepresentation;
}

@xmlRoot("Dimension")
struct SDMXDimension
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("position")
    Nullable!int position;

    @xmlElement("ConceptIdentity")
    Nullable!SDMXConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMXLocalRepresentation localRepresentation;

    @xmlElement("Ref")
    Nullable!SDMXRef ref_;
}

@xmlRoot("DimensionList")
struct SDMXDimensionList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("TimeDimension")
    SDMXTimeDimension timeDimension;

    @xmlElementList("Dimension")
    SDMXDimension[] dimensions;
}

@xmlRoot("AttributeRelationship")
struct SDMXAttributeRelationship
{
    @xmlElementList("Dimension")
    SDMXDimension[] dimensions;

    @xmlElement("PrimaryMeasure")
    Nullable!SDMXPrimaryMeasure primaryMeasure;
}

@xmlRoot("Attribute")
struct SDMXAttribute
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("assignementStatus")
    Nullable!string assignementStatus;

    @xmlElement("ConceptIdentity")
    Nullable!SDMXConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMXLocalRepresentation localRepresentation;

    @xmlElement("AttributeRelationship")
    Nullable!SDMXAttributeRelationship attributeRelationship;
}

@xmlRoot("AttributeList")
struct SDMXAttributeList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Attribute")
    SDMXAttribute[] attributes;
}

@xmlRoot("DimensionReference")
struct SDMXDimensionReference
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("GroupDimension")
struct SDMXGroupDimension
{
    @xmlElementList("DimensionReference")
    SDMXDimensionReference[] dimensionReference;
}

@xmlRoot("Group")
struct SDMXGroup
{
    @attr("urn")
    Nullable!string urn;

    @attr("id")
    string id;

    @xmlElementList("GroupDimension")
    SDMXGroupDimension[] groupDimesions;
}

@xmlRoot("PrimaryMeasure")
struct SDMXPrimaryMeasure
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("ConceptIdentity")
    Nullable!SDMXConceptIdentity conceptIdentity;
}

@xmlRoot("MeasureList")
struct SDMXMeasureList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("PrimaryMeasure")
    SDMXPrimaryMeasure primaryMeasure;
}

@xmlRoot("DataStructureComponents")
struct SDMXDataStructureComponents
{
    @xmlElement("DimensionList")
    SDMXDimensionList dimensionList;

    @xmlElement("AttributeList")
    SDMXAttributeList attributeList;

    @xmlElement("MeasureList")
    SDMXMeasureList measureList;

    @xmlElement("Group")
    Nullable!SDMXGroup group;
}

@xmlRoot("DataStructure")
struct SDMXDataStructure
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @attr("agencyID")
    string agencyId;

    @attr("version")
    string version_;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElement("DataStructureComponents")
    SDMXDataStructureComponents dataStructureComponents;
}

@xmlRoot("Code")
struct SDMXCode
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMXName[] names;
}

@xmlRoot("Codelist")
struct SDMXCodelist
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @attr("agencyID")
    string agencyId;

    @attr("version")
    string version_;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElementList("Code")
    SDMXCode[] codes;
}

@xmlRoot("Concept")
struct SDMXConcept
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMXName[] names;
}

@xmlRoot("ConceptScheme")
struct SDMXConceptScheme
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @attr("agencyID")
    string agencyId;

    @attr("version")
    string version_;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElementList("Concept")
    SDMXConcept[] concepts;
}

@xmlRoot("Category")
struct SDMXCategory
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMXName[] names;
}

@xmlRoot("CategoryScheme")
struct SDMXCategoryScheme
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("agencyID")
    Nullable!string agencyId;

    @attr("version")
    Nullable!string version_;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElementList("Category")
    SDMXCategory[] categories;
}

@xmlRoot("Codelists")
struct SDMXCodelists
{
    @xmlElementList("Codelist")
    SDMXCodelist[] codelists;
}

@xmlRoot("Concepts")
struct SDMXConcepts
{
    @xmlElementList("ConceptScheme")
    SDMXConceptScheme[] conceptSchemes;
}

@xmlRoot("DataStructures")
struct SDMXDataStructures
{
    @xmlElementList("DataStructure")
    SDMXDataStructure[] dataStructures;
}

@xmlRoot("Dataflows")
struct SDMXDataflows
{
    @xmlElementList("Dataflow")
    SDMXDataflow[] dataflows;
}

@xmlRoot("CategorySchemes")
struct SDMXCategorySchemes
{
    @xmlElementList("CategoryScheme")
    SDMXCategoryScheme[] categorySchemes;
}

@xmlRoot("KeyValue")
struct SDMXKeyValue
{
    @attr("id")
    string id;

    @xmlElementList("Value")
    SDMXValue[] values;
}

@xmlRoot("ConstraintAttachment")
struct SDMXConstraintAttachment
{
    @xmlElement("Dataflow")
    Nullable!SDMXDataflow dataflow;
}

@xmlRoot("CubeRegion")
struct SDMXCubeRegion
{
    @attr("include")
    Nullable!bool include;

    @xmlElementList("KeyValue")
    SDMXKeyValue[] keyValues;
}

@xmlRoot("ContentConstraint")
struct SDMXContentConstraint
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("isExternalReference")
    Nullable!bool isExternalReference;

    @attr("agencyID")
    Nullable!string agencyId;

    @attr("isFinal")
    Nullable!bool isFinal;

    @attr("type")
    Nullable!string type;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElement("ConstraintAttachment")
    Nullable!SDMXConstraintAttachment constraintAttachment;

    @xmlElement("CubeRegion")
    Nullable!SDMXCubeRegion cubeRegion;
}

@xmlRoot("Constraints")
struct SDMXConstraints
{
    @xmlElementList("ContentConstraint")
    SDMXContentConstraint[] constraints;
}

@xmlRoot("Structures")
struct SDMXStructures
{
    @xmlElement("Codelists")
    Nullable!SDMXCodelists codelists;

    @xmlElement("Concepts")
    Nullable!SDMXConcepts concepts;

    @xmlElement("DataStructures")
    Nullable!SDMXDataStructures dataStructures;

    @xmlElement("Dataflows")
    Nullable!SDMXDataflows dataflows;

    @xmlElement("CategorySchemes")
    Nullable!SDMXCategorySchemes categorySchemes;

    @xmlElement("Constraints")
    Nullable!SDMXConstraints constraints;

}

@xmlRoot("Value")
struct SDMXValue
{
    @attr("id")
    Nullable!string id;

    @attr("value")
    Nullable!string value;

    @text
    Nullable!string content;
}

@xmlRoot("SeriesKey")
struct SDMXSeriesKey
{
    @xmlElementList("Value")
    SDMXValue[] values;
}

@xmlRoot("Attributes")
struct SDMXAttributes
{
    @xmlElementList("Value")
    SDMXValue[] values;
}

@xmlRoot("ObsDimension")
struct SDMXObsDimension
{
    @attr("value")
    string value;
}

@xmlRoot("ObsValue")
struct SDMXObsValue
{
    @attr("value")
    Nullable!double value;
}

@xmlRoot("Obs")
struct SDMXObs
{
    @xmlElement("ObsDimension")
    SDMXObsDimension obsDimesion;

    @xmlElement("ObsValue")
    SDMXObsValue obsValue;

    @xmlElement("Attributes")
    Nullable!SDMXAttributes attributes;
}

@xmlRoot("Series")
struct SDMXSeries
{
    @xmlElement("SeriesKey")
    SDMXSeriesKey seriesKey;

    @xmlElement("Attributes")
    SDMXAttributes attributes;
}

@xmlRoot("DataSet")
struct SDMXDataSet
{
    @attr("structureRef")
    string structureRef;

    @xmlElementList("Series")
    SDMXSeries[] series;
}

unittest
{
    import std.file : readText;

    const SDMXStructures structures = readText("./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    assert(structures.categorySchemes.isNull);
    assert(!structures.codelists.isNull);
    assert(!structures.concepts.isNull);
    assert(!structures.dataStructures.isNull);
    assert(!structures.dataflows.isNull);
    assert(!structures.constraints.isNull);

    const SDMXDataflows dataflows = structures.dataflows.get;
    assert(dataflows.dataflows.length == 1);

    const SDMXDataflow dataflow = dataflows.dataflows[0];
    assert(!dataflow.id.isNull);
    assert(dataflow.id.get == "01R");
    assert(!dataflow.agencyId.isNull);
    assert(dataflow.agencyId.get == "IMF");
    assert(dataflow.names.length == 1);
    assert(dataflow.names[0] == SDMXName(
        "en", "Exchange Rates and International Reserves (01R) for Collection"));
    assert(!dataflow.structure.isNull);
    assert(dataflow.structure.get.ref_.id == "ECOFIN_DSD");
    assert(dataflow.structure.get.ref_.agencyId == "IMF");

    const SDMXConstraints constraints = structures.constraints.get;
    assert(constraints.constraints.length == 1);

    const SDMXContentConstraint contentConstraint = constraints.constraints[0];
    assert(!contentConstraint.id.isNull);
    assert(contentConstraint.id.get == "01R_CONSTRAINT");
    assert(contentConstraint.names.length == 1);
    assert(contentConstraint.names[0] == SDMXName("en", "01R_CONSTRAINT"));
    assert(!contentConstraint.constraintAttachment.isNull);
    assert(!contentConstraint.constraintAttachment.get.dataflow.isNull);
    assert(contentConstraint.constraintAttachment.get.dataflow.get.ref_.get.id == "01R");
    assert(!contentConstraint.cubeRegion.isNull);

    const SDMXCubeRegion cubeRegion = contentConstraint.cubeRegion.get;
    assert(cubeRegion.keyValues.length == 2);

    const SDMXKeyValue keyValue = cubeRegion.keyValues[0];
    assert(keyValue.id == "COUNTERPART_AREA");
    assert(keyValue.values.length == 1);
    assert(!keyValue.values[0].content.isNull);
    assert(keyValue.values[0].content.get == "_Z");
}

unittest
{
    import std.file : readText;

    const SDMXStructures structures = readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    assert(structures.categorySchemes.isNull);
    assert(!structures.codelists.isNull);
    assert(!structures.concepts.isNull);
    assert(!structures.dataStructures.isNull);
    assert(structures.dataflows.isNull);
    assert(structures.constraints.isNull);

    const SDMXCodelists codelists = structures.codelists.get;
    assert(codelists.codelists.length == 6);
    assert(codelists.codelists[0].id == "CL_FREQ");
    assert(codelists.codelists[0].agencyId == "ESTAT");
    assert(codelists.codelists[0].names.length == 1);
    assert(codelists.codelists[0].names[0] == SDMXName("en", "FREQ"));
    assert(codelists.codelists[0].codes.length == 7);
    assert(codelists.codelists[0].codes[0].id == "D");
    assert(codelists.codelists[0].codes[0].names.length == 1);
    assert(codelists.codelists[0].codes[0].names[0] == SDMXName("en", "Daily"));

    const SDMXConcepts concepts = structures.concepts.get;
    assert(concepts.conceptSchemes.length == 1);
    assert(concepts.conceptSchemes[0].id == "CS_DSD_nama_10_gdp");
    assert(concepts.conceptSchemes[0].agencyId == "ESTAT");
    assert(concepts.conceptSchemes[0].names.length == 1);
    assert(concepts.conceptSchemes[0].names[0] == SDMXName("en", "Concept Scheme for DSD_nama_10_gdp"));
    assert(concepts.conceptSchemes[0].concepts.length == 9);
    assert(concepts.conceptSchemes[0].concepts[0].id == "FREQ");
    assert(concepts.conceptSchemes[0].concepts[0].names.length == 1);
    assert(concepts.conceptSchemes[0].concepts[0].names[0] == SDMXName("en", "FREQ"));

    const SDMXDataStructures dataStructures = structures.dataStructures.get;
    assert(dataStructures.dataStructures.length == 1);

    const SDMXDataStructure dataStructure = dataStructures.dataStructures[0];
    assert(dataStructure.id == "DSD_nama_10_gdp");
    assert(dataStructure.agencyId == "ESTAT");
    assert(dataStructure.names.length == 1);
    assert(dataStructure.names[0] == SDMXName("en", "DSWS Data Structure Definition"));

    assert(dataStructure.dataStructureComponents.dimensionList.dimensions.length == 4);
    assert(dataStructure.dataStructureComponents.dimensionList.dimensions[0].id == "FREQ");
    assert(dataStructure.dataStructureComponents.dimensionList.dimensions[0].position == 1);
    assert(dataStructure.dataStructureComponents
        .dimensionList
        .dimensions[0]
        .conceptIdentity.get.ref_.id == "FREQ");
    assert(dataStructure.dataStructureComponents
        .dimensionList
        .dimensions[0]
        .localRepresentation.get.enumeration.get.ref_.id == "CL_FREQ");

    assert(dataStructure.dataStructureComponents.attributeList.attributes.length == 2);
    assert(dataStructure.dataStructureComponents.attributeList.attributes[0].id == "OBS_FLAG");
    assert(dataStructure.dataStructureComponents
        .attributeList
        .attributes[0]
        .conceptIdentity.get.ref_.id == "OBS_FLAG");
    assert(dataStructure.dataStructureComponents
        .attributeList
        .attributes[0]
        .localRepresentation.get.enumeration.get.ref_.id == "CL_OBS_FLAG");

    assert(dataStructure.dataStructureComponents.dimensionList.timeDimension.id == "TIME_PERIOD");
    assert(dataStructure.dataStructureComponents.dimensionList.timeDimension.position == 5);
    assert(dataStructure.dataStructureComponents
        .dimensionList
        .timeDimension
        .conceptIdentity.get.ref_.id == "TIME");
    assert(dataStructure.dataStructureComponents
        .dimensionList
        .timeDimension
        .localRepresentation.get.enumeration.isNull);

    assert(dataStructure.dataStructureComponents.measureList.primaryMeasure.id == "OBS_VALUE");
    assert(dataStructure
        .dataStructureComponents
        .measureList
        .primaryMeasure
        .conceptIdentity
        .get
        .ref_.id == "OBS_VALUE");

    assert(dataStructure.dataStructureComponents.group.isNull);
}

unittest
{
    import std.file : readText;

    const SDMXStructures structures = readText("./fixtures/sdmx/structure_category.xml")
        .deserializeAs!SDMXStructures;

    assert(!structures.categorySchemes.isNull);
    assert(structures.codelists.isNull);
    assert(structures.concepts.isNull);
    assert(structures.dataStructures.isNull);
    assert(structures.dataflows.isNull);
    assert(structures.constraints.isNull);

    const SDMXCategorySchemes categorySchemes = structures.categorySchemes.get;
    assert(categorySchemes.categorySchemes.length == 1);
    assert(categorySchemes.categorySchemes[0].categories[0].id == "ECO");
    assert(categorySchemes.categorySchemes[0].categories[0].names.length == 2);
    assert(categorySchemes
        .categorySchemes[0]
        .categories[0]
        .names[0] == SDMXName("fr", "Économie – Conjoncture – Comptes nationaux"));
}

alias ResourceRefPair = Tuple!(string, "resourceId", SDMXRef, "reference");
alias AgencyReferencePair = Tuple!(string, "agencyId", string, "referenceId");

private auto extractIdAndAgencyId(const SDMXRef ref_, const SDMXDataStructure structure)
{
    return ref_.agencyId.isNull
        ? AgencyReferencePair(structure.agencyId, ref_.id)
        : AgencyReferencePair(ref_.agencyId.get, ref_.id);
}

private auto gatherResourceRefs(T)(T resources) pure nothrow @safe
if(isInputRange!T && (is(ElementType!T: const(SDMXAttribute)) || is(ElementType!T: const(SDMXDimension))))
{
    return resources
        .filter!(d =>
            !d.localRepresentation.isNull
            && !d.localRepresentation.get.enumeration.isNull
            && !d.id.isNull)
        .map!(d => ResourceRefPair(d.id.get, d.localRepresentation.get.enumeration.get.ref_));
}

private auto gatherResourceConcept(T)(T resources) pure nothrow @safe
if(isInputRange!T &&
    (
        is(ElementType!T: const(SDMXAttribute))
        || is(ElementType!T: const(SDMXDimension))
        || is(ElementType!T: const(SDMXPrimaryMeasure))
        || is(ElementType!T: const(SDMXTimeDimension))
    )
)
{
    return resources
        .filter!(a => !a.id.isNull && !a.conceptIdentity.isNull)
        .map!(a => ResourceRefPair(a.id.get, a.conceptIdentity.get.ref_));
}

private auto gatherEnumerationRefs(const SDMXDataStructure structure) pure nothrow @safe
{
    auto fromDimensions = structure
        .dataStructureComponents.dimensionList.dimensions
            .gatherResourceRefs;

    auto fromAttributes = structure
        .dataStructureComponents.attributeList.attributes
            .gatherResourceRefs;

    return chain(fromDimensions, fromAttributes);
}

auto gatherCodelistIds(const SDMXDataStructures structures) pure nothrow @safe
{
    return structures.dataStructures
        .map!(ds => gatherEnumerationRefs(ds).map!(r => extractIdAndAgencyId(r.reference, ds)))
        .joiner
        .array;
}

auto gatherConceptIds(const SDMXDataStructures structures) pure nothrow @safe
{
    return structures.dataStructures
        .map!(ds =>
            ds.dataStructureComponents.dimensionList.dimensions
                .gatherResourceConcept
                .map!(d => extractIdAndAgencyId(d.reference, ds))
                .chain(
                    ds.dataStructureComponents.attributeList.attributes
                        .gatherResourceConcept
                        .map!(a => extractIdAndAgencyId(a.reference, ds))
                )
                .chain(
                    [ds.dataStructureComponents.measureList.primaryMeasure]
                        .gatherResourceConcept
                        .map!(m => extractIdAndAgencyId(m.reference, ds))
                )
                .chain(
                    [ds.dataStructureComponents.dimensionList.timeDimension]
                        .gatherResourceConcept
                        .map!(t => extractIdAndAgencyId(t.reference, ds))
                )
        )
        .joiner
        .array;
}

unittest
{
    import std.file : readText;

    const SDMXStructures structures = readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    const SDMXDataStructures dataStructures = structures.dataStructures.get;
    const conceptIds = gatherConceptIds(dataStructures);
    assert(conceptIds.length == 8);
    assert(conceptIds[0] == AgencyReferencePair("ESTAT", "FREQ"));

    const codelistIds = gatherCodelistIds(dataStructures);
    assert(codelistIds.length == 6);
    assert(codelistIds[0] == AgencyReferencePair("ESTAT", "CL_FREQ"));
}
