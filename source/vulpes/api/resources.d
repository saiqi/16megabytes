module source.vulpes.api.resources;

import std.typecons : Nullable;

mixin template GenerateFromModel(Model, Resource)
{
    import std.traits : FieldNameTuple, hasMember, Unqual, isArray, isAssociativeArray, isSomeString;
    import std.range : ElementType, zip;
    import std.algorithm : map;
    import std.array : array, assocArray;
    import vulpes.lib.monadish : isNullable, NullableOf;

    static Resource fromModel(in ref Model m)
    {
        Resource r;

        static foreach(member; FieldNameTuple!Resource)
        {{
            alias ResourceFieldT = typeof(__traits(getMember, Resource, member));
            enum currentMember = Resource.stringof ~ "." ~ member;

            static assert(hasMember!(Model, member),
                          currentMember ~ " not found in " ~ Model.stringof);

            alias ModelFieldT = Unqual!(typeof(__traits(getMember, Model, member)));
            static if(is(ResourceFieldT == struct))
            {
                static assert(is(ModelFieldT == struct),
                                "Cannot assign " ~ ModelFieldT.stringof ~ " to " ~ currentMember);
                static if(isNullable!ResourceFieldT)
                {
                    static assert(isNullable!ModelFieldT,
                                 currentMember ~ " is Nullable, corresponding model field is not");
                    alias ResourceFieldST = NullableOf!ResourceFieldT;
                    if(__traits(getMember, m, member).isNull)
                    {
                        __traits(getMember, r, member) = (Nullable!ResourceFieldST).init;
                    }
                    else
                    {
                        alias ModelFieldST = NullableOf!ModelFieldT;
                        Nullable!ResourceFieldST value;
                        static if(is(ResourceFieldST == struct))
                        {
                            ModelFieldST model = __traits(getMember, m, member).get;
                            value = ResourceFieldST.fromModel(model);
                        }
                        else static if(isAssociativeArray!ResourceFieldST)
                        {
                            static assert(isAssociativeArray!ModelFieldST,
                                currentMember ~ " is an associative array, the corresponding model field is not");
                            value = zip(__traits(getMember, m, member).get.keys.dup,
                                        __traits(getMember, m, member).get.values.dup).assocArray;
                        }
                        else
                        {
                            value = __traits(getMember, m, member).get;
                        }
                        __traits(getMember, r, member) = value;
                    }
                }
                else
                {
                    __traits(getMember, r, member) = ResourceFieldT.fromModel(__traits(getMember, m, member));
                }
            }
            else static if(isArray!ResourceFieldT && !isSomeString!ResourceFieldT)
            {
                static assert(isArray!ModelFieldT,
                             currentMember ~ " is an array, the corresponding model field is not");
                alias ResourceFieldST = ElementType!ResourceFieldT;
                static if(is(ResourceFieldST == struct))
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member)
                        .dup
                        .map!(a => ResourceFieldST.fromModel(a))
                        .array;
                }
                else
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member).dup;
                }
            }
            else static if(isAssociativeArray!ResourceFieldT)
            {
                static assert(isAssociativeArray!ModelFieldT,
                             currentMember ~ " is an associative array, the corresponding model field is not");
                __traits(getMember, r, member) = zip(__traits(getMember, m, member).keys.dup,
                                                     __traits(getMember, m, member).values.dup).assocArray;
            }
            else
            {
                static if(is(ModelFieldT == struct) && isSomeString!ResourceFieldT)
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member).toString();
                }
                else
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member);
                }
            }
        }}

        return r;
    }
}

