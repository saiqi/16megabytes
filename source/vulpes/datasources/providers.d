module vulpes.datasources.providers;

import std.typecons : Nullable, Tuple;
import vulpes.lib.boilerplate : Generate;
import vulpes.core.model : ResourceType;

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
    Nullable!(string[string]) queryTemplate;
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
