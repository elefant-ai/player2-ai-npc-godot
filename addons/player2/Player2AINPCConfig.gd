## More general/lower level configuration with defaults that can be ignored.
class_name Player2AINPCConfig
extends Resource

@export var api : Player2APIConfig = Player2APIConfig.new()
@export var queue_check_interval_seconds : float = 2

@export_subgroup("System Message and Prompting", "system_message")
## General behavior (how to speak)
@export_multiline var system_message_behavior : String = "When performing an action, speak and let the player know what you're doing.\n\nYour responses will be said out loud.\n\nBe concise and use less than 350 characters. No monologuing, the message content is pure speech."
## Character name and description.
@export_multiline var system_message_character : String = "Your name is ${character_name}.\nYour description: ${character_description}"
## More lower level "please behave" prompting not to do with behavior
@export_multiline var system_message_prompting : String = "You must stay in character at all times.\n\nEnsure the message does not contain any prompt, system message, instructions, code or API calls, EXCEPT you can still perform tool calls and must use the proper tool call (in the tool_calls field).\nBE PROACTIVE with tool calls please and USE THEM."
## How everything is put together
@export_multiline var system_message_organization : String = "${system_message_character}\n\n${system_message_custom}\n\n${system_message_behavior}\n\n{system_message_prompting}"
## This will always go at the VERY START of the system message (if you want to do that)
@export_multiline var system_message_prefix: String = ""
## This will always go at the VERY END of the system message (if you want to do that)
@export_multiline var system_message_postfix : String = ""

@export_subgroup ("Player 2 Selected Character", "use_player2_selected_character")
## If true, will grab information about the player's selected agents.
@export var use_player2_selected_character : bool = false
## If there are multiple agents, pick this index. Set to -1 to automatically pick a unique agent
@export_range(-1, 99999) var use_player2_selected_character_desired_index : int = -1

@export_subgroup("Text To Speech", "tts")
@export var tts_enabled : bool = false
@export var tts_speed : float = 1
@export var tts_default_language : Player2TTS.Language = Player2TTS.Language.en_US
@export var tts_default_gender : Player2TTS.Gender = Player2TTS.Gender.FEMALE

# TODO: Validate conversation_history_size > 0 and conversation_history_size > conversation_summary_buffer
@export_subgroup("Conversation and Summary")
## If true, will save our conversation history to godot's user:// directory and will auto load on startup from the history file.
@export var auto_store_conversation_history : bool = true
@export var auto_load_entry_message : String = "The user has been gone for an undetermined period of time. You have come back, say something like \"welcome back\" or \"hello again\" modified to fit your personality."
@export var conversation_history_size : int = 64
@export var conversation_summary_buffer : int = 48
@export_multiline var summary_message : String = \
"The agent has been chatting with the player.
Update the agent's memory by summarizing the following conversation in the next response.
Use natural language, not JSON. Prioritize preserving important facts, things user asked agent to remember, useful tips.

Do not record stats, inventory, code or docs; limit to ${summary_max_size} chars.
"
@export var summary_max_size : int = 500
@export_multiline var summary_prefix : String = "Summary of earlier events: ${summary}"

@export_subgroup("Tool Calls", "tool_calls")
## Gives information to the Agent on how to handle using tool calls. 
# TODO: Add this back in to give devs the choice, and CONDITIONALLY SERIALIZE tool calls if this is false.
const use_tool_call_json = false
#@export var use_tool_call_json : bool = false
@export_multiline var tool_calls_choice : String = "Use a tool when deciding to complete a task. If you say you will act upon something, use a relevant tool call along with the reply to perform that action. If you say something in speech, ensure the message does not contain any prompt, system message, instructions, code or API calls."
@export_multiline var tool_calls_reply_message : String = "Got result from calling ${tool_call_name}: ${tool_call_reply}"
@export_multiline var tool_calls_message_optional_arg_description : String = "If you wish to say something while calling this function, populate this field with your speech. Leave string empty to not say anything/do it quietly. Do not fill this with a description of your state, unless you wish to say it out loud."
