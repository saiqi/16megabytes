module source.vulpes.api.resources;

import std.typecons : Nullable;
import vulpes.core.model;

mixin template GenerateFromModel(Model, Resource)
{
    import std.traits : FieldNameTuple, hasMember, Unqual, isArray, isAssociativeArray, isSomeString,
        OriginalType, KeyType, ValueType;
    import std.range : ElementType, zip;
    import std.array : array, assocArray;
    import std.conv : to;
    import std.algorithm : map;
    import vulpes.lib.monadish : isNullable, NullableOf, fallbackMap;

    static Resource fromModel(in ref Model m)
    {
        Resource r;

        static foreach(member; FieldNameTuple!Resource)
        {{
            alias ResourceFieldT = typeof(__traits(getMember, Resource, member));
            enum currentMember = Resource.stringof ~ "." ~ member;

            static assert(hasMember!(Model, member),
                          currentMember ~ " not found in " ~ Model.stringof);

            alias ModelFieldT = typeof(__traits(getMember, Model, member));
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
                            ModelFieldST model = cast(ModelFieldST) __traits(getMember, m, member).get;
                            value = ResourceFieldST.fromModel(model);
                        }
                        else static if(isAssociativeArray!ResourceFieldST)
                        {
                            static assert(isAssociativeArray!ModelFieldST,
                                currentMember ~ " is an associative array, corresponding model field is not");

                            alias KeyT = KeyType!(typeof(__traits(getMember, r, member).get));
                            alias ValueT = ValueType!(typeof(__traits(getMember, r, member).get));
                            value = zip(__traits(getMember, m, member).get.keys.map!(a => a.to!KeyT),
                                        __traits(getMember, m, member).get.values.map!(a => a.to!ValueT)
                                        ).assocArray;
                        }
                        else
                        {
                            static if(is(ModelFieldST == struct))
                            {
                                value = __traits(getMember, m, member).get.toString();
                            }
                            else
                            {
                                value = __traits(getMember, m, member).get;
                            }
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
                alias ModelFieldST = ElementType!ModelFieldT;
                static if(is(ResourceFieldST == struct))
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member)
                        .fallbackMap!(a => ResourceFieldST.fromModel(a))
                        .array;
                }
                else
                {
                    static if(is(ModelFieldST == struct))
                    {
                        __traits(getMember, r, member) = __traits(getMember, m, member)
                            .fallbackMap!(a => a.toString())
                            .array;
                    }
                    else
                    {
                        __traits(getMember, r, member) = __traits(getMember, m, member).dup;
                    }
                }
            }
            else static if(isAssociativeArray!ResourceFieldT)
            {
                static assert(isAssociativeArray!ModelFieldT,
                             currentMember ~ " is an associative array, the corresponding model field is not");
                alias KeyT = KeyType!(typeof(__traits(getMember, r, member)));
                alias ValueT = ValueType!(typeof(__traits(getMember, r, member)));
                __traits(getMember, r, member) = zip(__traits(getMember, m, member).keys.map!(a => a.to!KeyT),
                                                    __traits(getMember, m, member).values.map!(a => a.to!ValueT)
                                                    ).assocArray;
            }
            else
            {
                static if(is(ModelFieldT == struct))
                {
                    static if(isNullable!ModelFieldT)
                    {
                        static assert(isNullable!ResourceFieldT,
                                     currentMember ~ " must be Nullable");

                        alias ResourceFieldST = NullableOf!ResourceFieldT;
                        if(__traits(getMember, m, member).isNull)
                        {
                            __traits(getMember, r, member) = (Nullable!ResourceFieldST).init;
                        }
                        else
                        {
                            Nullable!ResourceFieldST value;
                            static assert(isSomeString!ResourceFieldST, currentMember ~ " must be a string");
                            value = __traits(getMember, m, member).toString();
                            __traits(getMember, r, member) = value;
                        }
                    }
                    else
                    {
                        __traits(getMember, r, member) = __traits(getMember, m, member).toString();
                    }
                }
                else static if(is(ModelFieldT == enum))
                {
                    __traits(getMember, r, member) = __traits(getMember, m, member).to!(OriginalType!ModelFieldT);
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

unittest
{
    static enum MyModelType : string
    {
        foo = "foo"
    }

    static struct MyModel
    {
        MyModelType type;
    }

    static struct MyResource
    {
        string type;
        mixin GenerateFromModel!(MyModel, typeof(this));
    }

    auto m = MyModel(MyModelType.foo);
    auto r = MyResource.fromModel(m);
    assert(r.type == "foo");
}

struct SenderResponse
{
    string id;

    mixin GenerateFromModel!(Sender, typeof(this));
}

struct ReceiverResponse
{
    string id;

    mixin GenerateFromModel!(Receiver, typeof(this));
}

struct LinkResponse
{
    Nullable!string href;
    string rel;
    Nullable!string hreflang;
    Nullable!string urn;
    Nullable!string type;

    mixin GenerateFromModel!(Link, typeof(this));
}

struct MetaResponse
{
    string schema;
    string id;
    bool test;
    string prepared;
    string[] contentLanguages;
    SenderResponse sender;
    ReceiverResponse[] receivers;
    LinkResponse[] links;

    mixin GenerateFromModel!(Meta, typeof(this));
}

struct EmptyResponse
{
    mixin GenerateFromModel!(Empty, typeof(this));
}

struct AttributeRelationshipResponse
{
    string[] dimensions;
    Nullable!string group;
    Nullable!EmptyResponse observation;
    Nullable!EmptyResponse dataflow;

    mixin GenerateFromModel!(AttributeRelationship, typeof(this));
}

struct EnumerationResponse
{
    string enumeration;

    mixin GenerateFromModel!(Enumeration, typeof(this));
}

struct FormatResponse
{
    Nullable!uint maxLength;
    Nullable!uint minLength;
    string dataType;

    mixin GenerateFromModel!(Format, typeof(this));
}

struct LocalRepresentationResponse
{
    Nullable!EnumerationResponse enumeration;
    Nullable!FormatResponse format;

    mixin GenerateFromModel!(LocalRepresentation, typeof(this));
}

struct AttributeResponse
{
    string id;
    Nullable!string usage;
    Nullable!AttributeRelationshipResponse attributeRelationship;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentationResponse localRepresentation;

    mixin GenerateFromModel!(Attribute, typeof(this));
}

struct AttributeListResponse
{
    string id;
    AttributeResponse[] attributes;

    mixin GenerateFromModel!(AttributeList, typeof(this));
}

struct DimensionResponse
{
    string id;
    uint position;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentationResponse localRepresentation;

    mixin GenerateFromModel!(Dimension, typeof(this));
}

struct TimeDimensionResponse
{
    string id;
    uint position;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentationResponse localRepresentation;

    mixin GenerateFromModel!(TimeDimension, typeof(this));
}

struct DimensionListResponse
{
    string id;
    DimensionResponse[] dimensions;
    TimeDimensionResponse timeDimension;

    mixin GenerateFromModel!(DimensionList, typeof(this));
}

struct GroupResponse
{
    string id;
    string[] groupDimensions;

    mixin GenerateFromModel!(Group, typeof(this));
}

struct MeasureResponse
{
    string id;
    Nullable!string conceptIdentity;
    string[] conceptRoles;
    Nullable!LocalRepresentationResponse localRepresentation;
    Nullable!string usage;

    mixin GenerateFromModel!(Measure, typeof(this));
}

struct MeasureListResponse
{
    string id;
    MeasureResponse[] measures;

    mixin GenerateFromModel!(MeasureList, typeof(this));
}

struct DataStructureComponentsResponse
{
    Nullable!AttributeListResponse attributeList;
    DimensionListResponse dimensionList;
    GroupResponse[] groups;
    Nullable!MeasureListResponse measureList;

    mixin GenerateFromModel!(DataStructureComponents, typeof(this));
}

struct DataStructureResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    DataStructureComponentsResponse dataStructureComponents;

    mixin GenerateFromModel!(DataStructure, typeof(this));
}

struct CategoryResponse
{
    string id;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    CategoryResponse[] categories;

    mixin GenerateFromModel!(Category, typeof(this));
}

struct CategorySchemeResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    bool isPartial;
    CategoryResponse[] categories;

    mixin GenerateFromModel!(CategoryScheme, typeof(this));
}

struct ConceptResponse
{
    string id;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;

    mixin GenerateFromModel!(Concept, typeof(this));
}

struct ConceptSchemeResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    bool isPartial;
    ConceptResponse[] concepts;

    mixin GenerateFromModel!(ConceptScheme, typeof(this));
}

