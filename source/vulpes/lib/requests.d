module vulpes.lib.requests;

import std.typecons : Flag;
import std.exception : enforce;
import std.format : format;
import std.traits : isCallable, ReturnType, isSomeChar, Parameters;
import std.range : isForwardRange, ElementType;
import requests : Request;

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

enum isFetcher(alias func) =
    isCallable!func
    && isForwardRange!(ReturnType!func)
    && isSomeChar!(ElementType!(ReturnType!func));

auto doRequest(RaiseForStatus raiseForStatus)(string url, string[string] headers, string[string] params = null)
{
    auto req = Request();
    req.sslSetVerifyPeer(false);
    req.addHeaders(headers);

    auto resp = req.get(url, params);

    static if(raiseForStatus == RaiseForStatus.yes)
    {
        enforce!RequestException(resp.code < 400, format!"%s returned HTTP %s code"(url, resp.code));
    }

    return resp.responseBody.data!string;
}

static assert(isFetcher!(doRequest!(RaiseForStatus.yes)));

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