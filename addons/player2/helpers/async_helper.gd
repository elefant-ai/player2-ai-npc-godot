extends Node

# lets us "fire and forget" something, totally asynchronous
func run_await_async(call : Callable, on_done : Callable) -> void:
	var a := AsyncRunner.new()
	a.done.connect(func(result):
		on_done.call(result)
		a.queue_free()
	)
	add_child(a)
	a.run(call)
