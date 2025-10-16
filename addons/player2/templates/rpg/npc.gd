@tool
extends Player2RPGEntity

@export_group("AI", "ai")
@export var ai_name : String
@export_multiline var ai_description : String
@export var ai_save_conversation_history : bool = false
@export var ai_character_config : Player2AICharacterConfig = Player2AICharacterConfig.new()

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	$Player2AINPC.character_name = name
	$Player2AINPC.character_description = ai_description
	$Player2AINPC.auto_store_conversation_history = ai_save_conversation_history
	$Player2AINPC.character_config = ai_character_config
	if ai_save_conversation_history:
		$Player2AINPC.load_conversation_history()
