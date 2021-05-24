module app;
import vibe.d;

void handleProviders(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import vulpes.datasources.providers : getProviders;
    import vulpes.resources : ProviderResource;
    auto providers = getProviders()
        .map!(p => ProviderResource(p.id))
        .array;
    res.writeJsonBody(providers);
}

void handleTags(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import std.format : format;
    import std.typecons : apply;
    import vulpes.datasources.providers : getProvider;
    import vulpes.datasources.sdmxml21 : getTags;
    import vulpes.resources : TagResource, toLabelAA;
    auto provider = getProvider(req.params["providerId"]);

    auto tags = provider.apply!getTags;

    enforceHTTP(!tags.isNull,
                HTTPStatus.internalServerError,
                format!"Could not retrieve tags given the provider %s"(req.params["providerId"]));

    res.writeJsonBody(tags.get.map!(t => TagResource(t.id, t.labels.toLabelAA)).array);

}

void handleDescriptions(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.algorithm : map;
    import std.array : array;
    import std.format : format;
    import std.typecons : apply;
    import vulpes.datasources.providers : getProvider;
    import vulpes.datasources.sdmxml21 : getDescriptions;
    import vulpes.resources : DescriptionResource, toLabelAA;
    auto provider = getProvider(req.params["providerId"]);

    auto descs = provider.apply!getDescriptions;

    enforceHTTP(!descs.isNull,
                HTTPStatus.internalServerError,
                format!"Could not retrieve tags given the provider %s"(req.params["providerId"]));

    res.writeJsonBody(descs.get.map!(t => DescriptionResource(t.id,
                                                              t.providerId,
                                                              t.labels.toLabelAA,
                                                              t.definitionId,
                                                              t.definitionProviderId,
                                                              t.tagIds)).array);
}

void main()
{
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);
    setLogLevel(LogLevel.info);
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
        .get("/providers/:providerId/descriptions", &handleDescriptions);

    listenHTTP(settings, router);
    runApplication();
}