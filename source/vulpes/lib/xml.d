module vulpes.lib.xml;

import std.exception : enforce;
import std.traits : hasUDA, getUDAs, isArray;
import std.range;
import std.traits : isSomeChar, isSomeString, isArray, TemplateOf, TemplateArgsOf;
import std.typecons : Nullable, nullable;
import dxml.parser : simpleXML, EntityRange, EntityType, isAttrRange;

///Dedicated module `Exception`
class DeserializationException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Specify the root XML node to be deserialized
struct xmlRoot
{
    ///
    string tagName;
}

///
@safe nothrow unittest
{
    @xmlRoot("root")
    static struct Root {}
}

/// Specify the XML node of a nested struct to be deserialized
struct xmlElement
{
    ///
    string tagName;
}

///
@safe nothrow unittest
{
    @xmlRoot("bar")
    static struct Bar {}

    @xmlRoot("foo")
    static struct Foo
    {
        @xmlElement("bar")
        Bar bar;
    }
}

/// Specify the XML node of an array of nested structs to be deserialized
struct xmlElementList
{
    ///
    string tagName;
}

///
@safe nothrow unittest
{
    @xmlRoot("bar")
    static struct Bar {}

    @xmlRoot("foo")
    static struct Foo
    {
        @xmlElementList("bar")
        Bar[] bar;
    }
}


/// Control that value must be deserialized from an attribute
struct attr
{
    ///
    string attrName;
}

///
@safe nothrow unittest
{
    @xmlRoot("foo")
    static struct Foo
    {
        @attr("bar")
        Nullable!string bar;
    }
}

/// Control that value must be deserialized from text
enum text;

///
@safe nothrow unittest
{
    @xmlRoot("foo")
    static struct Foo
    {
        @text
        Nullable!string bar;
    }
}

/// Control that value all attributes must be deserialized as assoc array
enum allAttr;

///
@safe nothrow unittest
{
    @xmlRoot("Foo")
    static struct Foo
    {
        @allAttr
        string[string] attrs;
    }
}

///
@safe nothrow unittest
{
    @xmlRoot("bar")
    static struct Bar {}

    @xmlRoot("foo")
    static struct Foo
    {
        @xmlElementList("bar")
        Bar[] bar;
    }
}

private enum isNullable(T) = __traits(isSame, TemplateOf!T, Nullable);

private template handleNullable(T, alias pred, Args...)
{
    static if(!isNullable!T)
    {
        enum handleNullable = pred!(T, Args);
    }
    else
    {
        alias ST = TemplateArgsOf!T[0];
        enum handleNullable = pred!(ST, Args);
    }
}

private template getRootName(T)
{
    static if(!isArray!T)
        enum getRootName = getUDAs!(T, xmlRoot)[0].tagName;
    else
        enum getRootName = getUDAs!(ElementType!T, xmlRoot)[0].tagName;
}

private template getElementName(S, string name)
{
    alias member = __traits(getMember, S, name);
    static if(hasUDA!(member, xmlElement))
    {
        static assert(!isArray!(typeof(member)));
        enum getElementName = getUDAs!(member, xmlElement)[0].tagName;
    }
    else static if(hasUDA!(member, xmlElementList))
    {
        static assert(isArray!(typeof(member)));
        enum getElementName = getUDAs!(member, xmlElementList)[0].tagName;
    }
    else
        static assert(false);
}

/// Check wether a range is a `ForwardRange` of characters
enum isForwardRangeOfChar(R) = isForwardRange!R && isSomeChar!(ElementType!R);

private template allChildren(S)
{
    import std.meta : Filter;
    enum isChild(string name) = hasUDA!(__traits(getMember, S, name), xmlElement)
        || hasUDA!(__traits(getMember, S, name), xmlElementList);
    enum allChildren = Filter!(isChild, __traits(allMembers, S));
}


private auto cleanNs(R)(in R tagName) pure
if(isSomeString!R)
{
    import std.algorithm : splitter, fold;
    return tagName.splitter(":").fold!((a, b) => b);
}

