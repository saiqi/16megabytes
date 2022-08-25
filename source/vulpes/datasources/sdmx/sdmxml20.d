module vulpes.datasources.sdmx.sdmxml20;

import std.typecons : Nullable, nullable;
import std.range: InputRange;
import std.traits : Unqual;
import vulpes.lib.xml;
import vulpes.core.model;
import vulpes.datasources.sdmx.sdmxcommon;

private enum bool isDSDComponent(T) = is(Unqual!T == SDMX20Attribute)
    || is(Unqual!T == SDMX20Dimension)
    || is(Unqual!T == SDMX20TimeDimension)
    || is(Unqual!T == SDMX20PrimaryMeasure);

private Nullable!Urn conceptId(T)(in ref T resource, string agency)
if(isDSDComponent!T)
{
    if(resource.conceptRef.isNull) return typeof(return).init;

    Nullable!Urn urn = Urn(
        PackageType.conceptscheme,
        ClassType.Concept,
        resource.conceptSchemeAgency.get(agency),
        resource.conceptSchemeRef.get(Unknown),
        resource.conceptVersion.get(DefaultVersion),
        resource.conceptRef.get);

    return urn;
}

private Nullable!Enumeration enumeration(T)(in ref T resource, string agency)
if(isDSDComponent!T)
{
    static if(is(typeof(T.init.codelist)))
    {
        if(resource.codelist.isNull) return typeof(return).init;

        Urn u = Urn(
            PackageType.codelist,
            ClassType.Codelist,
            resource.codelistAgency.get(agency),
            resource.codelist.get,
            resource.codelistVersion.get(DefaultVersion));

        Nullable!Enumeration e = Enumeration(u);
        return e;
    }
    else
    {
        return typeof(return).init;
    }

}

private Nullable!LocalRepresentation localRepresentation(T)(in ref T resource, string agency)
if(isDSDComponent!T)
{
    import std.typecons : apply;

    auto e = enumeration!T(resource, agency);

    Nullable!LocalRepresentation rep;

    static if(is(typeof((Unqual!T).init.textFormat) == Nullable!SDMX20TextFormat))
    {
        Nullable!Format f;

        Nullable!BasicDataType type = resource.textFormat
            .apply!"a.textType"
            .apply!(a => a.enumMember!BasicDataType);

        if(type.isNull) f = (Nullable!Format).init;
        else f = Format(
            (Nullable!uint).init,
            (Nullable!uint).init,
            type.get);
        
        rep = LocalRepresentation(e, f);
    }
    else
    {
        rep = LocalRepresentation(e, (Nullable!Format).init);
    }

    return rep;
}

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

    Nullable!Dataflow convert() pure @safe inout
    {
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
            keyFamilyRef.urn
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
    assert(df.get.structure == sdmxDf.keyFamilyRef.urn);
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

    @attr("codelistVersion")
    Nullable!string codelistVersion;

    @attr("codelistAgency")
    Nullable!string codelistAgency;

    @attr("conceptRef")
    Nullable!string conceptRef;

    @attr("conceptVersion")
    Nullable!string conceptVersion;

    @attr("conceptSchemeRef")
    Nullable!string conceptSchemeRef;

    @attr("conceptSchemeAgency")
    Nullable!string conceptSchemeAgency;

    @attr("isFrequencyDimension")
    Nullable!bool isFrequencyDimension;

    @attr("isMeasureDimension")
    Nullable!bool isMeasureDimension;
}

@xmlRoot("TimeDimension")
struct SDMX20TimeDimension
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("codelistVersion")
    Nullable!string codelistVersion;

    @attr("codelistAgency")
    Nullable!string codelistAgency;

    @attr("conceptRef")
    Nullable!string conceptRef;

    @attr("conceptVersion")
    Nullable!string conceptVersion;

    @attr("conceptSchemeRef")
    Nullable!string conceptSchemeRef;

    @attr("conceptSchemeAgency")
    Nullable!string conceptSchemeAgency;
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

    @attr("conceptVersion")
    Nullable!string conceptVersion;

    @attr("conceptSchemeRef")
    Nullable!string conceptSchemeRef;

    @attr("conceptSchemeAgency")
    Nullable!string conceptSchemeAgency;

    @xmlElement("TextFormat")
    Nullable!SDMX20TextFormat textFormat;
}

