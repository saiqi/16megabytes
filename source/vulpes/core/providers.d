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

    bool hasResource(in string resourceName) pure nothrow @safe inout
    {
        if(this.resources.isNull) return false;

        if(resourceName in this.resources.get) return true;

        return false;
    }

    mixin(Generate);
}

unittest
{
    auto p = Provider("myid", true, "http://foo.bar", ["foo": Resource()].nullable);
    assert(!p.hasResource("bar"));
    assert(p.hasResource("foo"));
}
