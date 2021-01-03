module vulpes.lib.futures;

import std.typecons : Nullable, nullable;
import vibe.core.concurrency : Future;


auto getResultOrFail(E, T)(Future!T future)
if(is(E: Exception))
{
    try
    {
        return future.getResult;
    }
    catch(Exception e)
    {
        throw new E(e.msg);
    }
    assert(false);
}

version(unittest)
{
    bool f(bool fail)
    {
        if(fail) throw new Exception("");
        return fail;
    }
}

unittest
{
    static class MyException : Exception
    {
        this(string msg, string file = __FILE__, size_t line = __LINE__)
        {
            super(msg, file, line);
        }
    }

    import vibe.core.concurrency : async;
    import std.exception : assertThrown, assertNotThrown;

    assertThrown!MyException(
        async({return f(true);}).getResultOrFail!MyException);

    assertNotThrown!MyException(
        async({return f(false);}).getResultOrFail!MyException);
}


auto getResultOrNullable(T)(Future!T future) nothrow
{
    try
    {
        return future.getResult.nullable;
    }
    catch(Exception e)
    {
        return (Nullable!T).init;
    }
}


unittest
{
    import vibe.core.concurrency : async;
    assert(async({return f(true);}).getResultOrNullable.isNull);
    assert(!async({return f(false);}).getResultOrNullable.isNull);
}
