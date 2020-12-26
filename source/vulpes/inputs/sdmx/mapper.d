module vulpes.inputs.sdmx.mapper;

package:
import std.conv : to;
import std.typecons : Nullable, nullable;
import std.algorithm : map, filter;
import std.array : array;
import vulpes.inputs.sdmx.types;
import vulpes.core.models;

enum hasMember(ResourceT, MemberT, alias memberName) =
    is(typeof(__traits(getMember, ResourceT, memberName)) == MemberT)
    || is(typeof(__traits(getMember, ResourceT, memberName)) == const(MemberT));

Nullable!Label toLabel(const SDMXName name) pure nothrow @safe
{
    try
    {
        return Label(name.lang.to!Language, name.content).nullable;
    }
    catch(Exception e)
    {
        return typeof(return).init;
    }
}

auto toLabels(T)(T resource) pure nothrow @safe
if(hasMember!(T, SDMXName[], "names"))
{
    return resource.names
        .map!toLabel
        .filter!(l => !l.isNull)
        .map!(l => l.get)
        .array;
}

@safe unittest
{
    static struct SDMXResource
    {
        SDMXName[] names;
    }

    import std.algorithm : equal;
    const r = SDMXResource([SDMXName("fr", "foo"), SDMXName("unknown", "bar")]);
    const l = r.toLabels;
    assert(l.equal([Label(Language.fr, "foo", Nullable!string.init)]));
}

Nullable!(const(SDMXConcept)) findSDMXConcept(T)(T resource, const(SDMXConcept)[] concepts) pure nothrow @safe
if(hasMember!(T, Nullable!SDMXConceptIdentity, "conceptIdentity"))
{
    if(resource.conceptIdentity.isNull)
        return typeof(return).init;

    const conceptId = resource.conceptIdentity.get.ref_.id;

    auto s = concepts
        .filter!(c => c.id == conceptId);

    if(s.empty)
        return typeof(return).init;

    return s.front.nullable();

}

@safe unittest
{
    static struct SDMXResource
    {
        Nullable!SDMXConceptIdentity conceptIdentity;
    }

    const r = SDMXResource(SDMXConceptIdentity(SDMXRef("concept")).nullable);
    const cs = [
        const(SDMXConcept)("concept", "urn", [SDMXName("fr", "concept")]),
        const(SDMXConcept)("other", "urn", [SDMXName("fr", "other")])
    ];
    const sConcept = r.findSDMXConcept(cs);
    assert(!sConcept.isNull);
    assert(sConcept.get.id == "concept");

    assert(r.findSDMXConcept(
        [
            const(SDMXConcept)("other", "urn", [SDMXName("fr", "other")])
        ]
    ).isNull);
    const nr = SDMXResource((Nullable!SDMXConceptIdentity).init);
    assert(nr.findSDMXConcept(cs).isNull);
}

Concept toConcept(const SDMXConcept concept) pure nothrow @safe
{
    return Concept(concept.id, concept.toLabels);
}

@safe unittest
{
    const SDMXConcept concept = SDMXConcept("foo", "urn", [SDMXName("en", "foo")]);
    assert(concept.toConcept == Concept("foo", [Label(Language.en, "foo", (Nullable!string).init)]));
}

Nullable!(const(SDMXCodelist)) findSDMXCodelist(T)(T resource, const(SDMXCodelist)[] codelists) pure nothrow @safe
if(hasMember!(T, Nullable!SDMXLocalRepresentation, "localRepresentation"))
{
    if(resource.localRepresentation.isNull || resource.localRepresentation.get.enumeration.isNull)
        return typeof(return).init;

    const clId = resource.localRepresentation.get.enumeration.get.ref_.id;
    auto codelist = codelists.filter!(c => c.id == clId);

    if(codelist.empty)
        return typeof(return).init;

    return codelist.front.nullable;
}

@safe unittest
{
    import std.algorithm : equal;
    static struct SDMXResource
    {
        Nullable!SDMXLocalRepresentation localRepresentation;
    }

    const r = SDMXResource(SDMXLocalRepresentation(
        (Nullable!SDMXTextFormat).init,
        SDMXEnumeration(SDMXRef("codelist")).nullable).nullable);

    const cls = [
        const(SDMXCodelist)("codelist", "urn", "agency", "1.0", [], [
            const(SDMXCode)("code1", "urn", [SDMXName("fr", "code1")]),
            const(SDMXCode)("code2", "urn", [SDMXName("fr", "code2")])
        ]),
        const(SDMXCodelist)("other", "urn", "agency", "1.0", [], [
            const(SDMXCode)("other1", "urn", [SDMXName("fr", "other1")]),
            const(SDMXCode)("other2", "urn", [SDMXName("fr", "other2")])
        ])
    ];

    const codes = r.findSDMXCodelist(cls).get.codes;
    assert(codes.equal([
            const(SDMXCode)("code1", "urn", [SDMXName("fr", "code1")]),
            const(SDMXCode)("code2", "urn", [SDMXName("fr", "code2")])
        ]));
    assert(r.findSDMXCodelist([
        const(SDMXCodelist)("other", "urn", "agency", "1.0", [], [
            const(SDMXCode)("other1", "urn", [SDMXName("fr", "other1")]),
            const(SDMXCode)("other2", "urn", [SDMXName("fr", "other2")])
        ])
    ]).isNull);

    assert(findSDMXCodelist(SDMXResource((Nullable!SDMXLocalRepresentation).init), cls).isNull);
}

