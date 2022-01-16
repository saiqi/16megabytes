module vulpes.core.model;

import std.typecons : Nullable, nullable;
import vulpes.lib.boilerplate : Generate;

struct Sender
{
    string id;

    mixin(Generate);
}

struct Receiver
{
    string id;

    mixin(Generate);
}

struct Link
{
    string href;
    string rel;
    Nullable!string hreflang;
    Nullable!string urn;
    Nullable!string type;

    mixin(Generate);
}

struct Meta
{
    string schema;
    string id;
    bool test;
    string prepared;
    string[] contentLanguages;
    Sender sender;
    Receiver[] receivers;
    Link[] links;

    mixin(Generate);
}

enum AssignementStatus : string
{
    mandatory = "Mandatory",
    conditional = "Conditional"
}

enum UsageType : string
{
    mandatory = "Mandatory",
    conditional = "Conditional"
}

struct Empty
{}

struct AttributeRelationship
{
    string[] dimensions;
    Nullable!string group;
    Nullable!Empty observation;
    Nullable!Empty dataflow;

    mixin(Generate);
}

struct Enumeration
{
    string enumeration;

    mixin(Generate);
}

enum BasicDataType : string
{
    string_ = "String",
    alpha = "Alpha",
    alphanumeric = "AlphaNumeric",
    numeric = "Numeric",
    biginteger = "BigInteger",
    integer = "Integer",
    long_ = "Long",
    short_ = "Short",
    decimal = "Decimal",
    float_ = "Float",
    double_ = "Double",
    boolean = "Boolean",
    uri = "URI",
    count = "Count",
    inclusivevaluerange = "InclusiveValueRange",
    exclusivevaluerange = "ExclusiveValueRange",
    incremental = "Incremental",
    observationaltimeperiod = "ObservationalTimePeriod",
    standardtimeperiod = "StandardTimePeriod",
    basictimeperiod = "BasicTimePeriod",
    gregoriantimeperiod = "GregorianTimePeriod",
    gregorianyear = "GregorianYear",
    gregorianyearmonth = "GregorianYearMonth",
    gregorianday = "GregorianDay",
    reportingtimeperiod = "ReportingTimePeriod",
    reportingyear = "ReportingYear",
    reportingsemester = "ReportingSemester",
    reportingtrimester = "ReportingTrimester",
    reportingquarter = "ReportingQuarter",
    reportingmonth = "ReportingMonth",
    reportingweek = "ReportingWeek",
    reportingday = "ReportingDay",
    datetime = "DateTime",
    timerange = "TimeRange",
    month = "Month",
    monthday = "MonthDay",
    day = "Day",
    time = "Time",
    duration = "Duration",
    geospatialinformation = "GeospatialInformation",
    xhtml = "XHTML"
}

struct Format
{
    Nullable!uint maxLength;
    Nullable!uint minLength;
    BasicDataType dataType;

    mixin(Generate);
}

struct LocalRepresentation
{
    Nullable!Enumeration enumeration;
    Nullable!Format format;

    mixin(Generate);
}

struct Attribute
{
    string id;
    Link[] links;
    Nullable!AssignementStatus assignementStatus;
    Nullable!AttributeRelationship attributeRelationship;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;

    mixin(Generate);
}

struct AttributeList
{
    string id;
    Link[] links;
    Attribute[] attributes;

    mixin(Generate);
}

struct Dimension
{
    string id;
    Link[] links;
    uint position;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;

    mixin(Generate);
}

struct DimensionList
{
    string id;
    Link[] links;
    Dimension[] dimensions;
    Nullable!Dimension timeDimension;

    mixin(Generate);
}

struct Group
{
    string id;
    Link[] links;
    string[] groupDimensions;

    mixin(Generate);
}

struct Measure
{
    string id;
    Link[] links;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;
    Nullable!UsageType usage;

    mixin(Generate);
}

struct MeasureList
{
    string id;
    Link[] links;
    Measure[] measures;

    mixin(Generate);
}

enum Language : string
{
    en = "en",
    fr = "fr"
}

struct DataStructureComponents
{
    Nullable!AttributeList attributeList;
    Nullable!DimensionList dimensionList;
    Group[] groups;
    Nullable!MeasureList measureList;

    mixin(Generate);
}

struct DataStructure
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    DataStructureComponents dataStructureComponents;

    mixin(Generate);
}

struct Category
{
    string id;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    Category[] categories;

    mixin(Generate);
}

