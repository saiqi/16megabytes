module app;
import std.functional : toDelegate;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;
import vulpes.datasources.providers : Provider;

void handleError(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) @safe
{
    import vulpes.core.model : Error_, ErrorStatusCode;
    auto msg = (error.exception !is null) ? error.exception.msg : error.message;

    Error_ err;
    with(ErrorStatusCode) switch(error.code)
    {
        case 404:
        err = Error_.build(notFound, msg);
        break;

        default:
        err = Error_.build(internalServerError, msg);
    }

    res.writeJsonBody(err);
}

void handleGreetings(HTTPServerRequest req, HTTPServerResponse res)
{
    res.writeJsonBody(["message": "Welcome to Vulpes API"]);
}

immutable(Provider) getProviderOrError(in string providerId)
{
    import std.algorithm : find;
    import std.format : format;
    import vulpes.datasources.providers : loadProvidersFromConfig;

    auto ps = loadProvidersFromConfig()
        .find!(a => a.id == providerId);

    enforceHTTP(ps.length > 0, HTTPStatus.notFound, format!"%s not found"(providerId));

    return ps[0];
}

void handleDataflows(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.array : array;
    import std.algorithm : map;
    import vulpes.datasources.providers : dataflows;
    import vulpes.core.search : search;
    import vulpes.api.resources : DataflowResponse;

    auto provider = getProviderOrError(req.params["providerId"]);
    auto q = req.query.get("q");

    // if(q is null) res.writeJsonBody(provider.dataflows.map!(a => DataflowResponse.fromModel(a)).array);
    // else res.writeJsonBody(provider.dataflows.map!(a => DataflowResponse.fromModel(a)).search!1(q).array);
}

void main()
{
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);
    setLogLevel(LogLevel.debug_);
    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    settings.errorPageHandler = toDelegate(&handleError);

    auto router = new URLRouter;
    router
        .get("/", &handleGreetings)
        .get("/dataflow/:providerId/all/latest", &handleDataflows);

    auto l = listenHTTP(settings, router);
    scope(exit) l.stopListening();
    runApplication();
}