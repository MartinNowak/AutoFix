import std.range;
import std.algorithm;
import std.file;
import std.path;

import ae.utils.json;

enum JsonFiles =
[
	`C:\Projects\Extern\D\druntime\druntime.json`,
	`C:\Projects\Extern\D\phobos\phobos.json`,
	`C:\Projects\ae\ae.json`,
	`C:\Projects\Extern\dsource-bindings\bindings.json`,
	`C:\Projects\team15\team15.json`,
];

enum ManualFiles =
[
	`C:\Projects\Extern\dsource-bindings\bindings-handles.json`,
];

string[][string] getJsonSummary()
{
	static string[][string] jsonSummary;
	if (!jsonSummary)
	{
		string summaryFileName = thisExePath.dirName.buildPath("summary.json");
		if (!summaryFileName.exists
		 || chain(JsonFiles, ManualFiles, thisExePath.only)
			.any!(f => f.timeLastModified > summaryFileName.timeLastModified))
		{
			// summary is stale, rebuild
			rebuildSummary(summaryFileName);
		}

		jsonSummary = summaryFileName.readText.jsonParse!(typeof(return));
		jsonSummary.rehash;
	}
	return jsonSummary;
}

void rebuildSummary(string summaryFileName)
{
	struct Member
	{
		string file, name, kind;
		uint line;
	@JSONName("char")
		uint char_;

		string protection;
		string[] selective;
		string[] storageClass;
		string deco;
		string originalType;
		Member[] parameters;
		string init;
		Member[] members;
		string type;
		uint endline, endchar;
		uint offset;
	@JSONName("default")
		string default_;
		string defaultDeco;
		string defaultValue;
		string base;
		string baseDeco;
		string specValue;
		string defaultAlias;
	@JSONName("in")
		Member* in_;
	@JSONName("out")
		Member* out_;
		string[] overrides;
		string[string] renamed;
		string[] interfaces;
	@JSONName("alias")
		string alias_;
	@JSONName("align")
		uint align_;
		string specAlias;
		string value;
		string constraint;
	}

	bool[string][string] summary;

	foreach (fn; JsonFiles)
	{
		auto modules = fn.readText.jsonParse!(Member[]);
		foreach (m; modules)
		{
			if (m.name.startsWith("std.internal."))
				continue;

			foreach (d; m.members)
			{
				if (d.protection == "private"
				 || d.protection == "package"
				 || d.type == "import"
				 || d.type == "static import"
				 || d.name.startsWith("__unittest")
				)
					continue;
				summary[d.name][m.name] = true;
			}
		}
	}

	foreach (fn; ManualFiles)
	{
		auto dict = fn.readText.jsonParse!(string[string]);
		foreach (sym, mod; dict)
			if (sym.length && mod.length)
				summary[sym][mod] = true;
	}

	string[][string] result;
	foreach (sym, mods; summary)
			result[sym] = mods.keys;

	std.file.write(summaryFileName, result.toJson);
}

version(DjsonMain)
void main()
{
	getJsonSummary();
}
