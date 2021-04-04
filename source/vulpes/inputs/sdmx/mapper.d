module vulpes.inputs.sdmx.mapper;

package:
import std.conv : to;
import std.typecons : Nullable, nullable, Tuple, tuple;
import std.algorithm : map, filter, joiner;
import std.range : isInputRange, ElementType, chain;
import std.array : array;
import vulpes.inputs.sdmx.types;
import vulpes.core.cube;

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

auto extractIdAndAgencyId(const SDMXRef ref_, const SDMXDataStructure structure)
{
    return ref_.agencyId.isNull
        ? AgencyReferencePair(structure.agencyId, ref_.id)
        : AgencyReferencePair(ref_.agencyId.get, ref_.id);
}

auto gatherResourceRefs(T)(T resources) pure nothrow @safe
if(isInputRange!T && (is(ElementType!T: const(SDMXAttribute)) || is(ElementType!T: const(SDMXDimension))))
{
    return resources
        .filter!(d =>
            !d.localRepresentation.isNull
            && !d.localRepresentation.get.enumeration.isNull
            && !d.id.isNull)
        .map!(d => ResourceRefPair(d.id.get, d.localRepresentation.get.enumeration.get.ref_));
}

auto gatherResourceConcept(T)(T resources) pure nothrow @safe
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

auto gatherEnumerationRefs(const SDMXDataStructure structure) pure nothrow @safe
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

auto checkObservation(const SDMXObs obs, const string measureId, const string dimAtObservationId) pure nothrow @safe
{
    if(obs.structureAttributes)
    {
        if(measureId !in obs.structureAttributes)
            return false;
        if(dimAtObservationId !in obs.structureAttributes)
            return false;
        return true;
    }
    if(obs.obsDimension.isNull)
        return false;
    return true;
}

@safe unittest
{
    assert(SDMXObs(
        SDMXObsDimension("2021-01-24").nullable,
        SDMXObsValue(3.14.nullable).nullable,
        SDMXAttributes([SDMXValue("foo".nullable, "bar".nullable)]).nullable,
        null
    ).checkObservation(null, "time"));

    assert(!SDMXObs(
        (Nullable!SDMXObsDimension).init,
        SDMXObsValue(3.14.nullable).nullable,
        SDMXAttributes([SDMXValue("foo".nullable, "bar".nullable)]).nullable,
        null
    ).checkObservation(null, "time"));

    assert(SDMXObs(
        (Nullable!SDMXObsDimension).init,
        (Nullable!SDMXObsValue).init,
        (Nullable!SDMXAttributes).init,
        ["foo": "bar", "obs": "3.14", "time": "2021-02-15"]
    ).checkObservation("obs", "time"));

    assert(!SDMXObs(
        (Nullable!SDMXObsDimension).init,
        (Nullable!SDMXObsValue).init,
        (Nullable!SDMXAttributes).init,
        ["foo": "bar", "othr": "3.14", "time": "2021-02-15"]
    ).checkObservation("obs", "time"));

    assert(!SDMXObs(
        (Nullable!SDMXObsDimension).init,
        (Nullable!SDMXObsValue).init,
        (Nullable!SDMXAttributes).init,
        ["foo": "bar", "obs": "3.14", "othr": "2021-02-15"]
    ).checkObservation("obs", "time"));
}

auto toObservation(
    const SDMXObs obs,
    const string measureId,
    const string dimAtObservationId) pure nothrow @safe
{
    if(obs.structureAttributes)
    {
        auto obsDim = Value!string(
            obs.structureAttributes[dimAtObservationId].nullable,
            dimAtObservationId);

        import std.array : byPair;
        auto attrs = obs.structureAttributes.byPair
            .filter!(t => t[0] != measureId && t[0] != dimAtObservationId)
            .map!(t => Value!string(t[1].nullable, t[0]))
            .array;

        Nullable!double obsValue;
        try
        {
            obsValue = obs.structureAttributes[measureId].to!double.nullable;
        }
        catch(Exception){}

        return Observation!double(Value!double(obsValue, measureId), obsDim, attrs);
    }

    return Observation!double(
        obs.obsValue.isNull
            ? Value!double((Nullable!double).init, measureId)
            : Value!double(obs.obsValue.get.value, measureId),
        Value!string(obs.obsDimension.get.value.nullable, dimAtObservationId),
        obs.attributes.isNull
        ? []
        : obs.attributes.get.values
            .filter!(a => !a.id.isNull)
            .map!(a => Value!string(a.value, a.id.get))
            .array);
}

