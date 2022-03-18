module vulpes.datasources.sdmxml21;

import std.typecons : Nullable, nullable;
import std.traits : ReturnType;
import std.range : InputRange;
import vulpes.lib.xml;
import vulpes.core.model;
import vulpes.datasources.sdmxcommon : getIntlLabels, getLabel;

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

    Nullable!Dataflow convert() pure @safe inout
    {
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
    const df = sdmxDf.convert();
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

    inout(Nullable!Urn) urn() pure @safe inout
    {
        if(package_.isNull || class_.isNull || agencyId.isNull)
            return typeof(return).init;

        if(version_.isNull && maintainableParentVersion.isNull)
            return typeof(return).init;

        if(!maintainableParentId.isNull && maintainableParentVersion.isNull)
            return typeof(return).init;

        auto pkg = package_.get.enumMember!PackageType;
        auto cls = class_.get.enumMember!ClassType;

        if(pkg.isNull || cls.isNull) return typeof(return).init;

        Nullable!Urn urn = maintainableParentId.isNull
            ? Urn(pkg.get, cls.get, agencyId.get, id, version_.get)
            : Urn(pkg.get, cls.get, agencyId.get, maintainableParentId.get, maintainableParentVersion.get, id);
        return urn;
    }
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

    @attr("minLength")
    Nullable!string minLength;

    @attr("maxLength")
    Nullable!string maxLength;

    @attr("pattern")
    Nullable!string pattern;

    Nullable!Format convert() pure @safe inout
    {
        import std.conv : to;
        import std.typecons : apply;

        if(textType.isNull) return typeof(return).init;

        auto b = textType.get.enumMember!BasicDataType;

        if(b.isNull) return typeof(return).init;

        Nullable!Format fmt = Format(
            maxLength.apply!(to!uint),
            minLength.apply!(to!uint),
            b.get
        );

        return fmt;
    }
}

@xmlRoot("Enumeration")
struct SDMX21Enumeration
{
    @xmlElement("Ref")
    SDMX21Ref ref_;

    Nullable!Enumeration convert() @safe pure inout
    {
        if(ref_.urn.isNull) return typeof(return).init;
        return Enumeration(ref_.urn.get.toString).nullable;
    }
}

@xmlRoot("LocalRepresentation")
struct SDMX21LocalRepresentation
{
    @xmlElement("TextFormat")
    Nullable!SDMX21TextFormat textFormat;

    @xmlElement("Enumeration")
    Nullable!SDMX21Enumeration enumeration;

    Nullable!LocalRepresentation convert() pure @safe inout
    {
        if(enumeration.isNull && textFormat.isNull) return typeof(return).init;
        if(!enumeration.isNull && !textFormat.isNull) return typeof(return).init;

        Nullable!LocalRepresentation r = enumeration.isNull
            ? LocalRepresentation((Nullable!Enumeration).init, textFormat.get.convert)
            : LocalRepresentation(enumeration.get.convert, (Nullable!Format).init);

        return r;
    }
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

    Nullable!TimeDimension convert() pure @safe inout
    {
        import std.typecons : apply;

        if(id.isNull || position.isNull) return typeof(return).init;

        Nullable!LocalRepresentation rep = localRepresentation
            .apply!"a.convert";

        Nullable!string conceptId = conceptIdentity
            .apply!(a => a.ref_.urn)
            .apply!"a.toString";

        return TimeDimension(
            id.get,
            position.get,
            conceptId,
            [],
            rep
        ).nullable;
    }
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

    Nullable!Dimension convert() pure @safe inout
    {
        import std.typecons : apply;

        if(id.isNull || position.isNull) return typeof(return).init;

        Nullable!LocalRepresentation rep = localRepresentation
            .apply!"a.convert";

        Nullable!string conceptId = conceptIdentity
            .apply!(a => a.ref_.urn)
            .apply!"a.toString";

        return Dimension(
            id.get,
            position.get,
            conceptId,
            [],
            rep
        ).nullable;
    }
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

    Nullable!DimensionList convert() pure @safe inout
    {
        import std.algorithm : any;
        import std.array : array;
        import vulpes.lib.monadish : fallbackMap, filterNull;

        auto td = timeDimension.convert;

        if(td.isNull) return typeof(return).init;

        auto ds = dimensions.fallbackMap!"a.convert";

        if(ds.any!"a.isNull") return typeof(return).init;

        Nullable!DimensionList result = DimensionList(id, ds.filterNull.array, td.get);

        return result;
    }
}

@xmlRoot("AttributeRelationship")
struct SDMX21AttributeRelationship
{
    @xmlElementList("Dimension")
    SDMX21Dimension[] dimensions;

