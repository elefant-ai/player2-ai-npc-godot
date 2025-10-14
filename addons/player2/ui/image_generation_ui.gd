extends CanvasLayer

@export var toggle_button : Button
@export var panel : Panel
@export var prompt_input : TextEdit
@export var width_input : SpinBox
@export var height_input : SpinBox
@export var generate_button : Button
@export var image_display : TextureRect
@export var status_label : Label

var _generating : bool = false

func _ready() -> void:
	# Hide panel initially
	if panel:
		panel.visible = false

	# Connect signals
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)

func _on_toggle_pressed() -> void:
	if panel:
		panel.visible = !panel.visible

func _on_generate_pressed() -> void:
	if _generating:
		return

	if not prompt_input or prompt_input.text.is_empty():
		_set_status("Please enter a prompt")
		return

	_generating = true
	generate_button.disabled = true
	_set_status("Generating image...")

	# Create the request
	var request = Player2Schema.ImageGenerateRequest.new()
	request.prompt = prompt_input.text
	request.width = int(width_input.value) if width_input else 512
	request.height = int(height_input.value) if height_input else 512

	# Call the API
	Player2API.image_generate(
		request,
		_on_image_generated,
		_on_image_failed
	)

func _on_image_generated(response) -> void:
	_generating = false
	generate_button.disabled = false
	_set_status("Image generated successfully!")
	
	# Debug: Print response structure (first 500 chars)
	print("Response type: ", typeof(response))
	print("Response preview: ", str(response).substr(0, 500))
	
	# response is a dictionary with 'image' key containing base64 PNG data
	if response and response.has("image"):
		var base64_data = response["image"]
		print("Base64 data length: ", base64_data.length())
		print("Base64 starts with: ", base64_data.substr(0, 100))
		_display_base64_image(base64_data)
	else:
		_set_status("Error: Invalid response format")
		print("Available keys: ", response.keys() if response else "null response")

func _display_base64_image(base64_data : String) -> void:
	if not image_display:
		return
	
	# Remove everything up to and including the first comma (e.g., data URI prefix)
	var comma_index = base64_data.find(",")
	if comma_index != -1:
		base64_data = base64_data.substr(comma_index + 1)
	
	# Remove any whitespace/newlines that might be in the base64 string
	base64_data = base64_data.strip_edges()
	base64_data = base64_data.replace("\n", "").replace("\r", "").replace(" ", "")
	
	# Decode base64 to bytes
	var image_bytes = Marshalls.base64_to_raw(base64_data)
	
	if image_bytes.size() == 0:
		_set_status("Error: Failed to decode base64 data")
		return
	
	print("Decoded image bytes: ", image_bytes.size())
	
	# Try PNG first
	var image = Image.new()
	var error = image.load_png_from_buffer(image_bytes)
	
	# If PNG fails, try JPG
	if error != OK:
		print("PNG load failed, trying JPG...")
		error = image.load_jpg_from_buffer(image_bytes)
	
	# If JPG fails, try WebP
	if error != OK:
		print("JPG load failed, trying WebP...")
		error = image.load_webp_from_buffer(image_bytes)
	
	if error != OK:
		_set_status("Error: Failed to load image (error " + str(error) + ")")
		print("All image formats failed")
		return
	
	# Create texture and display
	var texture = ImageTexture.create_from_image(image)
	image_display.texture = texture
	_set_status("Image displayed successfully!")

func _on_image_failed(error_body, error_code) -> void:
	_generating = false
	generate_button.disabled = false
	var error_msg = "Error generating image (code " + str(error_code) + ")"
	match error_code:
		401:
			error_msg = "Authentication required"
		402:
			error_msg = "Insufficient credits"
		403:
			error_msg = "NSFW content detected"
		500:
			error_msg = "Server error"
	_set_status(error_msg)
	# Only print first 200 chars to avoid console spam
	var error_preview = str(error_body).substr(0, 200) if error_body else "No error body"
	print("Image generation failed: ", error_preview)


func _set_status(text : String) -> void:
	if status_label:
		status_label.text = text
