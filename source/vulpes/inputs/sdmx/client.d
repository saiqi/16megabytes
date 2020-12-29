module vulpes.inputs.sdmx.client;
import std.exception : enforce;
import std.format : format;
import std.typecons : nullable, Nullable, tuple;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import vulpes.inputs.sdmx.types;
import vulpes.lib.xml : deserializeAsRangeOf;
import vulpes.core.models;
import vibe.inet.url : URL;
import vibe.core.log;
import requests : Request;


///Dedicated module `Exception`
class SDMXClientException : Exception
{
@safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

package:
URL getRoolURL(const SDMXProvider provider)
{
    with(SDMXProvider)
    {
        final switch(provider)
        {
            case FR1:
            return URL("https://www.bdm.insee.fr/series/sdmx");

            case ESTAT:
            return URL("http://ec.europa.eu/eurostat/SDMX/diss-web/rest");

            case ECB:
            return URL("http://sdw-wsrest.ecb.int/service");

            case UNSD:
            return URL("https://data.un.org/WS/rest");

            case IAEG:
            return URL("https://data.un.org/WS/rest");

            case IMF:
            return URL("https://sdmxcentral.imf.org/ws/public/sdmxapi/rest");

            case ILO:
            return URL("http://www.ilo.org/ilostat/sdmx/ws/rest");

            case WB:
            return URL("http://api.worldbank.org/v2/sdmx/rest");

            case WITS:
            return URL("https://wits.worldbank.org/API/V1/SDMX/V21/rest");

            case SDMX:
            return URL("https://registry.sdmx.org/ws/public/sdmxapi/rest");
        }
    }
}

URL toURL(const StructureRequest req)
{
    auto url = getRoolURL(req.provider);

    import std.array : join;

    with(StructureType)
    {
        final switch(req.type)
        {
            case dataflow:
            if(req.provider != SDMXProvider.WB && req.provider != SDMXProvider.ESTAT)
                url.pathString([url.pathString, req.type, req.provider, req.version_, req.itemId].join("/"));
            else
                url.pathString([url.pathString, req.type, req.provider, req.version_].join("/"));
            break;

            case codelist, conceptscheme:
            if(req.provider == SDMXProvider.UNSD || req.provider == SDMXProvider.IAEG || SDMXProvider.WB)
                url.pathString(
                    [url.pathString, req.type, req.provider, req.resourceId].join("/"));
            else if(req.provider == SDMXProvider.ECB)
                url.pathString(
                    [url.pathString, req.type, req.provider, req.resourceId, req.version_].join("/"));
            else
                url.pathString(
                    [url.pathString, req.type, req.provider, req.resourceId, req.version_, req.itemId].join("/"));
            break;

            case datastructure:
            if(req.provider != SDMXProvider.WB)
                url.pathString([url.pathString, req.type, req.provider, req.resourceId, req.version_].join("/"));
            else
                url.pathString([url.pathString, req.type, req.provider, "all"].join("/"));
            break;
        }
    }

    if(req.provider == SDMXProvider.ILO)
        url.queryString(["format=compact_2_1", "references=" ~ req.references, "detail=" ~ req.detail].join("&"));
    else if(req.provider == SDMXProvider.SDMX)
        url.queryString(["format=sdmx-2.1", "references=" ~ req.references, "detail=" ~ req.detail].join("&"));
    else
        url.queryString(["references=" ~ req.references, "detail=" ~ req.detail].join("&"));

    return url;
}

unittest
{
    import std.traits : EnumMembers;
    import std.algorithm : cartesianProduct;

    cartesianProduct(
        [EnumMembers!SDMXProvider].map!(a => a.to!string).array,
        [EnumMembers!StructureType].map!(a => a.to!string).array,
        ["resourceId"],
        ["latest"],
        ["all"],
        [EnumMembers!StructureDetail].map!(a => a.to!string).array,
        [EnumMembers!StructureReferences].map!(a => a.to!string).array)
    .map!(a => StructureRequest(
        a[0].to!SDMXProvider,
        a[1].to!StructureType,
        a[2],
        a[3],
        a[4],
        a[5].to!StructureDetail,
        a[6].to!StructureReferences))
    .map!toURL
    .array;

}

auto errorMessage(const size_t code, const string responseBody)
{
    const defaultMessage = format!"HTTP error %s: %s"(code, responseBody);
    try
    {
        auto err = responseBody.deserializeAsRangeOf!SDMXError_;
        if(!err.empty && !err.front.errorMessage.isNull)
        {
            return format!"%s: %s"(
                err.front.errorMessage.get.code.get,
                err.front.errorMessage.get.text_.get.content.get);
        }
    } catch(Exception e) {}

    return defaultMessage;
}

auto doRequest(const URL url, string[string] headers)
{
    auto req = Request();
    req.sslSetVerifyPeer(false);
    req.addHeaders(headers);

    auto resp = req.get(url.toString);

    return tuple(resp.code, cast(string) resp.responseBody.data);
}

auto doStructureRequest(alias fetcher = doRequest)(const StructureRequest sReq)
{
    auto url = sReq.toURL();

    logDebug("Fetching from %s", url);

    auto response = fetcher(url, [
        "Accept":"application/vnd.sdmx.structure+xml;version=2.1",
        "Accept-Encoding": "gzip,deflate"
    ]);

    auto code = response[0];
    auto responseBody = response[1];

    if(code == 200) return responseBody;

    logError("HTTP code %s received from %s", code, url);
    enforce!SDMXClientException(false, errorMessage(code, responseBody));
    assert(false);
}

unittest
{
    import std.file : readText;
    import std.exception : assertThrown;

    auto mockFetcherOk(const URL url, string[string] headers)
    {
        return tuple(200, "ok");
    }

    const sReq = StructureRequest(
        SDMXProvider.ECB,
        StructureType.conceptscheme,
        "all",
        "latest",
        "all",
        StructureDetail.full,
        StructureReferences.parentsandsiblings);

    assert(doStructureRequest!mockFetcherOk(sReq) == "ok");

    auto mockFetcherKo(const URL url, string[string] headers)
    {
        return tuple(500, readText("./fixtures/sdmx/error.xml"));
    }

    auto mockFetchNoMessage(const URL url, string[string] headers)
    {
        return tuple(400, "not parsable");
    }

    assertThrown!SDMXClientException(doStructureRequest!mockFetcherKo(sReq));
    assertThrown!SDMXClientException(doStructureRequest!mockFetchNoMessage(sReq));
}

public:
enum StructureType: string
{
    dataflow = "dataflow",
    codelist = "codelist",
    conceptscheme = "conceptscheme",
    datastructure = "datastructure"
}

enum StructureDetail: string
{
    allstubs = "allstubs",
    referencestubs = "referencestubs",
    allcompletestubs = "allcompletestubs",
    referencecompletestubs = "referencecompletestubs",
    referencepartial = "referencepartial",
    full = "full"
}

enum StructureReferences: string
{
    none = "none",
    parents = "parents",
    parentsandsiblings = "parentsandsiblings",
    children = "children",
    descendants = "descendants",
    all = "all",
    codelist = "codelist",
    conceptscheme = "conceptscheme",
    contentconstraint = "contentconstraint"
}

struct StructureRequest
{
    SDMXProvider provider;
    StructureType type;
    string resourceId;
    string version_;
    string itemId;
    StructureDetail detail;
    StructureReferences references;
}

auto fetchStructure(alias fetcher = doRequest)(
    const string providerId,
    const StructureType type,
    const string resourceId = "all",
    const string version_ = "latest",
    const string itemId = "all",
    const StructureDetail detail = StructureDetail.full,
    const StructureReferences references = StructureReferences.none)
{
    SDMXProvider provider;
    try {
        provider = providerId.to!SDMXProvider;
    }
    catch(Exception e)
    {
        enforce!SDMXClientException(false, format!"Unknown SDMX provider: %s"(providerId));
    }

    return StructureRequest(provider, type, resourceId, version_, itemId, detail, references)
        .doStructureRequest!fetcher;
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto mockerFetcher(const URL url, string[string] headers)
    {
        return tuple(200, "ok");
    }

    assertThrown!SDMXClientException(
        fetchStructure!mockerFetcher("Unknown", StructureType.dataflow));
    assertNotThrown!SDMXClientException(
        fetchStructure!mockerFetcher(SDMXProvider.ECB.to!string, StructureType.dataflow));
}