    @xmlElement("PrimaryMeasure")
    Nullable!SDMX21PrimaryMeasure primaryMeasure;

    Nullable!AttributeRelationship convert() pure @safe inout
    {
        import std.algorithm : any;
        import std.array : array;
        import vulpes.lib.monadish : filterNull, fallbackMap;

        auto hasNone = primaryMeasure.isNull && dimensions.length == 0;
        auto hasBoth = !primaryMeasure.isNull && dimensions.length > 0;

        if(hasNone || hasBoth)
        {
            return typeof(return).init;
        }

        if(!primaryMeasure.isNull)
        {
            return AttributeRelationship(
                [],
                (Nullable!string).init,
                Empty().nullable,
                (Nullable!Empty).init
            ).nullable;
        }

        if(dimensions.any!"a.ref_.isNull") return typeof(return).init;

        return AttributeRelationship(
            dimensions.fallbackMap!"a.ref_.get.id".array,
            (Nullable!string).init,
            (Nullable!Empty).init,
            (Nullable!Empty).init
        ).nullable;
    }
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

    Nullable!Attribute convert() pure @safe inout
    {
        import std.typecons : apply;
        if(id.isNull) return typeof(return).init;

        Nullable!UsageType usage = assignementStatus
            .apply!(enumMember!UsageType);

        Nullable!AttributeRelationship rel = attributeRelationship
            .apply!"a.convert";

        Nullable!LocalRepresentation rep = localRepresentation
            .apply!"a.convert";

        Nullable!string conceptId = conceptIdentity
            .apply!(a => a.ref_.urn)
            .apply!"a.toString";

        return Attribute(
            id.get,
            usage,
            rel,
            conceptId,
            [],
            rep
        ).nullable;
    }
}

unittest
{
    auto attrWithId = SDMX21Attribute(
        "0".nullable,
        (Nullable!string).init,
        (Nullable!string).init,
        (Nullable!SDMX21ConceptIdentity).init,
        (Nullable!SDMX21LocalRepresentation).init,
        (Nullable!SDMX21AttributeRelationship).init
    );

    assert(!attrWithId.convert.isNull);

    auto attrWithoutId = SDMX21Attribute(
        (Nullable!string).init,
        (Nullable!string).init,
        (Nullable!string).init,
        (Nullable!SDMX21ConceptIdentity).init,
        (Nullable!SDMX21LocalRepresentation).init,
        (Nullable!SDMX21AttributeRelationship).init
    );

    assert(attrWithoutId.convert.isNull);
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

    Nullable!AttributeList convert() pure @safe inout
    {
        import std.array : array;
        import std.algorithm : any;
        import vulpes.lib.monadish : filterNull, fallbackMap;

        auto attrs = attributes.fallbackMap!"a.convert";

        if(attrs.any!"a.isNull") return typeof(return).init;

        return AttributeList(id, attrs.filterNull.array).nullable;
    }
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
    @xmlElement("DimensionReference")
    SDMX21DimensionReference dimensionReference;
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

    Nullable!Group convert() pure @safe inout
    {
        import std.algorithm : map;
        import std.array : array;
        import vulpes.lib.monadish : fallbackMap;

        auto gds = groupDimesions.fallbackMap!(a => a.dimensionReference.ref_.id);

        Nullable!Group g = Group(id, gds);
        return g;
    }
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

    @xmlElement("LocalRepresentation")
    Nullable!SDMX21LocalRepresentation localRepresentation;

    @xmlElement("Ref")
    Nullable!SDMX21Ref ref_;

    Nullable!Measure convert() pure @safe inout
    {
        import std.typecons : apply;

        if(id.isNull) return typeof(return).init;

        Nullable!string conceptId = conceptIdentity
            .apply!(a => a.ref_.urn)
            .apply!"a.toString";

        Nullable!LocalRepresentation rep = localRepresentation
            .apply!"a.convert";

        return Measure(
            id.get,
            conceptId,
            [],
            rep,
            (Nullable!UsageType).init
        ).nullable;
    }
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

    Nullable!MeasureList convert() pure @safe inout
    {
        auto pm = primaryMeasure.convert;

        if(pm.isNull) return typeof(return).init;

        return MeasureList(id, [pm.get]).nullable;
    }
}

@xmlRoot("DataStructureComponents")
struct SDMX21DataStructureComponents
{
    @xmlElement("DimensionList")
    SDMX21DimensionList dimensionList;

    @xmlElement("AttributeList")
    Nullable!SDMX21AttributeList attributeList;

    @xmlElement("MeasureList")
    Nullable!SDMX21MeasureList measureList;

    @xmlElementList("Group")
    SDMX21Group[] groups;

