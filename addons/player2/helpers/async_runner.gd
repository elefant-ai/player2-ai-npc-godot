class_name AsyncRunner
extends Node

signal done(result : Variant)

func run(call : Callable) -> void:
	var result = await call.call()
	done.emit(result)
