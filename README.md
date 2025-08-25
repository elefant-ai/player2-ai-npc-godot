# Player 2 AI NPC Plugin for Godot
The Official Player2 AI NPC Plugin for Godot

The Player 2 AI NPC Godot plugin allows developers to easily create AI NPCs in their Godot projects.

The plugin uses free AI APIs from the [player2 App](https://player2.game/)

Just open Player2, and the plugin connects automatically, so you can dive right into building your world instead of wrestling with keys or settings. When your game is ready, we’ll share it with our community of 40,000+ active players eager for AI-driven adventures [on our discord](https://player2.game/discord)

For usage information, visit [our blog](https://blog.player2.game/p/announcing-the-player-2-ai-npc-godot)

## Usage Guide

### Installing the plugin

[The plugin is available in the godot asset library](https://godotengine.org/asset-library/asset/4097)

### Adding the node
First, add a Player 2 AI NPC Node

<img width="751" height="698" alt="image" src="https://github.com/user-attachments/assets/f73b90ea-4919-40a7-8eb6-8a59a9591cf9" />

Then, open the node and modify the description of the agent

<img width="392" height="402" alt="image" src="https://github.com/user-attachments/assets/58afa74c-395a-4e26-b125-1b7c7aeb3430" />

## Talking to the Agent

To talk to the agent, call it's `chat` function. To notify the agent of stimuli from the world, call it's `notify` function.

For example, we have a simple interface example with a `text_sent` signal that is fired when the user types in a chat box and presses enter. This can get hooked into the `chat` function to talk to the agent.

<img width="396" height="124" alt="image" src="https://github.com/user-attachments/assets/e24b8ff1-6111-4ec7-8584-2473c26079e0" />

Hearing back from the agent can be done with the agent's `chat_received` signal. Hook this up to a function that can read the agent's reply.

## TTS and Player 2 Launcher Characters

Access TTS support and the characters from the Player 2 launcher using the Character Config

<img width="389" height="327" alt="image" src="https://github.com/user-attachments/assets/7a76d2b6-e516-4a43-9f04-c4c768069a6f" />

## Tool Calling

First, create a script that contains functions that the agent will call.

<img width="998" height="905" alt="image" src="https://github.com/user-attachments/assets/689e6113-a3ad-447d-ae46-942dda09db24" />

Then, add this script to an empty `Node`.

Then, drag the new node into the `Scan Node for Functions` property in the AI NPC node

<img width="403" height="620" alt="image" src="https://github.com/user-attachments/assets/7ec394c7-cfbd-417f-aa9c-c007a3647e3e" />

You should now see a list of functions with their descriptions below:

<img width="406" height="972" alt="image" src="https://github.com/user-attachments/assets/14cd2090-2c61-4292-ad02-68e0b0569a3a" />

## Manual TTS (Text To Speech)

Use the `Player2TTS` node to use Text To Speech manually.

An audio source output will be automatically created for you, but can be manually set in the node.

## STT (Speech To Text)

Use the `Player2STT` node to easily access Speech To Text

However, in order to do this audio must first be enabled in the godot engine.

Enable audio in godot:

**Project Settings** -> **Audio** -> **Enable Input (turn it on).**

## Client ID

Player2 now supports a Web API that requires NO launcher to access, but does require authentication. Thankfully the Godot plugin handles authentication for you, the only thing you need is your `client_id`.

A backend portal for creating a client_id is in progress, but feel free to DM a staff member [on our discord](https://player2.game/discord) for help getting one.

Populate your client_id under **Project Settings** -> **Player 2** -> **Game Key**

## Web API Configuration

The default behavior of the extension is to search the local API, then default to the web API if no local API is found.

If you wish to force the extension to only use local/web, open up the `addons/player2/api_config.tres` resource file and edit the `API Source Mode` field:
<img width="580" height="989" alt="image" src="https://github.com/user-attachments/assets/df04134a-d4d5-4e38-8fdf-e6d0e54cfaff" />

