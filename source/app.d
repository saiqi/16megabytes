module app;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;

private auto getProviderOr404(in string providerId)
{
    import vulpes.datasources.providers : getProvider;
    import std.format : format;
    auto provider = getProvider(providerId);

    enforceHTTP(!provider.isNull,
                HTTPStatus.notFound,
                format!"Provider %s not found"(providerId));
    return provider.get;
}

void handleProviders(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import vulpes.datasources.providers : getProviders;
    import vulpes.resources : ProviderResource;
    logDebug("Fetching providers");
    auto providers = getProviders()
        .map!(p => ProviderResource(p.id))
        .array;
    logDebug("Providers list fetched");
    res.writeJsonBody(providers);
}

void handleTags(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import std.format : format;
    import vulpes.datasources.sdmxml21 : getTags;
    import vulpes.resources : TagResource, toLabelAA;
    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetching tags for provider %s", provider.id);
    auto tags = getTags(provider)
        .map!(t => TagResource(t.id, t.labels.toLabelAA)).array;
    logDebug("Tags list fetched");
    res.writeJsonBody(tags);

}

void handleDescriptions(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map, filter;
    import std.array : array, split;
    import std.format : format;
    import std.conv : to;
    import std.range : take, drop;
    import vulpes.datasources.sdmxml21 : getDescriptions;
    import vulpes.resources : DescriptionResource, toLabelAA;
    import vulpes.core.cube : search, containsTags;

    enforceHTTP(req.query.get("s") is null || req.query.get("tags") is null,
                HTTPStatus.badRequest,
                "s and tags parameters are mutually exclusive");

    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetchings descriptions list for provider %s", provider.id);
    auto descs = getDescriptions(provider);

    alias toResource = t => DescriptionResource(t.id,
                                                t.providerId,
                                                t.labels.toLabelAA,
                                                t.definitionId,
                                                t.definitionProviderId,
                                                t.tagIds);

    if(req.query.get("s") is null && req.query.get("tags") is null)
    {
        auto result = descs.map!toResource.array;
        logDebug("Descriptions list fetched");
        res.writeJsonBody(result);
    }
    else if(req.query.get("s") !is null)
    {
        auto result = search(descs, req.query["s"]).map!toResource.array;
        logDebug("Search result fetched");
        res.writeJsonBody(result);
    }
    else
    {
        auto tagIds = req.query.get("tags").split(",");
        auto result = descs
            .filter!(d => d.containsTags(tagIds))
            .map!toResource
            .array;
        logDebug("Descriptions filtered by tags fetched");
        res.writeJsonBody(result);
    }
}

void handleDescriptionsCount(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.range : walkLength;
    import vulpes.resources : CountResource;
    import vulpes.datasources.sdmxml21 : getDescriptions;
    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetchings descriptions list for provider %s", provider.id);
    auto count = getDescriptions(provider).walkLength;
    logDebug("Count done");
    res.writeJsonBody(CountResource(count));
}

void main()
{
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);
    setLogLevel(LogLevel.debug_);
    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    settings.errorPageHandler = (HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) @safe {
        if(error.exception) res.writeJsonBody(["message": error.exception.msg]);
        else res.writeJsonBody(["message": error.message]);
    };

    auto router = new URLRouter;
    router.get("/providers", &handleProviders)
        .get("/providers/:providerId/tags", &handleTags)
        .get("/providers/:providerId/cube-descriptions", &handleDescriptions)
        .get("/providers/:providerId/cube-descriptions/count", &handleDescriptionsCount);

    auto l = listenHTTP(settings, router);
    scope(exit) l.stopListening();
    runApplication();
}