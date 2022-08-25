module vulpes.lib.monadish;

import std.typecons : Nullable;
import std.traits : Unqual, TemplateArgsOf;
import std.sumtype : SumType, match;
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

alias Result(T) = SumType!(Error, T);
enum bool isResult(Result) = is(Result: SumType!(E, T), T, E : Error);
template ResultOf(Result)
{
    static assert(isResult!Result);
    alias ResultOf = TemplateArgsOf!Result[1];
}

bool isError(Result)(auto ref Result r)
if(isResult!Result)
{
    alias T = ResultOf!Result;
    return r.match!(
        (inout(Error) e) => true,
        (inout(T) t) => false
    );
}

@safe unittest
{
    Result!int v = 1;
    assert(!v.isError);
}

unittest
{
    Result!int divide(int a, int b) nothrow
    {
        Result!int result;
        if(b == 0) result = new Error("Division by zero!");
        else result = a / b;
        return result;
    }

    auto d24 = divide(2, 4);
    assert(!d24.isError);

    auto d20 = divide(2, 0);
    assert(d20.isError);
}

T get(Result, T)(auto ref Result r, T default_)
if(isResult!Result && is(T : ResultOf!Result))
{
    return r.match!(
        (inout(Error) e) => default_,
        (inout(T) t) => t
    );
}

unittest
{
    Result!int err = new Error("");
    assert(err.get(0) == 0);

    Result!int ok = 1;
    assert(ok.get(0) == 1);
}

auto toRange(Result)(auto ref Result r)
if(isResult!Result)
{
    static struct ResultRange
    {
        private:
        Result result_;
        bool isEmpty;
        alias T = ResultOf!Result;

        public:
        this(Result result)
        {
            result_ = result;
            isEmpty = isError(result_);
        }

        @property bool empty() inout
        {
            return isEmpty;
        }

        @property T front() inout
        {
            assert(!empty);
            return result_.get(T.init);
        }

        alias back = front;

        void popFront()
        {
            assert(!empty);
            isEmpty = true;
        }

        void popBack()
        {
            popFront();
        }

        @property inout(typeof(this)) save() inout
        {
            return this;
        }

        @property size_t length() inout
        {
            return !empty;
        }
    }

    return ResultRange(r);
}

unittest
{
    import std.algorithm : equal;

    Result!int v = 1;
    auto rangeV = v.toRange;
    assert(!rangeV.empty);
    assert(rangeV.length == 1);
    assert(rangeV.equal([1]));

    auto copy = rangeV.save();
    rangeV.popFront();
    assert(rangeV.empty);
    assert(!copy.empty);

    Result!int err = new Error("");
    auto rangeErr = err.toRange;
    assert(rangeErr.empty);
    assert(rangeErr.length == 0);
}

unittest
{
    import std.algorithm : joiner, equal;
    import std.range;

    static struct Record
    {
        int id;
        string name;
    }

    Result!Record foo = Record(1, "foo");
    Result!Record bar = Record(2, "bar");
    Result!Record err = new Error("");
    assert([foo.toRange, err.toRange, bar.toRange]
        .joiner
        .equal([Record(1, "foo"), Record(2, "bar")]));
}