@safe unittest
{
    const obs1 = SDMXObs(
        SDMXObsDimension("2021-01-24").nullable,
        SDMXObsValue(3.14.nullable).nullable,
        SDMXAttributes([SDMXValue("foo".nullable, "bar".nullable)]).nullable,
        null
    ).toObservation("obs", "time");

    assert(obs1.obsValue.value.get == 3.14);
    assert(obs1.obsValue.id == "obs");
    assert(obs1.attributes.length == 1);
    assert(obs1.attributes[0].id == "foo");
    assert(obs1.attributes[0].value.get == "bar");
    assert(obs1.obsDimension.id == "time");
    assert(obs1.obsDimension.value.get == "2021-01-24");

    const obs2 = SDMXObs(
        SDMXObsDimension("2021-01-24").nullable,
        (Nullable!SDMXObsValue).init,
        SDMXAttributes([SDMXValue("foo".nullable, "bar".nullable)]).nullable,
        null
    ).toObservation("obs", "time");

    assert(obs2.obsValue.value.isNull);

    const obs3 = SDMXObs(
        SDMXObsDimension("2021-01-24").nullable,
        SDMXObsValue(3.14.nullable).nullable,
        (Nullable!SDMXAttributes).init,
        null
    ).toObservation("obs", "time");

    assert(obs3.attributes.length == 0);

    const obs4 = SDMXObs(
        (Nullable!SDMXObsDimension).init,
        (Nullable!SDMXObsValue).init,
        (Nullable!SDMXAttributes).init,
        ["foo": "bar", "obs": "3.14", "time": "2021-02-15"]
    ).toObservation("obs", "time");

    assert(obs4.obsValue.value.get == 3.14);
    assert(obs4.obsValue.id == "obs");
    assert(obs4.attributes.length == 1);
    assert(obs4.attributes[0].id == "foo");
    assert(obs4.attributes[0].value.get == "bar");
    assert(obs4.obsDimension.id == "time");
    assert(obs4.obsDimension.value.get == "2021-02-15");

    const obs5 = SDMXObs(
        (Nullable!SDMXObsDimension).init,
        (Nullable!SDMXObsValue).init,
        (Nullable!SDMXAttributes).init,
        ["foo": "bar", "obs": "NotConvertible", "time": "2021-02-15"]
    ).toObservation("obs", "time");

    assert(obs5.obsValue.value.isNull);
    assert(obs5.obsValue.id == "obs");
    assert(obs5.attributes.length == 1);
    assert(obs5.attributes[0].id == "foo");
    assert(obs5.attributes[0].value.get == "bar");
    assert(obs5.obsDimension.id == "time");
    assert(obs5.obsDimension.value.get == "2021-02-15");
}

auto toSerieFromStructureSpecific(
    const SDMXSeries series,
    const string measureId,
    const string dimAtObservationId,
    const string[] dimensionIds) pure nothrow @safe
{
    import std.array : byPair;
    import std.algorithm: canFind;

    auto dimensions = series.structureKeys.byPair
        .filter!(t => dimensionIds.canFind(t.key))
        .map!(t => Value!string(t.value.nullable, t.key))
        .array;

    auto attributes = series.structureKeys.byPair
        .filter!(t => !dimensionIds.canFind(t.key))
        .map!(t => Value!string(t.value.nullable, t.key))
        .array;

    auto observations = series.observations
        .filter!(o => o.checkObservation(measureId, dimAtObservationId))
        .map!(o => o.toObservation(measureId, dimAtObservationId))
        .array;

    return Serie!double(observations, dimensions, attributes);
}

auto toSerieFromGeneric(
    const SDMXSeries series,
    const string measureId,
    const string dimAtObservationId) pure nothrow @safe
{
    auto dimensions = series.seriesKey.isNull
        ? []
        : series.seriesKey.get.values
            .filter!(v => !v.id.isNull)
            .map!(v => Value!string(v.value, v.id.get))
            .array;

    auto attributes = series.attributes.isNull
        ? []
        : series.attributes.get.values
            .filter!(v => !v.id.isNull)
            .map!(v => Value!string(v.value, v.id.get))
            .array;

    auto observations = series.observations
        .filter!(o => o.checkObservation(measureId, dimAtObservationId))
        .map!(o => o.toObservation(measureId, dimAtObservationId))
        .array;

    return Serie!double(observations, dimensions, attributes);
}

