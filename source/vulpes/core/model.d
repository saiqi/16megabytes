module vulpes.core.model;

import std.typecons : Nullable, nullable;
import std.traits : Unqual;
import vulpes.lib.boilerplate : Generate;

enum Unknown = "Unknown";
enum DefaultVersion = "latest";

enum PackageType : string
{
    codelist = "codelist",
    conceptscheme = "conceptscheme",
    categoryscheme = "categoryscheme",
    datastructure = "datastructure",
    registry = "registry",
    base = "base"
}

enum ClassType : string
{
    Codelist = "Codelist",
    Code = "Code",
    ConceptScheme = "ConceptScheme",
    Concept = "Concept",
    Category = "Category",
    CategoryScheme = "CategoryScheme",
    Categorisation = "Categorisation",
    DataStructure = "DataStructure",
    Dataflow = "Dataflow",
    ContentConstraint = "ContentContraint",
    DataAttribute = "DataAttribute",
    AttributeDescriptor = "AttributeDescriptor",
    Dimension = "Dimension",
    TimeDimension = "TimeDimension",
    DimensionDescriptor = "DimensionDescriptor",
    MeasureDescriptor = "MeasureDescriptor",
    PrimaryMeasure = "PrimaryMeasure",
    GroupDimensionDescriptor = "GroupDimensionDescriptor"
}

class UrnException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct Urn
{
    private static enum root = "urn";
    private static enum nid = "sdmx";
    private static enum pkgPrefix = "org.sdmx.infomodel";
    private static enum pattern = root ~ ":" ~ nid ~ ":" ~ pkgPrefix
        ~ ".(?P<package>[a-z]+).(?P<class>[a-zA-Z]+)=(?P<agency>[A-Za-z0-9_\\-]+):(?P<resource>[A-Za-z0-9_\\-]+)"
        ~ "\\((?P<version>[A-Za-z0-9_\\-\\.]+)\\)?(.(?P<item>[A-Za-z0-9_\\-]+))?";

    private PackageType package_;
    private ClassType class_;
    private string id;
    private string agencyId;
    private string version_;
    private Nullable!string item;

    this(PackageType package_, ClassType class_, string agencyId, string id, string version_)
    pure @safe inout nothrow
    {
        this.package_ = package_;
        this.class_ = class_;
        this.agencyId = agencyId;
        this.id = id;
        this.version_ = version_;
    }

    this(PackageType package_, ClassType class_, string agencyId, string id, string version_, string item)
    pure @safe inout nothrow
    {
        this.package_ = package_;
        this.class_ = class_;
        this.agencyId = agencyId;
        this.id = id;
        this.version_ = version_;
        this.item = item;
    }

    this(string u) @safe
    {
        import std.regex : matchFirst;
        import std.conv : to;
        import std.exception : enforce;
        import std.algorithm : equal, sort;

        auto m = matchFirst(u, pattern);

        enforce!UrnException(!m.empty, "Bad formatted URN");

        package_ = m["package"].to!PackageType;
        class_ = m["class"].to!ClassType;
        agencyId = m["agency"];
        id = m["resource"];
        version_ = m["version"];

        if(m["item"]) item = m["item"];
    }

    string toString() pure @safe inout
    {
        import std.format : format;

        if(item.isNull)
            return format!"%s:%s:%s.%s.%s=%s:%s(%s)"
                (root, nid, pkgPrefix, package_, class_, agencyId, id, version_);

        return format!"%s:%s:%s.%s.%s=%s:%s(%s).%s"
            (root, nid, pkgPrefix, package_, class_, agencyId, id, version_, item.get);
    }

    static Nullable!Urn safeParse(inout string u) @safe nothrow
    {
        scope(failure) return typeof(return).init;
        
        Nullable!Urn urn = Urn(u);

        return urn;
    }
}

unittest
{
    const str = "urn:sdmx:org.sdmx.infomodel.categoryscheme.Category=ABC:ABC(1.0).ABC";
    auto urn = Urn(str);
    assert(urn.toString == str);
}

unittest
{
    const str = "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=FR1:CHOMAGE-TRIM-NATIONAL(1.0)";
    assert(Urn(str).toString == str);
}

unittest
{
    import std.exception : assertThrown;
    const str = "unmatched";
    assertThrown(Urn(str));
}

