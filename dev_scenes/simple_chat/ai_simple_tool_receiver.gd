extends Node
@export var billboard : Label
@export var blink_background : ColorRect

## Make the background of the user's input field quickly flash
## black and then go back to normal. Notifies caller when one blink is successful.
func blink() -> String:
	print("blinked!")
	var c = blink_background.color
	blink_background.color = Color.BLACK
	blink_background.create_tween().tween_property(blink_background, "color", c, 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1).timeout
	print("done.")
	return "Finished blinking."

## Gets the time in full string format (YYYY-MM-DDTHH:MM:SS).
func get_time() -> String:
	return Time.get_datetime_string_from_system()

## Set the text of a big label at the center of the screen.
## Label keeps this value until announce is called again.
func announce(announcement : String) -> void:
	print("announcing: " + announcement)
	billboard.text = announcement

func set_volume(volume : float) -> void:
	# Testing to make sure that no comments still work
	# currently does nothing
	print("Set volume!")
	print(volume)
