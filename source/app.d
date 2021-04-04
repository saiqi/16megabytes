import vibe.vibe;

void handle(HTTPServerRequest req, HTTPServerResponse resp)
{
    import vulpes.inputs.sdmx : getCubeDefinitionFromSDMXREST;
    auto c = getCubeDefinitionFromSDMXREST(
        "FR1", "BALANCE-PAIEMENTS", "BALANCE-PAIEMENTS");
    resp.writeBody("OK");
}

void main()
{
    auto router = new URLRouter;
    router.get("/", &handle);

    auto settings = new HTTPServerSettings;
    settings.bindAddresses = ["::", "127.0.0.1"];
    settings.port = 8080;

    listenHTTP(settings, router);

    runTask({
        import std.range : iota;
        import std.algorithm : map;
        import std.array : array;

        iota(4)
            .map!((i){
                runTask({
                    logInfo("[%s]", i);
                    requestHTTP("http://localhost:8080", (req) {}, (res) {
                        logInfo("[%s][%s]", i, res.statusCode);
                    });
                });
                return true;
            })
            .array;

    });

    runApplication();
}
