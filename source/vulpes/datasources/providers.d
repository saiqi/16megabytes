module vulpes.datasources.providers;

import std.typecons : Nullable, Tuple, Flag;
import std.functional : toDelegate;
import vibe.data.json : optional;
import vibe.core.concurrency : Future;
import vulpes.lib.boilerplate : Generate;
import vulpes.core.model : ResourceType;
import vulpes.requests : doAsyncRequest, Response;

///Dedicated module `Exception`
class ProviderException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

private enum VariableType : string
{
    resourceType = "resourceType",
    providerId = "providerId",
    resourceId = "resourceId"
}

alias RequestItems = Tuple!(
    string, "name",
    string, "url",
    string[string], "headers",
    string[string], "queryParams",
    bool, "mandatory",
    FormatType, "formatType"
);

enum FormatType : string
{
    sdmxml21 = "sdmxml21",
    sdmxml20 = "sdmxml20"
}

struct Resource
{
    string name;
    string pathTemplate;
    @optional Nullable!(string[string]) queryTemplate;
    string[string] headerTemplate;
    bool mandatory;
    FormatType formatType;

    private static string[string] handleVars(const(string[VariableType]) vars) @safe
    {
        import std.conv : to;
        return vars.to!(string[string]);
    }

    string path(const(string[VariableType]) vars) @safe inout
    {
        import vulpes.lib.templates : resolve;
        return resolve(this.pathTemplate, handleVars(vars));
    }

    string[string] headers(const(string[VariableType]) vars) @safe inout
    {
        import vulpes.lib.templates : resolve;
        return resolve(this.headerTemplate, handleVars(vars));
    }

    string[string] queryParams(const (string[VariableType]) vars) @safe inout
    {
        import vulpes.lib.templates : resolve;
        if(this.queryTemplate.isNull) return null;
        return resolve(this.queryTemplate.get, handleVars(vars));
    }

    RequestItems requestItem(in string rootUrl, const (string[VariableType]) vars) @safe inout
    {
        return RequestItems(
            this.name,
            rootUrl ~ this.path(vars),
            this.headers(vars),
            this.queryParams(vars),
            this.mandatory,
            this.formatType
        );
    }

    mixin(Generate);
}

unittest
{
    import std.typecons : nullable;
    const r = Resource(
        "foo",
        "/{resourceType}/foo",
        ["q": "{providerId}"].nullable,
        ["h": "{resourceId}"],
        true,
        FormatType.sdmxml21
    );

    with(VariableType)
    {
        const vars = [resourceType: "bar", providerId: "id", resourceId: "1"];
        assert(r.path(vars) == "/bar/foo");
        assert(r.headers(vars)["h"] == "1");
        assert(r.queryParams(vars)["q"] == "id");

        const ri = r.requestItem("https://foo.org", vars);
        assert(ri.name == "foo");
        assert(ri.url == "https://foo.org/bar/foo");
        assert(ri.headers["h"] == "1");
        assert(ri.queryParams["q"] == "id");
        assert(ri.mandatory);
        assert(ri.formatType == FormatType.sdmxml21);
    }
}

unittest
{
    const r = Resource(
        "foo",
        "/{resourceType}/foo",
        (Nullable!(string[string])).init,
        ["h": "{resourceId}"],
        true,
        FormatType.sdmxml21
    );

    with(VariableType)
    {
        const vars = [resourceType: "bar", providerId: "id", resourceId: "1"];
        assert(r.path(vars) == "/bar/foo");
        assert(r.headers(vars)["h"] == "1");
        assert(r.queryParams(vars) is null);

        const ri = r.requestItem("https://foo.org", vars);
        assert(ri.name == "foo");
        assert(ri.url == "https://foo.org/bar/foo");
        assert(ri.headers["h"] == "1");
        assert(ri.queryParams is null);
        assert(ri.mandatory);
    }
}

struct Provider
{
    string id;
    bool isPublic;
    string rootUrl;
    Nullable!(Resource[][string]) resources;

    bool hasResource(in ResourceType resourceType) pure nothrow @safe inout
    {
        if(this.resources.isNull) return false;

        if(resourceType in this.resources.get) return true;

        return false;
    }

    RequestItems[] requestItems(in ResourceType resourceType, in string resourceId) @safe inout
    {
        import std.exception : enforce;
        import std.format : format;
        import std.algorithm : map;
        import std.array : array;

        enforce!ProviderException(hasResource(resourceType),
                                  format!"%s has no resource %s!"(this.id, resourceType));

        const vars = [
            VariableType.providerId: this.id,
            VariableType.resourceType : resourceType,
            VariableType.resourceId : resourceId
        ];

        RequestItems[] r;
        foreach(ref res; this.resources.get[resourceType])
            r ~= res.requestItem(this.rootUrl, vars);
        return r;
    }

