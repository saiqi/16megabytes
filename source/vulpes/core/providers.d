module vulpes.core.providers;

import std.typecons : Nullable, nullable;
import vulpes.lib.boilerplate : Generate;

struct Resource
{
    string pathTemplate;
    Nullable!(string[string]) queryTemplate;
    Nullable!(string[string]) headerTemplate;

    mixin(Generate);
}

struct Provider
{
    string id;
    bool isPublic;
    string rootUrl;
    Nullable!(Resource[string]) resources;

    mixin(Generate);
}

bool hasResource(in Provider provider, in string resourceName) pure nothrow @safe
{
    if(provider.resources.isNull) return false;

    if(resourceName in provider.resources.get) return true;

    return false;
}

unittest
{
    auto p = Provider("myid", true, "http://foo.bar", ["foo": Resource()].nullable);
    assert(!hasResource(p, "bar"));
    assert(hasResource(p, "foo"));
}
