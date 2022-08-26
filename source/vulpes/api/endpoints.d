module vulpes.api.endpoints;

import vibe.web.rest : path;
import vulpes.api.resources;
import vulpes.datasources.providers : Provider;

private immutable(Provider) getProviderOrError(in string providerId) @safe
{
    import std.algorithm : find;
    import std.format : format;
    import vibe.http.common : enforceHTTP, HTTPStatus;
    import vulpes.datasources.providers : loadProvidersFromConfig;

    auto ps = loadProvidersFromConfig()
        .find!(a => a.id == providerId);

    enforceHTTP(ps.length > 0, HTTPStatus.notFound, format!"%s not found"(providerId));

    return ps[0];
}

unittest
{
    import std.exception : assertThrown;
    import vibe.http.common : HTTPStatusException;
    import vulpes.datasources.providers : loadProvidersFromConfig;
    auto providers = loadProvidersFromConfig();
    auto existingId = providers[0].id;

    assert(getProviderOrError(existingId).id == providers[0].id);
    assertThrown!HTTPStatusException(getProviderOrError("impossibleId"));
}

@path("/structure/")
interface StructureAPI
{
    @path(":structureType/:agencyId/:resourceId/:version")
    StructureMessageResponse getStructure(string _structureType, string _agencyId, string _resourceId, string _version);
}

class StructureApiImpl : StructureAPI
{
@safe:

    StructureMessageResponse getStructure(string _structureType, string _agencyId, string _resourceId, string _version)
    {
        auto provider = getProviderOrError(_agencyId);
        auto resp = StructureMessageResponse();
        resp.meta = buildMeta();
        return resp;
    }
}