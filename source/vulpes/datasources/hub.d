module vulpes.datasources.hub;

import vulpes.core.providers : Provider;
import vulpes.core.cube : CubeResourceType;

auto getTags(alias fetch, alias project)(in Provider provider)
{
    import std.array : array;
    import std.algorithm : map;
    import vulpes.core.providers : Format;

    with(Format) final switch(provider.format)
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : fetchTags, buildTags;

        return fetchTags!fetch(provider)
            .buildTags
            .map!project
            .array;
    }
}

unittest
{
    import std.algorithm : canFind;
    import vibe.core.concurrency : async;
    import vibe.core.file : readFileUTF8;
    import vulpes.core.providers : getProvider;

    auto fetcher(string u, string[string] h, string[string] q)
    {
        return async({
            if(u.canFind("/categorisation/"))
                return readFileUTF8("fixtures/sdmx/structure_category_categorisation.xml");
            return readFileUTF8("fixtures/sdmx/structure_category.xml");
        });
    }

    auto p = getProvider("FR1").get;

    alias projector = d => d.id;

    assert(getTags!(fetcher, projector)(p).canFind("CLASSEMENT_DATAFLOWS.ECO"));
}

auto getDescriptions(alias fetch, alias project)(in Provider provider, in string s, in string[] tagIds)
{
    import std.array : array;
    import std.algorithm : filter, map;
    import vulpes.core.providers : Format;
    import vulpes.core.cube : search, containsTags;

    with(Format) final switch(provider.format)
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : fetchDescriptions, buildDescriptions;

        alias filterTags = d => tagIds.length == 0 || containsTags(d, tagIds);

        if(s !is null)
        {
            return fetchDescriptions!fetch(provider)
                .buildDescriptions
                .search(s)
                .filter!filterTags
                .map!project
                .array;
        }

        return fetchDescriptions!fetch(provider)
            .buildDescriptions
            .filter!filterTags
            .map!project
            .array;
    }
}

unittest
{
    import std.algorithm : canFind;
    import vibe.core.concurrency : async;
    import vibe.core.file : readFileUTF8;
    import vulpes.core.providers : getProvider;

    auto fetcher(string u, string[string] h, string[string] q)
    {
        return async({
            if(u.canFind("/dataflow/"))
                return readFileUTF8("fixtures/sdmx/structure_dataflow_categorisation.xml");
            return readFileUTF8("fixtures/sdmx/structure_category.xml");
        });
    }

    auto p = getProvider("FR1").get;

    alias projector = d => d.id;

    assert(getDescriptions!(fetcher, projector)(p, null, [])[0] == "BALANCE-PAIEMENTS");
    assert(getDescriptions!(fetcher, projector)(p, "paiement", []).length);
    assert(getDescriptions!(fetcher, projector)(p, null, ["CLASSEMENT_DATAFLOWS.COMMERCE_EXT"]).length);
    assert(getDescriptions!(fetcher, projector)(p, "paiement", ["CLASSEMENT_DATAFLOWS.COMMERCE_EXT"]).length);
    assert(!getDescriptions!(fetcher, projector)(p, null, ["UNKNOWN"]).length);
    assert(!getDescriptions!(fetcher, projector)(p, "paiement", ["UNKNOWN"]).length);
}

auto getDefinition(alias fetch, alias project)(in Provider provider, in string id)
{
    import vulpes.core.providers : Format;
    import std.typecons : apply;

    with(Format) final switch(provider.format)
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : fetchDefinition, buildDefinition;

        return fetchDefinition!fetch(provider, id)
            .buildDefinition
            .apply!project;
    }
}

unittest
{
    import vibe.core.concurrency : async;
    import vibe.core.file : readFileUTF8;
    import vulpes.core.providers : getProvider;

    auto fetcher(string u, string[string] h, string[string] q)
    {
        return async({
            return readFileUTF8("fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml");
        });
    }

    auto p = getProvider("FR1").get;

    alias projector = d => d.id;

    auto def = getDefinition!(fetcher, projector)(p, "01R");
    assert(!def.isNull);
    assert(def.get == "ECOFIN_DSD");
}

auto getCodes(alias fetch, alias project, CubeResourceType type)(in Provider provider, in string cubeId, in string resourceId)
{
    import vulpes.core.providers : Format;
    import std.array : array;
    import std.algorithm : map;

    with(Format) final switch(provider.format)
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : fetchCodes, buildCodes;

        return fetchCodes!(fetch, type)(provider, cubeId, resourceId)
            .buildCodes
            .map!project
            .array;
    }
}

unittest
{
    import vibe.core.concurrency : async;
    import vibe.core.file : readFileUTF8;
    import vulpes.core.providers : getProvider;

    auto fetcher(string u, string[string] h, string[string] q)
    {
        return async({
            return readFileUTF8("fixtures/sdmx/structure_dsd_dataflow_constraint_codelist_conceptscheme.xml");
        });
    }

    auto p = getProvider("FR1").get;

    alias projector = d => d.id;

    assert(getCodes!(fetcher, projector, CubeResourceType.dimension)(p, "01R", "REF_AREA").length);
}