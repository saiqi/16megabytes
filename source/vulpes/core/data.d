module vulpes.core.data;

import vulpes.core.model;
import vulpes.core.query : DataQuery;

///Dedicated module `Exception`
class DataServiceException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

private StructureComponent buildStructureComponent(R)(
    R resource, DataQuery query, Codelist[] codelists, ConceptScheme[] conceptSchemes) @safe
if(isDsdComponent!R)
{
    import std.exception : enforce;
    import std.format : format;
    import std.traits : Unqual;
    import std.algorithm : map, sort, filter;
    import std.array : array;
    import std.typecons : Nullable;
    import vulpes.lib.operations : innerjoin;
    import vulpes.core.structure : findCodelist, findConcept;

    auto concept = resource.findConcept(conceptSchemes);
    enforce!DataServiceException(!concept.isNull,
                                 format!"Cannot find the concept corresponding to %s"(resource.id));
    auto cl = resource.findCodelist(codelists);

    StructureComponentValue[] values;
    Nullable!Format fmt;
    if(!resource.localRepresentation.isNull)
        fmt = resource.localRepresentation.get.format;

    static if(is(Unqual!R == Dimension) || is(Unqual!R == TimeDimension))
    {
        Nullable!uint keyPosition = resource.position;
        Nullable!AttributeRelationship relationship;
        if(!cl.isNull)
        {
            auto qcs = query.components.filter!(a => a.position == resource.position);
            enforce!DataServiceException(!qcs.empty,
                                        format!"Cannot find the query component corresponding to %s"(resource.id));
            auto qc = qcs.front;
            values = qc.isWildcard
                ? cl.get.codes.map!(a => StructureComponentValue(a.id, a.name, a.names)).array
                : cl.get.codes
                    .sort!"a.id < b.id"
                    .innerjoin!(c => c.id, v => v)(qc.values.sort)
                    .map!(a => StructureComponentValue(a.left.id, a.left.name, a.left.names))
                    .array;
        }
    }
    else static if(is(Unqual!R == Attribute))
    {
        Nullable!uint keyPosition;
        Nullable!AttributeRelationship relationship = resource.attributeRelationship;
        if(!cl.isNull)
            values = cl.get.codes.map!(a => StructureComponentValue(a.id, a.name, a.names)).array;
    }
    else
    {
        Nullable!uint keyPosition;
        Nullable!AttributeRelationship relationship;
    }

    return StructureComponent(
        resource.id,
        concept.get.name,
        concept.get.names,
        concept.get.description,
        concept.get.descriptions,
        keyPosition,
        [],
        (Nullable!bool).init,
        relationship,
        fmt,
        (Nullable!string).init,
        values
    );
}

