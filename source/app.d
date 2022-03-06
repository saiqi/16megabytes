module app;
import std.functional : toDelegate;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;
import vulpes.api;

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