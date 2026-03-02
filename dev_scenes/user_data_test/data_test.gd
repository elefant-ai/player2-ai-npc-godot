extends Node2D

@export var run_on_ready := false

@onready var status_label: Label = $StatusLabel
@onready var set_btn: Button = $SetBtn
@onready var get_btn: Button = $GetBtn
@onready var delete_btn: Button = $DeleteBtn
@onready var delete_all_btn: Button = $DeleteAllBtn

var test_key := "test_save"
var test_data := {"level": 5, "coins": 100, "inventory": ["sword", "shield"]}


func _ready() -> void:
	# Force local API for testing (until web API has data endpoints)
	var api = Player2APIConfig.grab()
	api.source_mode = Player2APIConfig.SourceMode.LOCAL_ONLY

	set_btn.pressed.connect(_on_set_pressed)
	get_btn.pressed.connect(_on_get_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	delete_all_btn.pressed.connect(_on_delete_all_pressed)


func _log(msg: String) -> void:
	print("[DataTest] ", msg)
	status_label.text = msg


func _on_set_pressed() -> void:
	_log("Setting data...")
	Player2API.Data.set_value(test_key, test_data,
		func():
			_log("SET SUCCESS: " + JSON.stringify(test_data)),
		func(error_msg, error_code):
			_log("SET FAILED: " + error_msg + " (code: " + str(error_code) + ")")
	)


func _on_get_pressed() -> void:
	_log("Getting data...")
	Player2API.Data.get_value(test_key,
		func(value):
			if value:
				_log("GET SUCCESS: " + JSON.stringify(value))
			else:
				_log("GET SUCCESS: null (no data)"),
		func(error_msg, error_code):
			_log("GET FAILED: " + error_msg + " (code: " + str(error_code) + ")")
	)


func _on_delete_pressed() -> void:
	_log("Deleting key...")
	Player2API.Data.delete(test_key,
		func():
			_log("DELETE SUCCESS"),
		func(error_msg, error_code):
			_log("DELETE FAILED: " + error_msg + " (code: " + str(error_code) + ")")
	)


func _on_delete_all_pressed() -> void:
	_log("Deleting all data...")
	Player2API.Data.delete_all(
		func():
			_log("DELETE ALL SUCCESS"),
		func(error_msg, error_code):
			_log("DELETE ALL FAILED: " + error_msg + " (code: " + str(error_code) + ")")
	)


func _run_full_test() -> void:
	_log("Running full test...")
	Player2API.Data.set_value(test_key, test_data,
		func():
			_log("SET SUCCESS")
			Player2API.Data.get_value(test_key,
				func(value):
					_log("GET SUCCESS: " + JSON.stringify(value))
					Player2API.Data.delete(test_key,
						func():
							_log("DELETE SUCCESS")
							Player2API.Data.get_value(test_key,
								func(v):
									_log("After delete GET: " + str(v)),
								func(msg, code):
									_log("After delete - expected error: " + str(code))
							),
						func(msg, code):
							_log("DELETE FAILED: " + msg)
					),
				func(msg, code):
					_log("GET FAILED: " + msg)
			),
		func(msg, code):
			_log("SET FAILED: " + msg)
	)
