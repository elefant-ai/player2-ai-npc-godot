class_name Player2AcceptRejectPrompt
extends Node

signal accepted
signal rejected

func accept():
	accepted.emit()

func reject():
	rejected.emit()
