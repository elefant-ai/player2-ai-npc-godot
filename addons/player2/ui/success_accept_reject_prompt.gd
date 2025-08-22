class_name Player2SuccessAcceptRejectPrompt
extends Player2AcceptRejectPrompt

signal succeeded

func succeed():
	succeeded.emit()
