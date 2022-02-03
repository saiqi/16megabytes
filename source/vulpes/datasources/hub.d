module vulpes.datasources.hub;

import std.sumtype : SumType, isSumType;
import std.typecons : Nullable;
import vulpes.core.providers : Provider;
import vulpes.core.model : Error_, Dataflow, ErrorStatusCode;

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

SumType!(Error_, Dataflow[]) getDataflows(in Provider provider)
{
    import std.format : format;
    
    SumType!(Error_, Dataflow) result;
    // HTTP query ?
    // Deserialization ?

    if(!provider.hasResource("dataflow"))
    {
        result = Error_.build(ErrorStatusCode.notImplemented,
                              format!"dataflows not found for agency %s"(provider.id));
        return result;
    }

    return result;
}

unittest
{
    import std.typecons : Nullable;
    import std.sumtype : match;
    import vulpes.core.providers : Resource;
    
    const p = Provider("Foo", true, "https://foo.org", Nullable!(Resource[string]).init);
    assert(isError(getDataflows(p)));
}