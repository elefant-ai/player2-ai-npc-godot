extends Node

@export var billboard : Label
@export var blink_background : ColorRect

## Blinks the screen
func blink() -> void:
	print("blinked!")
	var c = blink_background.color
	blink_background.color = Color.BLACK
	blink_background.create_tween().tween_property(blink_background, "color", c, 0.5).set_trans(Tween.TRANS_SINE)

## Sets the switch
## Right now it's just on or off.
#func set_switch(state : bool):
	#print("Set switch:")
	#print(state)

## Gets the time in the format YYYY-MM-DDTHH:MM:SS
func get_time() -> String:
	return Time.get_datetime_string_from_system()

## Announces a message by placing it on a billboard
func announce(announcement : String) -> void:
	print("announcing: " + announcement)
	billboard.text = announcement

## Sets the game volume
func set_volume(volume : float) -> void:
	print("Set volume!")
	print(volume)
