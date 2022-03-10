module vulpes.api;

import std.typecons : No;
import std.algorithm : map;
import std.format : format;
import std.array : array;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.common : enforceHTTP, HTTPStatus;
import vulpes.datasources.providers;
import vulpes.core.model : ResourceType;
import vulpes.lib.xml : deserializeAs, deserializeAsRangeOf;

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
    auto provider = getProviderOrError(req.params["providerId"]);
    res.writeJsonBody(provider.dataflows.array);
}