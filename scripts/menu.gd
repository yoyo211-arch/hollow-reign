extends Control
## Main menu over a torch-lit pixel-art dungeon scene, with gate select, skill tree,
## armory, wardrobe (hero skins) and settings pages.

const Data = preload("res://scripts/data.gd")
const PostShader = preload("res://shaders/post.gdshader")
const SOUL_COL := Color(0.65, 0.88, 1.0)
const ROMAN := ["I", "II", "III", "IV", "V", "VI"]
const PX := 3.0
const TILE := 48.0

var main
var page := "main"
var content: Control
var info_label: Label
var confirm_reset := false
var scene_layer: CanvasLayer
var hero: AnimatedSprite2D
var lights: Array = []
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GameState.ui_theme
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_scene()
	if int(GameState.settings["quality"]) >= 1:
		var post := ColorRect.new()
		post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		post.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = PostShader
		post.material = mat
		add_child(post)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0, 0, 0, 0.0)
	dim.name = "Dim"
	add_child(dim)
	build()
	Sfx.music(false)


func _process(delta: float) -> void:
	t += delta
	for i in lights.size():
		lights[i].energy = 1.0 + sin(t * 11.0 + i * 1.7) * 0.07 + randf() * 0.08


# --- Background scene --------------------------------------------------------