private void convertValue(S, R)(ref S field, R value, string fieldName)
if(isAttrRange!R || isForwardRangeOfChar!R)
{
    import std.conv : to, ConvException;
    import std.format : format;

    auto errMsg() {
        return format!"Not nullable field %s cannot be null!"(fieldName);
    }

    static if (isForwardRangeOfChar!R)
    {
        static if(isNullable!S)
            field = value.to!(typeof(field.get)).nullable;
        else
        {
            enforce!DeserializationException(value !is null, errMsg);
            try
            {
                field = value.to!(typeof(field));
            }
            catch(ConvException)
            {
                enforce!DeserializationException(false,
                                                 format!"%s: %s cannot be converted into %s"(fieldName,
                                                                                             value,
                                                                                             typeof(field).stringof));
            }
        }
    }
    else
    {
        static if(isNullable!S)
        {
            if(!value.empty)
                convertValue(field, value.front.value, fieldName);
        }
        else
        {
            enforce!DeserializationException(!value.empty, errMsg);
            convertValue(field, value.front.value, fieldName);
        }
    }
}

private void setLeafValue(S, Entity, R)(ref S source, Entity entity, R text_)
if(isForwardRangeOfChar!R)
{
    import std.algorithm : find, map;
    import std.array : assocArray;
    import std.range : zip;
    import std.traits : isAssociativeArray;

    assert(entity.type == EntityType.elementStart);

    static foreach (m; __traits(allMembers, S))
    {
        static if (hasUDA!(__traits(getMember, S, m), attr))
        {
            convertValue(__traits(getMember, source, m),
                entity
                    .attributes
                    .find!(a => a.name.cleanNs == getUDAs!(__traits(getMember, S, m), attr)[0].attrName),
                m);
        }
        else static if (hasUDA!(__traits(getMember, S, m), text))
        {
            if(text_.length > 0)
                convertValue(__traits(getMember, source, m), text_, m);
        }
        else static if(hasUDA!(__traits(getMember, S, m), allAttr))
        {
            static assert(isAssociativeArray!(typeof(__traits(getMember, S, m))));
            __traits(getMember, source, m) = zip(entity.attributes.map!(a => a.name),
                                                entity.attributes.map!(a => a.value)).assocArray;
        }
    }
}

private void setValue(S, Entity, R)(ref S source, R[] path, Entity entity, R text_)
if(isForwardRangeOfChar!R)
{
    assert(path.length > 0);

    auto isLeaf = path.length == 1;

    if (handleNullable!(S, getRootName) == path[0])
    {
        static if(isArray!S)
        {
            static assert(!isNullable!S);

            alias ET = ElementType!S;

            if(isLeaf)
            {
                auto item = ET();
                setValue!(ET, Entity, R)(item, path, entity, text_);
                source ~= item;
            }
            else
            {
                path = path[1 .. $];

                static foreach (m; allChildren!ET)
                {
                    if (getElementName!(ET, m) == path[0])
                    {
                        alias CT = typeof(__traits(getMember, source[$ - 1], m));
                        static if(isNullable!CT)
                        {
                            if(__traits(getMember, source[$ - 1], m).isNull)
                                __traits(getMember, source[$ - 1], m) = (TemplateArgsOf!CT)[0]();
                        }
                        setValue!(CT, Entity, R)
                            (__traits(getMember, source[$ - 1], m), path, entity, text_);
                    }
                }
            }
        }
        else
        {
            if (isLeaf)
            {
                static if(isNullable!S)
                {
                    if(!source.isNull)
                        setLeafValue(source.get, entity, text_);
                }
                else
                    setLeafValue(source, entity, text_);
            }
            else
            {
                path = path[1 .. $];
                // iterate over struct member having either xmlElement or xmlElementList UDA
                static foreach (m; handleNullable!(S, allChildren))
                {
                    // if the attribute name of either xmlElement or xmlElementList equals to current path
                    // initialize the children
                    if (handleNullable!(S, getElementName, m) == path[0])
                    {
                        // workaround compiler warning on Nullable.get_ being deprecated
                        static if(isNullable!S)
                        {
                            assert(!source.isNull);
                            alias CT = typeof(__traits(getMember, source.get, m));
                        }
                        else
                            alias CT = typeof(__traits(getMember, source, m));

                        static if(isNullable!CT)
                        {
                            static if(isNullable!S)
                            {
                                if(__traits(getMember, source.get, m).isNull)
                                    __traits(getMember, source.get, m) = (TemplateArgsOf!CT)[0]();
                            }
                            else
                            {
                                if(__traits(getMember, source, m).isNull)
                                    __traits(getMember, source, m) = (TemplateArgsOf!CT)[0]();
                            }
                        }

                        // workaround compiler warning on Nullable.get_ being deprecated
                        static if(isNullable!S)
                            setValue!(CT, Entity, R)
                                (__traits(getMember, source.get, m), path, entity, text_);
                        else
                            setValue!(CT, Entity, R)
                                (__traits(getMember, source, m), path, entity, text_);
                    }
                }
            }
        }
    }
}

