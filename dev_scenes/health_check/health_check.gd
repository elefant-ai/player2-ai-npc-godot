extends Node2D

@export var run = false 

func _ready() -> void:
	if run:
		Player2API.get_health(
			func(data):
				print("health check passed!!")
				print("got ", JSON.stringify(data))
		,
			func(fail):
				print("health check failed!", fail)
				assert(false)
		)