    RequestItems[] requestItems(in ResourceType resourceType) @safe inout
    {
        return this.requestItems(resourceType, null);
    }

    FormatType[] formatTypes() @safe inout
    {
        import std.algorithm : map, uniq;
        import std.array : join, array;
        import std.exception : enforce;
        import std.format : format;

        enforce!ProviderException(!this.resources.isNull,
                                  format!"provider %s has no resource"(this.id));

        return this.resources
            .get
            .byValue
            .join
            .map!"a.formatType"
            .uniq
            .array
            .dup;

    }

    Nullable!FormatType formatType() @safe inout nothrow
    {
        import std.typecons : nullable;

        scope(failure) return typeof(return).init;

        auto fts = this.formatTypes();

        if(fts.length != 1) return typeof(return).init;

        return fts[0].nullable;
    }

    mixin(Generate);
}

unittest
{
    import std.typecons : nullable;
    auto p = Provider("myid", true, "http://foo.bar", ["dataflow": [Resource()]].nullable);
    assert(!p.hasResource(ResourceType.datastructure));
    assert(p.hasResource(ResourceType.dataflow));
}

unittest
{
    import std.typecons : nullable;

    auto resources = [
        Resource(
            "foo",
            "/foo/{resourceType}/{providerId}",
            ["q" : "aParam"].nullable,
            ["Content-Type": "application/json"],
            true,
            FormatType.sdmxml21
        )
    ];

    auto provider = Provider("ID", true, "https://vulpes.org", ["dataflow" : resources].nullable);
    auto ris = provider.requestItems(ResourceType.dataflow);
    assert(ris.length == 1);
    assert(ris[0].name == "foo");
    assert(ris[0].url == "https://vulpes.org/foo/dataflow/ID");
    assert(ris[0].headers["Content-Type"] == "application/json");
    assert(ris[0].queryParams["q"] == "aParam");
}

unittest
{
    import std.typecons : nullable;

    auto resources = [
        Resource(
            "bar",
            "/bar/{providerId}/{resourceId}",
            (Nullable!(string[string])).init,
            ["Content-Type": "application/json"],
            true,
            FormatType.sdmxml21
        )
    ];

    auto provider = Provider("ID", true, "https://vulpes.org", ["dataflow" : resources].nullable);
    auto ris = provider.requestItems(ResourceType.dataflow, "resource");
    assert(ris.length == 1);
    assert(ris[0].name == "bar");
    assert(ris[0].url == "https://vulpes.org/bar/ID/resource");
    assert(ris[0].headers["Content-Type"] == "application/json");
    assert(ris[0].queryParams is null);
}

unittest
{
    import std.typecons : nullable;
    import std.exception : assertThrown;

    auto provider = Provider("ID", true, "https://vulpes.org", ["dataflow" : [Resource()]].nullable);
    assertThrown!ProviderException(provider.requestItems(ResourceType.datastructure));
}

unittest
{
    import std.typecons : nullable;
    import std.algorithm : equal;

    auto resources = [
        Resource(
            "foo",
            "/foo/{resourceType}/{providerId}",
            ["q" : "aParam"].nullable,
            ["Content-Type": "application/json"],
            true,
            FormatType.sdmxml21
        )
    ];

    auto provider = Provider("ID", true, "https://vulpes.org", ["dataflow" : resources].nullable);
    assert(provider.formatTypes.equal([FormatType.sdmxml21]));
    assert(provider.formatType.get == FormatType.sdmxml21);
}

unittest
{
    import std.typecons : nullable;
    import std.algorithm : equal, sort;

    auto resources = [
        Resource(
            "foo",
            "/foo/{resourceType}/{providerId}",
            ["q" : "aParam"].nullable,
            ["Content-Type": "application/json"],
            true,
            FormatType.sdmxml21
        ),
         Resource(
            "bar",
            "/bar/{resourceType}/{providerId}",
            ["q" : "aParam"].nullable,
            ["Content-Type": "application/json"],
            true,
            FormatType.sdmxml20
        )
    ];

    auto provider = Provider("ID", true, "https://vulpes.org", ["dataflow" : resources].nullable);
    assert(provider.formatTypes.sort.equal([FormatType.sdmxml21, FormatType.sdmxml20].sort));
    assert(provider.formatType.isNull);
}

unittest
{
    import std.typecons : nullable;
    import std.exception : assertThrown;

    auto resources = Nullable!(Resource[][string]).init;

    auto provider = Provider("ID", true, "https://vulpes.org", resources);
    assertThrown!ProviderException(provider.formatTypes);
    assert(provider.formatType.isNull);
}

