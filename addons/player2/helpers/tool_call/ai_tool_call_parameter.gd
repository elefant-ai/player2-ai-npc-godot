class_name AIToolCallParameter
extends Resource

# TODO: This is a bad design, just use godot signals
# support only these parameters...
# and have the descriptions provided, maybe override a list of functions or something?

# 
enum Type {STRING, NUMBER, INTEGER, BOOLEAN, ENUM}
@export var name : String
@export var type : Type
@export var description : String
@export var enum_list : Array[String] 

static func arg_type_to_schema_type(t : Type) -> String:
	return Type.find_key(t).to_lower()
