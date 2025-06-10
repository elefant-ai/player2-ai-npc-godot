class_name Player2FunctionHelper

## Given a script, get a dictionary mapping a method name to its documentation string
## (TODO: test in an actual build to make sure this works)
## (TODO: Csharp implementation?)
static func parse_documentation(script : Script) -> Dictionary:
	var result := Dictionary()
	if script and script.has_source_code():
		var src := script.source_code
		var regex = RegEx.new()
		regex.compile("(?m)((^##.*$\\n)+)^\\s*func (.*)\\(.*$")
		var matches := regex.search_all(src)
		for m in matches:
			if m.strings.size() >= 4:
				var f_name = m.strings[3]
				var comments : Array[String] = []
				comments.assign(m.strings[1].split("\n"))
				comments.assign(comments.map(func(line : String):
					return line.trim_prefix("##").strip_edges()
				))
				var description := " ".join(comments)
				result[f_name] = description
	return result
