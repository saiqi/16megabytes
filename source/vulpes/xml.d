module vulpes.xml;

import std.exception : enforce;
import std.traits : hasUDA, getUDAs, isArray;
import std.range;
import std.traits : isSomeChar, isArray;
import std.typecons : Nullable;
import dxml.parser : simpleXML, EntityRange, EntityType, isAttrRange;

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

private template getRootName(T)
{
    static if(!isArray!T)
        enum getRootName = getUDAs!(T, xmlRoot)[0].tagName;
    else
        enum getRootName = getUDAs!(ElementType!T, xmlRoot)[0].tagName;
}

private template getElementName(alias v)
{
    static if(hasUDA!(v, xmlElement))
        enum getElementName = getUDAs!(v, xmlElement)[0].tagName;
    else static if(hasUDA!(v, xmlElementList))
        enum getElementName = getUDAs!(v, xmlElementList)[0].tagName;
}

/// Check wether a range is a `ForwardRange` of characters
template isForwardRangeOfChar(R)
{
    enum isForwardRangeOfChar = isForwardRange!R && isSomeChar!(ElementType!R);
}

private auto cleanNs(R)(in R tagName) pure
if(isArray!R)
{
    import std.array : split;
    return tagName.split(":")[$ - 1];
}

private void convertValue(S, R)(ref S field, R value)
if(isAttrRange!R || isForwardRangeOfChar!R)
{
    import std.conv : to;

    static if (isForwardRangeOfChar!R)
    {
        // Check whether field is Nullable
        static if(__traits(hasMember, field, "get"))
            field = value.to!(typeof(field.get));
        else
            field = value.to!(typeof(field));
    }
    else
    {
        if(!value.empty)
            convertValue(field, value.front.value);
    }
}

private void setLeafValue(S, Entity, R)(ref S source, Entity entity, R text_)
if(isForwardRangeOfChar!R)
{
    import std.algorithm : find;

    assert(entity.type == EntityType.elementStart);

    static foreach (m; __traits(allMembers, S))
    {
        static if (hasUDA!(__traits(getMember, S, m), attr))
        {
            convertValue(__traits(getMember, source, m),
                entity
                    .attributes
                    .find!(a => a.name.cleanNs == getUDAs!(__traits(getMember, S, m), attr)[0].attrName));
        }
        else static if (hasUDA!(__traits(getMember, S, m), text))
        {
            if(text_.length > 0)
                convertValue(__traits(getMember, source, m), text_);
        }
    }
}

