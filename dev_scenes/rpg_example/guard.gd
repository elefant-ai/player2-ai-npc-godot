extends Entity

@export var patrol_path : Path2D
@export var hear_zone : Area2D
@export var player_in_cell_zone : Area2D
@export var ai_brain : Player2AINPC
@export var start_talk_timeout : float
@export var talk_timeout : Vector2
@export var player_talk_point : Node2D
@export var door_point : Node2D
@export var door : Node2D

enum State {PATROL, STAND_BY_PRISONER_GATE, FREE_PRISONER}

var state : State = State.PATROL
var state_string : String:
	get:
		return State.find_key(state)

var _patrol_index : int = -1
var _force_stay_at_patrol_point : Node2D = null

var _was_at_target_point : bool = false

var _talk_timer : float = -1

func _set_state(target : State) -> String:
	if state == target:
		return "Already in state " + str(target) + "! Had no effect."
	state = target
	return ""

## Stop talking to the prisoner and go back to your job patrolling.
func leave_prisoner() -> String:
	return _set_state(State.PATROL)

## Go walk up to the prisoner gate. If the prisoner is inside the cell, this is the only way to hear them.
func go_to_prisoner_gate() -> String:
	return _set_state(State.STAND_BY_PRISONER_GATE)

## Unlock the door for the prisoner
func unlock_prisoner_door() -> String:
	return _set_state(State.FREE_PRISONER)

func _process_patrol() -> void:

	var target_pos : Vector2

	if _force_stay_at_patrol_point:
		_patrol_index = -1
		target_pos = _force_stay_at_patrol_point.global_position
	else:
		if _patrol_index == -1:
			# find nearest point
			_patrol_index = 0
			var closest_point_distance = (patrol_path.global_position + patrol_path.curve.get_point_position(0)).distance_to(position)
			for ind in range(patrol_path.curve.point_count):
				var pd =  (patrol_path.global_position + patrol_path.curve.get_point_position(ind)).distance_to(position)
				if pd < closest_point_distance:
					closest_point_distance = pd
					_patrol_index = ind
		target_pos = patrol_path.global_position + patrol_path.curve.get_point_position(_patrol_index)

	# move towards that point
	var delta = (target_pos - position)

	move_input = Vector2.ZERO

	if delta.length() < 1:
		var just_hit = !_was_at_target_point
		_was_at_target_point = true
		# first touch
		if _force_stay_at_patrol_point:
			if just_hit:
				if _force_stay_at_patrol_point == player_talk_point:
					ai_brain.notify("You are now close enough to the prisoner to hear them...")
				if _force_stay_at_patrol_point == door_point:
					# Unlock the door
					door.queue_free()
					ai_brain.notify("You just unlocked the door for the prisoner!")
		else:
			_patrol_index += 1
			if _patrol_index >= patrol_path.curve.point_count:
				_patrol_index = 0
		return

	_was_at_target_point = false

	move_input = delta.normalized()

## Called when the player talks in general (not a tool call)
func player_talked(message : String) -> void:

	if not player_in_cell_zone.has_overlapping_areas():
		print("yeah")
		# Player has left the cell, you can always hear.
		ai_brain.chat(message, "Prisoner")
		return

	if !hear_zone.overlaps_body(self):
		ai_brain.notify("You hear a sound coming from the prison window catching your attention, it sounds like the prisoner is talking... You want to hear what the prisoner has to say.")
	else:
		ai_brain.chat(message, "Prisoner")

func _process_idle_talk(delta : float) -> void:
	# If we're thinking, don't do a timer/timeout.
	if ai_brain and ai_brain.thinking:
		return

	# Randomly talk
	_talk_timer -= delta
	if _talk_timer <= 0:
		_reset_talk_timer()
		# Only bump if we're not thinking, to avoid queueing up too much.
		if !ai_brain.thinking:
			ai_brain.notify("Some time has passed.")

func _ready() -> void:
	_talk_timer = start_talk_timeout
	# Reset the talk timer if we recently received a chat
	ai_brain.chat_received.connect(func(a):
			_reset_talk_timer())

func _process(delta: float) -> void:
	super._process(delta)

	match state:
		State.PATROL:
			# Dont force a patrol point
			_force_stay_at_patrol_point = null
			_process_idle_talk(delta)
		State.STAND_BY_PRISONER_GATE:
			_force_stay_at_patrol_point = player_talk_point
		State.FREE_PRISONER:
			_force_stay_at_patrol_point = door_point
			_process_idle_talk(delta)

	_process_patrol()

func _reset_talk_timer() -> void:
	_talk_timer = randf_range(talk_timeout.x, talk_timeout.y)
