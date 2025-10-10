extends Label

var _labels := ["", ".", "..", "..."]
var _label_index := 0

func _ready() -> void:
	_label_index = -1
	inc_count()

func inc_count():
	_label_index += 1
	if _label_index >= _labels.size():
		_label_index = 0
	text = _labels[_label_index]
