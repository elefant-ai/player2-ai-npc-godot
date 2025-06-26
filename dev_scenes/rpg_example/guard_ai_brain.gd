extends Player2AINPC

@export var hear_zone : Area2D
@export var guard : PhysicsBody2D
@export var door : Node2D

func can_hear_player():
	return hear_zone.overlaps_body(guard)

func get_agent_status():
	var result = ""

	if guard.state_string:
		result += "Your current state: " + guard.state_string + ".\n"

	if hear_zone.overlaps_body(guard):
		result += "you are in range to hear the prisoner talk\n"
	else:
		result += "you are NOT in range to hear the prisoner talk. If you wish to hear what they're saying, stand by their gate first.\n"
	if door and door.visible:
		result += "the prisoner door is locked.\n"
	else:
		result += "the prisoner door is unlocked.\n"
	return result