Code toCode(const SDMXCode code) pure nothrow @safe
{
    return Code(code.id, code.toLabels);
}

@safe unittest
{
    assert(SDMXCode("foo", "urn", [SDMXName("en", "foo")]).toCode ==
        Code("foo", [Label(Language.en, "foo", (Nullable!string).init)]));
}

Code[] toCodes(const SDMXCodelist codelist) pure nothrow @safe
{
    return codelist.codes
        .map!toCode
        .array;
}

Dimension toDimension(T)(
    T dimension, const(SDMXCodelist)[] codelists, const(SDMXConcept)[] concepts) pure nothrow @safe
if((is(T: SDMXDimension) || is(T: SDMXTimeDimension)))
{
    const codelist = dimension.findSDMXCodelist(codelists);
    const sdmxConcept = dimension.findSDMXConcept(concepts);

    auto labels = codelist.isNull ? [] : codelist.get.toLabels;
    auto id = dimension.id;
    auto concept = sdmxConcept.isNull
        ? (Nullable!Concept).init
        : sdmxConcept.get.toConcept.nullable;
    auto codes = codelist.isNull
        ? []
        : codelist.get.toCodes;

    static if(is(T == SDMXDimension))
    {
        return Dimension(
            id,
            labels,
            false,
            codes,
            concept
        );
    }
    else {
        return Dimension(
            id,
            labels,
            true,
            codes,
            concept
        );
    }
}

Attribute toAttribute(
    const SDMXAttribute attr, const(SDMXCodelist)[] codelists, const(SDMXConcept)[] concepts) pure nothrow @safe
{
    auto codelist = attr.findSDMXCodelist(codelists);
    auto concept = attr.findSDMXConcept(concepts);

    return Attribute(
        attr.id.nullable,
        codelist.isNull ? [] : codelist.get.toLabels,
        codelist.isNull ? [] : codelist.get.toCodes,
        concept.isNull ? (Nullable!Concept).init : concept.get.toConcept.nullable);
}

Measure toMeasure(
    const SDMXPrimaryMeasure measure, const(SDMXConcept)[] concepts) pure nothrow @safe
{
    auto concept = measure.findSDMXConcept(concepts);

    return Measure(
        measure.id.isNull
            ? (Nullable!string).init
            : measure.id.get.nullable,
            [],
            concept.isNull
                ? (Nullable!Concept).init
                : concept.get.toConcept.nullable);
}

public:
CubeDefinition toDefinition(
    const SDMXDataStructure structure,
    const(SDMXCodelist)[] codelists,
    const(SDMXConcept)[] concepts) pure nothrow @safe
{
    auto dimensions = structure.dataStructureComponents.dimensionList.dimensions
            .map!(d => d.toDimension(codelists, concepts))
            .array;

    auto attrs = structure.dataStructureComponents.attributeList.attributes
        .map!(a => a.toAttribute(codelists, concepts))
        .array;

    auto measure = structure.dataStructureComponents.measureList.primaryMeasure
        .toMeasure(concepts);

    return CubeDefinition(
        structure.agencyId,
        structure.id,
        dimensions,
        attrs,
        [measure]
    );
}

unittest
{
    import std.file : readText;
    import vulpes.lib.xml : deserializeAs;
    import std.array : join;

    const SDMXStructures structures = readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    const CubeDefinition def = toDefinition(
        structures.dataStructures.get.dataStructures[0],
        structures.codelists.get.codelists,
        structures.concepts.get.conceptSchemes
            .map!(cs => cs.concepts)
            .array
            .join);
}

Nullable!CubeDescription toDescription(const SDMXDataflow df) pure nothrow @safe
{
    if(df.id.isNull || df.agencyId.isNull || df.structure.isNull)
        return typeof(return).init;

    return CubeDescription(
        df.agencyId.get,
        df.id.get,
        df.toLabels,
        df.structure.get.ref_.id,
        []).nullable;
}

@safe unittest
{
    import std.algorithm : equal;
    const df = SDMXDataflow(
        "foo".nullable,
        "urn".nullable,
        "agency".nullable,
        "1.0".nullable,
        false.nullable,
        [SDMXName("fr", "foo")],
        SDMXStructure(SDMXRef("struct_foo")).nullable);

    const cd = df.toDescription;
    assert(cd.get.providerId == "agency");
    assert(cd.get.id == "foo");
    assert(cd.get.labels.equal([Label(Language.fr, "foo")]));
    assert(cd.get.definitionId == "struct_foo");

    assert(SDMXDataflow().toDescription.isNull);
}