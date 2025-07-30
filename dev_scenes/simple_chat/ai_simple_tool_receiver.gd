extends Node
@export var billboard : Label
@export var blink_background : ColorRect

## Make the background of the user's input field quickly flash
## black and then go back to normal.
func blink() -> void:
	print("blinked!")
	var c = blink_background.color
	blink_background.color = Color.BLACK
	blink_background.create_tween().tween_property(blink_background, "color", c, 0.5).set_trans(Tween.TRANS_SINE)

## Gets the time in full string format (YYYY-MM-DDTHH:MM:SS).
func get_time() -> String:
	return Time.get_datetime_string_from_system()

## Set the text of a big label at the center of the screen.
## Label keeps this value until announce is called again.
func announce(announcement : String) -> void:
	print("announcing: " + announcement)
	billboard.text = announcement

## Sets the game volume
func set_volume(volume : float) -> void:
	print("Set volume!")
	print(volume)
