module app;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;

private auto getProviderOr404(in string providerId)
{
    import vulpes.core.providers : getProvider;
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
    import vulpes.core.providers : getProviders;
    import vulpes.resources : providerToResource;
    logDebug("Fetching providers");
    auto providers = getProviders()
        .map!providerToResource
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
    import vulpes.resources : tagToResource;
    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetching tags for provider %s", provider.id);
    auto tags = getTags(provider)
        .map!tagToResource.array;
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
    import vulpes.resources : descriptionToResource;
    import vulpes.core.cube : search, containsTags;

    enforceHTTP(req.query.get("s") is null || req.query.get("tags") is null,
                HTTPStatus.badRequest,
                "s and tags parameters are mutually exclusive");

    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetchings descriptions list for provider %s", provider.id);
    auto descs = getDescriptions(provider);

    if(req.query.get("s") is null && req.query.get("tags") is null)
    {
        auto result = descs.map!descriptionToResource.array;
        logDebug("Descriptions list fetched");
        res.writeJsonBody(result);
    }
    else if(req.query.get("s") !is null)
    {
        auto result = search(descs, req.query["s"]).map!descriptionToResource.array;
        logDebug("Search result fetched");
        res.writeJsonBody(result);
    }
    else
    {
        auto tagIds = req.query.get("tags").split(",");
        auto result = descs
            .filter!(d => d.containsTags(tagIds))
            .map!descriptionToResource
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

void handleDefinition(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.format : format;
    import vulpes.datasources.sdmxml21 : getDefinition;
    import vulpes.resources : definitionToResource;
    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"];
    logDebug("Fetching definition %s", cubeId);
    auto def = getDefinition(provider, cubeId);

    enforceHTTP(!def.isNull,
                HTTPStatus.notFound,
                format!"definition %s not found for provider %s"(cubeId, provider.id));

    res.writeJsonBody(definitionToResource(def.get));

}

void handleDimensionCodes(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import vulpes.datasources.sdmxml21 : getDimensionCodes;
    import vulpes.resources : codeToResource;
    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"]; auto resourceId = req.params["dimensionId"];

    logDebug("Fetching codes of dimension %s of cube %s for provider %s", resourceId, cubeId, provider.id);

    auto codes = getDimensionCodes(provider, cubeId, resourceId)
        .map!codeToResource
        .array;

    res.writeJsonBody(codes);
}

void handleAttributeCodes(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import vulpes.datasources.sdmxml21 : getAttributeCodes;
    import vulpes.resources : codeToResource;
    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"]; auto resourceId = req.params["attributeId"];

    logDebug("Fetching codes of attribute %s of cube %s for provider %s", resourceId, cubeId, provider.id);

    auto codes = getAttributeCodes(provider, cubeId, resourceId)
        .map!codeToResource
        .array;

    res.writeJsonBody(codes);
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
        .get("/providers/:providerId/cubes", &handleDescriptions)
        .get("/providers/:providerId/cubes/count", &handleDescriptionsCount)
        .get("/providers/:providerId/cubes/:cubeId/definition", &handleDefinition)
        .get("/providers/:providerId/cubes/:cubeId/dimensions/:dimensionId/codes", &handleDimensionCodes)
        .get("/providers/:providerId/cubes/:cubeId/attributes/:attributeId/codes", &handleAttributeCodes);

    auto l = listenHTTP(settings, router);
    scope(exit) l.stopListening();
    runApplication();
}