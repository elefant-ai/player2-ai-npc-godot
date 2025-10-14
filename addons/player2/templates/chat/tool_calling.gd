extends Node

# This script is attached to a node that is scanned in the Chat Template.
# When scanned, every public function will be referenced for tool calling.
# For best results, only have functions you want the AI to access in one script file.
# Attach that script file to an empty node and include that node in the Agent's tool call node list.
# Functions will have their doc comments (starting with ##) read and sent to the agent, so be consise and descriptive!

## Logs "Hello World!" to the console.
func console_log_hello_world():
	print("Hello World!")

## Make the background of the user's input field quickly flash
## black and then go back to normal. Notifies caller when one blink is successful.
func blink() -> String:
	print("blinked!")
	var blink_background : Panel = $"../Simple Interface"
	var c = blink_background.modulate
	blink_background.modulate = Color.BLACK
	blink_background.create_tween().tween_property(blink_background, "modulate", c, 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1).timeout
	print("done.")
	return "Finished blinking."


## Gets the time in full string format (YYYY-MM-DDTHH:MM:SS).
func get_current_time():
	return Time.get_datetime_string_from_system()
