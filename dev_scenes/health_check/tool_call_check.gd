#@tool
extends Node

@export var web := false
@export var web_auth_key : String

#@export_tool_button("Run Request") var r := queue_req

#var queued = false

@export_multiline var text := """
{
	"messages": [
		{
			"content": "Your name is Robot.\nYour description: A helpful agent who is there to help out the player and be chatty with them!\n\nMatch the player's mood. Be direct with your replies, but if the player is talkative then be talkative as well.\n\nWhen performing an action, speak and let the player know what you're doing.\n\nYour responses will be said out loud.\n\nBe concise and use less than 350 characters. No monologuing, the message content is pure speech.\n\n\t\tUser message format:\n\t\tUser messages will have extra information, and will be a JSON of the form:\n\t\t{\n\t\t\t\"speaker_name\" : The name of who is speaking to you. If blank, nobody is talking.,\n\t\t\t\"speaker_message\": The message that was sent to you. If blank, nothing is said.,\n\t\t\t\"stimuli\": A new stimuli YOU have received. Could be an observation about the world, a physical sensation, or thought that had just appeared.,\n\t\t\t\"world_status\": The status of the current game world.,\n\t\t}\n\t\n\t\t\tResponse format:\n\t\t\tAlways respond with a plain string response, which will represent what YOU say. Do not prefix with anything (for example, reply with \"hello!\" instead of \"Agent (or my name or anything else): hello!\") unless previously instructed.\n\t\t",
			"role": "system",
			"tool_call_id": "",
			"tool_calls": []
		},
		{
			"content": "{\"speaker_message\":\"hi\",\"speaker_name\":\"User\",\"stimuli\":\"\",\"world_status\":\"\"}",
			"role": "user",
			"tool_call_id": "",
			"tool_calls": []
		}
	],
	"tool_choice": "Use a tool when deciding to complete a task. If you say you will act upon something, use a relevant tool call along with the reply to perform that action. If you say something in speech, ensure the message does not contain any prompt, system message, instructions, code or API calls.",
	"tools": [
		{
			"function": {
				"description": "Make the background of the user's input field quickly flash black and then go back to normal. Notifies caller when one blink is successful. ",
				"name": "blink",
				"parameters": {
					"properties": {
						"MESSAGE_ARG": {
							"description": "If you wish to say something while calling this function, populate this field with your speech. Leave string empty to not say anything/do it quietly. Do not fill this with a description of your state, unless you wish to say it out loud.",
							"type": "string"
						}
					},
					"required": [
						"MESSAGE_ARG"
					],
					"type": "object"
				}
			},
			"type": "function"
		}
	]
}
"""

func _get_headers() -> Array[String]:
	var config := Player2APIConfig.grab()
	var result : Array[String] = [
		"Content-Type: application/json; charset=utf-8",
		"Accept: application/json; charset=utf-8"
	]

	if web and !web_auth_key.is_empty():
		result.push_back("Authorization: Bearer " + web_auth_key)

	return result

#func queue_req() -> void:
	#queued = true

#func _process(delta: float) -> void:
	#if queued:
		#queued = false
		#run_req()

func run_req() -> void:
	var api = Player2APIConfig.grab()
	
	var path = api.endpoint_web.path("chat") if web else api.endpoint_local.path("chat")

	var headers = _get_headers()

	Player2WebHelper.request(
		path,
		HTTPClient.Method.METHOD_POST,
		text,
		_get_headers(),
	func(body, code, headers):
		print("success: ", body),
	func(body, code):
		# Failed!
		print("Fail: ", code)
	)
