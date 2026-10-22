extends Control
## In-game HUD: pixel hearts, dash, souls, objective, boss bar, weapon slots, portal arrow, crosshair.

const Data = preload("res://scripts/data.gd")
const HP_PER_HEART := 20.0

var game
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = Art.font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.player == null:
		return
	var s := size
	var p = game.player
	var max_hp: float = p.stats["max_hp"]

	# Hearts (each heart is 20 health) with the exact number underneath.
	var hearts := int(ceil(max_hp / HP_PER_HEART))
	var full := Art.tex("ui_heart_full")
	var half := Art.tex("ui_heart_half")
	var empty := Art.tex("ui_heart_empty")
	var hp: float = maxf(p.hp, 0.0)
	for i in hearts:
		var v := hp - i * HP_PER_HEART
		var tex := full if v >= HP_PER_HEART * 0.75 else (half if v >= HP_PER_HEART * 0.25 else empty)
		var x := 20.0 + (i % 10) * 42.0
		var y := 18.0 + (i / 10) * 38.0
		draw_texture_rect(tex, Rect2(x, y, 39, 36), false)
	var rows := (hearts - 1) / 10 + 1
	var y0 := 18.0 + rows * 38.0
	_text(Vector2(22, y0 + 18), "%d / %d" % [ceili(hp), int(max_hp)], 22, Color(1, 0.88, 0.85))

	var dash_ready := 1.0 - clampf(p.dash_cd / float(p.stats["dash_cd"]), 0.0, 1.0)
	_bar(Rect2(22, y0 + 28, 150, 9), dash_ready, Color(0.6, 0.5, 1.0), Color(0.1, 0.08, 0.16))
	_text(Vector2(180, y0 + 38), "DASH", 18, Color(0.75, 0.7, 1.0) if dash_ready >= 1.0 else Color(0.45, 0.42, 0.55))

	# Souls
	var sp := Vector2(34, y0 + 66)
	draw_texture_rect(Art.fx("light_01"), Rect2(sp - Vector2(20, 20), Vector2(40, 40)), false, Color(0.4, 0.75, 1.0, 0.9))
	draw_circle(sp, 4.0, Color(0.9, 0.97, 1.0))
	_text(Vector2(58, y0 + 76), "%d" % GameState.souls, 30, Color(0.72, 0.9, 1.0))
	_text(Vector2(58, y0 + 98), "+%d this descent" % game.run_souls, 18, Color(0.55, 0.65, 0.78))

	# Objective
	_text_c(Vector2(s.x / 2.0, 34), String(game.level["name"]).to_upper(), 22, Color(0.75, 0.66, 0.6))
	match game.phase:
		"fight":
			var tl: float = maxf(game.time_left, 0.0)
			_text_c(Vector2(s.x / 2.0, 72), "SURVIVE  %d:%02d" % [int(tl) / 60, int(tl) % 60], 42, Color(1.0, 0.95, 0.88))
		"portal":
			var a := 0.6 + 0.4 * sin(game.elapsed * 5.0)
			_text_c(Vector2(s.x / 2.0, 72), "THE GATE IS OPEN - ENTER THE PORTAL", 34, Color(0.85, 0.65, 1.0, a))
		"intro":
			_text_c(Vector2(s.x / 2.0, 72), "SOMETHING STIRS...", 34, Color(1.0, 0.45, 0.4))
	if game.boss != null and is_instance_valid(game.boss):
		var b = game.boss
		var w := minf(640.0, s.x - 80.0)
		var r := Rect2(s.x / 2.0 - w / 2.0, 58, w, 18)
		_bar(r, clampf(b.hp / b.max_hp, 0.0, 1.0), Color(0.8, 0.12, 0.12), Color(0.18, 0.04, 0.05))
		_text_c(Vector2(s.x / 2.0, 102), "THE HOLLOW KING", 24, Color(1.0, 0.6, 0.5))
	_text(Vector2(s.x - 150, 42), "KILLS  %d" % game.kills, 26, Color(0.85, 0.75, 0.7))

	# Weapon slots with their pixel-art icons.
	var n: int = p.weapons.size()
	var bw := 84.0
	var x0 := s.x / 2.0 - n * (bw + 8.0) / 2.0
	for i in n:
		var r := Rect2(x0 + i * (bw + 8.0), s.y - 92, bw, 76)
		var on: bool = i == p.cur
		draw_rect(r.grow(3), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.2, 0.1, 0.1, 0.9) if on else Color(0.1, 0.08, 0.09, 0.85))
		draw_rect(r, Color(0.95, 0.35, 0.25) if on else Color(0.3, 0.24, 0.24), false, 3.0)
		var w: Dictionary = Data.WEAPONS[p.weapons[i]]
		var tex := Art.tex(w["sprite"])
		var ts := tex.get_size() * 1.6
		var c := r.get_center() + Vector2(0, -10)
		draw_set_transform(c, PI / 4.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-ts / 2.0, ts), false, Color(1, 1, 1, 1.0 if on else 0.55))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(r.position + Vector2(6, 18), str(i + 1), 18, Color(0.6, 0.55, 0.55))
		_text_c(Vector2(r.get_center().x, r.end.y - 6), w["short"], 18, Color(1, 0.92, 0.85) if on else Color(0.6, 0.55, 0.52))

	# Portal direction arrow
	if game.portal and game.phase == "portal":
		var sp2: Vector2 = get_viewport().get_canvas_transform() * game.portal.global_position
		var inner := Rect2(Vector2.ZERO, s).grow(-50)
		if inner.size.x > 0.0 and inner.size.y > 0.0 and not inner.has_point(sp2):
			var c := s / 2.0
			var dir := (sp2 - c).normalized()
			var edge := Vector2(clampf(sp2.x, inner.position.x, inner.end.x), clampf(sp2.y, inner.position.y, inner.end.y))
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([edge + dir * 18.0, edge - dir * 9.0 + side * 12.0, edge - dir * 9.0 - side * 12.0]), Color(0.8, 0.55, 1.0, 0.95))

	# Banner
	if game.banner_t > 0.0:
		var a := clampf(game.banner_t, 0.0, 1.0)
		_text_c(Vector2(s.x / 2.0, s.y * 0.3), game.banner, 64, Color(0.95, 0.2, 0.15, a), 10)
		if game.banner_sub != "":
			_text_c(Vector2(s.x / 2.0, s.y * 0.3 + 42), game.banner_sub, 28, Color(0.85, 0.8, 0.75, a))

	# Crosshair
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		var m := get_local_mouse_position().round()
		var cc := Color(1.0, 0.9, 0.8, 0.95)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_rect(Rect2(m + d * 9.0 - Vector2(3, 3) + d * 3.0, Vector2(6, 6)), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(m + d * 9.0 - Vector2(1.5, 1.5) + d * 3.0, Vector2(3, 3)), cc)
		draw_rect(Rect2(m - Vector2(1.5, 1.5), Vector2(3, 3)), cc)


func _bar(r: Rect2, ratio: float, fill: Color, back: Color) -> void:
	draw_rect(r.grow(3), Color(0, 0, 0, 0.85))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, 3)), Color(1, 1, 1, 0.25))


func _text(pos: Vector2, text: String, fs: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _text_c(pos: Vector2, text: String, fs: int, color: Color, outline := 6) -> void:
	var p := pos - Vector2(600, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, 1200, fs, outline, Color(0, 0, 0, color.a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, 1200, fs, color)
