@tool
class_name Player2APIConfig
extends Resource

@export_group("Error handling", "error")
@export var error_log_ui : bool = true

@export_group("Endpoints", "endpoint")
@export var endpoint_web : Player2WebEndpointConfig = Player2WebEndpointConfig.new()
@export var endpoint_local : Player2LocalEndpointConfig = Player2LocalEndpointConfig.new()

@export_group("Request Delay")
@export var request_too_much_delay_seconds : float = 3

static func grab() -> Player2APIConfig:
	return ProjectSettings.get("player2/api") as Player2APIConfig

func _property_can_revert(property: StringName) -> bool:
	return property == "endpoint_web" or property == "endpoint_local"

func _property_get_revert(property: StringName) -> Variant:
	if property == "endpoint_web":
		return Player2WebEndpointConfig.new()
	if property == "endpoint_local":
		return Player2LocalEndpointConfig.new()
	return null
