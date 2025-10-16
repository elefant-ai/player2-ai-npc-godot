@tool
## AI Image Slop generation using the Player2 API.
## Option to cache images to reduce cost and introduce repeatability.
class_name Player2AIImageGeneration
extends Node

## Base prompt that prefixes the user image generation prompt.
@export_multiline var base_prompt : String = "Generate an image based on the following prompt:\n{prompt}"
## Width [128, 1024] of the generated image. Keep this low to increase speed and reduce cost.
@export_range(128, 1024) var width : int = 128
## Height [128, 1024] of the generated image. Keep this low to increase speed and reduce cost.
@export_range(128, 1024) var height : int = 128
## Keeping this on might save a few trees in the amazon rainforest. Maybe not.
@export var cache : bool = true

signal generation_succeeded(image : Image)
signal generation_failed(body : String, error_code : int)

class QueuedMessage:
	var base_prompt : String
	var prompt : String
	var width : int
	var height : int
	var cache : bool

# Lets make sure we don't overdo this.
static var _generating_image :  bool = false
static var _queue : Array[QueuedMessage]

# Image functions in order.
# For some reason the API returns jpeg but this will support png in the future, although it will have errors.
# If users report errors just shift this around.
static var _image_parse_functions = [
	"load_jpg_from_buffer",
	"load_png_from_buffer",
	"load_webp_from_buffer",
	# These require some kind of Godot support, don't call em
	#"load_svg_from_buffer",
	#"load_tga_from_buffer",
]

# Given base 64 of any type really, parse it
func _parse_base64_to_image(img : Image, image_b64 : String) -> Error:
	# Remove b64 header
	var first_comma := image_b64.find(",")
	if first_comma != -1:
		image_b64 = image_b64.substr(first_comma + 1)

	var raw_bytes := Marshalls.base64_to_raw(image_b64)

	var error : Error = ERR_BUG # bug because in theory user should never see this
	for parse_func_name in _image_parse_functions:
		error = img.call(parse_func_name, raw_bytes)
		if error == OK:
			break
	return error

static func _get_key_file(full_prompt : String, width : int, height : int) -> String:
	var hash := hash([full_prompt, width, height])
	return "user://image_gen_cache#" + str(hash)

## Generate an image using Player2 API.
## Costly operation, will use a lot of credits. Use sparingly.
func generate_image(prompt : String) -> void:
	var message := QueuedMessage.new()
	message.base_prompt = base_prompt
	message.prompt = prompt
	message.width = width
	message.height = height
	message.cache = cache
	_queue.push_back(message)

func _process(delta: float) -> void:
	# Queue
	if _generating_image:
		return
	var msg := _queue.pop_front()
	if !msg:
		return
	_generating_image = true

	var full_prompt = msg.base_prompt.replace("{prompt}", msg.prompt)

	# Cached key for this generation request
	var file_key := _get_key_file(full_prompt, msg.width, msg.height)

	var use_cache = msg.cache

	if use_cache:
		# Cache this prompt in case if it happens often
		if FileAccess.file_exists(file_key):
			var file = FileAccess.open(file_key, FileAccess.READ)
			var image_b64 := file.get_as_text()
			file.close()
			var img := Image.new()
			var error := _parse_base64_to_image(img, image_b64)
			if error == OK:
				print("Got generated image from cache, avoiding generation.")
				generation_succeeded.emit(img)
				_generating_image = false
				return
			else:
				# Cache failed
				print("cache failed. Regenerating.")
				DirAccess.remove_absolute(file_key)

	print("Calling image generation API: ", full_prompt)
	var req := Player2Schema.ImageGenerateRequest.new()
	req.width = msg.width
	req.height = msg.height
	req.prompt = full_prompt
	Player2API.image_generate(req,
		func(result):
			var image_b64 : String = result["image"]
			var img := Image.new()

			var error := _parse_base64_to_image(img, image_b64)

			if error == OK:
				generation_succeeded.emit(img)
				if use_cache:
					print("(caching image gen result)")
					var file = FileAccess.open(file_key, FileAccess.WRITE)
					file.store_string(image_b64)
					file.close()
			else:
				generation_failed.emit("Failed to parse raw bytes from generated image. Internal Error code " + str(error), error)
			_generating_image = false
			,
		func(body, code):
			_generating_image = false
			generation_failed.emit(body, code)
	)
