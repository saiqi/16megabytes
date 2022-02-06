module vulpes.datasources.sdmx.xml21;

import std.typecons : Nullable, nullable;
import std.traits : ReturnType;
import vulpes.lib.xml;
import vulpes.core.model : Dataflow, Language, DefaultVersion, Urn;
import vulpes.datasources.sdmx.common : getIntlLabels, getLabel;

package:

@xmlRoot("Text")
struct SDMX21Text
{
    @text
    Nullable!string content;
}

@xmlRoot("ErrorMessage")
struct SDMX21ErrorMessage
{
    @attr("code")
    Nullable!string code;

    @xmlElement("Text")
    Nullable!SDMX21Text text_;

}

@xmlRoot("Error")
struct SDMX21Error_
{
    @xmlElement("ErrorMessage")
    Nullable!SDMX21ErrorMessage errorMessage;
}

@xmlRoot("Dataflow")
struct SDMX21Dataflow
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElement("Structure")
    Nullable!SDMX21Structure structure;

    @xmlElement("Ref")
    Nullable!SDMX21Ref ref_;

    Nullable!Dataflow coreResource() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        if(id.isNull || agencyId.isNull || structure.isNull || structure.get.ref_.urn.isNull)
            return typeof(return).init;

        auto structureUrn = structure.get.ref_.urn.get;

        auto cNames = names.dup;
        auto cDescriptions = descriptions.dup;

        auto name = getLabel(cNames);

        if(name.isNull)
            return typeof(return).init;

        return Dataflow(
            id.get,
            version_.get(DefaultVersion),
            agencyId.get,
            true,
            isFinal.get(true),
            name.get,
            getIntlLabels(cNames),
            getLabel(cDescriptions),
            getIntlLabels(cDescriptions),
            structureUrn.toString
        ).nullable;
    }
}

unittest
{
    import std.file : readText;
    const xmlStr = readText("fixtures/sdmx21/structure_dataflow.xml");
    const sdmxDf = xmlStr.deserializeAs!SDMX21Structures.dataflows.get.dataflows[0];
    const df = sdmxDf.coreResource();
    assert(!df.isNull);
    assert(df.get.id == "BALANCE-PAIEMENTS");
    assert(df.get.version_ == "1.0");
    assert(df.get.agencyId == "FR1");
    assert(df.get.name == "Balance of payments");
    assert(df.get.names.get[Language.fr] == "Balance des paiements");
    assert(df.get.description.isNull);
    assert(df.get.descriptions.isNull);
    assert(df.get.structure == sdmxDf.structure.get.ref_.urn.toString);
}

@xmlRoot("Name")
struct SDMX21Name
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Description")
struct SDMX21Description
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Structure")
struct SDMX21Structure
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("Ref")
struct SDMX21Ref
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

    inout(Nullable!Urn) urn() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        import std.conv : to;
        import vulpes.core.model : PackageType, ClassType;

        if(package_.isNull || class_.isNull || version_.isNull || agencyId.isNull)
            return typeof(return).init;

        Nullable!Urn urn = Urn(package_.get.to!PackageType, class_.get.to!ClassType, agencyId.get, id, version_.get);
        return urn;
    }
}

unittest
{
    assert(SDMX21Ref().urn.isNull);
    const ref_ = SDMX21Ref(
        "FOO",
        "1.0".nullable,
        (Nullable!string).init,
        (Nullable!string).init,
        "BAR".nullable,
        "datastructure".nullable,
        "DataStructure".nullable
    );
    const expected = "urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=BAR:FOO(1.0)";
    assert(ref_.urn.get.toString == expected);
}

@xmlRoot("ConceptIdentity")
struct SDMX21ConceptIdentity
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("TextFormat")
struct SDMX21TextFormat
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
struct SDMX21Enumeration
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("LocalRepresentation")
struct SDMX21LocalRepresentation
{
    @xmlElement("TextFormat")
    Nullable!SDMX21TextFormat textFormat;

