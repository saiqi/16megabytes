module vulpes.datasources.sdmxml20;

import std.typecons : Nullable, nullable;
import vulpes.lib.xml;
import vulpes.core.model : Urn, Dataflow, Language;

package:

@xmlRoot("KeyFamilyID")
struct SDMX20KeyFamilyID
{
    @text
    string id;
}

@xmlRoot("KeyFamilyAgencyID")
struct SDMX20KeyFamilyAgencyID
{
    @text
    string agencyId;
}

@xmlRoot("KeyFamilyRef")
struct SDMX20KeyFamilyRef
{
    @xmlElement("KeyFamilyID")
    SDMX20KeyFamilyID keyFamilyId;

    @xmlElement("KeyFamilyAgencyID")
    SDMX20KeyFamilyAgencyID keyFamilyAgencyId;

    inout(Urn) urn() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        import vulpes.core.model : PackageType, ClassType, DefaultVersion;
        return Urn(
            PackageType.datastructure,
            ClassType.DataStructure,
            keyFamilyAgencyId.agencyId,
            keyFamilyId.id,
            DefaultVersion
        );
    }
}

@xmlRoot("Name")
struct SDMX20Name
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Dataflow")
struct SDMX20Dataflow
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
    SDMX20KeyFamilyRef keyFamilyRef;

    @xmlElementList("Name")
    SDMX20Name[] names;

    Nullable!Dataflow convert() pure @safe inout nothrow
    {
        scope(failure) return typeof(return).init;

        import vulpes.datasources.sdmxcommon : getLabel, getIntlLabels;

        auto cNames = names.dup;

        auto name = getLabel(cNames);

        if(name.isNull) return typeof(return).init;

        return Dataflow(
            id,
            version_,
            agencyId,
            true,
            isFinal.get(true),
            name.get,
            getIntlLabels(cNames),
            (Nullable!string).init,
            (Nullable!(string[Language])).init,
            keyFamilyRef.urn.toString
        ).nullable;

    }
}

unittest
{
    import std.file : readText;
    const str = readText("fixtures/sdmx20/structure_dataflows.xml");
    const SDMX20Dataflow sdmxDf = str.deserializeAs!SDMX20Dataflows.dataflows[0];
    const df = sdmxDf.convert;
    assert(!df.isNull);
    assert(df.get.id == "DS-BOP_2017M06");
    assert(df.get.agencyId == "IMF");
    assert(df.get.version_ == "1.0");
    assert(df.get.name == "Balance of Payments (BOP), 2017 M06");
    assert(!df.get.names.isNull);
    assert(df.get.name == df.get.names.get[Language.en]);
    assert(df.get.structure == sdmxDf.keyFamilyRef.urn.toString);
}

@xmlRoot("Dataflows")
struct SDMX20Dataflows
{
    @xmlElementList("Dataflow")
    SDMX20Dataflow[] dataflows;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_dataflows.xml");
    auto dfs = message.deserializeAsRangeOf!SDMX20Dataflow;
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
struct SDMX20Dimension
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("conceptRef")
    Nullable!string conceptRef;
}

@xmlRoot("TimeDimension")
struct SDMX20TimeDimension
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("conceptRef")
    Nullable!string conceptRef;
}

@xmlRoot("TextFormat")
struct SDMX20TextFormat
{
    @attr("textType")
    Nullable!string textType;
}

@xmlRoot("PrimaryMeasure")
struct SDMX20PrimaryMeasure
{
    @attr("conceptRef")
    Nullable!string conceptRef;

    @xmlElement("TextFormat")
    Nullable!SDMX20TextFormat textFormat;
}

@xmlRoot("Attribute")
struct SDMX20Attribute
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
struct SDMX20Components
{
    @xmlElementList("Dimension")
    SDMX20Dimension[] dimensions;

    @xmlElement("TimeDimension")
    SDMX20TimeDimension timeDimension;

    @xmlElement("PrimaryMeasure")
    SDMX20PrimaryMeasure primaryMeasure;

    @xmlElementList("Attribute")
    SDMX20Attribute[] attributes;
}

@xmlRoot("KeyFamily")
struct SDMX20KeyFamily
{
    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElement("Components")
    SDMX20Components components;
}

@xmlRoot("KeyFamilies")
struct SDMX20KeyFamilies
{
    @xmlElementList("KeyFamily")
    SDMX20KeyFamily[] keyFamilies;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamilies.xml");
    auto kfs = message.deserializeAsRangeOf!SDMX20KeyFamily;
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
    auto kf = message.deserializeAsRangeOf!SDMX20KeyFamily.front;
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
struct SDMX20Description
{
    @attr("lang")
    string lang;

    @text
    string content;
}

@xmlRoot("Code")
struct SDMX20Code
{
    @attr("value")
    string value;

    @xmlElementList("Description")
    SDMX20Description[] descriptions;
}

@xmlRoot("CodeList")
struct SDMX20Codelist
{
    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElementList("Code")
    SDMX20Code[] codes;

    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;
}

@xmlRoot("CodeLists")
struct SDMX20Codelists
{
    @xmlElementList("Codelist")
    SDMX20Codelist[] codelists;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto cl = message.deserializeAsRangeOf!SDMX20Codelist.front;
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
struct SDMX20Concept
{
    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @xmlElementList("Name")
    SDMX20Name[] names;
}

@xmlRoot("Concepts")
struct SDMX20Concepts
{
    @xmlElementList("Concept")
    SDMX20Concept[] concepts;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto s = message.deserializeAsRangeOf!SDMX20Concept.front;
    assert(s.id == "LOCATION");
    assert(s.agencyId == "OECD");
    assert(s.names.length == 2);
    assert(s.names[0].lang == "en");
    assert(s.names[0].content == "Country");
}

@xmlRoot("Structure")
struct SDMX20Structure
{
    @xmlElement("Dataflows")
    Nullable!SDMX20Dataflows dataflows;

    @xmlElement("KeyFamilies")
    Nullable!SDMX20KeyFamilies keyFamilies;

    @xmlElement("CodeLists")
    Nullable!SDMX20Codelists codelists;

    @xmlElement("Concepts")
    Nullable!SDMX20Concepts concepts;
}

unittest
{
    import std.file : readText;
    auto message = readText("fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml");
    auto s = message.deserializeAs!SDMX20Structure;
    assert(s.dataflows.isNull);
    assert(!s.keyFamilies.isNull);
    assert(!s.codelists.isNull);
    assert(!s.concepts.isNull);
}