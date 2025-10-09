class_name Player2EditorUIHelper

static func get_editor_top_bar() -> Control:
	var root : Control = EditorInterface.get_base_control()

	var top_bar = root.find_child("*EditorTitleBar*", true, false)

	return top_bar
