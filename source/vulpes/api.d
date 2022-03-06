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
    enforceHTTP(!ps[0].formatType.isNull,
                HTTPStatus.internalServerError,
                format!"Cannot find provider %s format"(providerId));

    return ps[0];
}

void handleDataflows(HTTPServerRequest req, HTTPServerResponse res)
{
    auto provider = getProviderOrError(req.params["providerId"]);

    auto messages = fetchResources(provider, ResourceType.dataflow);

    auto fmt = provider.formatType.get;

    with(FormatType) switch(provider.formatType.get)
    {
        case sdmxml21:
        import vulpes.datasources.sdmxml21 : buildDataflows;
        auto dfs = buildDataflows(messages);
        res.writeJsonBody(dfs.array);
        break;

        default:
        enforceHTTP(false, HTTPStatus.notImplemented, format!"%s not implemented"(fmt));
        break;
    }
}