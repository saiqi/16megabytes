module vulpes.xml;

import std.exception : enforce;
import std.traits : hasUDA, getUDAs, isArray;
import std.range;
import std.traits : isSomeChar, isArray;
import std.typecons : Nullable, Flag;
import dxml.parser : simpleXML, EntityRange, EntityType, isAttrRange;

struct XMLRoot
{
    string tagName;
}

struct XMLElement
{
    string tagName;
}

struct XMLElementList
{
    string tagName;
}

struct Attr
{
    string attrName;
}

enum Text;

enum Ignore;

alias IgnoreItems = Flag!"ignoreItems";

private template getRootName(T)
{
    static if(!isArray!T)
        enum getRootName = getUDAs!(T, XMLRoot)[0].tagName;
    else
        enum getRootName = getUDAs!(ElementType!T, XMLRoot)[0].tagName;
}

private template getElementName(alias v)
{
    static if(hasUDA!(v, XMLElement))
        enum getElementName = getUDAs!(v, XMLElement)[0].tagName;
    else static if(hasUDA!(v, XMLElementList))
        enum getElementName = getUDAs!(v, XMLElementList)[0].tagName;
}

private template shouldIgnore(alias v, IgnoreItems ignoreItems)
{
    static if(ignoreItems == IgnoreItems.no)
        enum shouldIgnore = false;
    else
    {
        static if(hasUDA!(v, Ignore))
            enum shouldIgnore = true;
        else
            enum shouldIgnore = false;
    }
}

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

private void setLeafValue(S, Entity, R)(ref S source, Entity entity, R text)
if(isForwardRangeOfChar!R)
{
    import std.algorithm : find;

    assert(entity.type == EntityType.elementStart);

    static foreach (m; __traits(allMembers, S))
    {
        static if (hasUDA!(__traits(getMember, S, m), Attr))
        {
            convertValue(__traits(getMember, source, m),
                entity
                    .attributes
                    .find!(a => a.name.cleanNs == getUDAs!(__traits(getMember, S, m), Attr)[0].attrName));
        }
        else static if (hasUDA!(__traits(getMember, S, m), Text))
        {
            if(text.length > 0)
                convertValue(__traits(getMember, source, m), text);
        }
    }
}

private void setValue(S, Entity, R, IgnoreItems ignoreItems)
(ref S source, R[] path, Entity entity, R text)
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
                setValue!(ET, Entity, R, ignoreItems)(item, path, entity, text);
                source ~= item;
            }
            else
            {
                auto next = path[1];
                static foreach (m; __traits(allMembers, ET))
                {
                    static if (
                        hasUDA!(__traits(getMember, ET, m), XMLElement)
                        || (hasUDA!(__traits(getMember, ET, m), XMLElementList)
                            && !shouldIgnore!(__traits(getMember, ET, m), ignoreItems)))
                    {
                        if (getElementName!(__traits(getMember, ET, m)) == next)
                            setValue!(typeof(__traits(getMember, source[$ - 1], m)), Entity, R, ignoreItems)
                                (__traits(getMember, source[$ - 1], m), path[1 .. $], entity, text);
                    }
                }
            }
        }
        else
        {
            if (path.length == 1)
            {
                setLeafValue(source, entity, text);
            }
            else
            {
                auto next = path[1];
                static foreach (m; __traits(allMembers, S))
                {
                    static if (
                        hasUDA!(__traits(getMember, S, m), XMLElement)
                        || (hasUDA!(__traits(getMember, S, m), XMLElementList)
                            && !shouldIgnore!(__traits(getMember, S, m), ignoreItems)))
                    {
                        if (getElementName!(__traits(getMember, S, m)) == next)
                            setValue!(typeof(__traits(getMember, source, m)), Entity, R, ignoreItems)
                                (__traits(getMember, source, m), path[1 .. $], entity, text);
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

struct DeserializationResult(R, T, IgnoreItems ignoreItems)
if (hasUDA!(T, XMLRoot) && isForwardRangeOfChar!R)
{
    private EntityRange!(simpleXML, R) _entityRange;
    private T _current;
    private bool _primed;

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
                setValue!(T, typeof(n), R, ignoreItems)(_current, path, n, _entityRange.getText());
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

    bool empty()
    {
        prime();
        return _entityRange.empty;
    }

    T front()
    {
        prime();
        assert(!empty);

        return _current;
    }

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

auto deserializeAsRangeOf(T, R, IgnoreItems ignoreItems)(R xmlStr)
if(isForwardRangeOfChar!R)
{
    import dxml.parser : parseXML;
    auto r = parseXML!(simpleXML, R)(xmlStr);
    return DeserializationResult!(R, T, ignoreItems)(r);
}

version (unittest)
{

    @XMLRoot("name")
    struct Name
    {
        @Attr("lang")
        Nullable!string lang;

        @Text
        Nullable!string label;
    }

    @XMLRoot("ref")
    struct Bar
    {
        @Attr("status")
        Nullable!string status;

        @Text
        Nullable!string value;
    }

    @XMLRoot("current")
    struct Current
    {
        @Attr("year")
        Nullable!uint year;
    }

    @XMLRoot("previous")
    struct Previous
    {
        @Attr("year")
        Nullable!uint year;
    }

    @XMLRoot("other")
    struct Other
    {
        @XMLElement("ref")
        Bar ref_;
    }

    @XMLRoot("description")
    struct Description
    {
        @Text
        Nullable!string content;

        @XMLElement("current")
        Current current;

        @XMLElement("previous")
        Previous previous;

        @XMLElement("other")
        Other other;
    }

    @XMLRoot("foo")
    struct Foo
    {
        @Attr("id")
        Nullable!uint id;

        @Attr("category")
        Nullable!string category;

        @XMLElement("description")
        Description desc;

        @XMLElement("ref")
        Bar ref_;

        @XMLElementList("name")
        Name[] names;

    }

    @XMLRoot("foos")
    struct Foos
    {
        @XMLElementList("foo")
        @Ignore
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

    auto results = deserializeAsRangeOf!(Foo, string, IgnoreItems.no)(xml);
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

    auto results = deserializeAsRangeOf!(Foos, string, IgnoreItems.no)(xml);
    assert(!results.empty);

    Foos fs = results.front;
    assert(fs.foos.length == 2);
    assert(fs.foos[0].id == 0);
    assert(fs.foos[0].desc.current.year == 2020);
    assert(fs.foos[0].desc.other.ref_.value == "XB12");

    auto ignored = deserializeAsRangeOf!(Foos, string, IgnoreItems.yes)(xml);
    assert(ignored.front.foos.length == 0);
}

unittest
{
    immutable xml = "<root/>";

    auto results = deserializeAsRangeOf!(Foo, string, IgnoreItems.no)(xml);
    assert(results.empty);
}

unittest
{
    immutable xml = "<root><node>text</node></root>";

    @XMLRoot("node")
    static struct Node
    {
        @Text
        Nullable!string value;
    }

    @XMLRoot("root")
    static struct Root
    {
        @XMLElement("node")
        Node node;
    }

    auto r = deserializeAsRangeOf!(Root, string, IgnoreItems.no)(xml);
    assert(!r.empty);
    assert(r.front.node.value.get == "text");
}