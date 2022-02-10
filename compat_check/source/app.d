import std.stdio : writefln;
import std.sumtype : match;
import std.algorithm : filter, each;
import vulpes.datasources.providers : loadProvidersFromConfig, Provider;
import vulpes.datasources.hub : getDataflows;
import vulpes.core.model : Error_, Dataflow;

void main()
{
	loadProvidersFromConfig("../conf/providers.json")
		.filter!(a => a.isPublic)
		.each!((p) {
			p.getDataflows(1, 0).match!(
				(Error_ e) => writefln("error when fetching dataflows for provider %s", p.id),
				(Dataflow[] df) => writefln("dataflows successfully fetched for provider %s", p.id)
			);
		});
}
