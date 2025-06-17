class_name StringFilter
extends Resource

@export var mode : Mode = Mode.WHITELIST
@export var list : Array[String] = []

enum Mode {WHITELIST, BLACKLIST}

func is_allowed(value : String) -> bool:
	if mode == Mode.WHITELIST:
		return list.has(value)
	if mode == Mode.BLACKLIST:
		return not list.has(value)
	return true
