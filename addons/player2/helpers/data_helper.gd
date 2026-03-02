## Helper class for user game data persistence.
## Access via Player2API.Data
class_name Player2Data
extends RefCounted

var _api: Node


func _init(api: Node) -> void:
	_api = api


const PATH_PROPERTY := "user_data"


## Get a value by key. Value is auto-deserialized from JSON.
## on_complete receives the deserialized Variant.
## on_fail receives (error_message: String, error_code: int).
func get_value(key: String, on_complete: Callable, on_fail: Callable = Callable()) -> void:
	if key.is_empty():
		if on_fail.is_valid():
			on_fail.call("Key cannot be empty", -1)
		return

	_api._req_with_game_id(PATH_PROPERTY, HTTPClient.Method.METHOD_GET, "",
		func(result):
			var value_str: String = result.get("value", "")
			var parsed: Variant = JSON.parse_string(value_str)
			if on_complete.is_valid():
				on_complete.call(parsed),
		on_fail,
		{"key": key}
	)


## Set a value by key. Value is auto-serialized to JSON string.
## on_complete receives no arguments.
## on_fail receives (error_message: String, error_code: int).
func set_value(key: String, value: Variant, on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void:
	if key.is_empty():
		if on_fail.is_valid():
			on_fail.call("Key cannot be empty", -1)
		return

	var value_json := JSON.stringify(value)
	var body := {"key": key, "value": value_json}
	_api._req_with_game_id(PATH_PROPERTY, HTTPClient.Method.METHOD_PUT, body,
		func(_result):
			if on_complete.is_valid():
				on_complete.call(),
		on_fail
	)


## Delete a single key.
## on_complete receives no arguments.
## on_fail receives (error_message: String, error_code: int).
func delete(key: String, on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void:
	if key.is_empty():
		if on_fail.is_valid():
			on_fail.call("Key cannot be empty", -1)
		return

	_api._req_with_game_id(PATH_PROPERTY, HTTPClient.Method.METHOD_DELETE, "",
		func(_result):
			if on_complete.is_valid():
				on_complete.call(),
		on_fail,
		{"key": key}
	)


## Delete all user data for this game.
## on_complete receives no arguments.
## on_fail receives (error_message: String, error_code: int).
func delete_all(on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void:
	_api._req_with_game_id(PATH_PROPERTY, HTTPClient.Method.METHOD_DELETE, "",
		func(_result):
			if on_complete.is_valid():
				on_complete.call(),
		on_fail
	)
