module vulpes.datasources.sdmxml21;

import std.typecons : Nullable, nullable, Tuple, apply;
import std.range : isInputRange, isRandomAccessRange, ElementType;
import vulpes.lib.xml;
import vulpes.core.providers;
import vulpes.core.cube;

package:

enum Unknown = "Unknown";

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

    @xmlElementList("Category")
    SDMXCategory[] children;
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

SDMXCategory[] flattenCategory(SDMXCategory category) pure nothrow @safe
{
    import std.range : chain;
    import std.algorithm : joiner, map;
    import std.array: array;

    return [category]
        .chain(category.children.map!(c => flattenCategory(c)).joiner)
        .array;
}

unittest
{
    import std.file : readText;
    auto message = readText("./fixtures/sdmx/structure_category.xml")
        .deserializeAs!SDMXCategorySchemes;
    auto category = message.categorySchemes[0].categories[0];
    auto categories = flattenCategory(category);
    assert(categories.length == 7);
}

SDMXCategory[][SDMXCategory] buildHierarchy(SDMXCategoryScheme categoryScheme)
{
    SDMXCategory[][SDMXCategory] path;

    void visit(SDMXCategory category)
    {
        import std.container : DList;

        DList!SDMXCategory queue;
        queue.insertFront(category);
        bool[SDMXCategory] visited = [category : true];

        while(!queue.empty)
        {
            auto c = queue.front;
            queue.removeFront;

            visited[c] = true;

            foreach(child; c.children)
            {
                if(!(child in visited))
                {
                    visited[child] = true;
                    queue.insertBack(child);
                    foreach(u; path.get(c, []))
                    {
                        path[child] ~= u;
                    }

                    path[child] ~= c;
                }
            }
        }
    }

    foreach(c; categoryScheme.categories)
    {
        visit(c);
    }
    return path;
}

unittest
{
    import std.file : readText;
    auto message = readText("./fixtures/sdmx/structure_category.xml");
    auto schemes = message.deserializeAs!SDMXCategorySchemes;
    auto h = buildHierarchy(schemes.categorySchemes[0]);
    import std.algorithm : map, equal, filter;

    auto c = message
        .deserializeAsRangeOf!SDMXCategory.filter!(c => c.id.get == "COMMERCE_GROS")
        .front;

    assert(equal(h[c].map!(a => a.id.get), ["SECT_ACT", "COMMERCE"]));
}

@xmlRoot("Source")
struct SDMXSource
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("Target")
struct SDMXTarget
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

@xmlRoot("Categorisation")
struct SDMXCategorisation
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

    @xmlElement("Source")
    SDMXSource source;

    @xmlElement("Target")
    SDMXTarget target;
}

@xmlRoot("Categorisations")
struct SDMXCategorisations
{
    @xmlElementList("Categorisation")
    SDMXCategorisation[] categorisations;
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

    @xmlElement("Categorisations")
    Nullable!SDMXCategorisations categorisations;

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
    Nullable!SDMXObsDimension obsDimension;

    @xmlElement("ObsValue")
    Nullable!SDMXObsValue obsValue;

    @xmlElement("Attributes")
    Nullable!SDMXAttributes attributes;

    @allAttr
    string[string] structureAttributes;
}

@xmlRoot("Series")
struct SDMXSeries
{
    @xmlElement("SeriesKey")
    Nullable!SDMXSeriesKey seriesKey;

    @xmlElement("Attributes")
    Nullable!SDMXAttributes attributes;

    @xmlElementList("Obs")
    SDMXObs[] observations;

    @allAttr
    string[string] structureKeys;
}

@xmlRoot("DataSet")
struct SDMXDataSet
{
    @attr("structureRef")
    Nullable!string structureRef;

    @xmlElementList("Series")
    SDMXSeries[] series;
}

