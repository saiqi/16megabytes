module vulpes.api;

import std.typecons : No;
import std.algorithm : map;
import std.format : format;
import std.array : array;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.common : enforceHTTP, HTTPStatus;
import vibe.core.log;
import vulpes.datasources.providers;

immutable(Provider) getProviderOrError(in string providerId)
{
    import std.algorithm : find;
    import std.format : format;

    auto ps = loadProvidersFromConfig()
        .find!(a => a.id == providerId);

    enforceHTTP(ps.length > 0, HTTPStatus.notFound, format!"%s not found"(providerId));

    return ps[0];
}

void handleDataflows(HTTPServerRequest req, HTTPServerResponse res)
{
    import vulpes.core.search : search;

    auto provider = getProviderOrError(req.params["providerId"]);
    auto q = req.query.get("q");
    logInfo(q);

    if(q is null) res.writeJsonBody(provider.dataflows.array);
    else res.writeJsonBody(provider.dataflows.search!1(q).array);
}