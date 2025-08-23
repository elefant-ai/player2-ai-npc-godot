extends Node

## Sent if the user cancels verification locally, to stop doing any kind of checking
signal auth_user_cancelled

var auth_cancelled : bool

var _ui_prompt : Player2AcceptRejectPrompt

# Call this if you wish to cancel the auth sequence and deny the web API
func cancel_auth() -> void:

	if _ui_prompt:
		_ui_prompt.queue_free()
		_ui_prompt = null

	if !auth_cancelled:
		auth_cancelled = true
		auth_user_cancelled.emit()

## Return a callable to call when verification is complete
func _run_auth_verification(verification_url : String) -> Callable:

	auth_cancelled = false

	var open_link = func():
		OS.shell_open(verification_url)

	var on_finish = func():
		# We successfully verified
		if _ui_prompt is Player2SuccessAcceptRejectPrompt:
			# Notify that we succeeded
			(_ui_prompt as Player2SuccessAcceptRejectPrompt).succeed()
		else:
			# Just close
			_ui_prompt.queue_free()
		pass

	print("RUNNING AUTH VERIFICATION")

	var api := Player2APIConfig.grab()
	
	if !api.ui_web_auth_prompt:
		# No ui, just open the link normally.
		open_link.call()
	else:
		# UI found!
		_ui_prompt = api.ui_web_auth_prompt.instantiate()
		add_child(_ui_prompt)
		if _ui_prompt is not Player2AcceptRejectPrompt:
			printerr("API ui_web_auth_prompt is not a Player2AcceptRejectPrompt. Please have the right type.")
			_ui_prompt.queue_free()
			open_link.call()
			return on_finish

		var prompt : Player2AcceptRejectPrompt = _ui_prompt
		prompt.accepted.connect(
			func():
				# Open the link, that's it.
				open_link.call()
		)
		prompt.rejected.connect(
			func():
				# Cancel auth
				cancel_auth()
		)

	return on_finish