unittest
{
    const str = "urn:sdmx:org.sdmx.infomodel.categoryscheme.Category=ABC:ABC(1.0).ABC";
    auto urn = Urn.safeParse(str);
    assert(!urn.isNull);
    assert(urn.get.toString == str);
}

unittest
{
    assert(Urn.safeParse("foo").isNull);
    assert(Urn.safeParse("urn:sdmx:org.sdmx.infomodel.impo.Ssible=ABC:ABC(1.0).ABC").isNull);
}

enum Item;

struct Package
{
    string name;
}

struct Class
{
    string name;
}

struct Type
{
    string name;
}

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
    Nullable!string href;
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

@Package(PackageType.datastructure)
@Class(ClassType.DataAttribute)
struct Attribute
{
    string id;
    Nullable!AssignementStatus assignementStatus;
    Nullable!AttributeRelationship attributeRelationship;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.AttributeDescriptor)
struct AttributeList
{
    string id;
    Attribute[] attributes;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.Dimension)
struct Dimension
{
    string id;
    uint position;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.TimeDimension)
struct TimeDimension
{
    string id;
    uint position;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.DimensionDescriptor)
struct DimensionList
{
    string id;
    Dimension[] dimensions;
    TimeDimension[] timeDimensions;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.GroupDimensionDescriptor)
struct Group
{
    string id;
    string[] groupDimensions;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.PrimaryMeasure)
struct PrimaryMeasure
{
    string id;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentation localRepresentation;
    Nullable!UsageType usage;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

@Package(PackageType.datastructure)
@Class(ClassType.MeasureDescriptor)
struct MeasureList
{
    string id;
    PrimaryMeasure measure;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), DataStructure);
}

enum Language : string
{
    en = "en",
    fr = "fr",
    de = "de",
    es = "es"
}

enum DefaultLanguage = Language.en;

struct DataStructureComponents
{
    Nullable!AttributeList attributeList;
    Nullable!DimensionList dimensionList;
    Group[] groups;
    Nullable!MeasureList measureList;

    mixin(Generate);
}

@Package(PackageType.datastructure)
@Class(ClassType.DataStructure)
@Type("datastructure")
struct DataStructure
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    DataStructureComponents dataStructureComponents;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
}

@Package(PackageType.categoryscheme)
@Class(ClassType.Category)
@Item
struct Category
{
    string id;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Category[] categories;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), CategoryScheme);
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

    auto buildCategory(string id)
    {
        return Category(
            id,
            null,
            Nullable!(string[Language]).init,
            (Nullable!string).init,
            Nullable!(string[Language]).init,
            []);
    }

    auto child0 = buildCategory("0");
    auto child00 = buildCategory("00");
    auto child01 = buildCategory("01");
    auto child010 = buildCategory("010");
    auto child011 = buildCategory("011");
    auto child012 = buildCategory("012");

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

@Package(PackageType.categoryscheme)
@Class(ClassType.CategoryScheme)
@Type("categoryscheme")
struct CategoryScheme
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    bool isPartial;
    Category[] categories;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
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

    auto buildCategory(string id)
    {
        return Category(
            id,
            null,
            Nullable!(string[Language]).init,
            (Nullable!string).init,
            Nullable!(string[Language]).init,
            []);
    }

    auto cs = CategoryScheme();
    auto child0 =   buildCategory("0");
    auto child1 =   buildCategory("1");
    auto child00 =  buildCategory("00");
    auto child01 =  buildCategory("01");
    auto child010 = buildCategory("010");
    auto child011 = buildCategory("011");
    auto child012 = buildCategory("012");

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

@Package(PackageType.conceptscheme)
@Class(ClassType.Concept)
@Item
struct Concept
{
    string id;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), ConceptScheme);
}

@Package(PackageType.conceptscheme)
@Class(ClassType.ConceptScheme)
@Type("conceptscheme")
struct ConceptScheme
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    bool isPartial;
    Concept[] concepts;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
}

@Package(PackageType.codelist)
@Class(ClassType.Code)
@Item
struct Code
{
    string id;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this), Codelist);
}

@Package(PackageType.codelist)
@Class(ClassType.Codelist)
@Type("codelist")
struct Codelist
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    bool isPartial;
    Code[] codes;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
}

@Package(PackageType.datastructure)
@Class(ClassType.Dataflow)
@Type("dataflow")
struct Dataflow
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    string structure;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
}

@Package(PackageType.categoryscheme)
@Class(ClassType.Categorisation)
@Type("categorisation")
struct Categorisation
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    string source;
    string target;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
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

