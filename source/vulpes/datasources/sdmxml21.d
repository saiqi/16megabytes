module vulpes.datasources.sdmxml21;

import std.typecons : Nullable, nullable, Tuple, apply;
import std.range : isInputRange, isRandomAccessRange, ElementType;
import std.traits : Unqual;
import vulpes.lib.xml;
import vulpes.core.model : Dataflow, Language, Unknown, DefaultLanguage;

package:

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

    @xmlElement("Structure")
    Nullable!SDMXStructure structure;

    @xmlElement("Ref")
    Nullable!SDMXRef ref_;

    Nullable!Dataflow dataflow() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        if(id.isNull || agencyId.isNull || urn.isNull || structure.isNull)
            return typeof(return).init;

        auto cNames = names.dup;
        auto cDescriptions = descriptions.dup;

        auto name = getLabel(cNames);

        if(name.isNull)
            return typeof(return).init;

        auto urn = structure.get.ref_.urn;

        if(urn.isNull)
            return typeof(return).init;

        return Dataflow(
            id.get,
            version_.get(Unknown),
            agencyId.get,
            true,
            isFinal.get(true),
            name.get,
            getIntlLabels(cNames),
            getLabel(cDescriptions),
            getIntlLabels(cDescriptions),
            urn.get
        ).nullable;
    }
}

unittest
{
    import std.file : readText;
    const xmlStr = readText("fixtures/sdmx21/structure_dataflow.xml");
    const sdmxDf = xmlStr.deserializeAs!SDMXStructures.dataflows.get.dataflows[0];
    const df = sdmxDf.dataflow();
    assert(!df.isNull);
    assert(df.get.id == "BALANCE-PAIEMENTS");
    assert(df.get.version_ == "1.0");
    assert(df.get.agencyId == "FR1");
    assert(df.get.name == "Balance of payments");
    assert(df.get.names.get[Language.fr] == "Balance des paiements");
    assert(df.get.description.isNull);
    assert(df.get.descriptions.isNull);
    assert(df.get.structure == sdmxDf.structure.get.ref_.urn);
}

@xmlRoot("Name")
struct SDMXName
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Description")
struct SDMXDescription
{
    @attr("lang")
    string lang;

    @text
    string content;
}

enum isLabel(T) = (is(Unqual!T == SDMXName) || is(Unqual!T == SDMXDescription));

Nullable!string getLabel(T)(in T resources) pure @safe
if(isInputRange!T && isLabel!(ElementType!T))
{
    import std.algorithm : map, filter;
    import std.conv : to;

    auto r = resources
        .filter!(a => a.lang.to!Language == DefaultLanguage)
        .map!(a => a.content);

    if(r.empty) return typeof(return).init;

    return r.front.nullable;
}

unittest
{
    auto l1 = getLabel([SDMXName(DefaultLanguage, "Foo"), SDMXName("fr", "Fou")]);
    assert(!l1.isNull);
    assert(l1.get == "Foo");

    SDMXName[] eNames;
    assert(getLabel(eNames).isNull);

    auto l2 = getLabel([SDMXName("de", "Foo"), SDMXName("fr", "Fou")]);
    assert(l2.isNull);
}

Nullable!(string[Language]) getIntlLabels(T)(in T resources) pure @safe nothrow
if(isInputRange!T && isLabel!(ElementType!T))
{
    import std.array : assocArray;
    import std.typecons : tuple;
    import std.algorithm : map;
    import std.conv : to;
    import std.range;

    scope(failure) return typeof(return).init;

    if(resources.empty) return typeof(return).init;

    return resources
        .map!(a => tuple(a.lang.to!Language, a.content))
        .assocArray
        .nullable;
}

unittest
{
    import std.algorithm : equal;
    const names = [SDMXName("en", "Foo"), SDMXName("fr", "Fou")];
    auto r = getIntlLabels(names).get;
    assert(equal(r[Language.en], "Foo"));
    assert(equal(r[Language.fr], "Fou"));

    assert(getIntlLabels([SDMXName("unknown", "")]).isNull);
}

@xmlRoot("Structure")
struct SDMXStructure
{
    @xmlElement("Ref")
    SDMXRef ref_;
}

enum RootUrn = "urn:sdmx:org.sdmx.infomodel";

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

    inout(Nullable!string) urn() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        import std.format : format;

        if(package_.isNull || class_.isNull || version_.isNull || agencyId.isNull)
            return typeof(return).init;

        return format!"%s.%s.%s=%s:%s(%s)"(
            RootUrn,
            package_.get,
            class_.get,
            agencyId.get,
            id,
            version_.get
        ).nullable;

    }
}

unittest
{
    assert(SDMXRef().urn.isNull);
    const ref_ = SDMXRef(
        "FOO",
        "1.0".nullable,
        (Nullable!string).init,
        (Nullable!string).init,
        "BAR".nullable,
        "pkg".nullable,
        "class".nullable
    );
    const expected = "urn:sdmx:org.sdmx.infomodel.pkg.class=BAR:FOO(1.0)";
    assert(ref_.urn.get == expected);
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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;
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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;
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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

    @xmlElementList("Category")
    SDMXCategory[] categories;
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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    @xmlElementList("Description")
    SDMXDescription[] descriptions;

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

    const structures = readText("./fixtures/sdmx21/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")
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

    const structures = readText("./fixtures/sdmx21/structure_dsd_codelist_conceptscheme.xml")
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
    assert(concepts.conceptSchemes[0].concepts[0].descriptions.length == 1);

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

    const structures = readText("./fixtures/sdmx21/structure_category.xml")
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

    const structures = readText("./fixtures/sdmx21/structure_dataflow_categorisation.xml")
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

    const dataset = readText("./fixtures/sdmx21/data_generic.xml")
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

    const dataset = readText("./fixtures/sdmx21/data_specific.xml")
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
