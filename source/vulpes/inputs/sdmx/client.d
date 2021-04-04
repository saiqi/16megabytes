module vulpes.inputs.sdmx.client;
import std.exception : enforce;
import std.format : format;
import std.typecons : nullable, Nullable, tuple;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import vulpes.inputs.sdmx.types;
import vulpes.lib.xml : deserializeAsRangeOf;
import vulpes.core.cube;
import vibe.inet.url : URL;
import vibe.core.log;
import requests : Request;
import sumtype : SumType, match;


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
URL getRoolURL(const SDMXProvider provider) @safe
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
            return URL("http://sdw-wsrest.ecb.europa.eu/service");

            case UNSD:
            return URL("https://data.un.org/WS/rest");

            case IAEG:
            return URL("https://data.un.org/WS/rest");

            case IMF:
            return URL("https://sdmxcentral.imf.org/ws/public/sdmxapi/rest");

            case ILO:
            return URL("https://www.ilo.org/sdmx/rest");

            case WB:
            return URL("http://api.worldbank.org/v2/sdmx/rest");

            case WITS:
            return URL("http://wits.worldbank.org/API/V1/SDMX/V21/rest");

            case SDMX:
            return URL("https://registry.sdmx.org/ws/public/sdmxapi/rest");

            case UNICEF:
            return URL("https://sdmx.data.unicef.org/ws/public/sdmxapi/rest");
        }
    }
}

