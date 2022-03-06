module vulpes.lib.monadish;

import std.typecons : Nullable;
import std.traits : Unqual;
import std.range;

enum bool isNullable(T) = is(T: Nullable!Arg, Arg);

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