    @xmlElement("Enumeration")
    Nullable!SDMX21Enumeration enumeration;
}

@xmlRoot("TimeDimension")
struct SDMX21TimeDimension
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("position")
    Nullable!int position;

    @xmlElement("ConceptIdentity")
    Nullable!SDMX21ConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMX21LocalRepresentation localRepresentation;
}

@xmlRoot("Dimension")
struct SDMX21Dimension
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("position")
    Nullable!int position;

    @xmlElement("ConceptIdentity")
    Nullable!SDMX21ConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMX21LocalRepresentation localRepresentation;

    @xmlElement("Ref")
    Nullable!SDMX21Ref ref_;
}

@xmlRoot("DimensionList")
struct SDMX21DimensionList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("TimeDimension")
    SDMX21TimeDimension timeDimension;

    @xmlElementList("Dimension")
    SDMX21Dimension[] dimensions;
}

@xmlRoot("AttributeRelationship")
struct SDMX21AttributeRelationship
{
    @xmlElementList("Dimension")
    SDMX21Dimension[] dimensions;

    @xmlElement("PrimaryMeasure")
    Nullable!SDMX21PrimaryMeasure primaryMeasure;
}

@xmlRoot("Attribute")
struct SDMX21Attribute
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @attr("assignementStatus")
    Nullable!string assignementStatus;

    @xmlElement("ConceptIdentity")
    Nullable!SDMX21ConceptIdentity conceptIdentity;

    @xmlElement("LocalRepresentation")
    Nullable!SDMX21LocalRepresentation localRepresentation;

    @xmlElement("AttributeRelationship")
    Nullable!SDMX21AttributeRelationship attributeRelationship;
}

@xmlRoot("AttributeList")
struct SDMX21AttributeList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Attribute")
    SDMX21Attribute[] attributes;
}

@xmlRoot("DimensionReference")
struct SDMX21DimensionReference
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("GroupDimension")
struct SDMX21GroupDimension
{
    @xmlElementList("DimensionReference")
    SDMX21DimensionReference[] dimensionReference;
}

@xmlRoot("Group")
struct SDMX21Group
{
    @attr("urn")
    Nullable!string urn;

    @attr("id")
    string id;

    @xmlElementList("GroupDimension")
    SDMX21GroupDimension[] groupDimesions;
}

@xmlRoot("PrimaryMeasure")
struct SDMX21PrimaryMeasure
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("ConceptIdentity")
    Nullable!SDMX21ConceptIdentity conceptIdentity;
}

@xmlRoot("MeasureList")
struct SDMX21MeasureList
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElement("PrimaryMeasure")
    SDMX21PrimaryMeasure primaryMeasure;
}

@xmlRoot("DataStructureComponents")
struct SDMX21DataStructureComponents
{
    @xmlElement("DimensionList")
    SDMX21DimensionList dimensionList;

    @xmlElement("AttributeList")
    SDMX21AttributeList attributeList;

    @xmlElement("MeasureList")
    SDMX21MeasureList measureList;

    @xmlElement("Group")
    Nullable!SDMX21Group group;
}

@xmlRoot("DataStructure")
struct SDMX21DataStructure
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElement("DataStructureComponents")
    SDMX21DataStructureComponents dataStructureComponents;
}

@xmlRoot("Code")
struct SDMX21Code
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;
}

@xmlRoot("Codelist")
struct SDMX21Codelist
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElementList("Code")
    SDMX21Code[] codes;
}

@xmlRoot("Concept")
struct SDMX21Concept
{
    @attr("id")
    string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;
}

@xmlRoot("ConceptScheme")
struct SDMX21ConceptScheme
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElementList("Concept")
    SDMX21Concept[] concepts;
}

@xmlRoot("Category")
struct SDMX21Category
{
    @attr("id")
    Nullable!string id;

    @attr("urn")
    Nullable!string urn;