URL toStructureURL(const StructureRequest req) @safe
{
    auto url = getRoolURL(req.provider);

    import std.array : join;

    with(StructureType)
    {
        final switch(req.type)
        {
            case dataflow, codelist, conceptscheme, datastructure:
            req.resourceId == "all"
                ? url.pathString([url.pathString, req.type, req.provider].join("/"))
                : url.pathString([url.pathString, req.type, req.provider, req.resourceId].join("/"));
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
    .map!toStructureURL
    .array;

}

URL toDataURL(const DataRequest req)
{
    auto url = getRoolURL(req.provider);

    import std.array : join;

    url.pathString([url.pathString, "data", req.resourceId, req.keys, req.provider].join("/"));

    string[] queryParams = [];

    if(!req.startPeriod.isNull) queryParams ~= "startPeriod=" ~ req.startPeriod.get;
    if(!req.endPeriod.isNull) queryParams ~= "endPeriod=" ~ req.endPeriod.get;
    if(!req.updatedAfter.isNull) queryParams ~= "updatedAfter=" ~ req.updatedAfter.get;
    if(!req.firstNObservations.isNull) queryParams ~= "firstNObservations=" ~ req.firstNObservations.get;
    if(!req.lastNObservations.isNull) queryParams ~= "lastNObservations=" ~ req.lastNObservations.get;

    if(queryParams) url.queryString(queryParams.join("&"));

    return url;
}

unittest
{
    import std.traits : EnumMembers;
    [EnumMembers!SDMXProvider]
        .map!(p => [
            DataRequest(
                DataRequestFormat.generic,
                "resource",
                "keys",
                p,
                (Nullable!string).init,
                (Nullable!string).init,
                (Nullable!string).init,
                (Nullable!string).init,
                (Nullable!string).init)
                .toDataURL,
            DataRequest(
                DataRequestFormat.structurespecific,
                "resource",
                "keys",
                p,
                "ok".nullable,
                "ok".nullable,
                "ok".nullable,
                "ok".nullable,
                "ok".nullable)
                .toDataURL,
        ])
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

auto doVibedRequest(const URL url, string[string] headers)
{
    import vibe.http.client : requestHTTP;
    import vibe.stream.operations : readAllUTF8;
    auto resp = requestHTTP(url.toString, (scope req) {
        foreach(i; headers.byKeyValue)
        {
            req.headers[i.key] = i.value;
        }
    });
    scope(exit) resp.dropBody();

    return tuple(resp.statusCode, resp.bodyReader.readAllUTF8);
}

auto toURL(SDMXRequest req)
{
    return req.match!(
        (StructureRequest sReq) => toStructureURL(sReq),
        (DataRequest dReq) => toDataURL(dReq)
    );
}

auto toHeaders(SDMXRequest req)
{
    return req.match!(
        (StructureRequest sReq) => [
            "Accept":"application/vnd.sdmx.structure+xml;version=2.1",
            "Accept-Encoding": "gzip,deflate"
        ],
        (DataRequest dReq) => [
            "Accept": dReq.format == DataRequestFormat.generic
                ? "application/vnd.sdmx.genericdata+xml;version=2.1"
                : "application/vnd.sdmx.structurespecificdata+xml;version=2.1",
            "Accept-Encoding": "gzip,deflate"
        ]
    );
}

auto doSDMXRequest(alias fetcher)(const SDMXRequest sReq)
{
    auto url = sReq.toURL();

    logDebug("Fetching from %s", url);

    auto response = fetcher(url, sReq.toHeaders());

    logDebug("Got response from %s", url);

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

    SDMXRequest sReq = StructureRequest(
        SDMXProvider.ECB,
        StructureType.conceptscheme,
        "all",
        "latest",
        "all",
        StructureDetail.full,
        StructureReferences.parentsandsiblings);

    assert(doSDMXRequest!mockFetcherOk(sReq) == "ok");

    auto mockFetcherKo(const URL url, string[string] headers)
    {
        return tuple(500, readText("./fixtures/sdmx/error.xml"));
    }

    auto mockFetchNoMessage(const URL url, string[string] headers)
    {
        return tuple(400, "not parsable");
    }

    assertThrown!SDMXClientException(doSDMXRequest!mockFetcherKo(sReq));
    assertThrown!SDMXClientException(doSDMXRequest!mockFetchNoMessage(sReq));

    SDMXRequest dReq = DataRequest(DataRequestFormat.generic, "foo", "keys", SDMXProvider.UNICEF);
    assert(doSDMXRequest!mockFetcherOk(dReq) == "ok");
}

auto getProvider(const string providerId)
{
    SDMXProvider provider;
    try {
        provider = providerId.to!SDMXProvider;
    }
    catch(Exception e)
    {
        enforce!SDMXClientException(false, format!"Unknown SDMX provider: %s"(providerId));
    }
    return provider;
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

struct DataRequest
{
    DataRequestFormat format;
    string resourceId;
    string keys;
    SDMXProvider provider;
    Nullable!string startPeriod;
    Nullable!string endPeriod;
    Nullable!string updatedAfter;
    Nullable!string firstNObservations;
    Nullable!string lastNObservations;
}

alias SDMXRequest = SumType!(StructureRequest, DataRequest);

public:
enum SDMXProvider: string
{
    FR1 = "FR1",
    ESTAT = "ESTAT",
    ECB = "ECB",
    UNSD = "UNSD",
    IMF = "IMF",
    ILO = "ILO",
    WB = "WB",
    WITS = "WITS",
    IAEG = "IAEG",
    UNICEF = "UNICEF",
    SDMX = "SDMX"
}

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

enum DataRequestFormat
{
    generic,
    structurespecific
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
    SDMXRequest req = StructureRequest(providerId.getProvider, type, resourceId, version_, itemId, detail, references);
    return req.doSDMXRequest!fetcher;
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

auto fetchData(alias fetcher = doRequest)(
    const DataRequestFormat format,
    const string resourceId,
    const string keys,
    const string providerId,
    const Nullable!string startPeriod = (Nullable!string).init,
    const Nullable!string endPeriod = (Nullable!string).init,
    const Nullable!string updatedAfter = (Nullable!string).init,
    const Nullable!string firstNObservations = (Nullable!string).init,
    const Nullable!string lastNObservations = (Nullable!string).init)
{
    SDMXRequest req = DataRequest(
        format,
        resourceId,
        keys,
        providerId.getProvider,
        startPeriod,
        endPeriod,
        updatedAfter,
        firstNObservations,
        lastNObservations
    );
    return req.doSDMXRequest!fetcher;
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto mockerFetcher(const URL url, string[string] headers)
    {
        return tuple(200, "ok");
    }

    assertNotThrown!SDMXClientException(
        fetchData!mockerFetcher(DataRequestFormat.generic, "foo", "keys", SDMXProvider.UNICEF.to!string));
}