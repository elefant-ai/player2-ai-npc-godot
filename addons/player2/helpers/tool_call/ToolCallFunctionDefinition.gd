@tool
class_name ToolcallFunctionDefinition
extends Resource

@export var name : String
@export var enabled : bool:
	set(value):
		enabled = value
		notify_property_list_changed()
## Read from the comment above the function
@export_multiline var description : String

func _validate_property(property: Dictionary) -> void:
	if property.name == "name":
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	if property.name == "enabled":
		return
	if enabled:
		if property.name == "description":
			property.usage |= PROPERTY_USAGE_READ_ONLY
			return
	property.usage = PROPERTY_USAGE_NO_EDITOR
	