    @xmlElementList("Name")
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElementList("Category")
    SDMX21Category[] children;
}

@xmlRoot("CategoryScheme")
struct SDMX21CategoryScheme
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElementList("Category")
    SDMX21Category[] categories;
}

@xmlRoot("Source")
struct SDMX21Source
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("Target")
struct SDMX21Target
{
    @xmlElement("Ref")
    SDMX21Ref ref_;
}

@xmlRoot("Categorisation")
struct SDMX21Categorisation
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElement("Source")
    SDMX21Source source;

    @xmlElement("Target")
    SDMX21Target target;
}

@xmlRoot("Categorisations")
struct SDMX21Categorisations
{
    @xmlElementList("Categorisation")
    SDMX21Categorisation[] categorisations;
}

@xmlRoot("Codelists")
struct SDMX21Codelists
{
    @xmlElementList("Codelist")
    SDMX21Codelist[] codelists;
}

@xmlRoot("Concepts")
struct SDMX21Concepts
{
    @xmlElementList("ConceptScheme")
    SDMX21ConceptScheme[] conceptSchemes;
}

@xmlRoot("DataStructures")
struct SDMX21DataStructures
{
    @xmlElementList("DataStructure")
    SDMX21DataStructure[] dataStructures;
}

@xmlRoot("Dataflows")
struct SDMX21Dataflows
{
    @xmlElementList("Dataflow")
    SDMX21Dataflow[] dataflows;
}

@xmlRoot("CategorySchemes")
struct SDMX21CategorySchemes
{
    @xmlElementList("CategoryScheme")
    SDMX21CategoryScheme[] categorySchemes;
}

@xmlRoot("KeyValue")
struct SDMX21KeyValue
{
    @attr("id")
    string id;

    @xmlElementList("Value")
    SDMX21Value[] values;
}

@xmlRoot("ConstraintAttachment")
struct SDMX21ConstraintAttachment
{
    @xmlElement("Dataflow")
    Nullable!SDMX21Dataflow dataflow;
}

@xmlRoot("CubeRegion")
struct SDMX21CubeRegion
{
    @attr("include")
    Nullable!bool include;

    @xmlElementList("KeyValue")
    SDMX21KeyValue[] keyValues;
}

@xmlRoot("ContentConstraint")
struct SDMX21ContentConstraint
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
    SDMX21Name[] names;

    @xmlElementList("Description")
    SDMX21Description[] descriptions;

    @xmlElement("ConstraintAttachment")
    Nullable!SDMX21ConstraintAttachment constraintAttachment;

    @xmlElement("CubeRegion")
    Nullable!SDMX21CubeRegion cubeRegion;
}

@xmlRoot("Constraints")
struct SDMX21Constraints
{
    @xmlElementList("ContentConstraint")
    SDMX21ContentConstraint[] constraints;
}

@xmlRoot("Structures")
struct SDMX21Structures
{
    @xmlElement("Codelists")
    Nullable!SDMX21Codelists codelists;

    @xmlElement("Concepts")
    Nullable!SDMX21Concepts concepts;

    @xmlElement("DataStructures")
    Nullable!SDMX21DataStructures dataStructures;

    @xmlElement("Dataflows")
    Nullable!SDMX21Dataflows dataflows;

    @xmlElement("CategorySchemes")
    Nullable!SDMX21CategorySchemes categorySchemes;

    @xmlElement("Constraints")
    Nullable!SDMX21Constraints constraints;

    @xmlElement("Categorisations")
    Nullable!SDMX21Categorisations categorisations;

}

@xmlRoot("Value")
struct SDMX21Value
{
    @attr("id")
    Nullable!string id;

    @attr("value")
    Nullable!string value;

    @text
    Nullable!string content;
}

@xmlRoot("SeriesKey")
struct SDMX21SeriesKey
{
    @xmlElementList("Value")
    SDMX21Value[] values;
}

