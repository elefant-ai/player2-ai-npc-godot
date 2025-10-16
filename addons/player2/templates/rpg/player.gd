@tool
extends Player2RPGEntity

@export var bubble_dialogue : SpeechBubble

func talk(message : String) -> void:
	bubble_dialogue.play(message)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._process(delta)
		return
	move_input = Vector2.RIGHT * Input.get_axis("ui_left", "ui_right") + Vector2.UP * Input.get_axis("ui_down", "ui_up")
	if get_viewport().gui_get_focus_owner():
		move_input = Vector2.ZERO

	super._process(delta)
