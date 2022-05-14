module vulpes.core.data;

import vulpes.core.model;
import vulpes.core.query : QueryComponent;

///Dedicated module `Exception`
class DataServiceException : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

// Structure buildStructure(
//     DataStructure dsd, in QueryComponent[] query, in Codelist[] codelists) pure @safe
// {
//     import std.algorithm : sort, map;
//     import std.array : array;
//     import std.range : walkLength;
//     import std.exception : enforce;
//     import vulpes.lib.operations : innerjoin;

//     auto dimensions = dsd
//         .dataStructureComponents
//         .dimensionList
//         .dimensions
//         .sort!"a.position < b.position";

//     auto dimComponents = query
//         .sort!"a.position < b.position"
//         .innerjoin!(a => a.position, a => a.position)(dimensions)
//         .map!((t) {
//             auto q = t[0]; auto dim = t[1];

//             StructureComponentValue[] values = !dim.localRepresentation.isNull
//                 ? []
//                 : [];

//         });

//     enforce!DataServiceException(dimComponents.walkLength == query.length,
//                                  "query does not match dimensions structure!");



// }