unittest
{
    import std.file : readText;

    const structures = readText("./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    assert(structures.categorySchemes.isNull);
    assert(!structures.codelists.isNull);
    assert(!structures.concepts.isNull);
    assert(!structures.dataStructures.isNull);
    assert(!structures.dataflows.isNull);
    assert(!structures.constraints.isNull);

    const dataflows = structures.dataflows.get;
    assert(dataflows.dataflows.length == 1);

    const dataflow = dataflows.dataflows[0];
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

    const constraints = structures.constraints.get;
    assert(constraints.constraints.length == 1);

    const contentConstraint = constraints.constraints[0];
    assert(!contentConstraint.id.isNull);
    assert(contentConstraint.id.get == "01R_CONSTRAINT");
    assert(contentConstraint.names.length == 1);
    assert(contentConstraint.names[0] == SDMXName("en", "01R_CONSTRAINT"));
    assert(!contentConstraint.constraintAttachment.isNull);
    assert(!contentConstraint.constraintAttachment.get.dataflow.isNull);
    assert(contentConstraint.constraintAttachment.get.dataflow.get.ref_.get.id == "01R");
    assert(!contentConstraint.cubeRegion.isNull);

    const cubeRegion = contentConstraint.cubeRegion.get;
    assert(cubeRegion.keyValues.length == 2);

    const keyValue = cubeRegion.keyValues[0];
    assert(keyValue.id == "COUNTERPART_AREA");
    assert(keyValue.values.length == 1);
    assert(!keyValue.values[0].content.isNull);
    assert(keyValue.values[0].content.get == "_Z");
}

unittest
{
    import std.file : readText;

    const structures = readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    assert(structures.categorySchemes.isNull);
    assert(!structures.codelists.isNull);
    assert(!structures.concepts.isNull);
    assert(!structures.dataStructures.isNull);
    assert(structures.dataflows.isNull);
    assert(structures.constraints.isNull);

    const codelists = structures.codelists.get;
    assert(codelists.codelists.length == 6);
    assert(codelists.codelists[0].id == "CL_FREQ");
    assert(codelists.codelists[0].agencyId == "ESTAT");
    assert(codelists.codelists[0].names.length == 1);
    assert(codelists.codelists[0].names[0] == SDMXName("en", "FREQ"));
    assert(codelists.codelists[0].codes.length == 7);
    assert(codelists.codelists[0].codes[0].id == "D");
    assert(codelists.codelists[0].codes[0].names.length == 1);
    assert(codelists.codelists[0].codes[0].names[0] == SDMXName("en", "Daily"));

    const concepts = structures.concepts.get;
    assert(concepts.conceptSchemes.length == 1);
    assert(concepts.conceptSchemes[0].id == "CS_DSD_nama_10_gdp");
    assert(concepts.conceptSchemes[0].agencyId == "ESTAT");
    assert(concepts.conceptSchemes[0].names.length == 1);
    assert(concepts.conceptSchemes[0].names[0] == SDMXName("en", "Concept Scheme for DSD_nama_10_gdp"));
    assert(concepts.conceptSchemes[0].concepts.length == 9);
    assert(concepts.conceptSchemes[0].concepts[0].id == "FREQ");
    assert(concepts.conceptSchemes[0].concepts[0].names.length == 1);
    assert(concepts.conceptSchemes[0].concepts[0].names[0] == SDMXName("en", "FREQ"));

    const dataStructures = structures.dataStructures.get;
    assert(dataStructures.dataStructures.length == 1);

    const dataStructure = dataStructures.dataStructures[0];
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

    const structures = readText("./fixtures/sdmx/structure_category.xml")
        .deserializeAs!SDMXStructures;

    assert(!structures.categorySchemes.isNull);
    assert(structures.codelists.isNull);
    assert(structures.concepts.isNull);
    assert(structures.dataStructures.isNull);
    assert(structures.dataflows.isNull);
    assert(structures.constraints.isNull);

    const categorySchemes = structures.categorySchemes.get;
    assert(categorySchemes.categorySchemes.length == 1);
    assert(categorySchemes.categorySchemes[0].categories[0].id == "ECO");
    assert(categorySchemes.categorySchemes[0].categories[0].names.length == 2);
    assert(categorySchemes
        .categorySchemes[0]
        .categories[0]
        .names[0] == SDMXName("fr", "Économie – Conjoncture – Comptes nationaux"));
    assert(categorySchemes.categorySchemes[0].categories[0].children.length == 6);
}

unittest
{
    import std.file : readText;

    const structures = readText("./fixtures/sdmx/structure_dataflow_categorisation.xml")
        .deserializeAs!SDMXStructures;

    assert(structures.categorySchemes.isNull);
    assert(structures.codelists.isNull);
    assert(structures.concepts.isNull);
    assert(structures.dataStructures.isNull);
    assert(!structures.dataflows.isNull);
    assert(structures.constraints.isNull);
    assert(!structures.categorisations.isNull);

    const categorisations = structures.categorisations.get;
    assert(categorisations.categorisations.length == 1);
    assert(categorisations.categorisations[0].names.length == 2);
    assert(categorisations.categorisations[0].source.ref_.id == "BALANCE-PAIEMENTS");
    assert(categorisations.categorisations[0].target.ref_.id == "COMMERCE_EXT");
}

unittest
{
    import std.file : readText;
    import std.typecons : nullable;

    const dataset = readText("./fixtures/sdmx/data_generic.xml")
        .deserializeAs!SDMXDataSet;

    assert(!dataset.structureRef.isNull);
    assert(dataset.series.length == 3);
    assert(dataset.series[0].seriesKey.get.values.length == 10);
    assert(dataset.series[0].seriesKey.get.values[0] == SDMXValue("BASIND".nullable, "SO".nullable));
    assert(dataset.series[0].attributes.get.values.length == 5);
    assert(dataset.series[0].attributes.get.values[0] == SDMXValue("IDBANK".nullable, "001694113".nullable));
    assert(dataset.series[0].observations.length == 10);
    assert(dataset.series[0].observations[0].obsDimension.get.value == "2020-10");
    assert(dataset.series[0].observations[0].obsValue.get.value.get == 4027.0);
    assert(!dataset.series[0].observations[0].attributes.isNull);
    assert(dataset.series[0].observations[0].attributes.get.values.length == 3);
    assert(dataset.series[0].observations[0].attributes.get.values[0] == SDMXValue(
        "OBS_STATUS".nullable, "A".nullable));
}

unittest
{
    import std.file : readText;
    import std.typecons : nullable;

    const dataset = readText("./fixtures/sdmx/data_specific.xml")
        .deserializeAs!SDMXDataSet;

    assert(dataset.structureRef.isNull);
    assert(dataset.series);
    assert(dataset.series[0].seriesKey.isNull);
    assert(dataset.series[0].attributes.isNull);
    assert(dataset.series[0].structureKeys["FREQ"] == "A");
    assert(!dataset.series[0].observations);
    assert(dataset.series[2].observations);
    assert(dataset.series[2].observations[0].structureAttributes["TIME_PERIOD"] == "2019");
    assert(dataset.series[2].observations[0].obsDimension.isNull);
    assert(dataset.series[2].observations[0].attributes.isNull);
    assert(dataset.series[2].observations[0].obsValue.isNull);
}

auto toLabel(in SDMXName name) pure nothrow @safe
{
    return Label(name.lang, name.content, (Nullable!string).init);
}

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
    all = "all"
}

