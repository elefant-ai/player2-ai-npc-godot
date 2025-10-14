extends Node

@export var expressions : Dictionary[String, Texture2D]
@export var texture : TextureRect

@export var current_expression : String

@export var tween_bounce_yoffs : float = 10

func _ready() -> void:
	if not current_expression or current_expression.is_empty() and expressions.size() > 0:
		set_expression(expressions.keys()[0])

## Get a list of all expressions available to use.
func get_expressions() -> Array:
	return expressions.keys()

## Gets the current expression.
func get_current_expression() -> String:
	return current_expression

## Sets our current expression.
func set_expression(expression : String):
	if not expressions.has(expression):
		return "Invalid expression: " + expression + ". Valid expressions are " + ",".join(PackedStringArray(expressions.keys()))
	if expression and current_expression != expression:
		var result : Texture2D = expressions.get(expression)
		texture.texture = result
		current_expression = expression
		# Tween
		var p = texture.position
		p.y -= tween_bounce_yoffs
		texture.create_tween().tween_property(texture, "position", p, 0.4).set_trans(Tween.TRANS_BACK)
		current_expression = expression
