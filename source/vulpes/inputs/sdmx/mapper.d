module vulpes.inputs.sdmx.mapper;

package:
import std.conv : to;
import std.typecons : Nullable, nullable, Tuple, tuple;
import std.algorithm : map, filter, joiner;
import std.range : isInputRange, ElementType, chain;
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
        const(SDMXConcept)("concept", "urn".nullable, [SDMXName("fr", "concept")]),
        const(SDMXConcept)("other", "urn".nullable, [SDMXName("fr", "other")])
    ];
    const sConcept = r.findSDMXConcept(cs);
    assert(!sConcept.isNull);
    assert(sConcept.get.id == "concept");

    assert(r.findSDMXConcept(
        [
            const(SDMXConcept)("other", "urn".nullable, [SDMXName("fr", "other")])
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
    const SDMXConcept concept = SDMXConcept("foo", "urn".nullable, [SDMXName("en", "foo")]);
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
        const(SDMXCodelist)("codelist", "urn".nullable, "agency", "1.0", [], [
            const(SDMXCode)("code1", "urn".nullable, [SDMXName("fr", "code1")]),
            const(SDMXCode)("code2", "urn".nullable, [SDMXName("fr", "code2")])
        ]),
        const(SDMXCodelist)("other", "urn".nullable, "agency", "1.0", [], [
            const(SDMXCode)("other1", "urn".nullable, [SDMXName("fr", "other1")]),
            const(SDMXCode)("other2", "urn".nullable, [SDMXName("fr", "other2")])
        ])
    ];

    const codes = r.findSDMXCodelist(cls).get.codes;
    assert(codes.equal([
            const(SDMXCode)("code1", "urn".nullable, [SDMXName("fr", "code1")]),
            const(SDMXCode)("code2", "urn".nullable, [SDMXName("fr", "code2")])
        ]));
    assert(r.findSDMXCodelist([
        const(SDMXCodelist)("other", "urn".nullable, "agency", "1.0", [], [
            const(SDMXCode)("other1", "urn".nullable, [SDMXName("fr", "other1")]),
            const(SDMXCode)("other2", "urn".nullable, [SDMXName("fr", "other2")])
        ])
    ]).isNull);

    assert(findSDMXCodelist(SDMXResource((Nullable!SDMXLocalRepresentation).init), cls).isNull);
}

Nullable!(const(SDMXKeyValue)) findSDMXKeyValue(T)(T resource, const(SDMXKeyValue)[] keyValues) pure nothrow @safe
if(is(T: const(SDMXDimension)) || is(T: const(SDMXTimeDimension)) || is(T: const(SDMXAttribute)))
{
    auto res = keyValues
        .filter!(kv => !resource.id.isNull && kv.id == resource.id.get);

    return res.empty
        ? typeof(return).init
        : res.front.nullable;
}

Code toCode(const SDMXCode code) pure nothrow @safe
{
    return Code(code.id, code.toLabels);
}

@safe unittest
{
    assert(SDMXCode("foo", "urn".nullable, [SDMXName("en", "foo")]).toCode ==
        Code("foo", [Label(Language.en, "foo", (Nullable!string).init)]));
}

Code[] toCodes(const SDMXCodelist codelist, const SDMXKeyValue keyValue) pure nothrow @safe
{
    auto filterByConstraint(const SDMXCode code)
    {
        import std.algorithm : canFind;

        return keyValue.values
            .filter!(v => !v.content.isNull)
            .map!(v => v.content.get)
            .canFind(code.id);
    }
    return codelist.codes
        .filter!filterByConstraint
        .map!toCode
        .array;
}

Code[] toCodes(const SDMXCodelist codelist) pure nothrow @safe
{
    return codelist.codes
        .map!toCode
        .array;
}

auto flattenConstraints(const SDMXConstraints constraints) pure nothrow @safe
{
    import std.array : join;
    return constraints.constraints
        .filter!(c => !c.cubeRegion.isNull)
        .map!(c => c.cubeRegion.get.keyValues)
        .array
        .join;
}

Dimension toDimension(T)(
    T dimension,
    const(SDMXCodelist)[] codelists,
    const(SDMXConcept)[] concepts,
    const (SDMXKeyValue)[] keyValues) pure nothrow @safe
if((is(T: SDMXDimension) || is(T: SDMXTimeDimension)))
{
    const codelist = dimension.findSDMXCodelist(codelists);
    const sdmxConcept = dimension.findSDMXConcept(concepts);
    const keyValue = dimension.findSDMXKeyValue(keyValues);

    auto labels = codelist.isNull ? [] : codelist.get.toLabels;
    auto id = dimension.id;
    auto concept = sdmxConcept.isNull
        ? (Nullable!Concept).init
        : sdmxConcept.get.toConcept.nullable;
    auto codes = codelist.isNull
        ? []
        : keyValue.isNull
            ? codelist.get.toCodes
            : codelist.get.toCodes(keyValue.get);

    static if(is(T: SDMXDimension))
    {
        return Dimension(
            id,
            labels,
            false,
            codes,
            concept
        );
    }
    else static if(is(T: SDMXTimeDimension))
    {
        return Dimension(
            id,
            labels,
            true,
            codes,
            concept
        );
    }
    else
    {
        static assert(false);
    }
}

Attribute toAttribute(
    const SDMXAttribute attr,
    const(SDMXCodelist)[] codelists,
    const(SDMXConcept)[] concepts,
    const (SDMXKeyValue)[] keyValues) pure nothrow @safe
{
    auto codelist = attr.findSDMXCodelist(codelists);
    auto concept = attr.findSDMXConcept(concepts);
    const keyValue = attr.findSDMXKeyValue(keyValues);

    return Attribute(
        attr.id,
        codelist.isNull ? [] : codelist.get.toLabels,
        codelist.isNull
            ? []
            : keyValue.isNull
                ? codelist.get.toCodes
                : codelist.get.toCodes(keyValue.get),
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
    import vulpes.lib.xml : deserializeAs;

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

public:
CubeDefinition toDefinition(
    const SDMXDataStructure structure,
    const(SDMXCodelist)[] codelists,
    const(SDMXConcept)[] concepts,
    const Nullable!SDMXConstraints constraints) pure nothrow @safe
{
    auto keyValues = constraints.isNull
        ? []
        : flattenConstraints(constraints.get);

    auto dimensions = structure.dataStructureComponents.dimensionList.dimensions
            .map!(d => d.toDimension(codelists, concepts, keyValues))
            .chain(
                [structure.dataStructureComponents.dimensionList.timeDimension
                    .toDimension(codelists, concepts, keyValues)]
            ).array;

    auto attrs = structure.dataStructureComponents.attributeList.attributes
        .map!(a => a.toAttribute(codelists, concepts, keyValues))
        .array;

    auto measure = structure.dataStructureComponents.measureList.primaryMeasure
        .toMeasure(concepts);

    return CubeDefinition(
        structure.agencyId,
        structure.id,
        dimensions,
        attrs,
        [measure],
        constraints.isNull
            ? [Warning.no_code_constraint_provided]
            : []
    );
}

unittest
{
    import std.file : readText;
    import vulpes.lib.xml : deserializeAs;
    import std.array : join;

    const structures = readText("./fixtures/sdmx/structure_dsd_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    auto dataStructure = structures.dataStructures.get.dataStructures[0];
    auto codelists = structures.codelists.get.codelists;
    auto concepts = structures.concepts.get.conceptSchemes
        .map!(cs => cs.concepts)
        .array
        .join;

    auto def = toDefinition(
        dataStructure,
        codelists,
        concepts,
        structures.constraints);

    assert(def.id == "DSD_nama_10_gdp");
    assert(def.warnings.length == 1);
    assert(def.providerId == "ESTAT");
    assert(def.measures.length == 1);
    assert(def.measures[0].id == "OBS_VALUE");
    assert(!def.measures[0].concept.isNull);
    assert(def.measures[0].concept.get == Concept("OBS_VALUE", [Label(Language.en, "Observation value.")]));

    assert(def.dimensions.length == 5);
    assert(def.dimensions[0].id == "FREQ");
    assert(!def.dimensions[0].isTimeDimension);
    assert(def.dimensions[0].labels == [Label(Language.en, "FREQ")]);
    assert(!def.dimensions[0].concept.isNull);
    assert(def.dimensions[0].concept.get == Concept("FREQ", [Label(Language.en, "FREQ")]));
    assert(def.dimensions[0].codes.length == 7);
    assert(def.dimensions[0].codes[0].id == "D");
    assert(def.dimensions[0].codes[0].labels == [Label(Language.en, "Daily")]);
    assert(def.dimensions[4].id == "TIME_PERIOD");
    assert(def.dimensions[4].labels == []);
    assert(def.dimensions[4].isTimeDimension);
    assert(!def.dimensions[4].concept.isNull);
    assert(def.dimensions[4].concept.get == Concept("TIME", [Label(Language.en, "TIME")]));
    assert(def.dimensions[4].codes.length == 0);

    assert(def.attributes.length == 2);
    assert(def.attributes[0].id == "OBS_FLAG");
    assert(!def.attributes[0].concept.isNull);
    assert(def.attributes[0].concept.get == Concept("OBS_FLAG", [Label(Language.en, "Observation flag.")]));
    assert(def.attributes[0].codes.length == 12);
    assert(def.attributes[0].codes[0] == Code("f", [Label(Language.en, "forecast")]));

}

unittest
{
    import std.file : readText;
    import vulpes.lib.xml : deserializeAs;
    import std.array : join;

    auto structures = readText(
        "./fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml")
        .deserializeAs!SDMXStructures;

    auto dataStructure = structures.dataStructures.get.dataStructures[0];
    auto codelists = structures.codelists.get.codelists;
    auto concepts = structures.concepts.get.conceptSchemes
        .map!(cs => cs.concepts)
        .array
        .join;

    auto def = toDefinition(
        dataStructure,
        codelists,
        concepts,
        structures.constraints);
    assert(def.warnings.length == 0);
    assert(def.dimensions.length == 4);
    assert(def.dimensions[1].codes.length > 1);
    assert(def.dimensions[2].codes.length == 1);
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