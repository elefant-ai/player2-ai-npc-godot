@tool
class_name ToolcallFunctionDefinitions
extends Resource

@export var definitions : Array[ToolcallFunctionDefinition]

func _validate_property(property: Dictionary) -> void:
	if property.name == "definitions":
		property.usage = PROPERTY_USAGE_STORAGE
	if property.name == "Resource" or property.name == "resource_path" or property.name == "resource_name" or property.name == "resource_local_to_scene":
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _get_property_list():
	var result : Array = []
	if definitions:
		var i = 0
		for def in definitions:
			var key = "Def_" + str(i)
			#var usage = PROPERTY_USAGE_DEFAULT
			
			var usage = PROPERTY_USAGE_DEFAULT

			result.append({
				name = def.name,
				type = TYPE_OBJECT,
				#hint_string = "Def_" + str(i),
				usage = usage
			})
			i += 1
	return result


func _get(property : StringName):
	#print("GET " + property)
	if definitions:
		for d in definitions:
			if property == d.name:
				return d# if d.enabled else null