@Package(PackageType.registry)
@Class(ClassType.ContentConstraint)
@Type("contentconstraint")
struct DataConstraint
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[Language]) names;
    Nullable!string description;
    Nullable!(string[Language]) descriptions;
    Nullable!RoleType role;
    Nullable!ConstraintAttachment constraintAttachment;
    CubeRegion[] cubeRegions;

    mixin(Generate);
    mixin GenerateLinks!(typeof(this));
}

struct Data
{
    DataStructure[] dataStructures;
    CategoryScheme[] categorySchemes;
    ConceptScheme[] conceptSchemes;
    Codelist[] codelists;
    Dataflow[] dataflows;
    Categorisation[] categorisations;
    DataConstraint[] contentConstraints;

    mixin(Generate);
}

enum ErrorStatusCode
{
    notFound = 100u,
    unauthorized = 110u,
    responseTooLarge = 130u,
    syntaxError = 140u,
    sematicError = 150u,
    internalServerError = 500u,
    notImplemented = 501u,
    serviceNotAvailable = 503u,
    responseSizeExceedsServiceLimit = 510u
}

struct Error_
{
    ErrorStatusCode code;
    string title;
    string[Language] titles;
    Nullable!string detail;
    Nullable!(string[Language]) details;

    static Error_ build(in ErrorStatusCode code, in string message) pure @safe nothrow
    {
        return Error_(
            code,
            message, 
            [DefaultLanguage : message], 
            (Nullable!string).init,
            (Nullable!(string[Language])).init
        );
    }

    mixin(Generate);
}

unittest
{
    auto err = Error_.build(ErrorStatusCode.notFound, "Not found");
    assert(err.code == ErrorStatusCode.notFound);
    assert(err.title == "Not found");
    assert(err.titles[DefaultLanguage] == "Not found");
}

struct Message
{
    Meta meta;
    Nullable!Data data;
    Error_[] errors;

    mixin(Generate);
}

enum bool isIdentifiable(T) = is(Unqual!T == struct)
    && is(typeof(T.init.id) : string);

unittest
{
    static struct Foo
    {
        string id;
    }

    static struct Bar{}

    static assert(isIdentifiable!Foo);
    static assert(isIdentifiable!(const(Foo)));
    static assert(!isIdentifiable!Bar);
}

enum bool isRetrievable(T) = isIdentifiable!T
    && is(typeof(T.init.version_) : string)
    && is(typeof(T.init.agencyId) : string);

unittest
{
    static struct Foo
    {
        string id;
        string version_;
        string agencyId;
    }

    static struct Bar{}

    static assert(isRetrievable!Foo);
    static assert(isRetrievable!(const(Foo)));
    static assert(!isRetrievable!Bar);
}

private mixin template GenerateLinks(T, ParentType = void)
{
    import std.format : format;
    import std.uni : toLower;
    import std.conv : to;
    import std.traits : hasUDA, getUDAs;
    import vulpes.core.providers : Provider;

    enum self = "self";
    enum hasNoParentType = is(ParentType == void);

    private static PackageType getPackage() pure @safe
    {
        static if(hasUDA!(T, Package))
            return getUDAs!(T, Package)[0].name.to!PackageType;
        else
            return (Unqual!T).stringof.toLower.to!PackageType;
    }

    private static ClassType getClass() pure @safe
    {
        static if(hasUDA!(T, Class))
            return getUDAs!(T, Class)[0].name.to!ClassType;
        else
            return (Unqual!T).stringof.to!ClassType;
    }

    private static string getType() pure @safe
    {
        static if(hasUDA!(T, Type))
            return getUDAs!(T, Type)[0].name;
        else
            return (Unqual!T).stringof.toLower;
    }

    static if(hasNoParentType && isRetrievable!T)
    {
        string urn() pure @safe inout @property
        {
            return Urn(getPackage(), getClass(), agencyId, id, version_).toString;
        }

        Link[] links(inout ref Provider provider) pure @safe inout @property
        {
            const rootUrl = provider.rootUrl;

            const href = format!"%s/%s/%s/%s/%s"(rootUrl, getType(), agencyId, id, version_);
            auto s = Link(
                href.nullable,
                self,
                DefaultLanguage.to!string.nullable,
                urn.nullable,
                getType().nullable,
            );

            return [s];
        }
    }
    else static if(!hasNoParentType && isIdentifiable!T && isRetrievable!ParentType)
    {
        string urn(inout ref ParentType parent) pure @safe inout @property
        {
            return Urn(getPackage(), getClass(), parent.agencyId, parent.id, parent.version_, id).toString;
        }

        static if(hasUDA!(T, Item))
        {
            Link[] links(inout ref Provider provider, inout ref ParentType parent) pure @safe inout @property
            {
                const rootUrl = provider.rootUrl;
                const href = format!"%s/%s/%s/%s/%s/%s"
                    (rootUrl, getType(), parent.agencyId, parent.id, parent.version_, id);
                auto s = Link(
                    href.nullable,
                    self,
                    (Nullable!string).init,
                    urn(parent).nullable,
                    getType().nullable,
                );
                return [s];
            }
        }
        else
        {
            Link[] links(inout ref ParentType parent) pure @safe inout @property
            {
                auto s = Link(
                    (Nullable!string).init,
                    self,
                    (Nullable!string).init,
                    urn(parent).nullable,
                    getType().nullable,
                );
                return [s];
            }
        }
    }
}

