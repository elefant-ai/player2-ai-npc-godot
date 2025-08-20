extends Node

# An override to opening up verification in the browser
# Can add a custom UI or popup that prompts the user to continue
signal open_verification_window(verificationUrl : String)
var run_browser_verification_default : bool = true

# Sent if the user cancels verification locally, to stop doing any kind of checking
signal auth_cancelled

# Call this if you wish to cancel the auth sequence and deny the web API
func cancel_auth() -> void:
	auth_cancelled.emit()

func _run_auth_verification(verification_url : String) -> void:
	print("RUNNING AUTH VERIFICATION")
	open_verification_window.emit(verification_url)
	if run_browser_verification_default:
		# TODO: Prompt with some defaults or something?
		OS.shell_open(verification_url)
