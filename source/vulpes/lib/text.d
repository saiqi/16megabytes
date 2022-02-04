module vulpes.lib.text;

import std.typecons : Nullable, nullable;
import std.range;


/**
Return modified edit distance between a range and a longer one.
Params:
    needle = a finite random access range
    haystack = a finite random access range
Returns:
    the edit distance as `Nullable!size_t`
*/
Nullable!size_t fuzzySearch(R1, R2)(R1 needle, R2 haystack) @safe nothrow
if(isForwardRange!R1 && isForwardRange!R2)
{
    scope(failure) return (Nullable!size_t).init;
    import std.algorithm : canFind, min, minElement;
    import std.conv : to;

    auto m = walkLength(needle);
    auto n = walkLength(haystack);

    if(m == 1) return (!haystack.canFind(needle)).to!size_t.nullable;
    if(n == 0) return m.nullable;

    auto row1 = new size_t[](n + 1);
    foreach (i; 0 .. m)
    {
        auto row2 = new size_t[](n + 1);
        row2[0] = i + 1;

        auto sHaystack = haystack.save;

        foreach (j; 0 .. n)
        {
            size_t cost = needle.front != sHaystack.front;
            row2[j + 1] = min(row1[j + 1] + 1, row2[j] + 1, row1[j] + cost);
            sHaystack.popFront();
        }
        row1 = row2;
        needle.popFront();
    }

    return minElement(row1).nullable;
}

unittest
{
    assert(fuzzySearch("aba", "c abba c").get == 1);
    assert(fuzzySearch("a", "c abba c").get == 0);
    assert(fuzzySearch("d", "c abba c").get == 1);
    assert(fuzzySearch("a", "").get == 1);
}