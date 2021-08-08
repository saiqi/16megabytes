module vulpes.resources;

import std.typecons : Nullable, tuple;
import std.range : ElementType, isInputRange;
import std.traits : isSomeString;

struct ProviderResource
{
    string id;
}

struct NameResource
{
    string shortName;
    Nullable!string longName;
}

enum isLabelizable(T) = isSomeString!(typeof(T.init.language))
    && isSomeString!(typeof(T.init.shortName));

auto toLabelAA(R)(in R range) pure @safe nothrow
if(isInputRange!R && isLabelizable!(ElementType!R))
{
    import std.array : assocArray;
    import std.algorithm : map;
    alias ET = ElementType!R;

    static if(__traits(hasMember, ET, "longName"))
    {
        return range
            .map!(e => tuple(e.language, NameResource(e.shortName, e.longName)))
            .assocArray;
    }
    else
    {
        return range
            .map!(e => tuple(e.language, NameResource(e.shortName, (Nullable!string).init)))
            .assocArray;
    }
}

unittest
{
    static struct Label
    {
        private:
        string language_;
        string shortName_;
        Nullable!string longName_;

        public:
        inout(string) language() @property inout pure nothrow @safe
        {
            return language_;
        }

        inout(string) shortName() @property inout pure nothrow @safe
        {
            return shortName_;
        }

        inout(Nullable!string) longName() @property inout pure nothrow @safe
        {
            return longName_;
        }
    }

    static struct Foo
    {
        private:
        string id_;
        Label[] labels_;

        public:
        this(this)
        {
            labels_ = labels_.dup;
        }

        inout(Label[]) labels() @property inout pure nothrow @safe
        {
            return labels_;
        }
    }

    auto f = Foo("foo", [Label("en", "Foo", (Nullable!string).init)]);
    auto labels = f.labels.toLabelAA;
    assert("en" in labels);
    assert(labels["en"].shortName == "Foo");
    assert(labels["en"].longName.isNull);
}

struct TagResource
{
    string id;
    NameResource[string] labels;
}

struct DescriptionResource
{
    string id;
    string providerId;
    NameResource[string] labels;
    string definitionId;
    string definitionProviderId;
    string[] tagIds;
}

struct CountResource
{
    size_t count;
}