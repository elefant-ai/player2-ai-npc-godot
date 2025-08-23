# @abstract
class_name Player2EndpointConfig
extends Resource

#@export var root : String = "http://127.0.0.1"

func path(path_property : String) -> String:
	var root : String = get("root")
	var result : String = get(path_property)
	if root:
		result = result.replace("{root}", root)
	return result
