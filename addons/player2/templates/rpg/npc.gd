@tool
extends Player2RPGEntity

@export_group("AI", "ai")
@export var ai_name : String
@export_multiline var ai_description : String
@export var save_conversation_history : bool = true

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	$Player2AINPC.character_name = name
	$Player2AINPC.character_description = ai_description
	$Player2AINPC.auto_store_conversation_history = save_conversation_history
	if save_conversation_history:
		$Player2AINPC.load_conversation_history()