@xmlRoot("Attributes")
struct SDMX21Attributes
{
    @xmlElementList("Value")
    SDMX21Value[] values;
}

@xmlRoot("ObsDimension")
struct SDMX21ObsDimension
{
    @attr("value")
    string value;
}

@xmlRoot("ObsValue")
struct SDMX21ObsValue
{
    @attr("value")
    Nullable!double value;
}

@xmlRoot("Obs")
struct SDMX21Obs
{
    @xmlElement("ObsDimension")
    Nullable!SDMX21ObsDimension obsDimension;

    @xmlElement("ObsValue")
    Nullable!SDMX21ObsValue obsValue;

    @xmlElement("Attributes")
    Nullable!SDMX21Attributes attributes;

    @allAttr
    string[string] structureAttributes;
}

@xmlRoot("Series")
struct SDMX21Series
{
    @xmlElement("SeriesKey")
    Nullable!SDMX21SeriesKey seriesKey;

    @xmlElement("Attributes")
    Nullable!SDMX21Attributes attributes;

    @xmlElementList("Obs")
    SDMX21Obs[] observations;

    @allAttr
    string[string] structureKeys;
}

@xmlRoot("DataSet")
struct SDMX21DataSet
{
    @attr("structureRef")
    Nullable!string structureRef;

    @xmlElementList("Series")
    SDMX21Series[] series;
}