enum References = "references";
enum Details = "details";
enum DefaultResourceId = "all";
enum DefaultVersion = "latest";
enum ResourceType = "resourceType";
enum ProviderId = "providerId";
enum ResourceId = "resourceId";
enum Version = "version";

string[string] defaultStructureHeaders;

static this()
{
    defaultStructureHeaders = [
        "Accept": "application/vnd.sdmx.structure+xml;version=2.1",
        "Accept-Encoding": "gzip"
    ];
}

struct StructureRequestConfig
{
    Provider provider;
    bool mandatory;
    StructureType type;
    string[string] params = null;
    string resourceId = null;
    string version_ = null;
    string resourceProviderId = null;
}

T fetchStructure(alias fetch, T)(in StructureRequestConfig cfg)
{
    import vulpes.errors : NotImplemented;
    import vulpes.core.operations : mergeAA;
    import vulpes.lib.requests : resolveRequestTemplate;
    import std.exception : enforce;
    import std.format : format;

    enforce!NotImplemented(!cfg.provider.resources.isNull && cfg.type in cfg.provider.resources.get,
                            format!"%s not supported by provider %s"(cfg.type, cfg.provider.id));
    const resourceCfg = cfg.provider.resources.get[cfg.type];
    auto pathParams = [
        ResourceType: cfg.type,
        ProviderId: (cfg.resourceProviderId is null) ? cfg.provider.id : cfg.resourceProviderId,
        ResourceId: (cfg.resourceId is null) ? DefaultResourceId : cfg.resourceId,
        Version: (cfg.version_ is null) ? DefaultVersion : cfg.version_
    ];
    auto url = cfg.provider.rootUrl ~ resolveRequestTemplate(resourceCfg.pathTemplate, pathParams);

    auto query = resourceCfg.queryTemplate.isNull
        ? cast(string[string]) cfg.params
        // : resolveRequestTemplate(resourceCfg.queryTemplate.get, null)
        //     .mergeAAParams(cfg.params);
        : resolveRequestTemplate(cfg.params, null)
            .mergeAA(resourceCfg.queryTemplate.get);

    auto headers = resourceCfg.headerTemplate.isNull
        ? defaultStructureHeaders
        : resolveRequestTemplate(resourceCfg.headerTemplate.get.dup, null)
            .mergeAA(defaultStructureHeaders);

    return fetch(url, headers, query);
}

string[StructureType] fetchMessages(alias fetch)(in StructureRequestConfig[] cfgs)
{
    import vibe.core.concurrency : Future;
    import vulpes.lib.requests : getResultOrFail, getResultOrNullable;

    alias F = Future!string;

    string[StructureType] result;
    F[StructureType] mandFutures;
    F[StructureType] optFutures;
    foreach(c; cfgs)
    {
        if(c.mandatory)
            mandFutures[c.type] = fetchStructure!(fetch, F)(c);
        else
        {
            if(hasResource(c.provider, c.type))
                optFutures[c.type] = fetchStructure!(fetch, F)(c);
        }
    }

    foreach(k, v; optFutures)
    {
        auto r = getResultOrNullable(v);
        if(!r.isNull)
            result[k] = r.get;
    }

    foreach(k, v; mandFutures)
        result[k] = getResultOrFail(v);

    return result;
}

