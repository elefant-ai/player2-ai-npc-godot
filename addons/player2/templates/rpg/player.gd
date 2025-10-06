extends Entity

@export var bubble_dialogue : SpeechBubble

func talk(message : String) -> void:
	bubble_dialogue.play(message)

func _physics_process(delta: float) -> void:
	move_input = Vector2.RIGHT * Input.get_axis("move_left", "move_right") + Vector2.UP * Input.get_axis("move_down", "move_up")
	if get_viewport().gui_get_focus_owner():
		move_input = Vector2.ZERO
	super._physics_process(delta)