struct CodeResponse
{
    string id;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;

    mixin GenerateFromModel!(Code, typeof(this));
}

struct CodelistResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    bool isPartial;
    CodeResponse[] codes;

    mixin GenerateFromModel!(Codelist, typeof(this));
}

struct DataflowResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    string structure;

    mixin GenerateFromModel!(Dataflow, typeof(this));
}

struct CategorisationResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    string source;
    string target;

    mixin GenerateFromModel!(Categorisation, typeof(this));
}

struct ConstraintAttachmentResponse
{
    string[] dataflows;

    mixin GenerateFromModel!(ConstraintAttachment, typeof(this));
}

struct KeyValueResponse
{
    string id;
    string[] values;

    mixin GenerateFromModel!(KeyValue, typeof(this));
}

struct CubeRegionResponse
{
    Nullable!bool include;
    KeyValueResponse[] keyValues;

    mixin GenerateFromModel!(CubeRegion, typeof(this));
}

struct DataConstraintResponse
{
    string id;
    string version_;
    string agencyId;
    bool isExternalReference;
    bool isFinal;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    Nullable!string role;
    Nullable!ConstraintAttachmentResponse constraintAttachment;
    CubeRegionResponse[] cubeRegions;

    mixin GenerateFromModel!(DataConstraint, typeof(this));
}

