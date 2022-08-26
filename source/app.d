module app;
import std.functional : toDelegate;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;
import vibe.web.rest : registerRestInterface, RestInterfaceSettings, RestErrorInformation;
import vulpes.api.endpoints : StructureApiImpl;

void handleError(HTTPServerRequest req, HTTPServerResponse res, RestErrorInformation error) @safe
{
    import vulpes.api.resources : ErrorMessageResponse, buildMeta, ErrorResponse, ErrorStatusCode;

    ErrorResponse err;
    with(ErrorStatusCode) switch(error.statusCode)
    {
        case HTTPStatus.notFound:
        err = ErrorResponse.build(notFound, error.exception.msg);
        break;

        default:
        err = ErrorResponse.build(internalServerError, error.exception.msg);
    }

    auto resp = ErrorMessageResponse(buildMeta(), [err]);

    res.writeJsonBody(resp, error.statusCode);
}

void main()
{
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);
    setLogLevel(LogLevel.debug_);
    auto server = new HTTPServerSettings;
    server.port = 8080;
    server.bindAddresses = ["::1", "127.0.0.1"];

    auto router = new URLRouter;
    auto settings = new RestInterfaceSettings();
    settings.errorHandler = toDelegate(&handleError);

    router.registerRestInterface(new StructureApiImpl, settings);

    auto l = listenHTTP(server, router);
    scope(exit) l.stopListening();
    runApplication();
}