unittest
{
    import std.file : readText;

    const structures = readText("./fixtures/sdmx21/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")
        .deserializeAs!SDMX21Structures;

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
    assert(dataflow.names[0] == SDMX21Name(
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
    assert(contentConstraint.names[0] == SDMX21Name("en", "01R_CONSTRAINT"));
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

    const structures = readText("./fixtures/sdmx21/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMX21Structures;

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
    assert(codelists.codelists[0].names[0] == SDMX21Name("en", "FREQ"));
    assert(codelists.codelists[0].codes.length == 7);
    assert(codelists.codelists[0].codes[0].id == "D");
    assert(codelists.codelists[0].codes[0].names.length == 1);
    assert(codelists.codelists[0].codes[0].names[0] == SDMX21Name("en", "Daily"));

    const concepts = structures.concepts.get;
    assert(concepts.conceptSchemes.length == 1);
    assert(concepts.conceptSchemes[0].id == "CS_DSD_nama_10_gdp");
    assert(concepts.conceptSchemes[0].agencyId == "ESTAT");
    assert(concepts.conceptSchemes[0].names.length == 1);
    assert(concepts.conceptSchemes[0].names[0] == SDMX21Name("en", "Concept Scheme for DSD_nama_10_gdp"));
    assert(concepts.conceptSchemes[0].concepts.length == 9);
    assert(concepts.conceptSchemes[0].concepts[0].id == "FREQ");
    assert(concepts.conceptSchemes[0].concepts[0].names.length == 1);
    assert(concepts.conceptSchemes[0].concepts[0].names[0] == SDMX21Name("en", "FREQ"));
    assert(concepts.conceptSchemes[0].concepts[0].descriptions.length == 1);

    const dataStructures = structures.dataStructures.get;
    assert(dataStructures.dataStructures.length == 1);

    const dataStructure = dataStructures.dataStructures[0];
    assert(dataStructure.id == "DSD_nama_10_gdp");
    assert(dataStructure.agencyId == "ESTAT");
    assert(dataStructure.names.length == 1);
    assert(dataStructure.names[0] == SDMX21Name("en", "DSWS Data Structure Definition"));

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

    const structures = readText("./fixtures/sdmx21/structure_category.xml")
        .deserializeAs!SDMX21Structures;

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
        .names[0] == SDMX21Name("fr", "Économie – Conjoncture – Comptes nationaux"));
    assert(categorySchemes.categorySchemes[0].categories[0].children.length == 6);
}

unittest
{
    import std.file : readText;

    const structures = readText("./fixtures/sdmx21/structure_dataflow_categorisation.xml")
        .deserializeAs!SDMX21Structures;

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

    const dataset = readText("./fixtures/sdmx21/data_generic.xml")
        .deserializeAs!SDMX21DataSet;

    assert(!dataset.structureRef.isNull);
    assert(dataset.series.length == 3);
    assert(dataset.series[0].seriesKey.get.values.length == 10);
    assert(dataset.series[0].seriesKey.get.values[0] == SDMX21Value("BASIND".nullable, "SO".nullable));
    assert(dataset.series[0].attributes.get.values.length == 5);
    assert(dataset.series[0].attributes.get.values[0] == SDMX21Value("IDBANK".nullable, "001694113".nullable));
    assert(dataset.series[0].observations.length == 10);
    assert(dataset.series[0].observations[0].obsDimension.get.value == "2020-10");
    assert(dataset.series[0].observations[0].obsValue.get.value.get == 4027.0);
    assert(!dataset.series[0].observations[0].attributes.isNull);
    assert(dataset.series[0].observations[0].attributes.get.values.length == 3);
    assert(dataset.series[0].observations[0].attributes.get.values[0] == SDMX21Value(
        "OBS_STATUS".nullable, "A".nullable));
}

unittest
{
    import std.file : readText;
    import std.typecons : nullable;

    const dataset = readText("./fixtures/sdmx21/data_specific.xml")
        .deserializeAs!SDMX21DataSet;

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

enum bool isMappable(S, T) = is(ReturnType!((S s) => s.coreResource) : Nullable!T);

Nullable!(T[]) buildResourceList(string resourceName, S, T)(in Nullable!string[string] messages,
                                                            int limit = -1,
                                                            int offset = 0)
if(isMappable!(S, T))
{
    import std.range : drop, take;
    import std.array : Appender;
    import std.typecons : apply;

    return messages.get(resourceName, (Nullable!string).init)
        .apply!((msg) {
            Appender!(T[]) dfs;
            if(limit > 0) dfs.reserve(limit);
            auto iRange = msg.deserializeAsRangeOf!S
                .drop(offset)
                .take(limit);

            foreach (ref iDf; iRange)
            {
                auto df = iDf.coreResource();
                if(!df.isNull) dfs.put(df.get);
            }
            return dfs.data;
        });
}

alias buildDataflows = buildResourceList!("dataflow", SDMX21Dataflow, Dataflow);

unittest
{
    import std.file : readText;
    Nullable!string xmlStr = readText("fixtures/sdmx21/structure_dataflow.xml");
    auto r = buildDataflows(["dataflow": xmlStr], 10, 10);
    assert(!r.isNull);
    assert(r.get.length == 10);
}

unittest
{
    import std.file : readText;
    import std.range : walkLength;
    Nullable!string xmlStr = readText("fixtures/sdmx21/structure_dataflow.xml");
    auto r = buildDataflows(["dataflow": xmlStr]);
    auto expectedLength = deserializeAsRangeOf!SDMX21Dataflow(xmlStr.get).walkLength;
    assert(!r.isNull);
    assert(r.get.length == expectedLength);
}

unittest
{
    import std.file : readText;
    import std.datetime.stopwatch : benchmark;
    import std.stdio : writefln;
    import std.array : array;
    import dxml.dom : parseDOM;

    Nullable!string xmlStr = readText("fixtures/sdmx21/structure_dataflow.xml");
    auto bm = benchmark!({
        buildDataflows(["dataflow": xmlStr]);
    }, {
        deserializeAsRangeOf!SDMX21Dataflow(xmlStr.get).array;
    }, {
        parseDOM(xmlStr.get);
    })(100);

    writefln("Mapped: %s msecs", bm[0].total!"msecs");
    writefln("Original: %s msecs", bm[1].total!"msecs");
    writefln("Raw: %s msecs", bm[2].total!"msecs");
}