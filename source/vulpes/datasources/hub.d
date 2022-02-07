module vulpes.datasources.hub;

import std.sumtype : SumType, isSumType;
import std.typecons : Nullable, Tuple;
import std.traits : ReturnType;
import vibe.core.concurrency : Future;
import vulpes.datasources.providers : Provider, FormatType;
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
private alias Content = Tuple!(Nullable!string, "content", FormatType, "formatType");

private Content[string] fetchResources(Fetcher fetcher,
                                       in Provider provider,
                                       in ResourceType resourceType,
                                       in string resourceId = null)
{
    import std.typecons : tuple, nullable, apply;
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
            result[ri.name] = Content(getResultOrFail(fut).content.nullable, ri.formatType);
        else
        {
            auto rn = getResultOrNullable(fut).apply!(a => a.content);
            result[ri.name] = Content(rn, ri.formatType);
        }
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
                mandatory,
                FormatType.sdmxml21
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
    assert(!r["foo"].content.isNull);
    assert(r["foo"].formatType == FormatType.sdmxml21);
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(false, "dataflow");

    auto r = fetchResources(toDelegate(&ko), provider, ResourceType.dataflow, "aResourceId");
    assert(r["foo"].content.isNull);
    assert(r["foo"].formatType == FormatType.sdmxml21);
}

unittest
{
    import std.functional : toDelegate;
    import std.exception : assertThrown;
    auto provider = buildTestProvider(true, "dataflow");

    assertThrown(fetchResources(toDelegate(&ko), provider, ResourceType.dataflow, "aResourceId"));
}

unittest
{
    import std.functional : toDelegate;

    auto provider = buildTestProvider(false, "dataflow");

    auto r = fetchResources(toDelegate(&ok), provider, ResourceType.dataflow, "aResourceId");
    assert(!r["foo"].content.isNull);
    assert(r["foo"].formatType == FormatType.sdmxml21);
}

private enum bool isMappable(S, T) = is(ReturnType!((S s) => s.convert) : Nullable!T);

private Nullable!(T[]) buildListFromXml(string resourceName, S, T)(in Nullable!string[string] messages,
                                                                   int limit,
                                                                   int offset)
if(isMappable!(S, T))
{
    import std.range : drop, take;
    import std.array : Appender;
    import std.typecons : apply;
    import vulpes.lib.xml : deserializeAsRangeOf;

    return messages.get(resourceName, (Nullable!string).init)
        .apply!((msg) {
            Appender!(T[]) dfs;
            if(limit > 0) dfs.reserve(limit);
            auto iRange = msg.deserializeAsRangeOf!S
                .drop(offset)
                .take(limit);

            foreach (ref iDf; iRange)
            {
                auto df = iDf.convert;
                if(!df.isNull) dfs.put(df.get);
            }
            return dfs.data;
        });
}

unittest
{
    import std.algorithm : equal;
    import vulpes.lib.xml : xmlRoot, text;

    static struct Out
    {
        int v;
    }

    @xmlRoot("node")
    static struct In
    {
        @text
        int v;

        Nullable!Out convert() pure nothrow @safe inout
        {
            return Out(this.v).nullable;
        }
    }

    static assert(isMappable!(In, Out));

    auto xml = "<root><node>1</node><node>2</node><node>3</node></root>";

    auto messages = ["in": xml.nullable];
    assert(equal(buildListFromXml!("in", In, Out)(messages, 3, 0).get, [Out(1), Out(2), Out(3)]));
    assert(equal(buildListFromXml!("in", In, Out)(messages, 1, 0).get, [Out(1)]));
    assert(equal(buildListFromXml!("in", In, Out)(messages, 2, 1).get, [Out(2), Out(3)]));
    assert(buildListFromXml!("in", In, Out)(["other": xml.nullable], 3, 0).isNull);
}


SumType!(Error_, Dataflow[]) getDataflows(Fetcher fetcher, in Provider provider, int limit = -1, int offset = 0) nothrow
{
    import std.format : format;
    import std.algorithm : uniq, map;
    import std.typecons : tuple;
    import std.array : array, assocArray;

    SumType!(Error_, Dataflow[]) result;

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

    auto responses = fetchResources(fetcher, provider, ResourceType.dataflow);

    const types = responses.byValue.map!"a.formatType".uniq.array;

    auto messages = responses.byKeyValue.map!(t => tuple(t.key, t.value.content)).assocArray;

    if(types.length > 1)
    {
        result = Error_.build(ErrorStatusCode.internalServerError,
                              format!"multiple resource types are not supported: %s"(types));
        return result;
    }

    Nullable!(Dataflow[]) dfs;
    with(FormatType) final switch(types[0])
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : SDMX21Dataflow;
        dfs = buildListFromXml!("dataflow", SDMX21Dataflow, Dataflow)(messages, limit, offset);
        break;

        case sdmxml20:
        import vulpes.datasources.sdmxml20 : SDMX20Dataflow;
        dfs = buildListFromXml!("dataflow", SDMX20Dataflow, Dataflow)(messages, limit, offset);
        break;
    }

    if(dfs.isNull)
    {
        result = Error_.build(ErrorStatusCode.internalServerError,
                              "something went wrong!");
        return result;
    }

    result = dfs.get;

    return result;
}
