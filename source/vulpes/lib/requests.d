module vulpes.lib.requests;

import std.typecons : Flag, Tuple;
import std.traits : isCallable, ReturnType, isSomeChar, Parameters, isAssociativeArray, isSomeString, TemplateOf;
import std.range : isForwardRange, ElementType;
import vibe.core.concurrency : Future;

///Dedicated module `Exception`
class RequestException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

alias RaiseForStatus = Flag!"raiseForStatus";

alias RequestParameter = Tuple!(string, "url", string[string], "headers", string[string], "params");

auto doRequest(RaiseForStatus raiseForStatus)(string url, string[string] headers, string[string] params = null)
{
    import std.array : join, array, byPair;
    import std.algorithm : map;
    import std.exception : enforce;
    import std.format : format;
    import vibe.http.client : requestHTTP;
    import vibe.inet.url : URL;
    import vibe.stream.operations : readAllUTF8;
    import vibe.core.log : logDebug;

    auto pUrl = URL(url);
    pUrl.queryString = params.byPair.map!(t => t[0] ~ "=" ~ t[1]).array.join("&");
    string content;
    logDebug("Requesting: %s headers: %s", pUrl.toString, headers);
    requestHTTP(pUrl,
        (scope req) {
            foreach(k, v; headers.byPair)
                req.headers[k] = v;
        },
        (scope resp) {
            static if(raiseForStatus == RaiseForStatus.yes)
            {
                enforce!RequestException(resp.statusCode < 400,
                                         format!"%s returned HTTP %s code"(url, resp.statusCode));
            }
            content = resp.bodyReader.readAllUTF8;
            logDebug("%s: %s", pUrl.toString, resp.statusCode);
        }
    );
    return content;
}

auto doRequestFromParameter(RaiseForStatus raiseForStatus)(RequestParameter p)
{
    return doRequest!raiseForStatus(p.url, p.headers, p.params);
}

unittest
{
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(RaiseForStatus.yes)(url, headers);
    assert(resp.length);
}

unittest
{
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];
    auto params = ["args": "foo"];

    auto t = Tuple!(string, "url", string[string], "headers", string[string], "params")(url, headers, params);
    auto resp = doRequestFromParameter!(RaiseForStatus.yes)(t);
    assert(resp.length);
}

unittest
{
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(RaiseForStatus.yes)(url, headers, ["foo": "bar"]);
    assert(resp.length);
}

unittest
{
    auto url = "https://httpbin.org/status/400";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(RaiseForStatus.no)(url, headers);
    assert(!resp.length);
}

unittest
{
    import std.exception : assertThrown;

    auto url = "https://httpbin.org/status/400";
    auto headers = ["Accept": "application/json"];

    assertThrown!RequestException(doRequest!(RaiseForStatus.yes)(url, headers));
}

auto doAsyncRequest(string url, string[string] headers, string[string] params = null)
{
    import vibe.core.concurrency : async;
    return async({
        return doRequest!(RaiseForStatus.yes)(url, headers, params);
    });
}

unittest
{
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];
    auto fut = doAsyncRequest(url, headers);
    assert(fut.getResult.length);
}

auto getResultOrFail(alias E = RequestException, T)(Future!T fut)
{
    import std.exception : enforce;

    try
    {
        return fut.getResult;
    }
    catch(Exception e)
    {
        enforce!E(false, e.msg);
    }
    assert(false);
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    auto headers = ["Accept": "application/json"];
    assertThrown!RequestException(
        doAsyncRequest("https://httpbin.org/status/400", headers).getResultOrFail);
    assertNotThrown!RequestException(
        doAsyncRequest("https://httpbin.org/get", headers).getResultOrFail);
}

auto getResultOrNullable(T)(Future!T fut)
{
    import std.typecons : nullable, Nullable;
    scope(failure) return (Nullable!T).init;
    return fut.getResult.nullable;
}

unittest
{
    auto headers = ["Accept": "application/json"];
    assert(doAsyncRequest("https://httpbin.org/status/400", headers).getResultOrNullable.isNull);
    assert(!doAsyncRequest("https://httpbin.org/get", headers).getResultOrNullable.isNull);
}


T resolveRequestTemplate(T)(in T template_, in string[string] values)
if(isSomeString!T || (isAssociativeArray!T && isSomeString!(ElementType!(typeof(T.init.values)))))
{
    // TODO: check if the vibed URL pattern hanlder has a public interface
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
        enforce!RequestException(matchAll(result, r).empty,
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
    assertThrown!RequestException(resolveRequestTemplate("/foo/{id}/bar/", ["foo": "1"]));

    auto rAA = resolveRequestTemplate(["ref": "{refId}"], ["refId": "1"]);
    assert(rAA.keys.equal(["ref"]));
    assert(rAA.values.equal(["1"]));

    auto rWithoutVar = resolveRequestTemplate(["ref": "foo"], null);
    assert(rWithoutVar.keys.equal(["ref"]));
    assert(rWithoutVar.values.equal(["foo"]));
}