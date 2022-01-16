module vulpes.datasources.sdmxml20;

import std.typecons : Nullable;
import vulpes.lib.xml;

package:

@xmlRoot("KeyFamilyID")
struct SDMXKeyFamilyID
{
    @text
    string id;
}

@xmlRoot("KeyFamilyAgencyID")
struct SDMXKeyFamilyAgencyID
{
    @text
    string agencyId;
}

@xmlRoot("KeyFamilyRef")
struct SDMXKeyFamilyRef
{
    @xmlElement("KeyFamilyID")
    SDMXKeyFamilyID keyFamilyId;

    @xmlElement("KeyFamilyAgencyID")
    SDMXKeyFamilyAgencyID keyFamilyAgencyId;
}

@xmlRoot("Name")
struct SDMXName
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Dataflow")
struct SDMXDataflow
{
    @attr("id")
    string id;

    @attr("version")
    string version_;

    @attr("agencyID")
    string agencyId;

    @attr("isFinal")
    Nullable!bool isFinal;

    @xmlElement("KeyFamilyRef")
    SDMXKeyFamilyRef keyFamilyRef;

    @xmlElementList("Name")
    SDMXName[] names;
}

@xmlRoot("Dataflows")
struct SDMXDataflows
{
    @xmlElementList("Dataflow")
    SDMXDataflow[] dataflows;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_dataflows.xml");
    auto dfs = message.deserializeAsRangeOf!SDMXDataflow;
    assert(!dfs.empty);
    assert(dfs.front.id == "DS-BOP_2017M06");
    assert(dfs.front.version_ == "1.0");
    assert(dfs.front.agencyId == "IMF");
    assert(dfs.front.isFinal.get == true);
    assert(dfs.front.names.length == 1);
    assert(dfs.front.keyFamilyRef.keyFamilyId.id == "BOP_2017M06");
    assert(dfs.front.keyFamilyRef.keyFamilyAgencyId.agencyId == "IMF");
}

@xmlRoot("Dimension")
struct SDMXDimension
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("conceptRef")
    Nullable!string conceptRef;
}

@xmlRoot("TimeDimension")
struct SDMXTimeDimension
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("conceptRef")
    Nullable!string conceptRef;
}

@xmlRoot("TextFormat")
struct SDMXTextFormat
{
    @attr("textType")
    Nullable!string textType;
}

@xmlRoot("PrimaryMeasure")
struct SDMXPrimaryMeasure
{
    @attr("conceptRef")
    Nullable!string conceptRef;

    @xmlElement("TextFormat")
    Nullable!SDMXTextFormat textFormat;
}

@xmlRoot("Attribute")
struct SDMXAttribute
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("conceptRef")
    Nullable!string conceptRef;

    @attr("assignmentStatus")
    Nullable!string assignmentStatus;

    @attr("attachmentLevel")
    Nullable!string attachmentLevel;
}

@xmlRoot("Components")
struct SDMXComponents
{
    @xmlElementList("Dimension")
    SDMXDimension[] dimensions;

    @xmlElement("TimeDimension")
    SDMXTimeDimension timeDimension;

    @xmlElement("PrimaryMeasure")
    SDMXPrimaryMeasure primaryMeasure;

    @xmlElementList("Attribute")
    SDMXAttribute[] attributes;
}

@xmlRoot("KeyFamily")
struct SDMXKeyFamily
{
    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElement("Components")
    SDMXComponents components;
}

@xmlRoot("KeyFamilies")
struct SDMXKeyFamilies
{
    @xmlElementList("KeyFamily")
    SDMXKeyFamily[] keyFamilies;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamilies.xml");
    auto kfs = message.deserializeAsRangeOf!SDMXKeyFamily;
    assert(!kfs.empty);
    assert(kfs.front.id == "QNA");
    assert(kfs.front.agencyId == "OECD");
    assert(kfs.front.names.length == 2);
    assert(kfs.front.names[0].lang == "en");
    assert(kfs.front.names[0].content == "Quarterly National Accounts");
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto kf = message.deserializeAsRangeOf!SDMXKeyFamily.front;
    assert(kf.id == "QNA");
    assert(kf.agencyId == "OECD");
    assert(kf.names.length == 2);
    assert(kf.components.dimensions.length == 4);
    assert(kf.components.dimensions[0].codelist.get == "CL_QNA_LOCATION");
    assert(kf.components.dimensions[0].conceptRef.get == "LOCATION");
    assert(kf.components.timeDimension.codelist.get == "CL_QNA_TIME");
    assert(kf.components.timeDimension.conceptRef.get == "TIME");
    assert(kf.components.primaryMeasure.conceptRef.get == "OBS_VALUE");
    assert(kf.components.primaryMeasure.textFormat.get.textType.get == "Double");
    assert(kf.components.attributes.length == 5);
    assert(kf.components.attributes[0].codelist.get == "CL_QNA_OBS_STATUS");
    assert(kf.components.attributes[0].conceptRef.get == "OBS_STATUS");
    assert(kf.components.attributes[0].assignmentStatus.get == "Conditional");
    assert(kf.components.attributes[0].attachmentLevel.get == "Observation");
}

@xmlRoot("Description")
struct SDMXDescription
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Code")
struct SDMXCode
{
    @attr("value")
    string value;

    @xmlElementList("Description")
    SDMXDescription[] descriptions;
}

@xmlRoot("CodeList")
struct SDMXCodelist
{
    @xmlElementList("Name")
    SDMXName[] names;

    @xmlElementList("Code")
    SDMXCode[] codes;

    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;
}

@xmlRoot("CodeLists")
struct SDMXCodelists
{
    @xmlElementList("Codelist")
    SDMXCodelist[] codelists;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto cl = message.deserializeAsRangeOf!SDMXCodelist.front;
    assert(cl.id == "CL_QNA_LOCATION");
    assert(cl.agencyId == "OECD");
    assert(cl.names.length == 2);
    assert(cl.codes.length == 58);
    assert(cl.codes[0].value == "AUS");
    assert(cl.codes[0].descriptions.length == 2);
    assert(cl.codes[0].descriptions[0].lang == "en");
    assert(cl.codes[0].descriptions[0].content == "Australia");
}

@xmlRoot("Concept")
struct SDMXConcept
{
    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @xmlElementList("Name")
    SDMXName[] names;
}

@xmlRoot("Concepts")
struct SDMXConcepts
{
    @xmlElementList("Concept")
    SDMXConcept[] concepts;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto s = message.deserializeAsRangeOf!SDMXConcept.front;
    assert(s.id == "LOCATION");
    assert(s.agencyId == "OECD");
    assert(s.names.length == 2);
    assert(s.names[0].lang == "en");
    assert(s.names[0].content == "Country");
}

@xmlRoot("Structure")
struct SDMXStructure
{
    @xmlElement("Dataflows")
    Nullable!SDMXDataflows dataflows;

    @xmlElement("KeyFamilies")
    Nullable!SDMXKeyFamilies keyFamilies;

    @xmlElement("CodeLists")
    Nullable!SDMXCodelists codelists;

    @xmlElement("Concepts")
    Nullable!SDMXConcepts concepts;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto s = message.deserializeAs!SDMXStructure;
    assert(s.dataflows.isNull);
    assert(!s.keyFamilies.isNull);
    assert(!s.codelists.isNull);
    assert(!s.concepts.isNull);
}