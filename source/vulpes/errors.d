module vulpes.errors;

class NotFound : Exception
{
    @safe:
    ///ditto
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}