## Helper class for user game data persistence.
## Access via Player2API.Data
class_name Player2Data
extends RefCounted

var _api: Node


func _init(api: Node) -> void:
	_api = api


func _get_game_id() -> String:
	var client_id = ProjectSettings.get_setting("player2/client_id", "")
	return client_id


func _build_path(key: String = "") -> String:
	var game_id := _get_game_id()
	var path := "user_data"
	if not key.is_empty():
		path += "?key=" + key.uri_encode()
	return path


func _replace_game_id_in_path(path: String) -> String:
	var game_id := _get_game_id()
	return path.replace("{game_id}", game_id)


## Get a value by key. Value is auto-deserialized from JSON.
## on_complete receives the deserialized Variant.
## on_fail receives (error_message: String, error_code: int).
func get_value(key: String, on_complete: Callable, on_fail: Callable = Callable()) -> void:
	if key.is_empty():
		if on_fail.is_valid():
			on_fail.call("Key cannot be empty", -1)
		return

	var path := _build_path(key)
	_api._req_with_game_id(path, HTTPClient.Method.METHOD_GET, "",
		func(result):
			var value_str: String = result.get("value", "")
			var parsed = JSON.parse_string(value_str)
			if on_complete.is_valid():
				on_complete.call(parsed),
		on_fail
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
	var path := _build_path()
	_api._req_with_game_id(path, HTTPClient.Method.METHOD_PUT, body,
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

	var path := _build_path(key)
	_api._req_with_game_id(path, HTTPClient.Method.METHOD_DELETE, "",
		func(_result):
			if on_complete.is_valid():
				on_complete.call(),
		on_fail
	)


## Delete all user data for this game.
## on_complete receives no arguments.
## on_fail receives (error_message: String, error_code: int).
func delete_all(on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void:
	var path := _build_path()
	_api._req_with_game_id(path, HTTPClient.Method.METHOD_DELETE, "",
		func(_result):
			if on_complete.is_valid():
				on_complete.call(),
		on_fail
	)
