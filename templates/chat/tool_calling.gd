extends Node

# This script is attached to a node that is scanned in the Chat Template.
# When scanned, every public function will be referenced for tool calling.
# For best results, only have functions you want the AI to access in one script file.
# Attach that script file to an empty node and include that node in the Agent's tool call node list.
# Functions will have their doc comments (starting with ##) read and sent to the agent, so be consise and descriptive!

## Logs "Hello World!" to the console.
func console_log_hello_world():
	print("Hello World!")

## Logs a custom message to the console
func console_log(message : String):
	print("CONSOLE LOGGING:", message)

## Gets the time in full string format (YYYY-MM-DDTHH:MM:SS).
func get_current_time():
	return Time.get_datetime_string_from_system()