immutable(Provider[]) loadProvidersFromConfig(in string path = "conf/providers.json")
{
    import vibe.core.file : readFileUTF8;
    import vibe.data.json : deserializeJson;

    return readFileUTF8(path)
        .deserializeJson!(immutable(Provider[]));
}

unittest
{
    assert(loadProvidersFromConfig().length);
}

alias Fetcher = Future!Response delegate(in string, in string[string], in string[string]);

Nullable!string[string] fetchResources(in Provider provider,
                                       in ResourceType resourceType,
                                       in string resourceId = null,
                                       Fetcher fetcher = toDelegate(&doAsyncRequest))
{
    import std.typecons : tuple, nullable, apply;
    import std.algorithm : sort;
    import std.traits : ReturnType;
    import vulpes.datasources.providers : RequestItems;
    import vulpes.requests : getResultOrFail, getResultOrNullable;

    Nullable!string[string] result;

    auto reqItems = provider.requestItems(resourceType, resourceId);

    auto gatherFuture(in ref RequestItems ri)
    {
        auto fut = fetcher(ri.url, ri.headers, ri.queryParams);
        return tuple(ri, fut);
    }

    alias EnrichedFuture = ReturnType!gatherFuture;

    EnrichedFuture[] futures;
    foreach (ref ri; reqItems.sort!((a, b) => a.mandatory < b.mandatory))
    {
        futures ~= gatherFuture(ri);
    }

    foreach (ref EnrichedFuture eFut; futures)
    {
        auto ri = eFut[0]; auto fut = eFut[1];
        if(ri.mandatory)
            result[ri.name] = getResultOrFail(fut).content.nullable;
        else
        {
            auto rn = getResultOrNullable(fut).apply!(a => a.content);
            result[ri.name] = rn;
        }
    }

    return result;
}

version(unittest)
{
    import std.typecons : nullable;
    import std.exception : enforce;
    import vibe.core.concurrency : async;

    Future!Response ok(in string url, in string[string] headers, in string[string] queryParams)
    {
        return async({
            return Response(200, "ok");
        });
    }

    Future!Response ko(in string url, in string[string] headers, in string[string] queryParams)
    {
        return async({
            enforce(false);
            return Response(400, "ko");
        });
    }

    auto buildTestProvider(bool mandatory, string resourceName)
    {
        auto resources = [
            Resource(
                "foo",
                "/{resourceType}/{providerId}/{resourceId}",
                (Nullable!(string[string])).init,
                ["Content-Type": "application/json"],
                mandatory,
                FormatType.sdmxml21
            )
        ];

        return Provider("anId", true, "https://vulpes.org", [resourceName: resources].nullable);
    }
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(true, "dataflow");

    auto r = fetchResources(provider, ResourceType.dataflow, "aResourceId", toDelegate(&ok));
    assert(!r["foo"].isNull);
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(false, "dataflow");

    auto r = fetchResources(provider, ResourceType.dataflow, "aResourceId", toDelegate(&ko));
    assert(r["foo"].isNull);
}

unittest
{
    import std.functional : toDelegate;
    import std.exception : assertThrown;
    auto provider = buildTestProvider(true, "dataflow");

    assertThrown(fetchResources(provider, ResourceType.dataflow, "aResourceId", toDelegate(&ko)));
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(false, "dataflow");

    auto r = fetchResources(provider, ResourceType.dataflow, "aResourceId", toDelegate(&ok));
    assert(!r["foo"].isNull);
}

void enforceMessages(string k, Flag!"canBeNull" canBeNull)(in Nullable!string[string] messages) @safe
{
    import std.exception : enforce;
    import std.format : format;

    auto m = (k in messages);

    enforce!ProviderException(m !is null,
                              format!"provider did not provide %s"(k));

    static if(!canBeNull)
    {
        enforce!ProviderException(!m.isNull,
                                  format!"provider provided a Null resouce %s"(k));
    }
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;
    import std.typecons : nullable, Yes, No;

    auto valid = ["foo": "foo".nullable];
    auto invalid = ["foo": (Nullable!string).init];

    assertNotThrown!ProviderException(enforceMessages!("foo", Yes.canBeNull)(valid));
    assertNotThrown!ProviderException(enforceMessages!("foo", No.canBeNull)(valid));
    assertNotThrown!ProviderException(enforceMessages!("foo", Yes.canBeNull)(invalid));
    assertThrown!ProviderException(enforceMessages!("bar", Yes.canBeNull)(valid));
}