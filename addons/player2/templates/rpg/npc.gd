@tool
extends Player2RPGEntity

@export_group("AI", "ai")
@export var ai_name : String = "NPC":
	get:
		return $Player2AINPC.character_name
	set(val):
		if !Engine.is_editor_hint():
			await ready
		$Player2AINPC.character_name = val
@export_multiline var ai_description : String = "An NPC from the town, just an ordinary folk with some stories to tell.":
	get:
		return $Player2AINPC.character_description
	set(val):
		if !Engine.is_editor_hint():
			await ready
		$Player2AINPC.character_description = val