auto toSerie(
    const SDMXSeries series,
    const string measureId,
    const string dimAtObservationId,
    const string[] dimensionIds) pure nothrow @safe
{
    if(series.structureKeys)
    {
        return series.toSerieFromStructureSpecific(measureId, dimAtObservationId, dimensionIds);
    }

    return series.toSerieFromGeneric(measureId, dimAtObservationId);
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
        constraints.isNull ? NoConstraint.yes : NoConstraint.no,
        measure.id.isNull ? MissingMeasureId.yes : MissingMeasureId.no,
        !dimensions.filter!(d => d.id.isNull).empty ? MissingDimensionId.yes : MissingDimensionId.no
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
    assert(!def.missingDimensionId);
    assert(!def.missingMeasureId);
    assert(def.noConstraint);
    assert(def.providerId == "ESTAT");
    assert(def.measures.length == 1);
    assert(def.measures[0].id == "OBS_VALUE");
    assert(!def.measures[0].concept.isNull);
    assert(def.measures[0].concept.get == Concept("OBS_VALUE", [Label(Language.en, "Observation value.")]));

    assert(def.dimensions.length == 5);
    assert(def.dimensions[0].id == "FREQ");
    assert(!def.dimensions[0].isObsDimension);
    assert(def.dimensions[0].labels == [Label(Language.en, "FREQ")]);
    assert(!def.dimensions[0].concept.isNull);
    assert(def.dimensions[0].concept.get == Concept("FREQ", [Label(Language.en, "FREQ")]));
    assert(def.dimensions[0].codes.length == 7);
    assert(def.dimensions[0].codes[0].id == "D");
    assert(def.dimensions[0].codes[0].labels == [Label(Language.en, "Daily")]);
    assert(def.dimensions[4].id == "TIME_PERIOD");
    assert(def.dimensions[4].labels == []);
    assert(def.dimensions[4].isObsDimension);
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
    assert(!def.missingDimensionId);
    assert(!def.missingMeasureId);
    assert(!def.noConstraint);
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

auto toDataset(
    const SDMXDataSet dataset,
    const string measureId,
    const string dimAtObservationId,
    const string[] dimensionIds = []
    ) pure nothrow @safe
{
    return Dataset!double(
        dataset.series
            .map!(s => s.toSerie(measureId, dimAtObservationId, dimensionIds))
            .array);
}

unittest
{
    import std.file : readText;
    import vulpes.lib.xml : deserializeAs;

    const dataset = readText("./fixtures/sdmx/data_generic.xml")
        .deserializeAs!SDMXDataSet;

    const measureId = "OBS_VALUE";
    const dimAtObservationId = "TIME_PERIOD";

    auto result = dataset.toDataset(measureId, dimAtObservationId);
    assert(result.series.length == 3);
    assert(result.series[0].dimensions.length == 10);
    assert(result.series[0].dimensions[0].id == "BASIND");
    assert(result.series[0].dimensions[0].value.get == "SO");
    assert(result.series[0].attributes.length == 5);
    assert(result.series[0].attributes[0].id == "IDBANK");
    assert(result.series[0].attributes[0].value.get == "001694113");
    assert(result.series[0].observations.length == 10);
    assert(result.series[0].observations[0].obsValue.value.get == 4027.);
    assert(result.series[0].observations[0].obsValue.id == "OBS_VALUE");
    assert(result.series[0].observations[0].obsDimension.id == "TIME_PERIOD");
    assert(result.series[0].observations[0].obsDimension.value.get == "2020-10");
    assert(result.series[0].observations[0].attributes.length == 3);
    assert(result.series[0].observations[0].attributes[0].id == "OBS_STATUS");
    assert(result.series[0].observations[0].attributes[0].value.get == "A");
}

unittest
{
    import std.file : readText;
    import vulpes.lib.xml : deserializeAs;
    import std.algorithm : canFind;

    const dataset = readText("./fixtures/sdmx/data_specific.xml")
        .deserializeAs!SDMXDataSet;

    const measureId = "OBS_VALUE";
    const dimAtObservationId = "TIME_PERIOD";
    const dimensionIds = ["FREQ", "REF_AREA", "INDICATOR"];

    auto result = dataset.toDataset(measureId, dimAtObservationId, dimensionIds);
    assert(result.series.length == 3);
    assert(result.series[0].dimensions.length == 3);
    assert(dimensionIds.canFind(result.series[0].dimensions[0].id));
    assert(["A", "FR", "FCAA_NUM"].canFind(result.series[0].dimensions[0].value.get));
    assert(result.series[0].attributes.length == 2);
    assert(["UNIT_MULT", "TIME_FORMAT"].canFind(result.series[0].attributes[0].id));
    assert(["0", "P1Y"].canFind(result.series[0].attributes[0].value.get));
    assert(result.series[0].observations.length == 0);
    assert(result.series[2].observations.length == 1);
    assert(result.series[2].observations[0].obsDimension.id == "TIME_PERIOD");
    assert(result.series[2].observations[0].obsDimension.value.get == "2019");
    assert(result.series[2].observations[0].obsValue.value.get == 38_254.592);
    assert(result.series[2].observations[0].obsValue.id == "OBS_VALUE");
}