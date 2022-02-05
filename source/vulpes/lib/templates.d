module vulpes.lib.templates;

import std.traits : isSomeString;
import std.range : ElementType;

///Dedicated module `Exception`
class TemplateException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

enum bool isTemplate(T) = isSomeString!T || is(T == V[K], K : string, V : string);

unittest
{
    static assert(isTemplate!string);
    static assert(isTemplate!(const(string)));
    static assert(isTemplate!(inout(string)));
}

auto resolve(T)(T template_, in string[string] values) @safe
if(isTemplate!T)
{
    static if(isSomeString!T)
    {
        import std.regex : regex, matchAll;
        import std.array : replace;
        import std.exception : enforce;
        import std.format : format;

        auto r = regex(`\{(\w+)\}`);
        T result = template_.dup;
        foreach(m; matchAll(template_, r))
        {
            if(m[1] in values) result = replace(result, m[0], values[m[1]]);
        }
        enforce!TemplateException(matchAll(result, r).empty,
                                 format!"Serveral templated items have not been replace in %s"(result));
        return result;
    }
    else static if(is(T == V[K], K, V))
    {
        import std.traits : Unqual;

        Unqual!V[K] result;
        foreach(k; template_.keys)
        {
            result[k] = resolve(template_[k], values);
        }
        return result;
    }
}

unittest
{
    import std.exception : assertThrown;
    import std.algorithm : equal;
    assert(resolve("/foo/{id}/bar/", ["id": "1"]) == "/foo/1/bar/");
    assert(resolve("/{foo}/{id}/{bar}/", ["foo": "foo", "bar": "bar", "id": "1"]) == "/foo/1/bar/");
    assertThrown!TemplateException(resolve("/foo/{id}/bar/", ["foo": "1"]));

    auto rAA = resolve(["ref": "{refId}"], ["refId": "1"]);
    assert(rAA.keys.equal(["ref"]));
    assert(rAA.values.equal(["1"]));

    auto rWithoutVar = resolve(["ref": "foo"], null);
    assert(rWithoutVar.keys.equal(["ref"]));
    assert(rWithoutVar.values.equal(["foo"]));
}

unittest
{
    static struct A
    {
        string[string] tmpl;

        string[string] func(const(string[string]) vars) @safe inout
        {
            return resolve(this.tmpl, vars);
        }
    }

    const ac = A(["a": "{var}"]);
    assert(ac.func(["var": "1"])["a"] == "1");
}