module app;
import vibe.core.log;
import vibe.core.core;
import vibe.http.server;
import vibe.http.router;

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
    settings.errorPageHandler = (HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) @safe {
        if(error.exception) res.writeJsonBody(["message": error.exception.msg]);
        else res.writeJsonBody(["message": error.message]);
    };

    auto router = new URLRouter;
    router.get("/", &handleGreetings);

    auto l = listenHTTP(settings, router);
    scope(exit) l.stopListening();
    runApplication();
}