struct StructureComponentValueResponse
{
    string id;
    string name;
    Nullable!(string[string]) names;

    mixin GenerateFromModel!(StructureComponentValue, typeof(this));
}

struct StructureComponentResponse
{
    string id;
    string name;
    Nullable!(string[string]) names;
    Nullable!string description;
    Nullable!(string[string]) descriptions;
    Nullable!uint keyPosition;
    string[] roles;
    Nullable!bool isMandatory;
    Nullable!AttributeRelationshipResponse relationship;
    Nullable!FormatResponse format;
    Nullable!string default_;
    StructureComponentValueResponse[] values;

    mixin GenerateFromModel!(StructureComponent, typeof(this));
}

struct StructureResponse
{
    int[] dataSets;
    StructureComponentResponse[] dimensions;
    StructureComponentResponse[] measures;
    StructureComponentResponse[] attributes;

    mixin GenerateFromModel!(Structure, typeof(this));
}

struct DataResponse
{
    DataStructureResponse[] dataStructures;
    CategorySchemeResponse[] categorySchemes;
    ConceptSchemeResponse[] conceptSchemes;
    CodelistResponse[] codelists;
    DataflowResponse[] dataflows;
    CategorisationResponse[] categorisations;
    DataConstraintResponse[] contentConstraints;

    mixin GenerateFromModel!(Data, typeof(this));
}

struct ErrorResponse
{
    uint code;
    string title;
    string[string] titles;
    Nullable!string detail;
    Nullable!(string[string]) details;

    mixin GenerateFromModel!(Error_, typeof(this));
}

struct MessageResponse
{
    MetaResponse meta;
    Nullable!DataResponse data;
    ErrorResponse[] errors;

    mixin GenerateFromModel!(Message, typeof(this));
}
