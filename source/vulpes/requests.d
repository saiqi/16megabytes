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

auto doRequest(Flag!"raiseForStatus" raiseForStatus)(string url, string[string] headers, string[string] params = null)
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
            static if(raiseForStatus)
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

unittest
{
    import std.typecons : Yes;
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(Yes.raiseForStatus)(url, headers);
    assert(resp.length);
}

unittest
{
    import std.typecons : Yes;
    auto url = "https://httpbin.org/get";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(Yes.raiseForStatus)(url, headers, ["foo": "bar"]);
    assert(resp.length);
}

unittest
{
    import std.typecons : No;
    auto url = "https://httpbin.org/status/400";
    auto headers = ["Accept": "application/json"];

    auto resp = doRequest!(No.raiseForStatus)(url, headers);
    assert(!resp.length);
}

unittest
{
    import std.exception : assertThrown;
    import std.typecons : Yes;

    auto url = "https://httpbin.org/status/400";
    auto headers = ["Accept": "application/json"];

    assertThrown!RequestException(doRequest!(Yes.raiseForStatus)(url, headers));
}

auto doAsyncRequest(string url, string[string] headers, string[string] params = null)
{
    import std.typecons : Yes;
    import vibe.core.concurrency : async;
    return async({
        return doRequest!(Yes.raiseForStatus)(url, headers, params);
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
