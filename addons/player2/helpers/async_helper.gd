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

func call_timeout(call : Callable, timeout : float) -> void:
	var t = Timer.new()
	t.autostart = false
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(func():
		call.call()
		t.queue_free())
	add_child(t)
	t.start(timeout)

# call = func(func(complete : bool)) where complete is whether to continue
func call_poll(call : Callable, interval_between_shots : float) -> void:
	call.call(
		# `call` will call this inner function when we're done
		func(should_continue : bool) -> void:
			# We should continue, send another poll.
			if should_continue:
				call_timeout(func(): call_poll(call, interval_between_shots), interval_between_shots)
	)