@xmlRoot("Attribute")
struct SDMX20Attribute
{
    @attr("codelist")
    Nullable!string codelist;

    @attr("codelistVersion")
    Nullable!string codelistVersion;

    @attr("codelistAgency")
    Nullable!string codelistAgency;

    @attr("conceptRef")
    Nullable!string conceptRef;

    @attr("conceptVersion")
    Nullable!string conceptVersion;

    @attr("conceptSchemeRef")
    Nullable!string conceptSchemeRef;

    @attr("conceptSchemeAgency")
    Nullable!string conceptSchemeAgency;

    @attr("assignmentStatus")
    Nullable!string assignmentStatus;

    @attr("attachmentLevel")
    Nullable!string attachmentLevel;

    @xmlElement("TextFormat")
    Nullable!SDMX20TextFormat textFormat;
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

    @attr("version")
    Nullable!string version_;

    @attr("isFinal")
    Nullable!bool isFinal;

    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElement("Components")
    SDMX20Components components;

    Nullable!DataStructure convert() pure @safe inout
    {
        import std.range : enumerate;
        import std.algorithm : any, map, joiner;
        import std.array : array;
        import std.typecons : tuple;
        import vulpes.lib.monadish : fallbackMap;

        Nullable!Dimension handleDimension(in SDMX20Dimension dim, uint pos)
        {
            if(dim.conceptRef.isNull) return typeof(return).init;

            Nullable!Dimension r = Dimension(
                dim.conceptRef.get,
                pos,
                conceptId(dim, this.agencyId),
                [],
                localRepresentation(dim, this.agencyId));

            return r;
        }

        Nullable!TimeDimension handleTimeDimension(in SDMX20TimeDimension dim, uint pos)
        {
            if(dim.conceptRef.isNull) return typeof(return).init;

            Nullable!TimeDimension r = TimeDimension(
                dim.conceptRef.get,
                pos,
                conceptId(dim, this.agencyId),
                [],
                localRepresentation(dim, this.agencyId));

            return r;
        }

        Nullable!Attribute handleAttribute(in SDMX20Attribute attr)
        {
            import std.typecons : apply;
            import std.array : array;
            import std.algorithm : joiner;

            if(attr.conceptRef.isNull) return typeof(return).init;
            Nullable!UsageType usage = attr.assignmentStatus.apply!(a => a.enumMember!UsageType);
            Nullable!AttributeRelationship rel = attr.attachmentLevel.apply!((a) {
                if(a == "Series")
                {
                    auto dims = this.components
                        .dimensions
                        .fallbackMap!"a.conceptRef"
                        .joiner
                        .array;
                    return AttributeRelationship(
                        dims,
                        (Nullable!string).init,
                        (Nullable!Empty).init,
                        (Nullable!Empty).init);
                }
                else if(a == "Observation")
                {
                    Nullable!Empty obs = Empty();
                    return AttributeRelationship(
                        [],
                        (Nullable!string).init,
                        obs,
                        (Nullable!Empty).init);
                }
                else
                {
                    Nullable!Empty df = Empty();
                    return AttributeRelationship(
                        [],
                        (Nullable!string).init,
                        (Nullable!Empty).init,
                        df);
                }
            });

            Nullable!Attribute r = Attribute(
                attr.conceptRef.get,
                usage,
                rel,
                conceptId(attr, this.agencyId),
                [],
                localRepresentation(attr, this.agencyId));
            return r;
        }

        Nullable!Measure handleMeasure(in SDMX20PrimaryMeasure mes)
        {
            if(mes.conceptRef.isNull) return typeof(return).init;

            Nullable!Measure r = Measure(
                mes.conceptRef.get,
                conceptId(mes, agencyId),
                [],
                localRepresentation(mes, agencyId),
                (Nullable!UsageType).init);
            return r;
        }

        auto cNames = names.dup;

        auto name = getLabel(cNames);

        if(name.isNull) return typeof(return).init;

        auto tDims = this.components
            .dimensions
            .dup
            .enumerate(1)
            .fallbackMap!(a => tuple(a[0], handleDimension(a[1], a[0])))
            .array;

        if(tDims.length == 0 || tDims.any!"a[1].isNull") return typeof(return).init;

        uint lastPos = tDims[$ - 1][0];

        auto dims = tDims.map!"a[1]".joiner.array;

        auto timeDim = handleTimeDimension(this.components.timeDimension, lastPos + 1);

        if(timeDim.isNull) return typeof(return).init;

        auto attrs = this.components
            .attributes
            .fallbackMap!handleAttribute;

        auto pMeasure = handleMeasure(this.components.primaryMeasure);

        Nullable!AttributeList attrList;
        if(attrs.any!"a.isNull") attrList = (Nullable!AttributeList).init;
        else attrList = AttributeList("AttributeDescriptor", attrs.joiner.array);

        Nullable!MeasureList measList;
        if(pMeasure.isNull) measList = (Nullable!MeasureList).init;
        else measList = MeasureList("MeasureDescriptor", [pMeasure.get]);

        DimensionList dimList = DimensionList("DimensionDescriptor", dims, timeDim.get);

        auto comps = DataStructureComponents(attrList, dimList, [], measList);

        Nullable!DataStructure dsd = DataStructure(
            id,
            version_.get(DefaultVersion),
            agencyId,
            true,
            isFinal.get(false),
            name.get,
            getIntlLabels(cNames),
            (Nullable!string).init,
            (Nullable!(string[Language])).init,
            comps
        );

        return dsd;
    }
}

