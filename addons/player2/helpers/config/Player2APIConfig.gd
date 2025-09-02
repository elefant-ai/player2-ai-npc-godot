@tool
class_name Player2APIConfig
extends Resource

enum SourceMode {
	## Starts with trying to hit the web endpoints. If that fails, tries local.
	WEB_FIRST_THEN_LOCAL,
	## Only uses the web API from the Player2 website.
	WEB_ONLY,
	## Only uses the local API from the Player2 launcher.
	LOCAL_ONLY
}

## IF web client is used and this is set to true, immediately prompt the user to auth
@export var prompt_auth_page_immediately : bool = true

@export_group("API Source", "source")
## Which endpoints to use, local or web? Old behavior is local only.
@export var source_mode : SourceMode = SourceMode.WEB_FIRST_THEN_LOCAL

@export_group("Error handling", "error")
@export var error_log_ui : bool = true

@export_group("Endpoints", "endpoint")
@export var endpoint_web : Player2WebEndpointConfig = Player2WebEndpointConfig.new()
@export var endpoint_local : Player2LocalEndpointConfig = Player2LocalEndpointConfig.new()

@export_group("Timeouts and Delays")
@export var request_timeout : float = 30.0
@export var request_timeout_check_local : float = 1.0
@export var request_timeout_check_web : float = 8.0
@export var request_timeout_local_auth : float = 0.5
@export var retry_delay : float = 3

@export_group("Authentication", "auth")
## If true, the user's auth key will be cached locally after logging in and read
## on startup
@export var auth_key_cache_locally : bool = true

@export_group("UI", "ui")
@export var ui_web_auth_prompt : PackedScene

static var _instance : Player2APIConfig

static func grab() -> Player2APIConfig:
	if !_instance:
		_instance = Player2APISourceHelper.api
		print("GOT SOURCE:", _instance)
		print(_instance.endpoint_web.root)
		if !_instance:
			_instance = Player2APIConfig.new()
	return _instance

func _property_can_revert(property: StringName) -> bool:
	return property == "endpoint_web" or property == "endpoint_local"

func _property_get_revert(property: StringName) -> Variant:
	if property == "endpoint_web":
		return Player2WebEndpointConfig.new()
	if property == "endpoint_local":
		return Player2LocalEndpointConfig.new()
	return null
