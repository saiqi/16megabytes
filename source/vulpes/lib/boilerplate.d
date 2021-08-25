module vulpes.lib.boilerplate;

struct getter
{
    string name;
}

mixin template GenerateMembers()
{
    import std.traits : isArray, isAssociativeArray;
    import std.range : ElementType;
    import std.format : format;
    import std.traits : FieldNameTuple, RepresentationTypeTuple, getUDAs, hasUDA;
    import std.meta : anySatisfy;

    private enum dupNeeded(T) = isAssociativeArray!(T) || isArray!T;

    unittest
    {
        static struct A {
            @getter("bs")
            private string[] bs_;

            @getter("v")
            private int v_;
        }
        static assert(dupNeeded!(typeof(__traits(getMember, A, "bs_"))));
        static assert(!dupNeeded!(typeof(__traits(getMember, A, "v_"))));
    }

    alias T = typeof(this);

    private static string generatePostblitCtor()
    {
        string statements;
        static foreach(m; FieldNameTuple!T)
        {
            static if(dupNeeded!(typeof(__traits(getMember, T, m))))
                statements ~= format!"%s = %s.dup;"(m, m);
        }
        return format!"public this(this) pure nothrow @safe {%s}"(statements);
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
    import std.traits : hasElaborateCopyConstructor, hasMember;

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

    static assert(hasElaborateCopyConstructor!A);
    static assert(!hasElaborateCopyConstructor!B);
    static assert(!hasElaborateCopyConstructor!C);
    static assert(hasMember!(A, "ids"));
    static assert(hasMember!(A, "bs"));
    static assert(hasMember!(B, "v"));
    static assert(hasMember!(B, "c"));
    static assert(hasMember!(C, "r"));
}

enum Generate = q{
    import vulpes.lib.boilerplate : GenerateMembers;
    mixin GenerateMembers;
    mixin(typeof(this).generateMembers());
};