Category[] flattenCategory(Category category) pure @safe
{
    import std.range : chain;
    import std.algorithm : joiner, map;
    import std.array: array;

    return [category]
        .chain(category.categories.map!(c => flattenCategory(c)).joiner)
        .array;
}

unittest
{
    import std.algorithm : equal, sort;

    auto child0 = Category("0", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child00 = Category("00", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child01 = Category("01", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child010 = Category("010", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child011 = Category("011", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child012 = Category("012", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);

    child01.categories ~= child010;
    child01.categories ~= child011;
    child01.categories ~= child012;

    child0.categories ~= child00;
    child0.categories ~= child01;

    auto categories = flattenCategory(child0);
    assert(categories.length == 6);

    auto expected = [child0, child00, child01, child010, child011, child012].sort!"a.id < b.id";
    assert(equal(child0.flattenCategory.sort!"a.id < b.id", expected));
}

struct CategoryScheme
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    bool isPartial;
    Category[] categories;

    mixin(Generate);
}

alias CategoryHierarchy = Category[][Category];

Nullable!CategoryHierarchy buildHierarchy(CategoryScheme categoryScheme) pure nothrow @safe
{
    scope(failure) return typeof(return).init;

    CategoryHierarchy path;

    void visit(Category category)
    {
        import std.container : DList;

        DList!Category queue;
        queue.insertFront(category);
        bool[Category] visited = [category : true];

        while(!queue.empty)
        {
            auto c = queue.front;
            queue.removeFront;

            visited[c] = true;

            foreach(child; c.categories)
            {
                if(!(child in visited))
                {
                    visited[child] = true;
                    queue.insertBack(child);
                    foreach(u; path.get(c, []))
                    {
                        path[child] ~= u;
                    }

                    path[child] ~= c;
                }
            }
        }
    }

    foreach(c; categoryScheme.categories)
    {
        visit(c);
    }
    return path.nullable;
}

unittest
{
    import std.algorithm : equal;

    auto cs = CategoryScheme();
    auto child0 = Category("0", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child1 = Category("1", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child00 = Category("00", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child01 = Category("01", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child010 = Category("010", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child011 = Category("011", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);
    auto child012 = Category("012", null, null, (Nullable!string).init, Nullable!(string[Language]).init, [], []);

    child01.categories ~= child010;
    child01.categories ~= child011;
    child01.categories ~= child012;

    child0.categories ~= child00;
    child0.categories ~= child01;

    cs.categories ~= child0;
    cs.categories ~= child1;

    auto hierarchy = buildHierarchy(cs).get;
    assert(hierarchy[child012].equal([child0, child01]));

}

struct Concept
{
    string id;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;

    mixin(Generate);
}

struct ConceptScheme
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    bool isPartial;
    Concept[] concepts;

    mixin(Generate);
}

struct Code
{
    string id;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;

    mixin(Generate);
}

struct Codelist
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    bool isPartial;
    Code[] codes;

    mixin(Generate);
}

struct Dataflow
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    string structure;

    mixin(Generate);
}

struct Categorisation
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    string source;
    string target;
}

enum RoleType : string
{
    allowed = "Allowed",
    actual = "Actual"
}

struct ConstraintAttachment
{
    string[] dataflows;

    mixin(Generate);
}

struct KeyValue
{
    string id;
    string[] values;

    mixin(Generate);
}

struct CubeRegion
{
    bool include;
    KeyValue[] keyValues;

    mixin(Generate);
}

struct DataConstraint
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    string[Language] names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Link[] links;
    Nullable!RoleType role;
    Nullable!ConstraintAttachment constraintAttachment;
    CubeRegion[] cubeRegions;

    mixin(Generate);
}

struct Data
{
    DataStructure[] dataStructures;
    CategoryScheme[] categorySchemes;
    ConceptScheme[] conceptSchemes;
    Codelist[] codelists;
    Dataflow[] dataflows;
    Categorisation[] categorisations;
    DataConstraint[] dataConstraints;

    mixin(Generate);
}

struct Error
{
    uint code;
    string title;
    string[Language] titles;
    Nullable!string detail;
    Nullable!string[Language] details;
    Link[] links;

    mixin(Generate);
}

struct Message
{
    Meta meta;
    Nullable!Data data;
    Error[] errors;

    mixin(Generate);
}

import std.range : isInputRange, ElementType;

enum canBeSearched(T) = is(typeof(T.name.init) : string);

unittest
{
    static assert(canBeSearched!Dataflow);
    static assert(canBeSearched!Concept);
    static assert(canBeSearched!Code);
    static assert(canBeSearched!DataStructure);
    static assert(canBeSearched!ConceptScheme);
    static assert(canBeSearched!Codelist);
    static assert(canBeSearched!Categorisation);
    static assert(canBeSearched!Category);
    static assert(canBeSearched!CategoryScheme);
    static assert(canBeSearched!DataConstraint);
}

string[] collectSearchItems(T)(in T resource) pure @safe nothrow
if(canBeSearched!T)
{
    import std.array : appender, array;
    import std.algorithm : uniq;

    auto a = appender!(string[]);
    a.put(resource.name);

    static if(is(typeof(T.names.init) : string[Language]))
    {
        if(resource.names !is null)
            a.put(resource.names.byValue);
    }

    static if(is(typeof(T.description.init) : Nullable!string))
    {
        if(!resource.description.isNull)
            a.put(resource.description.get);
    }

    static if(is(typeof(T.descriptions.init) : Nullable!(string[Language])))
    {
        if(!resource.descriptions.isNull)
            a.put(resource.descriptions.get.byValue);
    }

    return a.data.uniq.array;
}

unittest
{
    import std.algorithm : equal, sort;

    static struct OnlyName
    {
        string name;
    }

    static struct WithDesc
    {
        string name;
        Nullable!string description;
    }

    static struct WithNames
    {
        string name;
        Nullable!string description;
        string[Language] names;
    }

    static struct WithDescriptions
    {
        string name;
        Nullable!string description;
        string[Language] names;
        Nullable!(string[Language]) descriptions;
    }

    auto onlyName = OnlyName("foo");
    assert(equal(collectSearchItems(onlyName), ["foo"]));

    auto withDesc = WithDesc("foo", "Foo".nullable);
    assert(equal(collectSearchItems(withDesc).sort, ["foo", "Foo"].sort));
    auto withNullDesc = WithDesc("foo", (Nullable!string).init);
    assert(equal(collectSearchItems(withNullDesc), ["foo"]));

    auto withNames = WithNames("foo", "Foo".nullable, [Language.en : "foo", Language.fr: "fou"]);
    assert(equal(collectSearchItems(withNames).sort, ["foo", "fou", "Foo"].sort));
    auto withNullNames = WithNames("foo", "Foo".nullable, null);
    assert(equal(collectSearchItems(withNullNames).sort, ["foo", "Foo"].sort));

    auto withDescriptions = WithDescriptions(
        "foo",
        "Foo".nullable,
        [Language.en : "foo", Language.fr: "fou"],
        [Language.en : "Foo", Language.fr: "Fou"].nullable
    );
    assert(equal(collectSearchItems(withDescriptions).sort, ["foo", "Foo", "fou", "Fou"].sort));
    auto withNullDescriptions = WithDescriptions(
        "foo",
        "Foo".nullable,
        [Language.en : "foo", Language.fr: "fou"],
        (Nullable!(string[Language])).init
    );
    assert(equal(collectSearchItems(withNullDescriptions).sort, ["foo", "Foo", "fou"].sort));

}

auto search(size_t threshold, R)(R resources, in string q) pure @safe nothrow
if(isInputRange!R && canBeSearched!(ElementType!R))
{
    import vulpes.lib.text : fuzzySearch;
    import std.typecons : Tuple;
    import std.array : array;
    import std.algorithm : map, filter, sort, uniq, min, reduce;
    import std.functional : partial;

    alias T = Tuple!(ElementType!R, "resource", size_t, "score");
    alias pSearch = partial!(fuzzySearch, q);

    T computeScore(ElementType!R resource)
    {
        auto score = collectSearchItems(resource)
            .map!pSearch
            .map!(a => a.get(size_t.max));
        return T(resource, reduce!((a, b) => min(a, b))(size_t.max, score));
    }

    return resources.map!computeScore
        .filter!(a => a.score <= threshold)
        .array
        .sort!((a, b) => a.score < b.score)
        .map!"a.resource"
        .array;
}

unittest
{
    import std.algorithm : equal;
    static struct WithName
    {
        string name;
    }

    auto wonderful = WithName("wonderful");
    auto unreachable = WithName("unreachable");
    auto wanderful = WithName("wanderful");
    auto withNames = [unreachable, wanderful, wonderful];

    assert(equal(search!1(withNames, "wonderful"), [wonderful, wanderful]));
}