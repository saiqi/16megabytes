module vulpes.lib.boilerplate;

struct getter
{
    string name;
}

mixin template GenerateMembers()
{
    import std.traits : isArray, isAssociativeArray;
    import std.range : ElementType;
    import std.typecons : Nullable, nullable;
    import std.format : format;
    import std.traits : FieldNameTuple, RepresentationTypeTuple, getUDAs, hasUDA, hasFunctionAttributes, hasMember;
    import std.meta : anySatisfy;
    import std.algorithm : filter;
    import std.array : array, join;

    private enum bool isNullable(T) = is(T: Nullable!Arg, Arg);

    private enum dupNeeded(T) = (isAssociativeArray!(T)
        || isArray!T
        || (isNullable!T && dupNeeded!(typeof(T.init.get))))
        && !__traits(compiles, (const T x) { T y = x; });

    unittest
    {
        static struct A {
            @getter("bs")
            private string[] bs_;

            @getter("v")
            private int v_;

            @getter("n")
            private string n_;

            @getter("v2")
            private const(int)[] v2_;
        }
        static assert(dupNeeded!(typeof(__traits(getMember, A, "bs_"))));
        static assert(!dupNeeded!(typeof(__traits(getMember, A, "v_"))));
        static assert(!dupNeeded!(typeof(__traits(getMember, A, "n_"))));
        static assert(!dupNeeded!(typeof(__traits(getMember, A, "v2_"))));
    }

    private template dupCanThrow(T)
    {
        static if(isAssociativeArray!T || (isNullable!T && isAssociativeArray!(typeof(T.init.get))))
        {
            enum dupCanThrow = true;
        }
        else
        {
            static if(!isArray!T)
            {
                enum dupCanThrow = false;
            }
            else
            {
                static if(!hasMember!(ElementType!T, "__postblit"))
                {
                    enum dupCanThrow = false;
                }
                else
                {
                    enum dupCanThrow = !hasFunctionAttributes!((ElementType!T).__postblit, "nothrow");
                }
            }
        }
    }

    alias T = typeof(this);

    private static string generatePostblitCtor()
    {
        string statements;
        string[] ctorAttrs = ["pure", "nothrow", "@safe", "@nogc"];

        static foreach(m; FieldNameTuple!T)
        {{
            alias Type = typeof(__traits(getMember, T, m));
            static if(dupNeeded!Type)
            {
                ctorAttrs = ctorAttrs.filter!(q{a != "@nogc"}).array;
                static if(isNullable!Type)
                {
                    statements ~= format!"%s = %s.isNull ? typeof(%s).init : typeof(%s)(%s.get.dup);"
                        (m, m, m, m, m);
                }
                else
                {
                    statements ~= format!"%s = %s.dup;"(m, m);
                }

                static if(dupCanThrow!Type)
                {
                    ctorAttrs = ctorAttrs.filter!(q{a != "nothrow"}).array;
                }
            }
        }}
        string attrs = ctorAttrs.join(" ");
        return format!"public this(this) %s {%s}"(attrs, statements);
    }

    private static string generateMembers()
	{
        if(!__ctfe)
        {
            return null;
        }

    	string members = null;
        static if(anySatisfy!(dupNeeded, RepresentationTypeTuple!T))
        {
            members ~= generatePostblitCtor();
        }
		static foreach(m; FieldNameTuple!T)
    	{
            static if(hasUDA!(__traits(getMember, T, m), getter))
            {
        	    members ~= format!"public inout(%s) %s() inout pure nothrow @safe {return %s;}"(
                    typeof(__traits(getMember, T, m)).stringof,
                    getUDAs!(__traits(getMember, T, m), getter)[0].name,
                    m);
            }
    	}
    	return members;
	}
}

unittest
{
    import std.typecons : Nullable;
    import std.traits : hasMember;

    static struct C
    {
        @getter("r")
        private int r_;

        mixin(Generate);
    }

    static struct B
    {
        @getter("v")
        private Nullable!int v_;

        @getter("c")
        private C c_;

        mixin(Generate);
    }

    static struct A
    {
        @getter("bs")
        private B[] bs_;

        @getter("ids")
        private string[] ids_;

        mixin(Generate);
    }

    assert(hasMember!(A, "ids"));
    assert(hasMember!(A, "bs"));
    assert(hasMember!(B, "v"));
    assert(hasMember!(B, "c"));
    assert(hasMember!(C, "r"));
}

unittest
{
    static struct A
    {
        int[] v;

        mixin GenerateMembers;
        mixin(typeof(this).generatePostblitCtor());
    }

    auto vs = [1, 2, 3];
    auto a = A(vs);
    auto aa = a;
    vs[0] = -1;
    assert(aa.v[0] == 1);
}


unittest
{
    import std.typecons : Nullable, nullable;

    static struct A
    {
        Nullable!(int[]) v;

        mixin(Generate);
    }

    auto v = [0, 1, 2];
    auto a = A(v.nullable);
    auto aa = a;
    v[0] = 9;
    assert(aa.v.get[0] == 0);
}

unittest
{
    static struct A
    {
        int[int] values;

        mixin(Generate);
    }

    auto v = [1 : 1];
    const a = A(v);
    auto b = a;
    v[1] = -1;
    assert(b.values[1] == 1);
}

enum Generate = q{
    import vulpes.lib.boilerplate : GenerateMembers, getter;
    mixin GenerateMembers;
    mixin(typeof(this).generateMembers());
};