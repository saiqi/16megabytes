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
    import vulpes.datasources : getTags;
    import vulpes.resources : tagToResource;
    import vulpes.lib.requests : doAsyncRequest;
    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetching tags for provider %s", provider.id);
    auto tags = getTags!(doAsyncRequest, tagToResource)(provider);
    logDebug("Tags list fetched");
    res.writeJsonBody(tags);

}

void handleDescriptions(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.array : split;
    import std.format : format;
    import vulpes.datasources : getDescriptions;
    import vulpes.resources : descriptionToResource;
    import vulpes.lib.requests : doAsyncRequest;

    auto provider = getProviderOr404(req.params["providerId"]);

    logDebug("Fetchings descriptions list for provider %s", provider.id);
    auto s = req.query.get("s");
    auto tagIds = ("tags" in req.query)
        ? req.query["tags"].split(",")
        : [];

    auto descs = getDescriptions!(doAsyncRequest, descriptionToResource)(provider, s, tagIds);
    res.writeJsonBody(descs);
}

void handleDefinition(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.format : format;
    import vulpes.datasources : getDefinition;
    import vulpes.resources : definitionToResource;
    import vulpes.lib.requests : doAsyncRequest;
    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"];
    logDebug("Fetching definition %s", cubeId);
    auto def = getDefinition!(doAsyncRequest, definitionToResource)(provider, cubeId);

    enforceHTTP(!def.isNull,
                HTTPStatus.notFound,
                format!"definition %s not found for provider %s"(cubeId, provider.id));

    res.writeJsonBody(def.get);

}

void handleDimensionCodes(HTTPServerRequest req, HTTPServerResponse res)
{
    import vulpes.datasources : getCodes;
    import vulpes.resources : codeToResource;
    import vulpes.lib.requests : doAsyncRequest;
    import vulpes.core.cube : CubeResourceType;

    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"]; auto resourceId = req.params["dimensionId"];

    logDebug("Fetching codes of dimension %s of cube %s for provider %s", resourceId, cubeId, provider.id);

    auto codes = getCodes!(doAsyncRequest, codeToResource, CubeResourceType.dimension)(provider, cubeId, resourceId);

    logDebug("Code list built");
    res.writeJsonBody(codes);
}

void handleAttributeCodes(HTTPServerRequest req, HTTPServerResponse res)
{
    import vulpes.datasources : getCodes;
    import vulpes.resources : codeToResource;
    import vulpes.lib.requests : doAsyncRequest;
    import vulpes.core.cube : CubeResourceType;

    auto provider = getProviderOr404(req.params["providerId"]);

    auto cubeId = req.params["cubeId"]; auto resourceId = req.params["attributeId"];

    logDebug("Fetching codes of attribute %s of cube %s for provider %s", resourceId, cubeId, provider.id);

    auto codes = getCodes!(doAsyncRequest, codeToResource, CubeResourceType.attribute)(provider, cubeId, resourceId);

    logDebug("Code list built");
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
        .get("/providers/:providerId/cubes/:cubeId/definition", &handleDefinition)
        .get("/providers/:providerId/cubes/:cubeId/dimensions/:dimensionId/codes", &handleDimensionCodes)
        .get("/providers/:providerId/cubes/:cubeId/attributes/:attributeId/codes", &handleAttributeCodes);

    auto l = listenHTTP(settings, router);
    scope(exit) l.stopListening();
    runApplication();
}