unittest
{
    import std.typecons : Nullable;
    import vulpes.core.query : CFilter, QueryComponent;

    auto q = DataQuery([QueryComponent(0, ["NOK", "NZD"], false)], [CFilter("CURRENCY", [["NOK"], ["NZD"]])]);
    Nullable!Urn cpt = Urn(PackageType.conceptscheme, ClassType.Concept, "FOO", "CONCEPT", "1.0", "CURRENCY");
    auto conceptSchemes = [
        ConceptScheme(
            "CONCEPT",
            "1.0",
            "FOO",
            false,
            false,
            "Concepts",
            (Nullable!(string[Language])).init,
            (Nullable!string).init,
            (Nullable!(string[Language])).init,
            false,
            [
                Concept(
                    "CURRENCY",
                    "Currency",
                    (Nullable!(string[Language])).init,
                    (Nullable!string).init,
                    (Nullable!(string[Language])).init,
                ),
                Concept(
                    "TIME_PERIOD",
                    "Time Period",
                    (Nullable!(string[Language])).init,
                    (Nullable!string).init,
                    (Nullable!(string[Language])).init,
                )
            ]
        )
    ];
    auto codelists = [
        Codelist(
            "CODELIST",
            "1.0",
            "FOO",
            false,
            false,
            "Codelist",
            (Nullable!(string[Language])).init,
            (Nullable!string).init,
            (Nullable!(string[Language])).init,
            false,
            [
                Code(
                    "NOK",
                    "Norwegian Krone",
                    (Nullable!(string[Language])).init,
                    (Nullable!string).init,
                    (Nullable!(string[Language])).init
                ),
                Code(
                    "NZD",
                    "New Zeland Dollar",
                    (Nullable!(string[Language])).init,
                    (Nullable!string).init,
                    (Nullable!(string[Language])).init
                ),
                Code(
                    "GBP",
                    "British Pound",
                    (Nullable!(string[Language])).init,
                    (Nullable!string).init,
                    (Nullable!(string[Language])).init
                )
            ]
        )
    ];
    Nullable!Enumeration en = Enumeration(Urn(PackageType.codelist, ClassType.Codelist, "FOO", "CODELIST", "1.0"));
    Nullable!Format fmt = Format((Nullable!uint).init, (Nullable!uint).init, BasicDataType.alphanumeric);
    Nullable!LocalRepresentation rep = LocalRepresentation(en, fmt);

    auto dim = Dimension("CURRENCY", 0, cpt, [], rep);
    auto rDim = buildStructureComponent(dim, q, codelists, conceptSchemes);
    assert(rDim.id == "CURRENCY");
    assert(rDim.name == "Currency");
    assert(rDim.keyPosition.get == 0);
    assert(rDim.values.length == 2);
    assert(rDim.values[0].id == "NOK");
    assert(rDim.values[0].name == "Norwegian Krone");
    assert(rDim.values[1].id == "NZD");
    assert(rDim.values[1].name == "New Zeland Dollar");
    assert(rDim.relationship.isNull);
    assert(!rDim.format.isNull);

    auto tDim = TimeDimension("TIME_PERIOD", 1, cpt, [], (Nullable!LocalRepresentation).init);
    auto rTDim = buildStructureComponent(tDim, q, codelists, conceptSchemes);
    assert(rTDim.values.length == 0);
    assert(rTDim.id == "TIME_PERIOD");

    Nullable!AttributeRelationship rel = AttributeRelationship(
        ["Currency"], (Nullable!string).init, (Nullable!Empty).init, (Nullable!Empty).init);
    auto attr = Attribute("CURRENCY", (Nullable!UsageType).init, rel, cpt, [], rep);
    auto rAttr = buildStructureComponent(attr, q, codelists, conceptSchemes);
    assert(!rAttr.relationship.isNull);
    assert(rAttr.keyPosition.isNull);
    assert(rAttr.name == "Currency");

    auto measure = Measure("CURRENCY", cpt, [], rep, (Nullable!UsageType).init);
    auto rMeasure = buildStructureComponent(measure, q, codelists, conceptSchemes);
    assert(rMeasure.relationship.isNull);
    assert(rMeasure.keyPosition.isNull);
    assert(rMeasure.name == "Currency");

    auto qWildcard = DataQuery([QueryComponent(0, [], true)], [CFilter("CURRENCY", [["NOK"], ["NZD"]])]);
    auto rDimWildcard = buildStructureComponent(dim, qWildcard, codelists, conceptSchemes);
    assert(rDimWildcard.values.length == 3);
}

// Structure buildStructure(
//     DataStructure dsd, DataQuery query, in Codelist[] codelists, in ConceptScheme[] conceptSchemes) pure @safe
// {
//     import std.algorithm : sort, map;
//     import std.array : array;
//     import std.range : walkLength;
//     import std.exception : enforce;
//     import vulpes.lib.operations : innerjoin;

//     auto dimensions = dsd
//         .dataStructureComponents
//         .dimensionList
//         .dimensions
//         .sort!"a.position < b.position";

//     auto dimComponents = query.components
//         .sort!"a.position < b.position"
//         .innerjoin!(a => a.position, a => a.position)(dimensions)
//         .map!(a => buildStructureComponent(a.right, a.left, codelists, conceptSchemes));

//     enforce!DataServiceException(dimComponents.walkLength == query.length,
//                                  "query does not match dimensions structure!");


// }