func _build_scene() -> void:
	scene_layer = CanvasLayer.new()
	scene_layer.layer = -1
	add_child(scene_layer)
	var vp := get_viewport_rect().size
	var cm := CanvasModulate.new()
	cm.color = Color(0.3, 0.24, 0.28)
	scene_layer.add_child(cm)
	var wall_rows := 4
	var wall_y := TILE * wall_rows
	var bg := Node2D.new()
	bg.draw.connect(func():
		var cols := int(vp.x / TILE) + 2
		var rows := int((vp.y - wall_y) / TILE) + 2
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for gy in rows:
			for gx in cols:
				var tile := "floor_1" if rng.randf() < 0.6 else "floor_%d" % rng.randi_range(2, 8)
				bg.draw_texture_rect(Art.tex(tile), Rect2(gx * TILE, wall_y + gy * TILE, TILE, TILE), false)
		for gx in cols:
			var face := "wall_mid"
			if gx % 6 == 2:
				face = "wall_banner_red"
			for gy in wall_rows:
				var tile := face if gy == wall_rows - 1 else "wall_mid"
				bg.draw_texture_rect(Art.tex(tile), Rect2(gx * TILE, gy * TILE, TILE, TILE), false, Color(1, 1, 1) if gy == wall_rows - 1 else Color(0.6, 0.55, 0.55))
		for i in 6:
			bg.draw_rect(Rect2(0, wall_y + i * 6.0, vp.x, 6.0), Color(0, 0, 0, 0.35 - i * 0.055))
		for i in 7:
			var p := Vector2(rng.randf_range(0, vp.x), rng.randf_range(wall_y + 40, vp.y - 40)).snapped(Vector2(3, 3))
			bg.draw_texture_rect(Art.tex("skull"), Rect2(p, Vector2(TILE, TILE)), false))
	scene_layer.add_child(bg)
	for fx_x in [0.2, 0.8]:
		var x := snappedf(vp.x * fx_x, TILE)
		for part in [["wall_fountain_mid_red", wall_y - TILE], ["wall_fountain_basin_red", wall_y]]:
			var s := AnimatedSprite2D.new()
			s.sprite_frames = Art.frames(part[0])
			s.centered = false
			s.scale = Vector2(PX, PX)
			s.position = Vector2(x, part[1])
			s.play("idle")
			scene_layer.add_child(s)
	for tx in [0.08, 0.36, 0.64, 0.92]:
		_torch(Vector2(vp.x * tx, wall_y - TILE * 0.6))
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	scene_layer.add_child(actors)
	var cast := [
		["big_demon", Vector2(0.84, 0.86), 4.5, true],
		["necromancer", Vector2(0.15, 0.72), 3.0, false],
		["skelet", Vector2(0.08, 0.9), 3.0, false],
		["skelet", Vector2(0.26, 0.95), 3.0, false],
		["imp", Vector2(0.7, 0.68), 3.0, true],
		["big_zombie", Vector2(0.03, 0.62), 3.0, false],
	]
	for c in cast:
		_actor(actors, c[0], Vector2(vp.x * c[1].x, vp.y * c[1].y), c[2], c[3])
	hero = _actor(actors, GameState.skin, Vector2(vp.x * 0.5, vp.y * 0.93), 3.0, false)
	var hl := PointLight2D.new()
	hl.texture = GameState.light_tex
	hl.texture_scale = 2.5
	hl.energy = 0.9
	hl.color = Color(1.0, 0.85, 0.7)
	hl.position = Vector2(vp.x * 0.5, vp.y * 0.85)
	scene_layer.add_child(hl)
	var embers := CPUParticles2D.new()
	embers.material = Art.add_mat
	embers.texture = Art.fx("light_01")
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	embers.amount = 50
	embers.lifetime = 8.0
	embers.preprocess = 8.0
	embers.position = Vector2(vp.x / 2.0, vp.y + 20.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(vp.x * 0.6, 10)
	embers.direction = Vector2(0.2, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(4, -8)
	embers.initial_velocity_min = 25.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 0.05
	embers.scale_amount_max = 0.12
	embers.color = Color(1.0, 0.45, 0.2, 0.9)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.15, Color(1, 1, 1, 1))
	embers.color_ramp = g
	scene_layer.add_child(embers)


func _actor(parent: Node2D, char_name: String, pos: Vector2, scale_px: float, flip: bool) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Art.frames(char_name)
	s.scale = Vector2(scale_px, scale_px)
	s.offset = Vector2(0, -Art.first_frame(char_name).get_height() / 2.0)
	s.position = pos
	s.flip_h = flip
	s.play("idle")
	s.frame = randi() % 4
	parent.add_child(s)
	return s


func _torch(pos: Vector2) -> void:
	var fl := CPUParticles2D.new()
	fl.material = Art.add_mat
	fl.texture = Art.fx("flame_02")
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fl.amount = 16
	fl.lifetime = 0.55
	fl.position = pos
	fl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 3.0
	fl.direction = Vector2.UP
	fl.spread = 12.0
	fl.gravity = Vector2(0, -70)
	fl.initial_velocity_min = 15.0
	fl.initial_velocity_max = 40.0
	fl.scale_amount_min = 0.14
	fl.scale_amount_max = 0.26
	fl.color = Color(1.0, 0.6, 0.3)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.set_color(1, Color(0.6, 0.05, 0.0, 0.0))
	fl.color_ramp = g
	scene_layer.add_child(fl)
	var l := PointLight2D.new()
	l.texture = GameState.light_tex
	l.texture_scale = 3.2
	l.color = Color(1.0, 0.6, 0.32)
	l.position = pos + Vector2(0, 30)
	scene_layer.add_child(l)
	lights.append(l)


# --- Page building -----------------------------------------------------------

func _go(p: String) -> void:
	page = p
	confirm_reset = false
	build()


func build() -> void:
	if content:
		content.queue_free()
	var dim: ColorRect = get_node("Dim")
	dim.color = Color(0, 0, 0, 0.0 if page == "main" else 0.55)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	content = center
	match page:
		"levels": _build_levels(center)
		"skills": _build_skills(center)
		"armory": _build_armory(center)
		"wardrobe": _build_wardrobe(center)
		"settings": _build_settings(center)
		_: _build_main(center)


func _vbox(parent: Control, sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v


func _label(text: String, fs: int, color: Color, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _title(parent: Control, text: String) -> void:
	parent.add_child(_label(text, 64, Color(0.95, 0.25, 0.2), 10))


func _button(parent: Control, text: String, cb: Callable, disabled := false, min_size := Vector2(320, 50)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.disabled = disabled
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b


func _spacer(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c)


func _build_main(parent: Control) -> void:
	var v := _vbox(parent, 8)
	v.add_child(_label("HOLLOW REIGN", 120, Color(0.95, 0.2, 0.15), 16))
	v.add_child(_label("descend the five gates  -  break the crown of bone", 26, Color(0.85, 0.78, 0.7)))
	_spacer(v, 6)
	v.add_child(_label("Souls: %d" % GameState.souls, 30, SOUL_COL))
	_spacer(v, 2)
	var next := mini(GameState.levels_cleared, 5)
	var label := "Begin the Descent" if GameState.levels_cleared == 0 else "Descend  -  Gate %s" % ROMAN[next]
	_button(v, label, func(): main.start_level(next))
	_button(v, "Choose Gate", func(): _go("levels"))
	_button(v, "Skill Tree", func(): _go("skills"))
	_button(v, "Armory", func(): _go("armory"))
	_button(v, "Wardrobe", func(): _go("wardrobe"))
	_button(v, "Settings", func(): _go("settings"))
	_button(v, "Quit", func(): get_tree().quit())
	_spacer(v, 120)
	v.add_child(_label("WASD move  |  Mouse aim & fire  |  Space dash  |  1-5, Q/E, wheel switch weapon  |  Esc pause  |  F11 fullscreen", 20, Color(0.7, 0.65, 0.62)))


func _build_levels(parent: Control) -> void:
	var v := _vbox(parent, 10)
	_title(v, "CHOOSE A GATE")
	_spacer(v, 8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for i in Data.LEVELS.size():
		var lv: Dictionary = Data.LEVELS[i]
		var locked := i > GameState.levels_cleared
		var mark := "  [cleared]" if i < GameState.levels_cleared else ""
		var text := "%s.  %s%s\n%s" % [ROMAN[i], lv["name"], mark, "Sealed - clear the previous gate" if locked else lv["sub"]]
		var idx := i
		_button(grid, text, func(): main.start_level(idx), locked, Vector2(440, 76))
	_spacer(v, 10)
	_button(v, "Back", func(): _go("main"))


func _build_skills(parent: Control) -> void:
	var v := _vbox(parent, 6)
	_title(v, "SKILL TREE")
	v.add_child(_label("Souls: %d" % GameState.souls, 30, SOUL_COL))
	_spacer(v, 4)
	info_label = _label("Hover a skill to read it. Each branch unlocks top to bottom.", 22, Color(0.85, 0.8, 0.75))
	info_label.custom_minimum_size = Vector2(900, 30)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for br in Data.SKILL_BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		h.add_child(col)
		var bcol: Color = br["color"]
		col.add_child(_label(br["name"], 34, bcol, 8))
		var first := true
		for id in br["skills"]:
			if not first:
				col.add_child(_label("|", 18, bcol.darkened(0.3)))
			first = false
			var sk: Dictionary = Data.SKILLS[id]
			var owned := GameState.skills.has(id)
			var req: String = sk["req"]
			var avail := req == "" or GameState.skills.has(req)
			var text := ""
			var disabled := true
			if owned:
				text = "%s\nAWAKENED" % sk["name"]
			elif not avail:
				text = "%s\nlocked" % sk["name"]
			else:
				text = "%s\n%d souls" % [sk["name"], sk["cost"]]
				disabled = GameState.souls < int(sk["cost"])
			var skill_id: String = id
			var b := _button(col, text, func(): _buy_skill(skill_id), disabled, Vector2(260, 66))
			if owned:
				b.add_theme_color_override("font_disabled_color", bcol.lightened(0.4))
				var sb: StyleBoxFlat = GameState.ui_theme.get_stylebox("disabled", "Button").duplicate()
				sb.border_color = bcol
				sb.bg_color = bcol.darkened(0.75)
				b.add_theme_stylebox_override("disabled", sb)
			b.tooltip_text = sk["desc"]
			b.mouse_entered.connect(func(): info_label.text = "%s:  %s" % [sk["name"], sk["desc"]])
	_spacer(v, 6)
	v.add_child(info_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_button(row, "Refund All Skills", _refund_skills, GameState.skills.is_empty(), Vector2(260, 48))
	_button(row, "Back", func(): _go("main"), false, Vector2(260, 48))


func _buy_skill(id: String) -> void:
	var cost: int = Data.SKILLS[id]["cost"]
	if GameState.souls < cost or GameState.skills.has(id):
		return
	GameState.souls -= cost
	GameState.skills.append(id)
	GameState.save_game()
	Sfx.play("buy", -2.0, 0.0)
	build()


func _refund_skills() -> void:
	for id in GameState.skills:
		GameState.souls += int(Data.SKILLS[id]["cost"])
	GameState.skills = []
	GameState.save_game()
	build()


func _build_armory(parent: Control) -> void:
	var v := _vbox(parent, 8)
	_title(v, "ARMORY")
	v.add_child(_label("Souls: %d" % GameState.souls, 30, SOUL_COL))
	_spacer(v, 4)
	for id in Data.WEAPON_ORDER:
		var w: Dictionary = Data.WEAPONS[id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(900, 0)
		v.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Art.tex(w["sprite"])
		icon.custom_minimum_size = Vector2(64, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var stats := ""
		if w["kind"] == "melee":
			stats = "DMG %d   %.1f swings/s   MELEE ARC" % [w["damage"], w["rate"]]
		else:
			var count: int = w["count"]
			stats = "DMG %d%s   %.1f shots/s%s%s" % [w["damage"], (" x%d" % count) if count > 1 else "", w["rate"],
				("   PIERCE %d" % w["pierce"]) if int(w["pierce"]) > 0 else "", "   HOMING" if w["kind"] == "homing" else ""]
		var info := _label("%s\n%s\n%s" % [w["name"], w["desc"], stats], 22, Color(0.9, 0.85, 0.8))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var owned := GameState.unlocked_weapons.has(id)
		var req: int = w["req"]
		var weapon_id: String = id
		if owned:
			_button(row, "OWNED", func(): pass, true, Vector2(230, 56))
		elif GameState.levels_cleared < req:
			_button(row, "Clear gate %s first" % ROMAN[req - 1], func(): pass, true, Vector2(230, 56))
		else:
			_button(row, "Forge  -  %d souls" % w["cost"], func(): _buy_weapon(weapon_id), GameState.souls < int(w["cost"]), Vector2(230, 56))
	_spacer(v, 4)
	_button(v, "Back", func(): _go("main"))


func _buy_weapon(id: String) -> void:
	var cost: int = Data.WEAPONS[id]["cost"]
	if GameState.souls < cost or GameState.unlocked_weapons.has(id):
		return
	GameState.souls -= cost
	GameState.unlocked_weapons.append(id)
	GameState.save_game()
	Sfx.play("buy", -2.0, 0.0)
	build()


func _build_wardrobe(parent: Control) -> void:
	var v := _vbox(parent, 8)
	_title(v, "WARDROBE")
	v.add_child(_label("Souls: %d" % GameState.souls, 30, SOUL_COL))
	_spacer(v, 4)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Data.SKIN_ORDER:
		var sk: Dictionary = Data.SKINS[id]
		var owned := GameState.unlocked_skins.has(id)
		var equipped: bool = GameState.skin == id
		var text := ""
		if equipped:
			text = "%s\nEQUIPPED" % sk["name"]
		elif owned:
			text = "%s\nwear" % sk["name"]
		else:
			text = "%s\n%d souls" % [sk["name"], sk["cost"]]
		var skin_id: String = id
		var b := _button(grid, text, func(): _pick_skin(skin_id), equipped or (not owned and GameState.souls < int(sk["cost"])), Vector2(150, 190))
		b.icon = Art.first_frame(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 22)
		if equipped:
			b.add_theme_color_override("font_disabled_color", Color(1.0, 0.8, 0.4))
			var sb: StyleBoxFlat = GameState.ui_theme.get_stylebox("disabled", "Button").duplicate()
			sb.border_color = Color(1.0, 0.75, 0.3)
			b.add_theme_stylebox_override("disabled", sb)
	_spacer(v, 6)
	_button(v, "Back", func(): _go("main"))


func _pick_skin(id: String) -> void:
	if not GameState.unlocked_skins.has(id):
		var cost: int = Data.SKINS[id]["cost"]
		if GameState.souls < cost:
			return
		GameState.souls -= cost
		GameState.unlocked_skins.append(id)
		Sfx.play("buy", -2.0, 0.0)
	GameState.skin = id
	GameState.save_game()
	hero.sprite_frames = Art.frames(id)
	hero.offset = Vector2(0, -Art.first_frame(id).get_height() / 2.0)
	hero.play("idle")
	build()


func _build_settings(parent: Control) -> void:
	var st: Dictionary = GameState.settings
	var v := _vbox(parent, 10)
	_title(v, "SETTINGS")
	_spacer(v, 8)
	_button(v, "Display: %s" % ("Fullscreen" if st["fullscreen"] else "Windowed"), func(): _toggle("fullscreen"))
	_button(v, "Quality: %s" % ("High" if int(st["quality"]) >= 1 else "Low (faster)"), func():
		st["quality"] = 0 if int(st["quality"]) >= 1 else 1
		_apply())
	_button(v, "VSync: %s" % ("On" if st["vsync"] else "Off"), func(): _toggle("vsync"))
	_button(v, "Screen Shake: %s" % ("On" if st.get("shake", true) else "Off"), func(): _toggle("shake"))
	_button(v, "Volume: %d%%" % int(round(float(st["volume"]) * 100.0)), func():
		st["volume"] = 0.0 if float(st["volume"]) >= 0.99 else snappedf(float(st["volume"]) + 0.2, 0.2)
		_apply())
	v.add_child(_label("Low quality turns off shadows, post-processing and halves particles.", 20, Color(0.7, 0.65, 0.62)))
	_spacer(v, 10)
	_button(v, "Are you sure? Click again to erase all progress" if confirm_reset else "Reset Progress", _reset, false, Vector2(520, 50))
	_button(v, "Back", func(): _go("main"))


func _toggle(key: String) -> void:
	GameState.settings[key] = not GameState.settings.get(key, true)
	_apply()


func _apply() -> void:
	GameState.apply_settings()
	GameState.save_game()
	build()


func _reset() -> void:
	if confirm_reset:
		GameState.reset_progress()
		confirm_reset = false
		_pick_skin("knight_m")
		return
	confirm_reset = true
	build()
