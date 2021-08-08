module vulpes.datasources.providers;
import std.typecons : Nullable, nullable;
import vibe.data.json : optional;
import vulpes.core.cube : ResourceType;
import vulpes.datasources.sdmxml21;

private:
auto readProviders()
{
    import vibe.core.file : readFileUTF8;
    import vibe.data.json : deserializeJson;
    auto content = readFileUTF8("./conf/providers.json");
    return deserializeJson!(immutable Provider[])(content);
}

unittest
{
    readProviders();
}

package:
enum Format : string
{
    sdmxml21 = "sdmxml21"
}

struct Resource
{
    string pathTemplate;
    @optional Nullable!(string[string]) queryTemplate;
    @optional Nullable!(string[string]) headerTemplate;
}

struct Provider
{
    string id;
    bool isPublic;
    string rootUrl;
    @optional Nullable!Format format;
    @optional Nullable!(Resource[string]) resources;
}

immutable Provider[] providers;

shared static this()
{
    providers = readProviders();
}

public:
auto getProviders() pure nothrow
{
    import std.algorithm : filter;
    import std.array : array;
    return providers.filter!(p => p.isPublic).array;
}

unittest
{
    import std.algorithm : all;
    auto ps = getProviders();
    assert(ps.all!(p => p.isPublic));
}

Nullable!(immutable(Provider)) getProvider(in string id)
{
    import std.algorithm : filter;
    auto candidates = providers.filter!(p => p.id == id);

    return candidates.empty
        ? (typeof(return)).init
        : candidates.front.nullable;
}

unittest
{
    assert(getProvider("FR1").get.id == "FR1");
    assert(getProvider("UNKNOWN").isNull);
}

bool hasResource(in Provider provider, in string resourceName) pure nothrow @safe
{
    if(provider.resources.isNull) return false;

    if(resourceName in provider.resources.get) return true;

    return false;
}

unittest
{
    auto p = getProvider("ESTAT").get;
    assert(!hasResource(p, "categoryscheme"));
    assert(hasResource(p, "dataflow"));
}