unittest
{
    import vulpes.core.providers : Provider, Resource;

    const provider = Provider("BAR", true, "https://bar.org", Nullable!(Resource[][string]).init);

    @Package(PackageType.base)
    @Class(ClassType.Codelist)
    @Type("foo")
    static struct Foo
    {
        string id;
        string version_;
        string agencyId;

        mixin GenerateLinks!(typeof(this));
    }

    auto foo = Foo("FOO", "1.0", "BAR");
    assert(foo.urn == "urn:sdmx:org.sdmx.infomodel.base.Codelist=BAR:FOO(1.0)");

    assert(foo.links(provider).length == 1);

    auto link = foo.links(provider)[0];
    assert(link.href.get == "https://bar.org/foo/BAR/FOO/1.0");
    assert(link.rel == "self");
    assert(link.type.get == "foo");
    assert(link.urn.get == foo.urn);
}

unittest
{
    static struct Foo
    {
        string id;
        string version_;
        string agencyId;
    }

    @Package(PackageType.base)
    @Class(ClassType.Codelist)
    static struct Bar
    {
        string id;

        mixin GenerateLinks!(typeof(this), Foo);
    }

    const foo = Foo("foo", "1.0", "PROV");
    const bar = Bar("bar");

    assert(bar.urn(foo) == "urn:sdmx:org.sdmx.infomodel.base.Codelist=PROV:foo(1.0).bar");
    assert(bar.links(foo).length == 1);

    auto link = bar.links(foo)[0];
    assert(link.href.isNull);
    assert(link.rel == "self");
    assert(link.type.get == "bar");
    assert(link.urn.get == bar.urn(foo));
}

unittest
{
    import vulpes.core.providers : Provider, Resource;

    const provider = Provider("BAR", true, "https://bar.org", Nullable!(Resource[][string]).init);

    @Package(PackageType.codelist)
    @Class(ClassType.Codelist)
    @Type("footype")
    static struct Foo
    {
        string id;
        string version_;
        string agencyId;

        mixin GenerateLinks!(typeof(this));
    }

    @Package(PackageType.codelist)
    @Class(ClassType.Code)
    @Item
    static struct Bar
    {
        string id;

        mixin GenerateLinks!(typeof(this), Foo);
    }

    const foo = Foo("foo", "1.0", "PROV");
    const bar = Bar("bar");

    assert(bar.urn(foo) == "urn:sdmx:org.sdmx.infomodel.codelist.Code=PROV:foo(1.0).bar");
    assert(bar.links(provider, foo).length == 1);

    auto link = bar.links(provider, foo)[0];
    assert(link.href.get = "https://bar.org/footype/PROV/foo/1.0/bar");
    assert(link.rel == "self");
    assert(link.type.get == "bar");
    assert(link.urn.get == bar.urn(foo));
}

enum bool isNamed(T) = is(typeof(T.name.init) : string);

unittest
{
    static assert(isNamed!Dataflow);
    static assert(isNamed!Concept);
    static assert(isNamed!Code);
    static assert(isNamed!DataStructure);
    static assert(isNamed!ConceptScheme);
    static assert(isNamed!Codelist);
    static assert(isNamed!Categorisation);
    static assert(isNamed!Category);
    static assert(isNamed!CategoryScheme);
    static assert(isNamed!DataConstraint);
}
