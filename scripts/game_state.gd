extends Node
## Persistent progress (souls, unlocks, skills), settings, input map and shared UI theme.

const Data = preload("res://scripts/data.gd")
const SAVE_PATH := "user://save.cfg"

var souls := 0
var levels_cleared := 0
var unlocked_weapons: Array = ["pistol"]
var skills: Array = []
var skin := "knight_m"
var unlocked_skins: Array = ["knight_m", "knight_f"]
var settings := {"fullscreen": false, "quality": 1, "vsync": true, "volume": 0.8, "shake": true}
var autotest := false
var debug_top := false

var light_tex: GradientTexture2D
var ui_theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	light_tex = _make_light_tex()
	ui_theme = _make_theme()
	load_game()
	apply_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		settings["fullscreen"] = not settings["fullscreen"]
		apply_settings()
		save_game()


func enable_autotest() -> void:
	autotest = true
	unlocked_weapons = Data.WEAPON_ORDER.duplicate()


# --- Stats -------------------------------------------------------------------

func get_stats() -> Dictionary:
	var s := {
		"max_hp": 100.0, "damage_mult": 1.0, "fire_rate_mult": 1.0, "move_speed": 265.0,
		"dash_cd": 1.1, "crit": 0.05, "armor": 0.0, "regen": 0.0, "pierce": 0,
		"soul_mult": 1.0, "pickup_radius": 110.0, "kill_heal": 0.0, "revive": false,
	}
	for id in skills:
		if not Data.SKILLS.has(id):
			continue
		var eff: Dictionary = Data.SKILLS[id]["effect"]
		for k in eff:
			if typeof(s[k]) == TYPE_BOOL:
				s[k] = true
			else:
				s[k] += eff[k]
	return s


# --- Save / load -------------------------------------------------------------

func save_game() -> void:
	if autotest:
		return
	var c := ConfigFile.new()
	c.set_value("progress", "souls", souls)
	c.set_value("progress", "levels_cleared", levels_cleared)
	c.set_value("progress", "unlocked_weapons", unlocked_weapons)
	c.set_value("progress", "skills", skills)
	c.set_value("progress", "skin", skin)
	c.set_value("progress", "unlocked_skins", unlocked_skins)
	c.set_value("settings", "values", settings)
	c.save(SAVE_PATH)


func load_game() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	souls = int(c.get_value("progress", "souls", 0))
	levels_cleared = int(c.get_value("progress", "levels_cleared", 0))
	unlocked_weapons = c.get_value("progress", "unlocked_weapons", ["pistol"])
	skills = c.get_value("progress", "skills", [])
	unlocked_skins = c.get_value("progress", "unlocked_skins", ["knight_m", "knight_f"])
	skin = c.get_value("progress", "skin", "knight_m")
	if not Data.SKINS.has(skin):
		skin = "knight_m"
	var st: Dictionary = c.get_value("settings", "values", {})
	for k in st:
		settings[k] = st[k]


func reset_progress() -> void:
	souls = 0
	levels_cleared = 0
	unlocked_weapons = ["pistol"]
	skills = []
	skin = "knight_m"
	unlocked_skins = ["knight_m", "knight_f"]
	save_game()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings["volume"]), 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web"):
		# Browsers control vsync and only allow fullscreen after a click.
		if settings["fullscreen"] != (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if settings["vsync"] else 165


# --- Setup helpers -----------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"dash": [KEY_SPACE, KEY_SHIFT], "next_weapon": [KEY_E], "prev_weapon": [KEY_Q],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)


func _make_light_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	g.add_point(0.7, Color(1, 1, 1, 0.12))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _box(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.border_width_bottom = bw + 3
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(3, 3)
	sb.shadow_size = 0
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = Art.font
	th.default_font_size = 24
	th.set_stylebox("normal", "Button", _box(Color(0.16, 0.12, 0.13), Color(0.36, 0.27, 0.27), 3))
	th.set_stylebox("hover", "Button", _box(Color(0.3, 0.12, 0.12), Color(0.75, 0.25, 0.2), 3))
	th.set_stylebox("pressed", "Button", _box(Color(0.42, 0.12, 0.1), Color(0.95, 0.4, 0.25), 3))
	th.set_stylebox("disabled", "Button", _box(Color(0.1, 0.08, 0.09, 0.9), Color(0.2, 0.17, 0.17), 3))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.92, 0.86, 0.78))
	th.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.85))
	th.set_color("font_pressed_color", "Button", Color(1.0, 0.85, 0.7))
	th.set_color("font_disabled_color", "Button", Color(0.42, 0.38, 0.37))
	th.set_color("font_outline_color", "Button", Color(0, 0, 0))
	th.set_constant("outline_size", "Button", 4)
	th.set_font_size("font_size", "Button", 26)
	th.set_color("font_color", "Label", Color(0.88, 0.82, 0.76))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0))
	th.set_constant("outline_size", "Label", 4)
	th.set_font_size("font_size", "Label", 24)
	th.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.075, 0.08, 0.92), Color(0.3, 0.22, 0.22), 3))
	th.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.03, 0.04, 0.95), Color(0.5, 0.1, 0.1), 1))
	th.set_color("font_color", "TooltipLabel", Color(0.9, 0.85, 0.8))
	return th