private auto getText(R)(EntityRange!(simpleXML, R) range)
if(isForwardRangeOfChar!R)
{
    assert(range.front.type == EntityType.elementStart);

    range.popFront();

    if(range.front.type == EntityType.text)
        return range.front.text;

    return null;
}

unittest
{
    immutable xml = "<a>foo</a>";
    import dxml.parser : parseXML;

    auto r = parseXML!simpleXML(xml);
    assert(r.getText == "foo");
    assert(r.front.type == EntityType.elementStart);
}

/// An `ForwardRange` of `T` resulting from the deserialization of a `ForwardRange` of `char`
struct DeserializationResult(R, T)
if (hasUDA!(T, xmlRoot) && isForwardRangeOfChar!R)
{
    private EntityRange!(simpleXML, R) _entityRange;
    private T _current;
    private bool _primed;

    ///ditto
    this(EntityRange!(simpleXML, R) entityRange)
    {
        _entityRange = entityRange;
    }

    private bool isNextNodeReached()
    {
        return _entityRange.empty || (_entityRange.front.type == EntityType.elementStart
                && _entityRange.front.name.cleanNs == getRootName!T);
    }

    private void prime()
    {
        if (_primed)
            return;

        while (!isNextNodeReached())
            _entityRange.popFront();

        _primed = true;

        buildCurrent();
    }

    private void buildCurrent()
    {

        assert(isNextNodeReached(), "Seek range to first node");

        _current = T();
        Appender!(R[]) path;
        path.reserve(42);

        while (!_entityRange.empty)
        {
            auto n = _entityRange.front;

            if (n.type == EntityType.elementStart)
            {
                path.put(n.name.cleanNs());
                setValue!(T, typeof(n), R)(_current, path.data, n, _entityRange.getText());
            }

            if (n.type == EntityType.elementEnd)
            {
                path.shrinkTo(path.data.length - 1u);
                if (n.name.cleanNs() == getRootName!T)
                {
                    break;
                }
            }

            _entityRange.popFront();
        }
    }

    ///ditto
    bool empty()
    {
        prime();
        return _entityRange.empty;
    }

    ///ditto
    ref T front()
    {
        prime();
        assert(!empty);

        return _current;
    }

    ///ditto
    void popFront()
    {
        prime();
        assert(!empty);

        do
        {
            _entityRange.popFront();
        }
        while (!isNextNodeReached());

        buildCurrent();
    }

    auto save()
    {
        auto retval = this;
        retval._entityRange = _entityRange.save;
        return retval;
    }
}

/**
Return a `DeserializationResult` of `T` resulting from the deserialization of a `ForwardRange` of `char`
Params:
    T           = the type of deserialized result
    R           = the type of input
    xmlStr = the serialized input
*/
auto deserializeAsRangeOf(T, R)(R xmlStr)
if(isForwardRangeOfChar!R)
{
    import dxml.parser : parseXML;
    auto r = parseXML!(simpleXML, R)(xmlStr);
    return DeserializationResult!(R, T)(r);
}

// Should deserialize an attribute
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint aa;
    }

    immutable xml = "<a aa='1'></a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.aa == 1u);
}

// Should ingore namespace
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint aa;
    }

    immutable xml = "<ns:a aa='1'></ns:a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.aa == 1u);
}

// Should deserialize multiple occurrences
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint aa;
    }

    immutable xml = "<root><ns:a aa='1'/><ns:a aa='2'/></root>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.aa == 1u);
    r.popFront();
    assert(r.front.aa == 2u);
    r.popFront();
    assert(r.empty);
}

// Should deserialize a text node
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @text
        uint aa;
    }

    immutable xml = "<a>1</a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.aa == 1u);
}

// Should ignore missing value
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @attr("b")
        Nullable!uint b;
    }

    immutable xml = "<a aa='1'>1</a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.b.isNull);
}

