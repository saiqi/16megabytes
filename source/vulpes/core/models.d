module vulpes.core.models;
import std.typecons : Nullable;

enum Language: string
{
    fr = "fr",
    en = "en",
    de = "de",
    es = "es"
}

struct Label
{
    Language language;
    string shortName;
    Nullable!string longName;
}

struct Provider
{
    string id;
    Label[] labels;
}

struct CubeDescription
{
    string providerId;
    string id;
    Label[] labels;
    string definitionId;
    string[] tags;
}

struct CubeDefinition
{
    string providerId;
    string id;
    Dimension[] dimensions;
    Attribute[] attributes;
    Measure[] measures;
}

struct Dimension
{
    Nullable!string id;
    Label[] labels;
    bool isTimeDimension;
    Code[] codes;
    Nullable!Concept concept;
}

struct Attribute
{
    Nullable!string id;
    Label[] labels;
    Code[] codes;
    Nullable!Concept concept;
}

struct Code
{
    string id;
    Label[] labels;
}

struct Concept
{
    string id;
    Label[] labels;
}

struct Measure
{
    Nullable!string id;
    Label[] labels;
    Nullable!Concept concept;
}