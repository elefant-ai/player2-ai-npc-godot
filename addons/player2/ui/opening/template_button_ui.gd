@tool
extends Node

@export var title : String:
	set(val):
		title = val
		$VBoxContainer/Title.text = title

@export var icon : Texture:
	set(val):
		icon = val
		$VBoxContainer/Icon.texture = val

@export var template_scene : PackedScene
