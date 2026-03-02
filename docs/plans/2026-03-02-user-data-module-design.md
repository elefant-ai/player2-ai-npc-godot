# Player2 User Data Module Design

## Overview

Add a `Player2API.Data` module for persisting user game data (player saves, progress, inventory) via the Player2 cloud API.

## Requirements

- **Use case**: Player save data (user-scoped storage)
- **API style**: Property on Player2API autoload (`Player2API.Data.<method>`)
- **Serialization**: Auto-serialize Variants to/from JSON
- **Operations**: Single-key only (get, set, delete, delete_all)
- **Scope**: User-scoped data only (not global)

## API Endpoints

From OpenAPI spec at `localhost:4315/v1/openapi.json`:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/games/{game_id}/data/user?key={key}` | Get single key-value |
| PUT | `/games/{game_id}/data/user` | Set key-value (body: `{key, value}`) |
| DELETE | `/games/{game_id}/data/user?key={key}` | Delete single key |
| DELETE | `/games/{game_id}/data/user` | Delete all keys |

**Constraints**:
- 4 MB quota per user per game
- Values are strings (we serialize to JSON)
- Requires authentication via Player2 app

## Architecture

### New File: `helpers/data_helper.gd`

```gdscript
class_name Player2Data
extends RefCounted

var _api: Node  # Reference to Player2API for _req()

func _init(api: Node) -> void:
    _api = api

func _get_game_id() -> String:
    return ProjectSettings.get_setting("player2/client_id", "")

## Get a value by key. Value is auto-deserialized from JSON.
## on_complete receives the deserialized Variant (or null if value was "null")
## on_fail receives (error_message: String, error_code: int)
func get(key: String, on_complete: Callable, on_fail: Callable = Callable()) -> void

## Set a value by key. Value is auto-serialized to JSON string.
## on_complete receives no arguments (called on success)
## on_fail receives (error_message: String, error_code: int)
func set(key: String, value: Variant, on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void

## Delete a single key.
## on_complete receives no arguments (called on success)
## on_fail receives (error_message: String, error_code: int)
func delete(key: String, on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void

## Delete all user data for this game.
## on_complete receives no arguments (called on success)
## on_fail receives (error_message: String, error_code: int)
func delete_all(on_complete: Callable = Callable(), on_fail: Callable = Callable()) -> void
```

### Endpoint Config Changes

Add to `Player2LocalEndpointConfig.gd`:
```gdscript
@export var user_data: String = "{root}/v1/games/{game_id}/data/user"
```

Add to `Player2WebEndpointConfig.gd`:
```gdscript
@export var user_data: String = "{root}/v1/games/{game_id}/data/user"
```

### api.gd Changes

```gdscript
# Add property
var Data: Player2Data

# In _ready(), after existing setup:
func _ready() -> void:
    Data = Player2Data.new(self)
    # ... existing code
```

## Usage Examples

```gdscript
# Save player progress
Player2API.Data.set("progress", {"level": 5, "score": 1200}, func():
    print("Progress saved!")
, func(msg, code):
    print("Failed to save: ", msg)
)

# Load player progress
Player2API.Data.get("progress", func(value):
    if value:
        print("Level: ", value.level)
        print("Score: ", value.score)
    else:
        print("No save data found")
, func(msg, code):
    if code == 404:
        print("Key not found - new player")
    else:
        print("Error loading: ", msg)
)

# Delete a specific key
Player2API.Data.delete("old_save", func():
    print("Deleted old save")
)

# Clear all user data (e.g., "reset progress" feature)
Player2API.Data.delete_all(func():
    print("All data cleared!")
)
```

## Error Handling

| HTTP Code | Meaning | Handling |
|-----------|---------|----------|
| 200 | Success | Call `on_complete` |
| 401 | Unauthenticated | Handled by `_req()` - triggers auth flow |
| 404 | Key not found | Call `on_fail` with message |
| 409 | Quota exceeded | Call `on_fail` with quota details |
| 429 | Rate limited | Handled by `_req()` retry logic |

## Implementation Notes

1. **Game ID**: Uses `player2/client_id` project setting (same as other API calls)
2. **Path building**: Replace `{game_id}` placeholder before calling `_req()`
3. **Serialization**: Use `JSON.stringify()` for set, `JSON.parse_string()` for get
4. **RefCounted**: Use RefCounted base (not Node) since it doesn't need scene tree

## Documentation Updates

Add section to README.md:
- Setup requirements
- Basic usage examples
- Error handling patterns
- Storage limits (4 MB per user per game)

## Files to Create/Modify

| File | Action |
|------|--------|
| `helpers/data_helper.gd` | Create |
| `helpers/config/Player2LocalEndpointConfig.gd` | Add `user_data` export |
| `helpers/config/Player2WebEndpointConfig.gd` | Add `user_data` export |
| `helpers/api.gd` | Add `Data` property, initialize in `_ready()` |
| `README.md` | Add User Data documentation section |
