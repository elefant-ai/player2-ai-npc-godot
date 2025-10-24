@tool
## AI Image editing using the Player2 API.
## Edit existing images with natural language prompts.
class_name Player2AIImageEdit
extends Node

## Base prompt that prefixes the user image edit prompt.
@export_multiline var base_prompt : String = "Edit the image based on the following instructions:\n{prompt}"

signal edit_succeeded(image : Image)
signal edit_failed(body : String, error_code : int)

class QueuedMessage:
	var base_prompt : String
	var prompt : String
	var image_b64 : String
	var images_b64 : Array[String]

# Lets make sure we don't overdo this.
static var _editing_image :  bool = false
static var _queue : Array[QueuedMessage]

# Map mimetypes to Image loading functions
static var _mimetype_to_loader = {
	"image/jpeg": "load_jpg_from_buffer",
	"image/jpg": "load_jpg_from_buffer",
	"image/png": "load_png_from_buffer",
	"image/webp": "load_webp_from_buffer",
	# Optional support
	#"image/svg+xml": "load_svg_from_buffer",
	#"image/tga": "load_tga_from_buffer",
}

# Parse image using mimetype from API response
func _parse_base64_to_image(img : Image, image_b64 : String, mimetype : String) -> Error:
	# Remove b64 header
	var first_comma := image_b64.find(",")
	if first_comma != -1:
		image_b64 = image_b64.substr(first_comma + 1)

	var raw_bytes := Marshalls.base64_to_raw(image_b64)

	# Use mimetype to select the correct loader
	if !_mimetype_to_loader.has(mimetype):
		printerr("Unsupported mimetype from API: ", mimetype)
		return ERR_FILE_UNRECOGNIZED

	var loader_func = _mimetype_to_loader[mimetype]
	var error = img.call(loader_func, raw_bytes)
	return error

# Convert Image to base64
func _image_to_base64(img : Image) -> String:
	# Save as PNG to get the raw bytes
	var png_bytes := img.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)
	return "data:image/png;base64," + b64

## Edit an image using Player2 API.
## Costly operation, will use a lot of credits. Use sparingly.
## image: The Image to edit
## prompt: The editing instructions
func edit_image(image : Image, prompt : String) -> void:
	var image_b64 := _image_to_base64(image)
	edit_image_base64(image_b64, prompt)

## Edit an image using Player2 API with base64 input.
## Costly operation, will use a lot of credits. Use sparingly.
## image_b64: Base64 encoded image string
## prompt: The editing instructions
func edit_image_base64(image_b64 : String, prompt : String) -> void:
	var message := QueuedMessage.new()
	message.base_prompt = base_prompt
	message.prompt = prompt
	message.image_b64 = image_b64
	_queue.push_back(message)

## Edit/combine multiple images together using Player2 API.
## The API will combine and edit all provided images together based on the prompt.
## Costly operation, will use a lot of credits. Use sparingly.
## images: Array of Images to edit/combine together
## prompt: The editing instructions (e.g., "Combine these images side by side" or "Merge these images")
func edit_images(images : Array[Image], prompt : String) -> void:
	var images_b64 : Array[String] = []
	for img in images:
		images_b64.append(_image_to_base64(img))
	edit_images_base64(images_b64, prompt)

## Edit/combine multiple images together using Player2 API with base64 input.
## The API will combine and edit all provided images together based on the prompt.
## Costly operation, will use a lot of credits. Use sparingly.
## images_b64: Array of base64 encoded image strings
## prompt: The editing instructions (e.g., "Combine these images side by side" or "Merge these images")
func edit_images_base64(images_b64 : Array[String], prompt : String) -> void:
	var message := QueuedMessage.new()
	message.base_prompt = base_prompt
	message.prompt = prompt
	message.images_b64 = images_b64
	_queue.push_back(message)

func _process(delta: float) -> void:
	# Queue
	if _editing_image:
		return
	var msg := _queue.pop_front()
	if !msg:
		return
	_editing_image = true

	var full_prompt = msg.base_prompt.replace("{prompt}", msg.prompt)

	# Determine if single or multiple images
	var is_multi_image = msg.images_b64.size() > 0

	print("Calling image edit API: ", full_prompt)
	var req := Player2Schema.ImageEditRequest.new()

	# Set images based on single or multiple
	if is_multi_image:
		req.images = msg.images_b64
	else:
		req.images = [msg.image_b64]

	req.prompt = full_prompt
	Player2API.image_edit(req,
		func(result):
			var edited_image_b64 : String = result["image"]
			var mimetype : String = result["mimetype"]
			var img := Image.new()

			var error := _parse_base64_to_image(img, edited_image_b64, mimetype)

			if error == OK:
				edit_succeeded.emit(img)
			else:
				edit_failed.emit("Failed to parse raw bytes from edited image. Internal Error code " + str(error), error)
			_editing_image = false
			,
		func(body, code):
			_editing_image = false
			edit_failed.emit(body, code)
	)
