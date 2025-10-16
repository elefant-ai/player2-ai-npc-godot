@tool
class_name Player2RPGEntity
extends CharacterBody2D

@export_group("Sprite", "sprite")
@export var sprite_texture : Texture2D
@export var sprite_scale : float = 1

@export_group("Sprite Bounce", "sprite_bounce")
@export var sprite_bounce_root: Node2D
@export var sprite_bounce_scale_factor : float = 5
@export var sprite_bounce_speed_factor : float = 0.025
@export var sprite_bounce_target_speed : float = 100
@export var sprite_bounce_curve : Curve
@export var sprite_bounce_angle : float = 10

@export_group("Movement", "move")
@export var move_speed : float = 200
@export var move_speed_accel : float = 5000
@export var move_speed_deaccel : float = 3000
@export var move_speed_anti_accel : float = 10000

var _sprite_bounce_cycle : float = 0

var move_input : Vector2

func _add_accel(val : Vector2, target : Vector2, accel : float, delta : float) -> Vector2:
	var delta_frame := accel * delta
	var offs := target - val
	if offs.length() < delta_frame:
		return target
	return val + offs.normalized() * delta_frame

func _process_move_speed(input : Vector2, delta : float) -> void:
	var v = velocity
	var accelerating = v.dot(input) > 0

	#v = input * move_speed
	#velocity = v
	#return

	if input.length() < 0.01:
		v = _add_accel(v, Vector2.ZERO, move_speed_deaccel, delta)
		velocity = v
		return

	var vel_aligned = v.project(input)
	var vel_side = v - vel_aligned

	var target_v = input * move_speed
	v =\
		_add_accel(vel_aligned, target_v, move_speed_accel if accelerating else move_speed_anti_accel, delta)\
		+ _add_accel(vel_side, Vector2.ZERO, move_speed_deaccel, delta)

	velocity = v

func _process_sprite_bounce(delta : float) -> void:
	var v = velocity
	var sprite_bounce_strength := clampf(v.length() / sprite_bounce_target_speed, 0, 1)
	_sprite_bounce_cycle += v.length() * sprite_bounce_speed_factor * delta

	var sample_t := fmod(_sprite_bounce_cycle, 1.0)
	var bounce_sampled := sprite_bounce_curve.sample_baked(sample_t)
	sprite_bounce_root.position = sprite_bounce_scale_factor * sprite_bounce_strength * Vector2.UP * bounce_sampled

	# Sprite angle
	var sign_flipped = fmod(_sprite_bounce_cycle, 2.0) > 1.0
	var angle = bounce_sampled * sprite_bounce_angle * (-1 if sign_flipped else 1)
	sprite_bounce_root.rotation_degrees = angle

	# Reset on stop (to last point)
	if sprite_bounce_strength <= 0.001:
		_sprite_bounce_cycle -= sample_t

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if $Sprite2D:
		$Sprite2D.texture = sprite_texture
		$Sprite2D.scale.x = sprite_scale
		$Sprite2D.scale.y = sprite_scale

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		if $Sprite2D:
			$Sprite2D.texture = sprite_texture
			$Sprite2D.scale.x = sprite_scale
			$Sprite2D.scale.y = sprite_scale
		return


	# Seems to work fine in process, is smoother.
	# Feel free to move these two back to physics process though.
	_process_move_speed(move_input.limit_length(1), delta)
	move_and_slide()

	_process_sprite_bounce(delta)


#func _physics_process(delta: float) -> void:
	#if Engine.is_editor_hint():
		#return
#
	#_process_move_speed(move_input, delta)
	#move_and_slide()