unittest
{
    import std.file : readText;
    import std.algorithm : equal;

    auto sdmxDsd = readText("./fixtures/sdmx20/structure_alt_keyfamily_concepts_codelists.xml")
        .deserializeAsRangeOf!SDMX20KeyFamily;
    DataStructure dsd = sdmxDsd.front.convert.get;
    assert(dsd.id == "GFSMAB2015");
    assert(dsd.agencyId == "IMF");
    assert(dsd.version_ == "1.0");
    assert(dsd.name == "Government Finance Statistics Yearbook (GFSY 2015), Main Aggregates and Balances");
    assert(dsd.names.get[Language.en] == dsd.name);

    DataStructureComponents components = dsd.dataStructureComponents;
    assert(components.dimensionList.id == "DimensionDescriptor");
    assert(components.attributeList.get.id == "AttributeDescriptor");
    assert(components.measureList.get.id == "MeasureDescriptor");
    assert(components.groups.length == 0);

    Dimension d0 = components.dimensionList.dimensions[0];
    assert(d0.id == "FREQ");
    assert(d0.position == 1);
    assert(d0
        .conceptIdentity
        .get == Urn("urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=IMF:GFSMAB2015(1.0).FREQ"));
    assert(d0
        .localRepresentation
        .get
        .enumeration
        .get
        .enumeration == Urn("urn:sdmx:org.sdmx.infomodel.codelist.Codelist=IMF:CL_FREQ(1.0)"));

    Attribute a0 = components.attributeList.get.attributes[0];
    assert(a0.id == "UNIT_MULT");
    assert(a0
        .conceptIdentity
        .get == Urn("urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=IMF:GFSMAB2015(1.0).UNIT_MULT"));
    assert(!a0.localRepresentation.get.enumeration.isNull);
    assert(a0.localRepresentation.get.format.isNull);
    auto dims = a0.attributeRelationship.get.dimensions;
    assert(dims.equal(["FREQ", "REF_AREA", "REF_SECTOR", "UNIT_MEASURE", "CLASSIFICATION"]));
    assert(a0.attributeRelationship.get.observation.isNull);
    assert(a0.usage.get == UsageType.mandatory);

    Attribute a1 = components.attributeList.get.attributes[1];
    assert(a1.usage.get == UsageType.conditional);
    assert(a1.localRepresentation.get.enumeration.isNull);
    assert(a1.localRepresentation.get.format.get.dataType == BasicDataType.string_);

    Attribute a3 = components.attributeList.get.attributes[3];
    assert(!a3.attributeRelationship.get.observation.isNull);
    assert(a3.attributeRelationship.get.dimensions.length == 0);

    TimeDimension td = components.dimensionList.timeDimension;
    assert(td.id == "TIME_PERIOD");
    assert(td.position == 6);

    Measure m0 = components.measureList.get.measures[0];
    assert(m0.id == "OBS_VALUE");
    assert(m0.localRepresentation.get.format.get.dataType == BasicDataType.double_);
}