unittest
{
    import std.exception : assertThrown;
    import vibe.core.concurrency : async;
    import vulpes.errors : NotImplemented;

    auto fetcher(string u, string[string] h, string[string] q)
    {
        return async({return "message";});
    }

    auto supportedP = Provider(
        "id",
        true,
        "http://localhost:8080",
        Format.sdmxml21.nullable,
        [
            "categorisation":  Resource("/{resourceType}/{providerId}/{resourceId}/{version}",
                (Nullable!(string[string])).init,
                ["Accept": "text/plain"].nullable),
            "categoryscheme": Resource("/{resourceType}/{providerId}/{resourceId}/{version}",
                (Nullable!(string[string])).init,
                ["Accept": "text/plain"].nullable)].nullable);

    auto unsupportedP = Provider(
        "id",
        true,
        "http://localhost:8080",
        Format.sdmxml21.nullable,
        ["categorisation":  Resource("/{resourceType}/{providerId}/{resourceId}/{version}",
                (Nullable!(string[string])).init,
                ["Accept": "text/plain"].nullable)].nullable);

    auto messages = fetchMessages!fetcher([
        StructureRequestConfig(supportedP, true, StructureType.categorisation),
        StructureRequestConfig(supportedP, true, StructureType.categoryscheme)
    ]);
    assert(StructureType.categorisation in messages);
    assert(StructureType.categoryscheme in messages);

    messages = fetchMessages!fetcher([
        StructureRequestConfig(supportedP, false, StructureType.categorisation),
        StructureRequestConfig(supportedP, false, StructureType.categoryscheme)
    ]);
    assert(StructureType.categorisation in messages);
    assert(StructureType.categoryscheme in messages);

    messages = fetchMessages!fetcher([
        StructureRequestConfig(unsupportedP, true, StructureType.categorisation),
        StructureRequestConfig(unsupportedP, false, StructureType.categoryscheme)
    ]);
    assert(StructureType.categorisation in messages);
    assert(StructureType.categoryscheme !in messages);

    assertThrown!NotImplemented(fetchMessages!fetcher([
        StructureRequestConfig(unsupportedP, true, StructureType.categorisation),
        StructureRequestConfig(unsupportedP, true, StructureType.categoryscheme)
    ]));

}

auto fetchTags(alias fetch)(in Provider provider)
{
    with(StructureType)
    {
        return fetchMessages!fetch([
            const(StructureRequestConfig)(provider, true, categoryscheme),
            const(StructureRequestConfig)(provider, true, categorisation)
        ]);
    }
}

auto buildTagId(in string parentResourceId, in string resourceId) pure nothrow @safe
{
    return parentResourceId ~ "." ~ resourceId;
}

auto transformCategories(R1, R2)(R1 categorisations, R2 categorySchemes)
if(is(ElementType!R1 == SDMXCategorisation) &&
   is(ElementType!R2 == SDMXCategoryScheme) &&
   isRandomAccessRange!R1 &&
   isInputRange!R2)
{
    import std.algorithm : map, filter, joiner, sort;
    import std.typecons : tuple;
    import std.array : assocArray, array;
    import vulpes.core.operations : groupby;

    alias toTuple = (c) => tuple(c.target.ref_.maintainableParentId.get, c.target.ref_.id);

    auto categorisationIdx = categorisations
        .filter!(c => !c.target.ref_.maintainableParentId.isNull)
        .array
        .sort!((a, b) => toTuple(a) < toTuple(b))
        .groupby!(c => toTuple(c))
        .assocArray;

    alias RT = Tuple!(
        string, "categorySchemeId",
        SDMXCategory, "category",
        SDMXCategory[], "parentCategories"
    );

    return categorySchemes
        .filter!(s => !s.id.isNull)
        .map!((s) {
            auto hierarchy = buildHierarchy(s);
            return s.categories
                .map!flattenCategory
                .joiner
                .filter!(c => !c.id.isNull)
                .filter!(c => tuple(s.id.get, c.id.get) in categorisationIdx)
                .map!(c => RT(s.id.get, c, hierarchy.get(c, [])));
        })
        .joiner;
}

unittest
{
    import std.file : readText;
    import std.algorithm : filter, equal, map, uniq, sort;
    import std.array : array;
    import std.range : walkLength;
    auto msg = readText("./fixtures/sdmx/structure_category_categorisation.xml");
    auto structures = msg.deserializeAs!SDMXStructures;
    auto r = transformCategories(structures.categorisations.get.categorisations,
                                 structures.categorySchemes.get.categorySchemes);
    assert(!r.empty);

    auto i = "CARAC_COMMERCE";
    auto c = r.filter!(a => a.category.id.get == i).front;
    assert(c.categorySchemeId == "CLASSEMENT_DATAFLOWS");
    assert(c.category.id == i);
    assert(equal(c.parentCategories.map!(a => a.id), ["SECT_ACT", "COMMERCE"]));

    auto allCategoryIds = r.map!(t => t.category.id.get).array;
    assert(allCategoryIds.filter!(a => a == "CONJ").walkLength == 1);
    assert(allCategoryIds.length == allCategoryIds.sort.uniq.walkLength);
}

