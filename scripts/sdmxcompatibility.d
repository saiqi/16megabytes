#!/usr/bin/env dub
/+dub.json:
{
    "name": "sdmxcompatibility",
    "dependencies": {
        "vulpes": {"path": "../"}
    }
}
+/
module scripts.sdmxcompatibility;
import std.algorithm : map;
import std.array : array;
import std.conv : to;
import std.range : walkLength, tee;
import std.getopt;
import vibe.core.log;
import vibe.core.core: runTask;
import vulpes.inputs.sdmx;
import vulpes.inputs.sdmx.client : SDMXProvider;


string[] providers;
bool debug_;

void handleProvider(string p)
{
    try {
        logInfo("[%s] Fetching all descriptions", p);
        auto descriptions = getCubeDescriptions!doRequest(p);

        if(descriptions.empty)
        {
            logWarn("[%s] returned empty description list!", p);
            return;
        }
        auto n = descriptions.walkLength;
        logInfo("[%s] Got %s descriptions", p, n);

        auto firstDescription = descriptions.front;

        logInfo("[%s][%s] Fetching definition ...", p, firstDescription.id);
        auto definition = getCubeDefinition!doRequest(p, firstDescription.id, firstDescription.definitionId);

        logInfo("[%s][%s] Running a naive query: ", p, firstDescription.id);
        auto dataset = getDataset!doRequest(definition, firstDescription, []);
        logInfo("[%s][%s] %s series found!", p, firstDescription.id, dataset.series.length);

    } catch(Exception e)
    {
        logError("[%s]: %s", p, e.msg);
    }
}

void main(string[] args)
{
    getopt(args, "provider", &providers, "debug", &debug_);
    setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);

    if(debug_)
        setLogLevel(LogLevel.debug_);
    else
        setLogLevel(LogLevel.info);

    providers
        .map!(p => p.to!string)
        .map!(p => runTask(&handleProvider, p))
        .array
        .tee!(t => t.join)
        .array;
}