unittest
{
    static struct MyModel
    {
        string field;
    }

    static struct MyResource
    {
        string field;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto m = MyModel("foo");
    auto r = MyResource.fromModel(m);
    assert(r.field == "foo");
}

unittest
{
    static struct MyModel
    {
        Nullable!string field;
    }

    static struct MyResource
    {
        Nullable!string field;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    Nullable!string v = "foo";
    auto m = MyModel(v);
    auto r = MyResource.fromModel(m);
    assert(r.field.get == "foo");
}

unittest
{
    static struct MyNestedModel
    {
        string field;
    }

    static struct MyModel
    {
        MyNestedModel nested;
    }

    static struct MyNestedResource
    {
        string field;
        mixin GenerateFromModel!(MyNestedModel, typeof(this));
    }

    static struct MyResource
    {
        MyNestedResource nested;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto m = MyModel(MyNestedModel("foo"));
    auto r = MyResource.fromModel(m);
    assert(r.nested.field == "foo");
}

unittest
{
    static struct MyNestedModel
    {
        string field;
    }

    static struct MyModel
    {
        Nullable!MyNestedModel nested;
    }

    static struct MyNestedResource
    {
        string field;
        mixin GenerateFromModel!(MyNestedModel, typeof(this));
    }

    static struct MyResource
    {
        Nullable!MyNestedResource nested;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }
    Nullable!MyNestedModel nested = MyNestedModel("foo");
    auto m = MyModel(nested);
    auto r = MyResource.fromModel(m);
    assert(r.nested.get.field == "foo");
}

unittest
{
    import std.algorithm : equal;

    static struct MyModel
    {
        int[] fields;
    }

    static struct MyResource
    {
        int[] fields;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    int[] fields = [1, 2, 3];
    auto m = MyModel(fields.dup);
    auto r = MyResource.fromModel(m);
    assert(r.fields.equal(m.fields));
    m.fields ~= 4;
    assert(r.fields.equal(fields));
}

unittest
{
    import std.algorithm : equal;

    static struct MyNestedModel
    {
        string field;
    }

    static struct MyModel
    {
        MyNestedModel[] nested;
    }

    static struct MyNestedResource
    {
        string field;
        mixin GenerateFromModel!(MyNestedModel, typeof(this));
    }

    static struct MyResource
    {
        MyNestedResource[] nested;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto a = [MyNestedModel("foo"), MyNestedModel("bar")];
    auto m = MyModel(a);
    auto r = MyResource.fromModel(m);
    auto expected = [MyNestedResource("foo"), MyNestedResource("bar")];
    assert(r.nested.equal(expected));
}

unittest
{
    import std.algorithm : equal;

    static struct MyNestedModel
    {
        string field;
    }

    static struct MyModel
    {
        MyNestedModel[] nested;
    }

    static struct MyNestedResource
    {
        string field;
        mixin GenerateFromModel!(MyNestedModel, typeof(this));
    }

    static struct MyResource
    {
        MyNestedResource[] nested;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto a = [MyNestedModel("foo"), MyNestedModel("bar")];
    auto m = MyModel(a);
    auto r = MyResource.fromModel(m);
    auto expected = [MyNestedResource("foo"), MyNestedResource("bar")];
    assert(r.nested.equal(expected));
}

unittest
{
    import std.algorithm : equal;

    static struct MyModel
    {
        int[int] fields;
    }

    static struct MyResource
    {
        int[int] fields;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    int[int] fields = [1: -1, 2: -2, 3: -3];
    auto m = MyModel(fields.dup);
    auto r = MyResource.fromModel(m);
    assert(r.fields[1] == -1);
    assert(r.fields[2] == -2);
    assert(r.fields[3] == -3);
    m.fields[4] = -4;
    assert(r.fields.keys.equal(fields.keys));
}

unittest
{
    static struct MyModel
    {
        Nullable!(int[int]) fields;
    }

    static struct MyResource
    {
        Nullable!(int[int]) fields;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    Nullable!(int[int]) fields = [1: -1, 2: -2, 3: -3];
    auto m = MyModel(fields);
    auto r = MyResource.fromModel(m);
    assert(r.fields.get[1] == -1);
    assert(r.fields.get[2] == -2);
    assert(r.fields.get[3] == -3);
}

unittest
{
    static struct MyNestedModel
    {
        string field;

        string toString() const
        {
            return field;
        }
    }

    static struct MyModel
    {
        MyNestedModel nested;
    }

    static struct MyResource
    {
        string nested;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto m = MyModel(MyNestedModel("foo"));
    auto r = MyResource.fromModel(m);
    assert(r.nested == "foo");
}
