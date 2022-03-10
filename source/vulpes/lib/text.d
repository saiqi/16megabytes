module vulpes.lib.text;

import std.range;


/**
Return modified edit distance between a range and a longer one.
Params:
    needle = a finite random access range
    haystack = a finite random access range
Returns:
    the edit distance
*/
int fuzzySearch(R1, R2)(R1 needle, R2 haystack)
if(isForwardRange!R1 && isForwardRange!R2)
{
    import std.algorithm : canFind, min, minElement;
    import std.conv : to;

    auto m = walkLength(needle).to!int;
    auto n = walkLength(haystack).to!int;

    if(m == 1) return (!haystack.canFind(needle)).to!int;
    if(n == 0) return m;

    auto row1 = new int[](n + 1);
    foreach (i; 0 .. m)
    {
        auto row2 = new int[](n + 1);
        row2[0] = i + 1;

        auto sHaystack = haystack.save;

        foreach (j; 0 .. n)
        {
            int cost = needle.front != sHaystack.front;
            row2[j + 1] = min(row1[j + 1] + 1, row2[j] + 1, row1[j] + cost);
            sHaystack.popFront();
        }
        row1 = row2;
        needle.popFront();
    }

    return minElement(row1);
}

@safe pure unittest
{
    assert(fuzzySearch("aba", "c abba c") == 1);
    assert(fuzzySearch("a", "c abba c") == 0);
    assert(fuzzySearch("d", "c abba c") == 1);
    assert(fuzzySearch("a", "") == 1);
}