auto buildTags(in string[StructureType] messages)
{
    import std.algorithm : joiner, map, filter;
    import std.array : array, join;
    import std.range : tee, chain;

    assert(StructureType.categorisation in messages);
    assert(StructureType.categoryscheme in messages);

    auto categorisations = messages[StructureType.categorisation].deserializeAs!SDMXCategorisations;
    auto categorySchemes = messages[StructureType.categoryscheme].deserializeAs!SDMXCategorySchemes;

    bool[string] buffer;

    return transformCategories(categorisations.categorisations, categorySchemes.categorySchemes)
        .map!((t) {
            auto current = Tag(buildTagId(t.categorySchemeId, t.category.id.get),t.category.names.map!toLabel.array);
            auto parents = t.parentCategories
                    .map!(a => Tag(buildTagId(t.categorySchemeId, a.id.get), a.names.map!toLabel.array))
                    .array;
            return [current].chain(parents);
        })
        .joiner
        .filter!(t => t.id !in buffer)
        .tee!(t => buffer[t.id] = true);
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.algorithm : filter, sort, uniq, map;
    import std.array : array;

    auto messages = [
        StructureType.categorisation : readText("./fixtures/sdmx/structure_category_categorisation.xml"),
        StructureType.categoryscheme : readText("./fixtures/sdmx/structure_category_categorisation.xml")
    ];
    auto tags = buildTags(messages).array;
    assert(tags.length > 0);

    auto i = "CLASSEMENT_DATAFLOWS.CARAC_ENTRP";

    auto cat = tags.filter!(t => t.id == i);
    assert(!cat.empty);
    assert(cat.front.id == i);
    assert(cat.front.labels[0].language == "fr");
    assert(cat.front.labels[0].shortName == "Caractéristiques des entreprises");
    assert(cat.front.labels[1].language == "en");
    assert(cat.front.labels[1].shortName == "Characteristics of enterprises");

    assert(tags.filter!(t => t.id == "CLASSEMENT_DATAFLOWS.SECT_ACT").walkLength == 1);

    auto allIds = tags.map!(t => t.id).array;
    assert(allIds.length == allIds.sort.uniq.walkLength);
}

auto fetchDescriptions(alias fetch)(in Provider provider)
{
    with(StructureType)
    {
        return fetchMessages!fetch([
            const(StructureRequestConfig)(provider, true, dataflow),
            const(StructureRequestConfig)(provider, false, categoryscheme)
        ]);
    }
}