// Should deserialize nullable fields
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @attr("b")
        Nullable!uint b;
    }

    immutable xml = "<a b='1'>1</a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.b.get == 1u);
}

// Should deserialize nested structures
unittest
{
    @xmlRoot("c")
    static struct C
    {
        @attr("cc")
        uint cc;
    }

    @xmlRoot("b")
    static struct B
    {
        @attr("bb")
        uint bb;

        @xmlElement("c")
        C c;
    }

    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint aa;

        @xmlElement("b")
        B b;
    }

    immutable xml = "<a aa='1'><b bb='2'><c cc='3'></c></b></a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.b.bb == 2u);
    assert(r.front.b.c.cc == 3u);
}

// Should deserialize nested structures having a one-to-many relationship
unittest
{
    @xmlRoot("c")
    static struct C
    {
        @attr("cc")
        uint cc;
    }

    @xmlRoot("b")
    static struct B
    {
        @attr("bb")
        uint bb;

        @xmlElement("c")
        C c;
    }

    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint aa;

        @xmlElementList("b")
        B[] b;
    }

    immutable xml = "<a aa='1'><b bb='2'><c cc='3'></c></b><b bb='22'><c cc='33'></c></b></a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    assert(!r.empty);
    assert(r.front.b[0].bb == 2u);
    assert(r.front.b[0].c.cc == 3u);
    assert(r.front.b[1].bb == 22u);
    assert(r.front.b[1].c.cc == 33u);
}

// Should raise when a value cannot be converted
unittest
{
    import std.exception : assertThrown;
    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint b;
    }

    immutable xml = "<a aa='A'></a>";
    assertThrown!DeserializationException(deserializeAsRangeOf!(A, string)(xml).front);
}

// Should raise when a mandatory value is missing
unittest
{
    import std.exception : assertThrown;
    @xmlRoot("a")
    static struct A
    {
        @attr("aa")
        uint b;
    }

    immutable xml = "<a b='A'></a>";
    assertThrown!DeserializationException(deserializeAsRangeOf!(A, string)(xml).front);
}

// Should be a ForwardRange
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @text
        uint aa;
    }

    immutable xml = "<a>1</a>";
    auto r = deserializeAsRangeOf!(A, string)(xml);
    auto c = r.save;
    r.popFront();
    assert(r.empty);
    assert(!c.empty);
}

// Should handle nested nullable
unittest
{
    @xmlRoot("b")
    static struct B
    {
        @text
        Nullable!uint value;
    }

    @xmlRoot("a")
    static struct A
    {
        @xmlElement("b")
        Nullable!B b;
    }

    @xmlRoot("root")
    static struct Root
    {
        @xmlElement("a")
        Nullable!A a;
    }

    immutable xml = "<root><a><b>5</b></a></root>";
    auto r = deserializeAsRangeOf!(Root, string)(xml);
    assert(r.front.a.get.b.get.value.get == 5);
}

// Should handle null nullable
unittest
{
    @xmlRoot("b")
    static struct B
    {
        @text
        Nullable!uint value;
    }

    @xmlRoot("a")
    static struct A
    {
        @xmlElement("b")
        Nullable!B b;
    }

    @xmlRoot("root")
    static struct Root
    {
        @xmlElement("a")
        Nullable!A a;
    }

    immutable xml = "<root><a></a></root>";
    auto r = deserializeAsRangeOf!(Root, string)(xml);
    assert(r.front.a.get.b.isNull);
}

auto deserializeAs(T, R)(R xmlStr)
if(isForwardRangeOfChar!R)
{
    import std.format : format;
    auto range = deserializeAsRangeOf!(T, R)(xmlStr);
    enforce!DeserializationException(
        !range.empty, format!"Cannot deserialize content as %s"(T.stringof));
    return range.front;
}

// Should deserialize a struct
unittest
{
    @xmlRoot("a")
    static struct A
    {
        @text
        uint aa;
    }

    immutable xml = "<a>1</a>";
    auto r = deserializeAs!(A, string)(xml);
    assert(r.aa == 1u);
}

// Should raise when nothing can be deserializabled
unittest
{
    import std.exception : assertThrown;
    @xmlRoot("a")
    static struct A
    {
        @text
        uint aa;
    }

    immutable xml = "<b>1</b>";
    assertThrown!DeserializationException(deserializeAs!(A, string)(xml));
}
