module vulpes.datasources.datasource;

import std.range : InputRange;
import vibe.core.concurrency : Future;
import vulpes.core.model;
import vulpes.datasources.providers : Provider, Fetcher;

///Dedicated module `Exception`
class DatasourceException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}


interface Datasource
{
    @safe:
    InputRange!Dataflow getDataflows(in ref Provider provider, Fetcher fetcher);
    DataStructure getDataStructure(in ref Provider provider, in string id, Fetcher fetcher);
    Codelist getCodelist(in ref Provider provider, in string id, Fetcher fetcher);
    ConceptScheme getConceptScheme(in ref Provider provider, in string id, Fetcher fetcher);
    InputRange!CategoryScheme getCategorySchemes(in ref Provider provider, Fetcher fetcher);
    InputRange!Categorisation getCategorisations(in ref Provider provider, Fetcher fetcher);
}