auto buildDescriptions(in string[StructureType] messages)
{
    assert(StructureType.dataflow in messages);

    import std.algorithm : map, filter, joiner, sort;
    import std.array : array, assocArray;
    import std.range : tee, chain;
    import vulpes.core.operations : groupby, index;
    import vibe.core.log : logDebug;

    logDebug("Build cube descriptions list");
    auto sDataflow = messages[StructureType.dataflow].deserializeAs!SDMXStructures;
    logDebug("Dataflows deserialized");

    auto sCategoryScheme = (StructureType.categoryscheme in messages)
        ? messages[StructureType.categoryscheme].deserializeAs!SDMXStructures
        : SDMXStructures();
    logDebug("CategorySchme deserialized");

    auto dataflows = (sDataflow.dataflows.isNull)
        ? []
        : sDataflow.dataflows.get.dataflows;

    auto categorisations = (sDataflow.categorisations.isNull)
        ? (
            (!sCategoryScheme.categorisations.isNull)
                ? sCategoryScheme.categorisations.get.categorisations
                : []
        )
        : sDataflow.categorisations.get.categorisations;

    auto categorisationIdx = (categorisations.length == 0)
        ? null
        : categorisations
            .filter!(c => !c.target.ref_.maintainableParentId.isNull)
            .array
            .sort!((a, b) => a.source.ref_.id < b.source.ref_.id)
            .groupby!(c => c.source.ref_.id)
            .assocArray;
    logDebug("Categorisations aggregated");

    auto makeCubeDescription(SDMXDataflow df, string[] tagIds)
    {
        return CubeDescription(df.agencyId.get(Unknown),
                               df.id.get,
                               df.names.map!toLabel.array,
                               df.structure.get.ref_.id,
                               df.structure.get.ref_.agencyId.get(Unknown),
                               tagIds);
    }

    auto categories = (!sCategoryScheme.categorySchemes.isNull)
        ? transformCategories(categorisations,
                              sCategoryScheme.categorySchemes.get.categorySchemes)
            .filter!(c => !c.category.id.isNull)
            .index!(c => c.category.id.get)
            .assocArray
        : null;
    logDebug("Categories indexed");

    return dataflows
        .filter!(d => !d.id.isNull && !d.structure.isNull)
        .map!((df) {
            if(categorisationIdx is null || !(df.id.get in categorisationIdx))
                return makeCubeDescription(df, []);

            if(categories is null)
            {
                auto currentTagIds = categorisationIdx[df.id.get]
                    .map!(cat => buildTagId(cat.target.ref_.maintainableParentId.get,
                                            cat.target.ref_.id));
                return makeCubeDescription(df, currentTagIds.array);
            }

            bool[string] buffer;

            auto currentTagIds = categorisationIdx[df.id.get]
                .map!((cat) {
                    auto currentTagId = buildTagId(cat.target.ref_.maintainableParentId.get,
                                                   cat.target.ref_.id);

                    auto parentCategories = (cat.target.ref_.id) in categories
                        ? categories[cat.target.ref_.id].parentCategories
                        : [];

                    auto parentIds = parentCategories
                        .filter!(c => !c.id.isNull)
                        .map!(c => buildTagId(categories[cat.target.ref_.id].categorySchemeId, c.id.get));

                    return [currentTagId].chain(parentIds);
                })
                .joiner
                .filter!(t => t !in buffer)
                .tee!(t => buffer[t] = true);

            return makeCubeDescription(df, currentTagIds.array);
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
    assert(descriptions.front.tagIds[0] == "CLASSEMENT_DATAFLOWS.COMMERCE_EXT");

    import std.algorithm : all;
    assert(descriptions.all!"a.id.length > 0");
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

    import std.algorithm : all;
    assert(descriptions.all!"a.id.length > 0");
}

unittest
{
    import std.file : readText;
    import std.algorithm : equal;
    auto messages = [
        StructureType.dataflow : readText("./fixtures/sdmx/structure_dataflow_categorisation.xml"),
        StructureType.categoryscheme : readText("./fixtures/sdmx/structure_category_categorisation.xml")
    ];
    auto descriptions = buildDescriptions(messages);
    assert(!descriptions.empty);
    assert(descriptions.front.id == "BALANCE-PAIEMENTS");
    assert(descriptions.front.providerId == "FR1");
    assert(descriptions.front.labels.length == 2);
    assert(descriptions.front.labels[0].language == "fr");
    assert(descriptions.front.labels[0].shortName == "Balance des paiements");
    assert(descriptions.front.definitionId == "BALANCE-PAIEMENTS");
    assert(descriptions.front.definitionProviderId == "FR1");
    assert(descriptions.front.tagIds.length == 2);
    assert(equal(descriptions.front.tagIds, ["CLASSEMENT_DATAFLOWS.COMMERCE_EXT", "CLASSEMENT_DATAFLOWS.ECO"]));
}

auto fetchDefinition(alias fetch)(in Provider provider, in string resourceId)
{
    import vulpes.lib.xml : deserializeAsRangeOf;
    with(StructureType)
    {
        auto msg = fetchMessages!fetch([
            const(StructureRequestConfig)(provider, false, dataflow, null, resourceId, null, null)
        ]);

        string dsdAgencyId = provider.id;
        string dsdId = resourceId;
        if(dataflow in msg)
        {
            auto dfs = msg[dataflow].deserializeAsRangeOf!SDMXDataflow;
            if(!dfs.empty)
            {
                if(!dfs.front.structure.isNull)
                {
                    dsdAgencyId = dfs.front.structure.get.ref_.agencyId.get(dsdAgencyId);
                    dsdId = dfs.front.structure.get.ref_.id;
                }
            }
        }

        return fetchMessages!fetch([
            const(StructureRequestConfig)(provider, true, datastructure, null, dsdId, null, dsdAgencyId)
        ]);
    }
}

Nullable!CubeDefinition buildDefinition(in string[StructureType] messages)
{
    import std.array : array, assocArray;
    import std.algorithm : map, joiner;
    import std.range : chain;
    import std.conv : to;
    import vulpes.core.operations : index;
    assert(StructureType.datastructure in messages);

    SDMXStructures sDsd = messages[StructureType.datastructure].deserializeAs!SDMXStructures;
    if(sDsd.dataStructures.isNull)
        return typeof(return).init;

    auto dsd = sDsd.dataStructures.get.dataStructures[0];
    auto cs = sDsd.concepts.isNull
        ? (StructureType.conceptscheme in messages)
            ? messages[StructureType.conceptscheme].deserializeAsRangeOf!SDMXConceptScheme.array
            : []
        : sDsd.concepts.get.conceptSchemes;

    auto conceptIdx = cs
        .map!(c => c.concepts)
        .joiner
        .index!(c => c.id)
        .assocArray;

    Nullable!Concept getConcept(T)(T resource)
    {
        if(resource.conceptIdentity.isNull)
            return typeof(return).init;

        auto conceptId = resource.conceptIdentity.get.ref_.id;

        if(conceptId !in conceptIdx)
            return typeof(return).init;

        auto concept = conceptIdx[conceptId];

        return Concept(concept.id, concept.names.map!toLabel.array).nullable;
    }

    auto getCodelist(T)(T resource)
    {
        return resource
            .localRepresentation
            .apply!(lr => lr.enumeration)
            .apply!(e => e.ref_);
    }

    auto dimensions = dsd.dataStructureComponents.dimensionList.dimensions
        .map!((d) => Dimension(d.id,
                               false,
                               false,
                               getConcept(d),
                               getCodelist(d).apply!(c => c.id),
                               getCodelist(d).apply!(c => c.agencyId)));
    auto timeDimension = [dsd.dataStructureComponents.dimensionList.timeDimension]
        .map!((td) => Dimension(td.id,
                                true,
                                true,
                                getConcept(td),
                                (Nullable!string).init,
                                (Nullable!string).init));
    auto attributes = dsd.dataStructureComponents.attributeList.attributes
        .map!((a) => Attribute(a.id,
                               getConcept(a),
                               getCodelist(a).apply!(c => c.id),
                               getCodelist(a).apply!(c => c.agencyId)));
    auto measures = [dsd.dataStructureComponents.measureList.primaryMeasure]
        .map!((m) => Measure(m.id, getConcept(m)));

    return CubeDefinition(dsd.agencyId,
                          dsd.id,
                          dimensions.chain(timeDimension).array,
                          attributes.array,
                          measures.array).nullable;
}

unittest
{
    import std.file : readText;
    import std.algorithm : canFind, map, all;
    auto messages = [StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd.xml")];
    auto def = buildDefinition(messages);
    assert(!def.isNull);
    assert(def.get.id == "BALANCE-PAIEMENTS");
    assert(def.get.providerId == "FR1");
    assert(def.get.dimensions[0].id == "FREQ");
    assert(!def.get.dimensions[0].obsDimension);
    assert(!def.get.dimensions[0].timeDimension);
    assert(def.get.dimensions[0].concept.isNull);
    assert(def.get.dimensions[0].codelistId.get == "CL_PERIODICITE");
    assert(def.get.dimensions[0].codelistProviderId.get == "FR1");
    assert(def.get.dimensions[1].id == "TIME_PERIOD");
    assert(def.get.dimensions[1].obsDimension);
    assert(def.get.dimensions[1].timeDimension);
    assert(def.get.dimensions[1].codelistId.isNull);
    assert(def.get.dimensions[1].codelistProviderId.isNull);
    assert(def.get.attributes.all!(a => ["UNIT_MULT", "IDBANK"].canFind(a.id.get)));
    assert(def.get.attributes.all!(a => a.concept.isNull));
    assert(def.get.attributes.all!(a => a.codelistId.isNull && a.codelistProviderId.isNull));
    assert(def.get.measures.length == 1);
    assert(def.get.measures[0].id.get == "OBS_VALUE");
    assert(def.get.measures[0].concept.isNull);
}

unittest
{
    import std.file : readText;
    import std.algorithm : any, map;
    auto messages = [
        StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd.xml"),
        StructureType.conceptscheme: readText("./fixtures/sdmx/structure_conceptscheme.xml")
    ];
    auto def = buildDefinition(messages).get;
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
    auto def = buildDefinition(messages).get;
    assert(def.dimensions.map!(d => d.id).equal(["FREQ", "UNIT", "NA_ITEM", "GEO", "TIME_PERIOD"]));
    assert(def.dimensions[0].concept.get.id == "FREQ");
    assert(def.dimensions[4].concept.get.id == "TIME");
    assert(def.attributes.all!(a => !a.concept.isNull));
    assert(def.attributes.all!(a => !a.codelistId.isNull && !a.codelistProviderId.isNull));
    assert(!def.measures[0].concept.isNull);
}

import vulpes.core.cube : CubeResourceType;

auto fetchCodes(alias fetch, CubeResourceType type)(in Provider provider, in string cubeId, in string resourceId)
if(type == CubeResourceType.dimension || type == CubeResourceType.attribute)
{
    import vulpes.lib.xml : deserializeAsRangeOf;
    import vulpes.core.operations : mergeAA;
    import vulpes.core.providers : hasResource;
    import std.algorithm : filter, map;

    alias RT = Tuple!(string[StructureType], string, string);

    with(StructureType)
    {
        auto dfMsg = fetchMessages!fetch([
            const(StructureRequestConfig)(
                provider, false, dataflow, [References: contentconstraint], cubeId, null, null)
        ]);

        string agencyCodelistId = provider.id;
        string codelistId = resourceId;
        if(dataflow in dfMsg)
        {
            auto dfs = dfMsg[dataflow].deserializeAsRangeOf!SDMXDataflow;

            if(!dfs.empty)
            {
                string dsdId = cubeId;
                string dsdAgencyId = provider.id;

                if(!dfs.front.structure.isNull)
                {
                    dsdId = dfs.front.structure.get.ref_.id;
                    dsdAgencyId = dfs.front.structure.get.ref_.agencyId.get(dsdAgencyId);
                }

                auto dsdMsg = fetchMessages!fetch([
                    const(StructureRequestConfig)(
                        provider, false, datastructure, [References: contentconstraint], dsdId, null, dsdAgencyId)
                ]);

                if(datastructure in dsdMsg)
                {

                    static if(type == CubeResourceType.dimension)
                    {
                        auto refs = dsdMsg[datastructure].deserializeAsRangeOf!SDMXDimension
                            .filter!(d => d.id == resourceId)
                            .filter!(d => !d.localRepresentation.isNull)
                            .filter!(d => !d.localRepresentation.get.enumeration.isNull)
                            .map!(d => d.localRepresentation.get.enumeration.get.ref_);
                    }
                    else
                    {
                        auto refs = dsdMsg[datastructure].deserializeAsRangeOf!SDMXAttribute
                            .filter!(a => !a.id.isNull)
                            .filter!(a => a.id.get == resourceId)
                            .filter!(a => !a.localRepresentation.isNull)
                            .filter!(a => !a.localRepresentation.get.enumeration.isNull)
                            .map!(a => a.localRepresentation.get.enumeration.get.ref_);
                    }

                    if(!refs.empty)
                    {
                        codelistId = refs.front.id;
                        agencyCodelistId = refs.front.agencyId.get(agencyCodelistId);
                    }

                    if(!hasResource(provider, codelist)) return RT(dsdMsg, resourceId, codelistId);
                }
            }

        }

        auto clMsg = fetchMessages!fetch([
            const(StructureRequestConfig)(provider, true, codelist, null, codelistId, null, agencyCodelistId)
        ]);

        return RT(clMsg.mergeAA(dfMsg), resourceId, codelistId);
    }
}

auto buildCodes(in Tuple!(string[StructureType], string, string) t)
{
    import std.array : array, assocArray;
    import std.algorithm : filter, map, joiner;
    import std.format : format;
    import std.exception : enforce;
    import vibe.core.log : logDebug;
    import vulpes.core.operations : index;
    import vulpes.errors : NotFound;

    auto messages = t[0]; auto resourceId = t[1]; auto codelistId = t[2];

    assert(StructureType.codelist in messages ||StructureType.datastructure in messages);

    auto codelist = messages.get(StructureType.codelist, messages[StructureType.datastructure])
        .deserializeAsRangeOf!SDMXCodelist
        .filter!(cl => cl.id == codelistId);

    enforce!NotFound(!codelist.empty, format!"Cannot find list of codes for resource %s"(resourceId));

    auto constraintIdx = (StructureType.dataflow in messages)
        ? messages[StructureType.dataflow]
            .deserializeAsRangeOf!SDMXKeyValue
            .filter!(kv => kv.id == resourceId)
            .map!(kv => kv.values)
            .joiner
            .filter!(v => !v.content.isNull)
            .map!(v => v.content.get)
            .index!(v => v)
            .assocArray
        : null;

    if(constraintIdx is null)
        logDebug("No contraint will be applied");

    return codelist.front.codes
        .filter!(c => (constraintIdx !is null && c.id in constraintIdx) || constraintIdx is null)
        .map!(c => Code(c.id, c.names.map!toLabel.array));
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.typecons : tuple;

    auto messages = [
        StructureType.codelist : readText(
            "./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml"),
        StructureType.dataflow : readText(
            "./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")];
    auto codes = buildCodes(tuple(messages, "DATA_DOMAIN", "CL_DATADOMAIN"));
    assert(!codes.empty);
    assert(codes.walkLength == 1);
    assert(codes.front.id == "01R");
    assert(codes.front.labels.length);
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.typecons : tuple;

    auto messages = [StructureType.codelist : readText("./fixtures/sdmx/structure_codelist.xml")];
    auto codes = buildCodes(tuple(messages, "FREQ", "CL_PERIODICITE"));
    assert(!codes.empty);
    assert(codes.walkLength == 5);
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    import std.typecons : tuple;

    auto messages = [
        StructureType.datastructure : readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
    ];
    auto codes = buildCodes(tuple(messages, "FREQ", "CL_FREQ"));
    assert(!codes.empty);
    assert(codes.walkLength == 7);
}
