# Player2 AI NPC Plugin for Godot
The Official Player2 AI NPC Plugin for Godot

The Player2 AI NPC Godot plugin allows developers to easily create AI NPCs in their Godot projects.

The plugin uses free AI APIs from the [player2 App](https://player2.game/)

Just open Player2, and the plugin connects automatically, so you can dive right into building your world instead of wrestling with keys or settings. When your game is ready, we’ll share it with our community of 40,000+ active players eager for AI-driven adventures [on our discord](https://player2.game/discord)

## Usage Guide

### Installing the plugin

[Most up to date download is here on github](https://github.com/elefant-ai/player2-ai-npc-godot/archive/refs/heads/main.zip). Feel free to drag and drop only the `addons` folder into your project.

[The plugin is also available in the godot asset library](https://godotengine.org/asset-library/asset/4097)

## Creating your Player2 Project and getting the Client ID

Player2 now supports a Web API that requires NO launcher to access, but does require authentication. Thankfully the Godot plugin handles authentication for you, the only thing you need is your `client_id`.

A backend portal for creating a client_id is present here: https://player2.game/profile/developer

Populate your client_id under **Project Settings** -> **Player2** -> **Game Key**

### Quick start Template

To jump right in with a Chat agent, open `templates/chat/chat_template.tscn` and get started!

<img width="358" height="120" alt="image" src="https://github.com/user-attachments/assets/7653f220-1ed0-4fb4-9f47-f8a7e22571f9" />


### Adding the node
To spawn in an AI NPC agent that can talk and perform actions in the world, add a Player2 AI NPC Node:

<img width="751" height="698" alt="image" src="https://github.com/user-attachments/assets/f73b90ea-4919-40a7-8eb6-8a59a9591cf9" />

Then, open the node and modify the description of the agent

<img width="392" height="402" alt="image" src="https://github.com/user-attachments/assets/58afa74c-395a-4e26-b125-1b7c7aeb3430" />

## Talking to the Agent

An agent chat example can be found under `dev_scenes/simple_chat/simple_chat.tscn`

To talk to the agent, call it's `chat` function. To notify the agent of stimuli from the world, call it's `notify` function.

For example, we have a simple interface example with a `text_sent` signal that is fired when the user types in a chat box and presses enter. This can get hooked into the `chat` function to talk to the agent.

<img width="396" height="124" alt="image" src="https://github.com/user-attachments/assets/e24b8ff1-6111-4ec7-8584-2473c26079e0" />

Hearing back from the agent can be done with the agent's `chat_received` signal. Hook this up to a function that can read the agent's reply.

## Text To Speech and Player2 Launcher Characters

Access TTS support and the characters from the Player2 launcher using the Character Config

<img width="426" height="322" alt="image" src="https://github.com/user-attachments/assets/702e0382-f84f-4c96-b897-c74063cffa88" />

You can set the Voice ID to get a custom voice. [View all voice IDs here](https://api.player2.game/v1/tts/voices)

To have more control over the bot's TTS, you can manually create a `Player2TTS` node and assign it to the agent. However, a default TTS node is populated automatically at runtime.

## Remembering chat history

By default, an agent will remember the previous chat history and greet the player at the start. This can be disabled under the Chat Config:

<img width="414" height="148" alt="image" src="https://github.com/user-attachments/assets/66e2ccac-e1b3-463f-8187-7794cf378959" />

## Tool Calling

First, create a script that contains functions that the agent will call.

<img width="998" height="905" alt="image" src="https://github.com/user-attachments/assets/689e6113-a3ad-447d-ae46-942dda09db24" />

Then, add this script to an empty `Node`.

Then, drag the new node into the `Scan Node for Functions` property in the AI NPC node

<img width="403" height="620" alt="image" src="https://github.com/user-attachments/assets/7ec394c7-cfbd-417f-aa9c-c007a3647e3e" />

You should now see a list of functions with their descriptions below:

<img width="406" height="972" alt="image" src="https://github.com/user-attachments/assets/14cd2090-2c61-4292-ad02-68e0b0569a3a" />

## Simple chat completion

If you wish to simply run AI/LLM chat completion without history, TTS, or agent replies, use the `Player2AIChatCompletion` node.

The interface is similar to the `Player2AINPC` node.

An example can be found under `dev_scenes/simple_completion/simple_completion.tscn`

## Manual TTS (Text To Speech)

Use the `Player2TTS` node to use Text To Speech manually.

An audio source output will be automatically created for you, but can be manually set in the node.

## STT (Speech To Text)

Use the `Player2STT` node to easily access Speech To Text

However, in order to do this audio must first be enabled in the godot engine.

Enable audio in godot:

## Image generation

Use the `Player2AIImageGeneration` node to generate AI images.

Use the `generate_image` function and the `generation_succeeded` signal to receive your generated image.
Use `cache` to avoid hitting the endpoint multiple times for the same image.

An example of generating AI slop can be found under `dev_scenes/slop_gen/slop_gen.tscn`

**Project Settings** -> **Audio** -> **Enable Input (turn it on).**

## Web API Configuration

If you wish to disable the error logging at the top of the screen, customize request timeouts, or customize the authentication UI for the Web API, modify the resource at `addons/player2/api_config.tres`

<img width="356" height="459" alt="image" src="https://github.com/user-attachments/assets/23cd97b5-e01c-4401-8fb8-53208144ff33" />
