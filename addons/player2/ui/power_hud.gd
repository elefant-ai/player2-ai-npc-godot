class_name Player2PowerHud
extends Node

@export_group("Components")
@export var active_root : CanvasItem
@export var color_items : Array[CanvasItem] = []
@export var button : Button

@export_group("Visuals")
@export var colors : Array[Color] = [Color.RED, Color.YELLOW, Color.LIME_GREEN]
@export var thresholds : Array[int] = [20, 100]

@export_group("Behavior")
@export var power_poll_interval : float = 10
@export var request_ignore_power_blacklist : Array[String] = ["health", "get_selected_characters", "auth_start", "auth_poll"]

# singleton boo
static var _instance : Player2PowerHud

class ColorThreshold extends Resource:
	@export var upper_threshold : int
	@export var color : Color
	func _init(upper_threshold : int, color : Color) -> void:
		self.upper_threshold = upper_threshold
		self.color = color

var _power_read_wait_timer : Timer
var _power_read_queued : bool
var _power_read_paused : bool

func _ready() -> void:
	_instance = self

	_power_read_wait_timer = Timer.new()
	_power_read_wait_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_power_read_wait_timer.one_shot = true
	_power_read_wait_timer.autostart = false
	_power_read_wait_timer.timeout.connect(func():
		_power_read_paused = false
	)
	add_child(_power_read_wait_timer)
	_power_read_queued = false
	_power_read_paused = false

	
	var api : Player2APIConfig = Player2APIConfig.grab()
	if button:
		button.pressed.connect(func():
			button.release_focus()
			var url := api.endpoint_webpage.profile_ai_power
			OS.shell_open(url)
		)
	if active_root:
		active_root.hide()

	# If we're in the internal site, do not show power hud.
	if Player2API.using_internal_site():
		print("(not showing power hud, inside internal site)")
		return

	# Poll power
	_check_power_endpoint(func():
		Player2AsyncHelper.call_timeout(_check_power_endpoint, power_poll_interval)
	)

	Player2API.request_success.connect(func(path : String):
			if path == "joules":
				return
			if request_ignore_power_blacklist.find(path) != -1:
				return
			_power_read_queued = true
	)

func _process(delta: float) -> void:
	if _power_read_paused:
		return
	if _power_read_queued:
		_check_power_endpoint()
		_power_read_queued = false
		_power_read_paused = true
		_power_read_wait_timer.start(5)

func _get_power_color(power : int) -> Color:
	for i in range(colors.size()):
		var t = INF if i >= thresholds.size() else thresholds[i]
		if power < t:
			return colors[i]
	return colors[colors.size() - 1]

func _update_ui_power(power : int) -> void:
	if active_root:
		active_root.show()
	if button:
		button.text = str(power)
	var color := _get_power_color(power)
	for c in color_items:
		c.modulate = color

func _check_power_endpoint(on_next : Callable = Callable()) -> void:
	print("Checking player2 power...")
	Player2API.joules(func(data):
		var joules = data["joules"]
		if joules is int or joules is float:
			_update_ui_power(int(joules))
		if on_next:
			on_next.call()
		,
	func(msg, code):
		print("Failed to get power. Doing nothing.")
		if on_next:
			on_next.call()
	)

static func force_refresh_power() -> void:
	if _instance:
		_instance._check_power_endpoint()
