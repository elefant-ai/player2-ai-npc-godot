# Player2API.Data Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `Player2API.Data` module for persisting user game data (saves, progress, inventory) via the Player2 cloud API.

**Architecture:** Create a `Player2Data` class (RefCounted) exposed as `Player2API.Data`. It wraps HTTP calls to `/games/{game_id}/data/user` endpoints, auto-serializing Variants to JSON strings and deserializing responses.

**Tech Stack:** GDScript, Godot 4.x, existing Player2 HTTP infrastructure (`_req()` method)

---

### Task 1: Add Endpoint Configuration

**Files:**
- Modify: `addons/player2/helpers/config/Player2LocalEndpointConfig.gd:20`
- Modify: `addons/player2/helpers/config/Player2WebEndpointConfig.gd:28`

**Step 1: Add user_data endpoint to local config**

In `Player2LocalEndpointConfig.gd`, add after line 20 (`webapi_login`):

```gdscript
@export var user_data : String = "{root}/v1/games/{game_id}/data/user"
```

**Step 2: Add user_data endpoint to web config**

In `Player2WebEndpointConfig.gd`, add after line 28 (`endpoint_check`):

```gdscript
@export var user_data : String = "{root}/v1/games/{game_id}/data/user"
```

**Step 3: Commit**

```bash
git add addons/player2/helpers/config/Player2LocalEndpointConfig.gd addons/player2/helpers/config/Player2WebEndpointConfig.gd
git commit -m "feat: add user_data endpoint to config"
```

---

### Task 2: Create Player2Data Helper Class

**Files:**
- Create: `addons/player2/helpers/data_helper.gd`

**Step 1: Create the data_helper.gd file**

```gdscript
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
func get(key: String, on_complete: Callable, on_fail: Callable = Callable()) -> void:
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
func set(key: String, value: Variant, on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void:
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
```

**Step 2: Commit**

```bash
git add addons/player2/helpers/data_helper.gd
git commit -m "feat: add Player2Data helper class"
```

---

### Task 3: Add _req_with_game_id to api.gd

**Files:**
- Modify: `addons/player2/helpers/api.gd`

**Step 1: Add the _req_with_game_id method**

Add after the `_req_stream` method (around line 294), before `_prereq_auth`:

```gdscript
## Like _req but replaces {game_id} in the path with the client_id
func _req_with_game_id(path_property: String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body: Variant = "", on_completed: Callable = Callable(), on_fail: Callable = Callable()):
	var game_id = ProjectSettings.get_setting("player2/client_id", "")
	if game_id.is_empty():
		var msg = "No client id defined. Cannot make game data request."
		Player2ErrorHelper.send_error(msg)
		if on_fail.is_valid():
			on_fail.call(msg, -2)
		return

	var api := Player2APIConfig.grab()
	var use_web = using_web()
	var endpoint = api.endpoint_web if use_web else api.endpoint_local

	# Get the raw path and replace game_id
	var path: String = endpoint.get(path_property)
	if path:
		path = path.replace("{root}", endpoint.get("root"))
		path = path.replace("{game_id}", game_id)

	print("hitting path (with game_id) ", path)

	var on_auth_ready = func(run_again):
		Player2WebHelper.request(
			path,
			method,
			body,
			_get_headers(use_web),
			func(response_body, code, headers):
				if !_code_success(code):
					if use_web and code == 401:
						if _internal_site:
							Player2ErrorHelper.send_error("Got Unauthorized response. Try refreshing the page!")
							return
						print("Unauthorized response. Resetting key and trying to re-auth.")
						Player2ErrorHelper.send_error("Got Unauthorized while doing web requests, redoing auth.")
						_web_p2_key = ""
						run_again.call()
						return
					_alert_error_fail(code, false, response_body)
					if on_fail.is_valid():
						on_fail.call(response_body, code)
					return
				if on_completed.is_valid():
					var result = JSON.parse_string(response_body)
					on_completed.call(result if result else response_body)
				request_success.emit(path_property),
			func(response_body, code):
				if code != HTTPRequest.RESULT_SUCCESS:
					if use_web:
						_last_web_present = false
					else:
						_last_local_present = false
					if !_last_local_present and !_last_web_present:
						_source_tested = false
						print("Source got unset. Trying to find again...")
						Player2AsyncHelper.call_timeout(run_again, 3)
				else:
					_last_web_present = true
				_alert_error_fail(code, true)
				if on_fail.is_valid():
					on_fail.call("", code)
		)

	_prereq_auth(on_auth_ready, on_fail)
```