private void setValue(S, Entity, R)
(ref S source, R[] path, Entity entity, R text_)
if(isForwardRangeOfChar!R)
{
    assert(path.length > 0);

    if (getRootName!S == path[0])
    {
        static if(isArray!S)
        {
            alias ET = ElementType!S;

            if(path.length == 1)
            {
                auto item = ET();
                setValue!(ET, Entity, R)(item, path, entity, text_);
                source ~= item;
            }
            else
            {
                auto next = path[1];
                static foreach (m; __traits(allMembers, ET))
                {
                    static if (
                        hasUDA!(__traits(getMember, ET, m), xmlElement)
                        || hasUDA!(__traits(getMember, ET, m), xmlElementList))
                    {
                        if (getElementName!(__traits(getMember, ET, m)) == next)
                            setValue!(typeof(__traits(getMember, source[$ - 1], m)), Entity, R)
                                (__traits(getMember, source[$ - 1], m), path[1 .. $], entity, text_);
                    }
                }
            }
        }
        else
        {
            if (path.length == 1)
            {
                setLeafValue(source, entity, text_);
            }
            else
            {
                auto next = path[1];
                static foreach (m; __traits(allMembers, S))
                {
                    static if (
                        hasUDA!(__traits(getMember, S, m), xmlElement)
                        || hasUDA!(__traits(getMember, S, m), xmlElementList))
                    {
                        if (getElementName!(__traits(getMember, S, m)) == next)
                            setValue!(typeof(__traits(getMember, source, m)), Entity, R)
                                (__traits(getMember, source, m), path[1 .. $], entity, text_);
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

/// An `InputRange` of `T` resulting from the deserialization of a `ForwardRange` of `char`
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
        R[] path;

        while (!_entityRange.empty)
        {
            auto n = _entityRange.front;

            if (n.type == EntityType.elementStart)
            {
                path ~= n.name.cleanNs();
                setValue!(T, typeof(n), R)(_current, path, n, _entityRange.getText());
            }

            if (n.type == EntityType.elementEnd)
            {
                path = path[0 .. $ - 1];
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
    T front()
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
}

/**
Return a `DeserializationResult` of `T` resulting from the deserialization of a `ForwardRange` of `char`
Params:
    T           = the type of deserialized result
    R           = the type of input
    ignoreItems = should we ignore the @ignore fields
    xmlStr = the serialized input
*/
auto deserializeAsRangeOf(T, R)(R xmlStr)
if(isForwardRangeOfChar!R)
{
    import dxml.parser : parseXML;
    auto r = parseXML!(simpleXML, R)(xmlStr);
    return DeserializationResult!(R, T)(r);
}

version (unittest)
{

    @xmlRoot("name")
    struct Name
    {
        @attr("lang")
        Nullable!string lang;

        @text
        Nullable!string label;
    }

    @xmlRoot("ref")
    struct Bar
    {
        @attr("status")
        Nullable!string status;

        @text
        Nullable!string value;
    }

    @xmlRoot("current")
    struct Current
    {
        @attr("year")
        Nullable!uint year;
    }

    @xmlRoot("previous")
    struct Previous
    {
        @attr("year")
        Nullable!uint year;
    }

    @xmlRoot("other")
    struct Other
    {
        @xmlElement("ref")
        Bar ref_;
    }

    @xmlRoot("description")
    struct Description
    {
        @text
        Nullable!string content;

        @xmlElement("current")
        Current current;

        @xmlElement("previous")
        Previous previous;

        @xmlElement("other")
        Other other;
    }

    @xmlRoot("foo")
    struct Foo
    {
        @attr("id")
        Nullable!uint id;

        @attr("category")
        Nullable!string category;

        @xmlElement("description")
        Description desc;

        @xmlElement("ref")
        Bar ref_;

        @xmlElementList("name")
        Name[] names;

    }

    @xmlRoot("foos")
    struct Foos
    {
        @xmlElementList("foo")
        Foo[] foos;
    }
}

unittest
{
    immutable xml =
    "<root>\n"
    ~   "<level>\n"
    ~       "<foos>\n"
    ~           "<ns:foo id='0' category='a'>\n"
    ~               "<ref status='bar'>XB12</ref>\n"
    ~               "<description>\n"
    ~                   "<current year='2020'/>\n"
    ~               "</description>\n"
    ~               "<name xml:lang='fr'>Bare</name>\n"
    ~               "<name xml:lang='en'>Bar</name>\n"
    ~           "</ns:foo>\n"
    ~           "<ns:foo id='1' category='b'>\n"
    ~               "<ref status='baz'>HB15</ref>\n"
    ~               "<description>\n"
    ~                   "<previous year='2019'/>\n"
    ~               "</description>\n"
    ~               "<name xml:lang='fr'>Baze</name>\n"
    ~               "<name xml:lang='en'>Baz</name>\n"
    ~           "</ns:foo>\n"
    ~       "</foos>\n"
    ~   "</level>\n"
    ~ "</root>";

    auto results = deserializeAsRangeOf!(Foo, string)(xml);
    assert(!results.empty);

    results.popFront();

    assert(!results.empty);

    Foo foo = results.front;
    assert(foo.id.get == 1);
    assert(foo.ref_.status.get == "baz");
    assert(foo.ref_.value.get == "HB15");
    assert(foo.names.length == 2);
    assert(foo.names[0].lang.get == "fr");
    assert(foo.names[0].label.get == "Baze");
    assert(foo.names[1].lang.get == "en");
    assert(foo.names[1].label.get == "Baz");
    assert(foo.desc.content.isNull);
    assert(foo.desc.current.year.isNull);
    assert(foo.desc.previous.year == 2019);

    results.popFront();

    assert(results.empty);
}

unittest
{
    immutable xml =
    "<root>\n"
    ~   "<level>\n"
    ~       "<foos>\n"
    ~           "<ns:foo id='0' category='a'>\n"
    ~               "<ref status='bar'>XB12</ref>\n"
    ~               "<description>\n"
    ~                   "<current year='2020'/>\n"
    ~                   "<other>\n"
    ~                       "<ref status='bar'>XB12</ref>\n"
    ~                   "</other>\n"
    ~               "</description>\n"
    ~               "<name xml:lang='fr'>Bare</name>\n"
    ~               "<name xml:lang='en'>Bar</name>\n"
    ~           "</ns:foo>\n"
    ~           "<ns:foo id='1' category='b'>\n"
    ~               "<ref status='baz'>HB15</ref>\n"
    ~               "<description>\n"
    ~                   "<previous year='2019'/>\n"
    ~                   "<other>\n"
    ~                       "<ref status='baz'>HB15</ref>\n"
    ~                   "</other>\n"
    ~               "</description>\n"
    ~               "<name xml:lang='fr'>Baze</name>\n"
    ~               "<name xml:lang='en'>Baz</name>\n"
    ~           "</ns:foo>\n"
    ~       "</foos>\n"
    ~   "</level>\n"
    ~ "</root>";

    auto results = deserializeAsRangeOf!(Foos, string)(xml);
    assert(!results.empty);

    Foos fs = results.front;
    assert(fs.foos.length == 2);
    assert(fs.foos[0].id == 0);
    assert(fs.foos[0].desc.current.year == 2020);
    assert(fs.foos[0].desc.other.ref_.value == "XB12");
}

unittest
{
    immutable xml = "<root/>";

    auto results = deserializeAsRangeOf!(Foo, string)(xml);
    assert(results.empty);
}

unittest
{
    immutable xml = "<root><node>text</node></root>";

    @xmlRoot("node")
    static struct Node
    {
        @text
        Nullable!string value;
    }

    @xmlRoot("root")
    static struct Root
    {
        @xmlElement("node")
        Node node;
    }

    auto r = deserializeAsRangeOf!(Root, string)(xml);
    assert(!r.empty);
    assert(r.front.node.value.get == "text");
}