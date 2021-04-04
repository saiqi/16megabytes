#!/usr/bin/env dub
/+dub.json:
{
    "name": "imfcodelist",
    "dependencies": {
        "vulpes": {"path": "../"}
    }
}
+/
module scripts.imfcodelist;

import std.range : walkLength;
import dxml.parser: parseXML, simpleXML;
import vibe.core.log;
import requests : Request;
import vulpes.lib.xml : deserializeAsRangeOf;
import vulpes.inputs.sdmx.types;

void main(string[] args)
{
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);
    const url =
    "https://sdmxcentral.imf.org/ws/public/sdmxapi/rest/codelist/IMF/CL_INDICATOR?references=none&detail=full";
    auto req = Request();
    req.sslSetVerifyPeer(false);
    req.addHeaders([
        "Accept":"application/vnd.sdmx.structure+xml;version=2.1",
        "Accept-Encoding": "gzip,deflate"
    ]);

    logInfo("Starting ...");
    auto payload = cast(string) req.get(url).responseBody.data;
    logInfo("Fetched");
    parseXML!simpleXML(payload).walkLength;
    logInfo("Simple");
    auto r = payload.deserializeAsRangeOf!SDMXCode.walkLength;
    logInfo("Parsed %s codes", r);
}