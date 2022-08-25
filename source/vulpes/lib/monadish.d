module vulpes.lib.monadish;

import std.typecons : Nullable;
import std.traits : Unqual, TemplateArgsOf;
import std.range;

enum bool isNullable(T) = is(T: Nullable!Arg, Arg);

template NullableOf(T)
{
    static assert(isNullable!T, "NullableOf can only be called on Nullable type");
    alias NullableOf = TemplateArgsOf!T[0];
}

unittest
{
    static assert(is(NullableOf!(Nullable!int) == int));
    static assert(is(NullableOf!(Nullable!(const int)) == const int));
}

template fallbackMap(alias fun)
{
    import std.functional : unaryFun;

    alias f = unaryFun!fun;

    auto fallbackMap(R)(R r)
    if(isInputRange!(Unqual!R) && !is(typeof(f(ElementType!R).init) == void))
    {
        alias RT = typeof(f((ElementType!R).init));

        import std.array : Appender;
        Appender!(RT[]) app;

        foreach (el; r) app.put(f(el));

        return app.data;
    }
}

pure @safe nothrow unittest
{
    static struct A
    {
        int v;
    }

    static struct B
    {
        A[] as;

        int[] prop() pure @safe inout
        {
            return as.fallbackMap!"a.v%2";
        }
    }

    assert(B([A(0), A(1), A(2), A(4)]).prop);
}

Nullable!ValueType convertLookup(ValueType, KeyType, AA)(AA aa, KeyType k)
{
    import std.conv : to;

    Nullable!ValueType result;
    auto v = (k in aa);
    if(v is null) return result;
    result = aa[k].to!ValueType;
    return result;
}

unittest
{
    auto aa = ["a": "1", "b": "true", "c": "foo"];
    assert(!convertLookup!(uint, string)(aa, "a").isNull);
    assert(!convertLookup!(bool, string)(aa, "b").isNull);
    assert(!convertLookup!(string, string)(aa, "c").isNull);
    assert(convertLookup!(uint, string)(aa, "d").isNull);
}