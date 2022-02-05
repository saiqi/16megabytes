module vulpes.datasources.hub;

import std.sumtype : SumType, isSumType;
import std.typecons : Nullable;
import vibe.core.concurrency : Future;
import vulpes.datasources.providers : Provider;
import vulpes.core.model;
import vulpes.requests : doAsyncRequest, Response;

private bool isError(T)(auto ref const T t) pure @safe
if(isSumType!T)
{
    import std.sumtype : match;
    return t.match!(
        (ref const Error_ e) => true,
        _ => false
    );
}

unittest
{
    SumType!(Error_, int) s;
    s = Error_.build(ErrorStatusCode.notFound, "my message");
    assert(isError(s));

    s = 42;
    assert(!isError(s));
}

alias Fetcher = Future!Response delegate(in string, in string[string], in string[string]);

private Nullable!string[string] fetchResources(Fetcher fetcher,
                                               in Provider provider,
                                               in ResourceType resourceType,
                                               in string resourceId = null)
{
    import std.typecons : tuple, nullable, apply;
    import std.traits : ReturnType;
    import std.algorithm : sort;
    import vulpes.datasources.providers : RequestItems;
    import vulpes.requests : getResultOrFail, getResultOrNullable;

    typeof(return) result;

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
            result[ri.name] = getResultOrNullable(fut)
                .apply!(r => r.content);
    }

    return result;
}

version(unittest)
{
    import std.typecons : nullable;
    import std.exception : enforce;
    import vibe.core.concurrency : async;
    import vulpes.datasources.providers : Resource;

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
                mandatory
            )
        ];

        return Provider("anId", true, "https://vulpes.org", [resourceName: resources].nullable);
    }
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(true, "dataflow");

    auto r = fetchResources(toDelegate(&ok), provider, ResourceType.dataflow, "aResourceId");
    assert(!r["foo"].isNull);
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(false, "dataflow");

    auto r = fetchResources(toDelegate(&ko), provider, ResourceType.dataflow, "aResourceId");
    assert(r["foo"].isNull);
}

unittest
{
    import std.functional : toDelegate;
    import std.exception : assertThrown;
    auto provider = buildTestProvider(true, "dataflow");

    assertThrown(fetchResources(toDelegate(&ko), provider, ResourceType.dataflow, "aResourceId"));
}

SumType!(Error_, Dataflow[]) getDataflows(Fetcher fetcher, in Provider provider) nothrow
{
    import std.format : format;

    SumType!(Error_, Dataflow[]) result;
    // Deserialization ?

    scope(failure)
    {
        result = Error_.build(ErrorStatusCode.internalServerError,
                              "unexpected error");
        return result;
    }

    if(!provider.hasResource(ResourceType.dataflow))
    {
        result = Error_.build(ErrorStatusCode.notImplemented,
                              format!"dataflows not found for agency %s"(provider.id));
        return result;
    }

    const responses = fetchResources(fetcher, provider, ResourceType.dataflow);

    return result;
}