**Step 2: Commit**

```bash
git add addons/player2/helpers/api.gd
git commit -m "feat: add _req_with_game_id method for data endpoints"
```

---

### Task 4: Expose Data Property on Player2API

**Files:**
- Modify: `addons/player2/helpers/api.gd`

**Step 1: Add Data property declaration**

Add at the top of `api.gd`, after line 24 (`var _internal_site : bool = false`):

```gdscript
## User game data persistence. Access via Player2API.Data.get(), .set(), .delete()
var Data: Player2Data
```

**Step 2: Initialize Data in _ready()**

In the `_ready()` function, add as the first line inside the function (after line 716):

```gdscript
	Data = Player2Data.new(self)
```

**Step 3: Commit**

```bash
git add addons/player2/helpers/api.gd
git commit -m "feat: expose Data property on Player2API"
```

---

### Task 5: Add Documentation to README

**Files:**
- Modify: `README.md`

**Step 1: Add User Data section**

Add after the "Web API Configuration" section (after line 124):

```markdown

## User Data Storage

The plugin provides cloud-based user data storage for saving player progress, inventory, achievements, and other game state.

### Basic Usage

```gdscript
# Save player data (auto-serialized to JSON)
Player2API.Data.set("inventory", {"sword": 1, "shield": 2, "potions": 5}, func():
    print("Inventory saved!")
)

# Load player data (auto-deserialized from JSON)
Player2API.Data.get("inventory", func(value):
    if value:
        print("Loaded inventory: ", value)
    else:
        print("No saved inventory found")
)

# Delete a specific key
Player2API.Data.delete("old_save", func():
    print("Old save deleted!")
)

# Clear all user data (useful for "reset progress" feature)
Player2API.Data.delete_all(func():
    print("All progress reset!")
)
```

### Error Handling

All methods accept an optional `on_fail` callback:

```gdscript
Player2API.Data.get("progress",
    func(value):
        print("Got progress: ", value),
    func(error_msg, error_code):
        if error_code == 404:
            print("No save data yet - new player!")
        else:
            print("Error: ", error_msg)
)
```

### Storage Limits

- **4 MB** quota per user per game
- Data is stored as JSON strings
- Requires user authentication via Player2 app
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add User Data Storage section to README"
```

---

### Task 6: Manual Testing

**Files:**
- Reference: `dev_scenes/simple_chat/simple_chat.tscn`

**Step 1: Create a test script**

Temporarily add to any scene's `_ready()` to test:

```gdscript
func _ready():
    # Test set
    Player2API.Data.set("test_key", {"level": 1, "name": "Test"}, func():
        print("SET SUCCESS")
        # Test get
        Player2API.Data.get("test_key", func(value):
            print("GET SUCCESS: ", value)
            # Test delete
            Player2API.Data.delete("test_key", func():
                print("DELETE SUCCESS")
                # Verify deletion
                Player2API.Data.get("test_key", func(v):
                    print("Should be null: ", v),
                func(msg, code):
                    print("Expected 404: ", code)
                )
            )
        )
    )
```

**Step 2: Run the project and verify output**

Expected console output:
```
SET SUCCESS
GET SUCCESS: { "level": 1, "name": "Test" }
DELETE SUCCESS
Expected 404: 404
```

**Step 3: Remove test code and commit final state**

```bash
git add -A
git commit -m "feat: complete Player2API.Data implementation"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add endpoint config | 2 config files |
| 2 | Create Player2Data class | 1 new file |
| 3 | Add _req_with_game_id | api.gd |
| 4 | Expose Data property | api.gd |
| 5 | Add README docs | README.md |
| 6 | Manual testing | - |

**Total estimated time:** 20-30 minutes