    Nullable!DataStructureComponents convert() pure @safe inout
    {
        import std.typecons : apply;
        import std.array : array;
        import vulpes.lib.monadish : filterNull, fallbackMap;

        auto dl = dimensionList.convert;

        if(dl.isNull) return typeof(return).init;

        Nullable!AttributeList al = attributeList.apply!"a.convert";
        Nullable!MeasureList ml = measureList.apply!"a.convert";
        auto gs = groups.fallbackMap!"a.convert".filterNull.array;

        return DataStructureComponents(al, dl.get, gs, ml).nullable;
    }
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

    Nullable!DataStructure convert() pure @safe inout
    {
        auto comp = dataStructureComponents.convert;
        if(comp.isNull) return typeof(return).init;

        auto cNames = names.dup;
        auto cDescs = descriptions.dup;

        auto name = getLabel(cNames);

        if(name.isNull) return typeof(return).init;

        return DataStructure(
            id,
            version_,
            agencyId,
            true,
            true,
            name.get,
            getIntlLabels(cNames),
            getLabel(cDescs),
            getIntlLabels(cDescs),
            comp.get
        ).nullable;
    }
}

unittest
{
    import std.file : readText;

    auto msg = readText("./fixtures/sdmx21/structure_dsd_dataflow_constraint_codelist.xml");
    DataStructure dsd = msg.deserializeAs!SDMX21DataStructure.convert.get;
    assert(dsd.name == "AMECO");
    assert(dsd.names.get[Language.en] == "AMECO");
    assert(dsd.description.isNull);
    assert(dsd.descriptions.isNull);

    assert(dsd.dataStructureComponents.dimensionList.dimensions.length == 7);
    assert(dsd.dataStructureComponents.groups.length == 1);
    assert(dsd.dataStructureComponents.attributeList.get.attributes.length == 11);
    assert(dsd.dataStructureComponents.measureList.get.measures.length == 1);

    Dimension d0 = dsd.dataStructureComponents.dimensionList.dimensions[0];
    assert(d0.id == "FREQ");
    assert(d0.position == 1);
    assert(d0.conceptIdentity.get == "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).FREQ");
    assert(d0
        .localRepresentation
        .get
        .enumeration
        .get
        .enumeration == "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_FREQ(1.0)");

    Group g = dsd.dataStructureComponents.groups[0];
    assert(g.groupDimensions.length == 6);
    assert(g.groupDimensions[0] == "AME_REF_AREA");

    Attribute a0 = dsd.dataStructureComponents.attributeList.get.attributes[0];
    assert(a0
        .conceptIdentity
        .get == "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TIME_FORMAT");
    assert(a0.localRepresentation.get.format.get.dataType == BasicDataType.string_);
    assert(a0.attributeRelationship.get.dimensions.length == 7);
    assert(a0.attributeRelationship.get.dimensions[0] == "FREQ");

    Measure m0 = dsd.dataStructureComponents.measureList.get.measures[0];
    assert(m0
        .conceptIdentity
        .get == "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_VALUE");
    assert(m0.localRepresentation.get.format.get.dataType == BasicDataType.string_);
    assert(m0.localRepresentation.get.format.get.maxLength == 15);
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

    assert(dataStructure.dataStructureComponents.attributeList.get.attributes.length == 2);
    assert(dataStructure.dataStructureComponents.attributeList.get.attributes[0].id == "OBS_FLAG");
    assert(dataStructure.dataStructureComponents
        .attributeList
        .get
        .attributes[0]
        .conceptIdentity.get.ref_.id == "OBS_FLAG");
    assert(dataStructure.dataStructureComponents
        .attributeList
        .get
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

    assert(dataStructure.dataStructureComponents.measureList.get.primaryMeasure.id == "OBS_VALUE");
    assert(dataStructure
        .dataStructureComponents
        .measureList
        .get
        .primaryMeasure
        .conceptIdentity
        .get
        .ref_.id == "OBS_VALUE");

    assert(dataStructure.dataStructureComponents.groups.length == 0);
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

InputRange!Dataflow buildDataflows(R)(in R xmlStr)
if(isForwardRangeOfChar!R)
{
    import std.algorithm : map;
    import std.range : inputRangeObject;
    import vulpes.lib.monadish : filterNull;

    return xmlStr
        .deserializeAsRangeOf!SDMX21Dataflow
        .map!"a.convert"
        .filterNull
        .inputRangeObject;
}

unittest
{
    import std.file : readText;
    auto xmlIn = readText("./fixtures/sdmx21/structure_dataflow.xml");
    auto dfs = buildDataflows(xmlIn);
    assert(!dfs.empty);
}