unittest
{
    import std.file : readText;
    import std.algorithm : equal;

    auto sdmxDsd = readText("./fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml")
        .deserializeAsRangeOf!SDMX20KeyFamily;
    DataStructure dsd = sdmxDsd.front.convert.get;
    DataStructureComponents components = dsd.dataStructureComponents;
    assert(components.dimensionList.id == "DimensionDescriptor");
    assert(components.attributeList.get.id == "AttributeDescriptor");
    assert(components.measureList.get.id == "MeasureDescriptor");
    assert(components.groups.length == 0);
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

    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElementList("Description")
    SDMX20Description[] descriptions;

    Nullable!Code convert() pure @safe inout
    {
        auto cDescs = descriptions.dup;

        auto name = getLabel(cDescs);

        if(name.isNull) return typeof(return).init;

        Nullable!Code r = Code(
            value,
            name.get,
            getIntlLabels(cDescs),
            (Nullable!string).init,
            (Nullable!(string[Language])).init);

        return r;
    }
}

@xmlRoot("CodeList")
struct SDMX20Codelist
{
    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElementList("Description")
    SDMX20Description[] descriptions;

    @xmlElementList("Code")
    SDMX20Code[] codes;

    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @attr("version")
    Nullable!string version_;

    Nullable!Codelist convert() pure @safe inout
    {
        return convertListOfItems!(typeof(this), Codelist, "codes")(this);
    }
}

unittest
{
    import std.file : readText;

    auto sdmxCls = readText("./fixtures/sdmx20/structure_alt_keyfamily_concepts_codelists.xml")
        .deserializeAsRangeOf!SDMX20Codelist;

    Codelist cl = sdmxCls.front.convert.get;
    assert(cl.id == "CL_UNIT_MULT");
    assert(cl.name == "Scale");
    assert(cl.codes[0].id == "0");
    assert(cl.codes[0].name == "Units");
}

unittest
{
    import std.file : readText;

    auto sdmxCls = readText("./fixtures/sdmx20/structure_keyfamily_concepts_codelists.xml")
        .deserializeAsRangeOf!SDMX20Codelist;

    Codelist cl = sdmxCls.front.convert.get;
    assert(cl.id == "CL_QNA_LOCATION");
    assert(cl.name == "Country");
    assert(cl.codes[0].id == "AUS");
    assert(cl.codes[0].name == "Australia");
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

    @attr("version")
    Nullable!string version_;

    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElementList("Description")
    SDMX20Description[] descriptions;

    Nullable!Concept convert() pure @safe inout
    {
        return convertIdentifiableItem!(typeof(this), Concept)(this);
    }
}

@xmlRoot("ConceptScheme")
struct SDMX20ConceptScheme
{
    @attr("id")
    string id;

    @attr("agencyID")
    string agencyId;

    @attr("version")
    string version_;

    @xmlElementList("Name")
    SDMX20Name[] names;

    @xmlElementList("Description")
    SDMX20Description[] descriptions;

    @xmlElementList("Concept")
    SDMX20Concept[] concepts;

    Nullable!ConceptScheme convert() pure @safe inout
    {
        return convertListOfItems!(typeof(this), ConceptScheme, "concepts")(this);
    }
}

unittest
{
    import std.file : readText;
    auto sdmxCss = readText("./fixtures/sdmx20/structure_alt_keyfamily_concepts_codelists.xml")
        .deserializeAsRangeOf!SDMX20ConceptScheme;

    ConceptScheme cs = sdmxCss.front.convert.get;
    assert(cs.id == "GFSMAB2015");
    assert(cs.name == "Government Finance Statistics Yearbook (GFSY 2015), Main Aggregates and Balances");
    assert(cs.concepts[0].id == "OBS_VALUE");
    assert(cs.concepts[0].name == "Value");
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

public:
alias buildDataflows = buildRangeFromXml!(SDMX20Dataflow, Dataflow, string);
alias buildDataStructures = buildRangeFromXml!(SDMX20KeyFamily, DataStructure, string);
alias buildCodelists = buildRangeFromXml!(SDMX20Codelist, Codelist, string);
alias buildConceptSchemes = buildRangeFromXml!(SDMX20ConceptScheme, ConceptScheme, string);