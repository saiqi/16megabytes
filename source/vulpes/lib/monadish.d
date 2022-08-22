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

auto filterNull(R)(R range)
if(isInputRange!(Unqual!R) && isNullable!(ElementType!(Unqual!R)))
{
    static struct FilterNullResult(Range)
    {
        alias R = Unqual!Range;
        private R inRange;
        private bool primed;

        private this(R r) { inRange = r; }

        private this(R r, bool isPrimed) { inRange = r; primed = isPrimed; }

        private void prime()
        {
            if(primed) return;

            while(!inRange.empty && inRange.front.isNull)
            {
                inRange.popFront();
            }

            primed = true;
        }

        auto opSlice() { return this; }

        static if(isInfinite!Range)
        {
            enum bool empty = false;
        }
        else
        {
            @property bool empty() { prime; return inRange.empty; }
        }

        @property auto ref front()
        {
            prime;
            assert(!inRange.empty, "Attempting to fetch front of an empty range.");
            return inRange.front.get;
        }

        void popFront()
        {
            prime;
            do
            {
                inRange.popFront();
            } while(!inRange.empty && inRange.front.isNull);
        }

        static if(isForwardRange!R)
        {
            @property auto save()
            {
                return typeof(this)(inRange.save, primed);
            }
        }


    }

    return FilterNullResult!R(range);
}

nothrow @safe pure unittest
{
    import std.range : iota, walkLength;
    import std.typecons : nullable;
    import std.algorithm : map;

    assert(iota(10).map!"a.nullable".filterNull.walkLength == 10);

    alias f = a => a % 2 == 0 ? (Nullable!int).init : a.nullable;
    assert(iota(10).map!f.filterNull.walkLength == 5);
}

nothrow @safe pure unittest
{
    import std.typecons : nullable;
    import std.range : iota;
    import std.algorithm : map;
    import std.array : array;

    auto range = iota(10).map!"a.nullable".array.filterNull;
    auto copy = range.save;
    range.popFront();
    assert(range.front == 1);
    assert(copy.front == 0);
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