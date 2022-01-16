module vulpes.lib.templates;

import std.traits : isSomeString, isAssociativeArray;
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


T resolveRequestTemplate(T)(in T template_, in string[string] values)
if(isSomeString!T || (isAssociativeArray!T && isSomeString!(ElementType!(typeof(T.init.values)))))
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
    else
    {
        import std.traits : Unqual;
        alias ElementT = Unqual!(ElementType!(typeof(T.init.values)));
        ElementT[ElementT] result;
        foreach(k; template_.keys)
        {
            result[k] = resolveRequestTemplate(template_[k], values);
        }
        return result;
    }
}

unittest
{
    import std.exception : assertThrown;
    import std.algorithm : equal;
    assert(resolveRequestTemplate("/foo/{id}/bar/", ["id": "1"]) == "/foo/1/bar/");
    assert(resolveRequestTemplate("/{foo}/{id}/{bar}/", ["foo": "foo", "bar": "bar", "id": "1"]) == "/foo/1/bar/");
    assertThrown!TemplateException(resolveRequestTemplate("/foo/{id}/bar/", ["foo": "1"]));

    auto rAA = resolveRequestTemplate(["ref": "{refId}"], ["refId": "1"]);
    assert(rAA.keys.equal(["ref"]));
    assert(rAA.values.equal(["1"]));

    auto rWithoutVar = resolveRequestTemplate(["ref": "foo"], null);
    assert(rWithoutVar.keys.equal(["ref"]));
    assert(rWithoutVar.values.equal(["foo"]));
}