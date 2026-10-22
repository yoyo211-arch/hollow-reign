extends Node2D
## One gate (level): arena, spawning, combat, pickups, effects and level flow.
## The floor, walls and blood are baked into one offscreen texture. Bullets, pickups and
## effects are plain data drawn by a few nodes, which keeps hundreds of them cheap on weak PCs.
## Actors (player, monsters, pillars) live in a y-sorted layer so they overlap correctly.

const Data = preload("res://scripts/data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BossScript = preload("res://scripts/boss.gd")
const HudScript = preload("res://scripts/hud.gd")
const PostShader = preload("res://shaders/post.gdshader")
const PX := 3.0
const TILE := 48.0
const GROUND_MARGIN := 144.0


class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 0.0
	var crit := false
	var life := 1.0
	var age := 0.0
	var pierce := 0
	var color := Color.WHITE
	var width := 3.0
	var r := 4.0
	var hostile := false
	var homing := false
	var style := ""
	var target = null
	var retarget := 0.0
	var hits: Array = []


class Pickup:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var kind := "soul"
	var value := 1
	var t := 0.0


class Fx:
	var kind := ""
	var pos := Vector2.ZERO
	var t := 0.0
	var dur := 0.3
	var r := 10.0
	var a := 0.0
	var color := Color.WHITE
	var text := ""
	var tex: Texture2D
	var additive := true
	var flip := false


var main
var level_index := 0
var level: Dictionary
var arena := Rect2(0, 0, 2400, 1584)
var hq := true
var max_enemies := 70

var player
var boss
var portal: Node2D
var enemies: Array = []
var bullets: Array = []
var pickups: Array = []
var fxs: Array = []
var splats: Array = []
var pillars: Array = []
var torches: Array = []

var phase := "fight"
var time_left := 60.0
var spawn_cd := 1.5
var interval := 1.2
var boss_spawn_t := 3.0
var elapsed := 0.0
var run_souls := 0
var kills := 0
var shake := 0.0
var hurt_flash := 0.0
var banner := ""
var banner_sub := ""
var banner_t := 0.0

var unshaded_mat: CanvasItemMaterial
var fade_grad: Gradient
var fire_grad: Gradient
var world: Node2D
var entities: Node2D
var floor_node: Node2D
var decal_node: Node2D
var pickup_add: Node2D
var pickup_spr: Node2D
var bullet_spr: Node2D
var bullet_add: Node2D
var particles_node: Node2D
var fx_norm: Node2D
var fx_add: Node2D
var cam: Camera2D
var hud
var hud_layer: CanvasLayer
var post_mat: ShaderMaterial
var overlay: Control
var paused_menu := false
var ground_vp: SubViewport
var ground_dirty := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = Data.LEVELS[level_index]
	hq = int(GameState.settings["quality"]) >= 1
	max_enemies = 70 if hq else 45
	time_left = float(level["time"])
	interval = float(level["interval"])
	unshaded_mat = Art.unshaded_mat
	fade_grad = Gradient.new()
	fade_grad.set_color(0, Color(1, 1, 1, 1))
	fade_grad.set_color(1, Color(1, 1, 1, 0))
	fire_grad = Gradient.new()
	fire_grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	fire_grad.set_color(1, Color(0.6, 0.05, 0.0, 0.0))
	fire_grad.add_point(0.35, Color(1.0, 0.55, 0.15, 0.9))

	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var cm := CanvasModulate.new()
	cm.color = level["ambient"]
	world.add_child(cm)

	_build_ground()
	pickup_add = _layer(Art.add_mat, true, _draw_pickups_add)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	world.add_child(entities)
	pickup_spr = _layer(unshaded_mat, false, _draw_pickups_spr)
	_build_arena()
	particles_node = Node2D.new()
	world.add_child(particles_node)
	bullet_spr = _layer(unshaded_mat, false, _draw_bullets_spr)
	bullet_add = _layer(Art.add_mat, true, _draw_bullets_add)
	fx_norm = _layer(unshaded_mat, true, _draw_fx_norm)
	fx_add = _layer(Art.add_mat, true, _draw_fx_add)

	player = PlayerScript.new()
	player.game = self
	player.position = arena.get_center() + (Vector2(0, 450) if is_boss_level() else Vector2.ZERO)
	if GameState.debug_top:
		player.position = Vector2(arena.position.x + arena.size.x * 0.25, arena.position.y + 120.0)
	entities.add_child(player)

	cam = Camera2D.new()
	cam.position = player.position
	cam.zoom = Vector2(1.0, 1.0)
	cam.limit_left = int(arena.position.x - TILE * 2.0)
	cam.limit_top = int(arena.position.y - TILE * 3.0)
	cam.limit_right = int(arena.end.x + TILE * 2.0)
	cam.limit_bottom = int(arena.end.y + TILE * 2.0)
	add_child(cam)
	cam.make_current()
	_add_ash()

	if hq:
		var pl := CanvasLayer.new()
		pl.layer = 5
		add_child(pl)
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		post_mat = ShaderMaterial.new()
		post_mat.shader = PostShader
		rect.material = post_mat
		pl.add_child(rect)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = HudScript.new()
	hud.game = self
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud_layer.add_child(hud)

	phase = "intro" if is_boss_level() else "fight"
	show_banner(String(level["name"]).to_upper(), level["sub"], 3.5)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Sfx.music(is_boss_level())


func is_boss_level() -> bool:
	return level.get("boss", false)


func _layer(mat: Material, linear: bool, cb: Callable) -> Node2D:
	var n := Node2D.new()
	n.material = mat
	if linear:
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	n.draw.connect(cb)
	world.add_child(n)
	return n


## The floor, walls and blood decals are rendered into an offscreen texture shown as one
## sprite, so each light re-lights a single quad instead of thousands of tiles.
func _build_ground() -> void:
	ground_vp = SubViewport.new()
	ground_vp.size = Vector2i(arena.size + Vector2.ONE * GROUND_MARGIN * 2.0)
	ground_vp.disable_3d = true
	ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	ground_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(ground_vp)
	var holder := Node2D.new()
	holder.position = -arena.position + Vector2.ONE * GROUND_MARGIN
	ground_vp.add_child(holder)
	floor_node = Node2D.new()
	floor_node.draw.connect(_draw_floor)
	holder.add_child(floor_node)
	decal_node = Node2D.new()
	decal_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	decal_node.draw.connect(_draw_decals)
	holder.add_child(decal_node)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = ground_vp.get_texture()
	spr.position = arena.position - Vector2.ONE * GROUND_MARGIN
	world.add_child(spr)


# --- Main loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if GameState.autotest and int(elapsed / 15.0) != int((elapsed + delta) / 15.0):
		print("AUTOTEST t=%d phase=%s enemies=%d bullets=%d boss_hp=%s fps=%d" % [elapsed, phase, enemies.size(), bullets.size(),
			str(int(boss.hp)) if boss != null and is_instance_valid(boss) else "-", Engine.get_frames_per_second()])
	elapsed += delta
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	match phase:
		"fight":
			time_left -= delta
			spawn_cd -= delta
			if spawn_cd <= 0.0:
				_spawn_wave()
			if time_left <= 0.0:
				time_left = 0.0
				_open_portal(Vector2.INF)
		"intro":
			boss_spawn_t -= delta
			if boss_spawn_t <= 0.0:
				_spawn_boss()
		"boss":
			spawn_cd -= delta
			if spawn_cd <= 0.0:
				spawn_cd = interval
				if enemies.size() < 14:
					spawn_enemy(_pick_kind(), _spawn_point())

	_update_bullets(delta)
	_update_pickups(delta)
	_update_fx(delta)
	_update_camera(delta)
	for i in torches.size():
		torches[i].energy = 0.95 + sin(elapsed * 11.0 + i * 1.7) * 0.07 + randf() * 0.08
	banner_t = maxf(banner_t - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta * 2.5, 0.0)
	if post_mat:
		var low := 0.0
		if not player.dead:
			var ratio: float = player.hp / float(player.stats["max_hp"])
			if ratio < 0.3:
				low = (0.3 - ratio) / 0.3 * (0.5 + 0.5 * sin(elapsed * 6.0))
		post_mat.set_shader_parameter("hurt", maxf(hurt_flash, low * 0.7))
		post_mat.set_shader_parameter("aberration", hurt_flash * 1.5)
	if portal:
		portal.queue_redraw()
		if phase == "portal" and not player.dead and player.global_position.distance_to(portal.position) < 46.0:
			_complete()
	if ground_dirty:
		ground_dirty = false
		ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	bullet_spr.queue_redraw()
	bullet_add.queue_redraw()
	pickup_add.queue_redraw()
	pickup_spr.queue_redraw()
	fx_norm.queue_redraw()
	fx_add.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if overlay and paused_menu:
		_resume()
	elif overlay == null and phase in ["fight", "portal", "boss", "intro"]:
		_pause_menu()


func _update_camera(delta: float) -> void:
	var pp: Vector2 = player.global_position + Vector2(0, -30)
	var lead := (get_global_mouse_position() - pp).limit_length(260.0) * 0.18
	if GameState.autotest:
		lead = Vector2.ZERO
	cam.global_position = cam.global_position.lerp(pp + lead, 1.0 - exp(-delta * 9.0))
	shake = maxf(shake - delta * 40.0, 0.0)
	var s := minf(shake, 16.0)
	cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))


func add_shake(amount: float) -> void:
	if GameState.settings.get("shake", true):
		shake += amount


# --- Arena -------------------------------------------------------------------

func _build_arena() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + level_index * 37
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var th := 200.0
	var rects := [
		Rect2(arena.position.x - th, arena.position.y - th, arena.size.x + th * 2.0, th),
		Rect2(arena.position.x - th, arena.end.y, arena.size.x + th * 2.0, th),
		Rect2(arena.position.x - th, arena.position.y, th, arena.size.y),
		Rect2(arena.end.x, arena.position.y, th, arena.size.y),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		walls.add_child(cs)
	world.add_child(walls)

	var center := arena.get_center()
	if is_boss_level():
		for i in 6:
			var a := TAU * i / 6.0 + PI / 6.0
			_add_pillar(center + Vector2(cos(a) * 640.0, sin(a) * 440.0))
	else:
		var count := 10 + rng.randi_range(0, 4)
		var tries := 0
		while pillars.size() < count and tries < 400:
			tries += 1
			var p := Vector2(rng.randf_range(arena.position.x + 150, arena.end.x - 150), rng.randf_range(arena.position.y + 220, arena.end.y - 100))
			if p.distance_to(center) < 280.0:
				continue
			var ok := true
			for q in pillars:
				if p.distance_to(q.get_center()) < 230.0:
					ok = false
					break
			if ok:
				_add_pillar(p)

	# Torches hang on the north wall face; braziers stand along the south edge.
	var nt := 6 if hq else 4
	var per_side := nt / 2
	for i in per_side:
		var x := arena.position.x + arena.size.x * (float(i) + 0.5) / float(per_side)
		_add_torch(Vector2(x + 72.0, arena.position.y - TILE * 0.55), true)
		_add_torch(Vector2(x - 72.0, arena.end.y - 10.0), false)
	# Animated blood fountains set into the north wall.
	for fx_x in [0.25, 0.75]:
		var fx := snappedf(arena.position.x + arena.size.x * fx_x, TILE)
		for part in [["wall_fountain_mid_red", -TILE], ["wall_fountain_basin_red", 0.0]]:
			var s := AnimatedSprite2D.new()
			s.sprite_frames = Art.frames(part[0])
			s.centered = false
			s.scale = Vector2(PX, PX)
			s.position = Vector2(fx, arena.position.y + part[1])
			s.play("idle")
			world.add_child(s)


func _add_pillar(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(40, 30)
	cs.shape = sh
	cs.position = Vector2(0, -16)
	body.add_child(cs)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-20, -40), Vector2(20, -40), Vector2(20, -4), Vector2(-20, -4)])
	occ.occluder = poly
	body.add_child(occ)
	var shadow := Node2D.new()
	shadow.draw.connect(func():
		shadow.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.4))
		shadow.draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.45)))
	body.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = Art.tex("column")
	spr.centered = false
	spr.scale = Vector2(PX, PX)
	# The column art has 12 empty rows under its base, so shift it down to stand on the origin.
	spr.position = Vector2(-TILE * 0.5, -TILE * 3.0 + 36.0)
	body.add_child(spr)
	entities.add_child(body)
	pillars.append(Rect2(pos + Vector2(-22, -100), Vector2(44, 96)))


func _add_torch(pos: Vector2, on_wall: bool) -> void:
	var n := Node2D.new()
	n.position = pos
	if not on_wall:
		n.draw.connect(func():
			n.draw_rect(Rect2(-9, -6, 18, 10), Color(0.16, 0.13, 0.12))
			n.draw_rect(Rect2(-4, 4, 8, 8), Color(0.12, 0.1, 0.09)))
	else:
		n.draw.connect(func(): n.draw_rect(Rect2(-4, -2, 8, 14), Color(0.2, 0.15, 0.1)))
	world.add_child(n)
	var fl := CPUParticles2D.new()
	fl.material = Art.add_mat
	fl.texture = Art.fx("flame_02")
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fl.amount = 16 if hq else 8
	fl.lifetime = 0.55
	fl.position = Vector2(0, -6)
	fl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 3.0
	fl.direction = Vector2.UP
	fl.spread = 12.0
	fl.gravity = Vector2(0, -70)
	fl.initial_velocity_min = 15.0
	fl.initial_velocity_max = 40.0
	fl.angle_min = -20.0
	fl.angle_max = 20.0
	fl.scale_amount_min = 0.14
	fl.scale_amount_max = 0.26
	fl.color = level["torch"]
	fl.color_ramp = fire_grad
	n.add_child(fl)
	var l := PointLight2D.new()
	l.texture = GameState.light_tex
	l.texture_scale = 3.0
	l.color = level["torch"]
	l.energy = 1.0
	l.position = Vector2(0, 20 if on_wall else -10)
	n.add_child(l)
	torches.append(l)


func _add_ash() -> void:
	var p := CPUParticles2D.new()
	p.material = unshaded_mat
	p.amount = 60 if hq else 20
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(760, 460)
	p.direction = Vector2(0.3, 1.0)
	p.spread = 30.0
	p.gravity = Vector2(6, 10)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = level["ash"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.8, Color(1, 1, 1, 1))
	p.color_ramp = g
	cam.add_child(p)


func _in_pillar(p: Vector2, margin: float) -> bool:
	for r in pillars:
		if r.grow(margin).has_point(p):
			return true
	return false


# --- Spawning ----------------------------------------------------------------

func _spawn_wave() -> void:
	var prog := 1.0 - time_left / float(level["time"])
	var base := float(level["interval"])
	spawn_cd = lerpf(base, base * 0.45, prog) * randf_range(0.8, 1.2)
	var count := 1 + int(prog * 2.5 * randf())
	if level_index >= 3 and randf() < 0.3:
		count += 1
	for i in count:
		if enemies.size() >= max_enemies:
			return
		spawn_enemy(_pick_kind(), _spawn_point())


func _pick_kind() -> String:
	var pool: Dictionary = level["pool"]
	var total := 0.0
	for k in pool:
		total += float(pool[k])
	var roll := randf() * total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0:
			return k
	return pool.keys()[0]


func _spawn_point() -> Vector2:
	var pp: Vector2 = player.global_position
	for i in 20:
		var p := Vector2(randf_range(arena.position.x + 60, arena.end.x - 60), randf_range(arena.position.y + 80, arena.end.y - 30))
		if p.distance_to(pp) < 520.0 or _in_pillar(p, 30.0):
			continue
		return p
	return arena.position + Vector2(80, 120)


func spawn_enemy(kind: String, pos: Vector2) -> void:
	pos = pos.clamp(arena.position + Vector2(30, 60), arena.end - Vector2(30, 10))
	var e := EnemyScript.new()
	e.game = self
	e.setup(kind, float(level["hp"]))
	e.position = pos
	entities.add_child(e)
	enemies.append(e)
	add_fx_tex("smoke_0%d" % randi_range(1, 4), pos + Vector2(0, -20), 0.7, e.radius * 5.0, Color(0.15, 0.05, 0.2, 0.8), randf() * TAU, false)
	add_fx_tex("magic_0%d" % randi_range(1, 5), pos + Vector2(0, -20), 0.4, e.radius * 4.0, Color(0.6, 0.25, 0.9, 0.6), randf() * TAU)


func _spawn_boss() -> void:
	phase = "boss"
	boss = BossScript.new()
	boss.game = self
	boss.position = Vector2(arena.get_center().x, arena.position.y + 420.0)
	entities.add_child(boss)
	enemies.append(boss)
	add_shake(20.0)
	Sfx.play("roar", 0.0, 0.0)
	Sfx.play("bell", -2.0, 0.0)
	add_fx_tex("twirl_01", boss.position + Vector2(0, -70), 1.2, 520.0, Color(1.0, 0.3, 0.25, 0.9))
	add_fx_tex("smoke_04", boss.position + Vector2(0, -40), 1.4, 400.0, Color(0.1, 0.03, 0.05, 0.9), 0.0, false)
	show_banner("THE HOLLOW KING", "He who wears the crown of bone", 3.5)
	spawn_cd = 8.0


# --- Combat ------------------------------------------------------------------

func spawn_bullet(pos: Vector2, vel: Vector2, dmg: float, crit: bool, pierce: int, life: float, color: Color, width: float, homing := false, style := "") -> void:
	var b := Bullet.new()
	b.pos = pos
	b.vel = vel
	b.dmg = dmg
	b.crit = crit
	b.pierce = pierce
	b.life = life
	b.color = color
	b.width = width
	b.r = width + 2.0
	b.homing = homing
	b.style = style
	bullets.append(b)


func spawn_enemy_bullet(pos: Vector2, vel: Vector2, dmg: float, color: Color) -> void:
	var b := Bullet.new()
	b.pos = pos
	b.vel = vel
	b.dmg = dmg
	b.life = 6.0
	b.color = color
	b.width = 6.0
	b.r = 7.0
	b.hostile = true
	b.style = "orb"
	bullets.append(b)


func _update_bullets(delta: float) -> void:
	var pp: Vector2 = player.global_position + player.hit_offset
	var i := bullets.size() - 1
	while i >= 0:
		var b: Bullet = bullets[i]
		var old := b.pos
		if b.homing:
			b.retarget -= delta
			if b.retarget <= 0.0 or not is_instance_valid(b.target) or b.target.dead:
				b.retarget = 0.15
				b.target = nearest_enemy(b.pos, 420.0)
			if b.target != null and is_instance_valid(b.target):
				var want: Vector2 = (b.target.global_position + b.target.hit_offset - b.pos).normalized() * b.vel.length()
				b.vel = b.vel.lerp(want, 1.0 - exp(-delta * 7.0))
		b.pos += b.vel * delta
		b.life -= delta
		b.age += delta
		var gone := b.life <= 0.0
		if not gone and (not arena.grow(40.0).has_point(b.pos) or _in_pillar(b.pos, 0.0)):
			gone = true
			_sparks(b.pos, b.color, 3)
		if not gone:
			if b.hostile:
				if not player.dead and Geometry2D.get_closest_point_to_segment(pp, old, b.pos).distance_to(pp) < b.r + 12.0:
					player.hurt(b.dmg, old)
					gone = true
			else:
				for e in enemies:
					if e.dead or b.hits.has(e.get_instance_id()):
						continue
					var ep: Vector2 = e.global_position + e.hit_offset
					var er: float = e.radius
					if absf(ep.x - b.pos.x) > er + 50.0 or absf(ep.y - b.pos.y) > er + 50.0:
						continue
					if Geometry2D.get_closest_point_to_segment(ep, old, b.pos).distance_to(ep) < er + b.r:
						b.hits.append(e.get_instance_id())
						e.take_damage(b.dmg, b.vel.normalized() * 160.0, b.crit)
						_sparks(b.pos, b.color, 2)
						b.pierce -= 1
						if b.pierce < 0:
							gone = true
							break
		if gone:
			bullets.remove_at(i)
		i -= 1


func melee_attack(origin: Vector2, aim: Vector2, w: Dictionary, stats: Dictionary) -> void:
	var reach: float = w["range"]
	var arc: float = w["arc"]
	var ang := aim.angle()
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position + e.hit_offset - origin
		if to.length() > reach + float(e.radius):
			continue
		if absf(wrapf(to.angle() - ang, -PI, PI)) > arc:
			continue
		var crit := randf() < float(stats["crit"])
		var dmg: float = float(w["damage"]) * float(stats["damage_mult"]) * (2.0 if crit else 1.0)
		e.take_damage(dmg, to.normalized() * 520.0, crit)
	var parried := false
	for b in bullets:
		if b.hostile and b.pos.distance_to(origin) < reach and absf(wrapf((b.pos - origin).angle() - ang, -PI, PI)) < arc:
			b.life = 0.0
			parried = true
			_sparks(b.pos, Color(1, 0.6, 0.4), 2)
	if parried:
		Sfx.play("parry", -4.0)
	add_fx_tex("slash_0%d" % randi_range(1, 4), origin + aim * reach * 0.45, 0.2, reach * 2.0, Color(w["color"], 0.9), ang)
	add_fx_tex("trace_01", origin + aim * reach * 0.5, 0.15, reach * 1.6, Color(1, 0.9, 0.8, 0.5), ang + PI / 2.0)


func explosion(pos: Vector2, radius: float, dmg: float) -> void:
	add_fx_tex("fire_0%d" % randi_range(1, 2), pos, 0.35, radius * 2.4, Color(1.0, 0.55, 0.2, 1.0), randf() * TAU)
	add_fx_tex("flame_0%d" % randi_range(1, 4), pos, 0.25, radius * 2.0, Color(1.0, 0.8, 0.4, 0.9), randf() * TAU)
	add_fx_tex("smoke_0%d" % randi_range(1, 4), pos, 0.9, radius * 2.6, Color(0.12, 0.1, 0.1, 0.8), randf() * TAU, false)
	add_fx_tex("circle_05", pos, 0.3, radius * 2.2, Color(1.0, 0.6, 0.3, 0.8))
	add_splat(pos, radius * 1.4, Color(0, 0, 0, 0.7), "scorch_0%d" % randi_range(1, 3))
	add_shake(8.0)
	Sfx.play("explode", -2.0)
	var l := PointLight2D.new()
	l.texture = GameState.light_tex
	l.color = Color(1.0, 0.5, 0.2)
	l.texture_scale = 2.2
	l.energy = 1.8
	l.position = pos
	particles_node.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	if not player.dead and (player.global_position + player.hit_offset).distance_to(pos) < radius + 12.0:
		player.hurt(dmg, pos)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and (e.global_position + e.hit_offset).distance_to(pos) < radius + float(e.radius):
			e.take_damage(dmg, (e.global_position - pos).normalized() * 400.0)


func nearest_enemy(pos: Vector2, max_dist: float):
	var best = null
	var bd := max_dist
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = pos.distance_to(e.global_position + e.hit_offset)
		if d < bd:
			bd = d
			best = e
	return best


func kill_enemy(e) -> void:
	kills += 1
	var pos: Vector2 = e.global_position + e.hit_offset
	var col: Color = e.blood_color
	var rad: float = e.radius
	blood_burst(pos, col, 12 + int(rad))
	add_splat(e.global_position + Vector2(0, -4), rad * 2.4, col, "dirt_0%d" % randi_range(1, 3))
	add_fx_tex("smoke_0%d" % randi_range(1, 4), pos, 0.5, rad * 4.0, Color(col.lightened(0.2), 0.5), randf() * TAU, false)
	var total: float = float(e.souls_value) * float(player.stats["soul_mult"])
	var n := int(total) + (1 if randf() < total - floorf(total) else 0)
	for i in n:
		_add_pickup("soul", pos, 1)
	if randf() < 0.035:
		_add_pickup("heal", pos, 0)
	var kh: float = player.stats["kill_heal"]
	if kh > 0.0 and not player.dead:
		player.heal(kh)
	Sfx.play("die", -6.0)
	add_shake(1.0)
	e.queue_free()


func kill_boss(b) -> void:
	var pos: Vector2 = b.global_position + b.hit_offset
	kills += 1
	for i in 6:
		blood_burst(pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)), Color(0.55, 0.06, 0.08), 30)
	for i in 4:
		explosion(pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)), 90.0, 0.0)
	add_splat(b.global_position, 130.0, Color(0.4, 0.03, 0.05), "dirt_02")
	add_fx_tex("twirl_03", pos, 1.2, 600.0, Color(1.0, 0.4, 0.3, 0.9))
	add_shake(30.0)
	Sfx.play("roar", 0.0, 0.0)
	Sfx.play("bell", 0.0, 0.0)
	for i in 60:
		_add_pickup("soul", pos, 5)
	for i in bullets.size():
		if bullets[i].hostile:
			bullets[i].life = 0.0
	b.queue_free()
	boss = null
	show_banner("THE HOLLOW KING FALLS", "His reign is ended", 4.0)
	_open_portal(b.global_position)


func on_boss_phase(p: int) -> void:
	add_shake(14.0)
	Sfx.play("roar", -2.0, 0.0)
	if p == 2:
		show_banner("THE KING STIRS", "", 2.0)
	else:
		show_banner("THE KING IS WRATHFUL", "", 2.0)


func on_player_hurt(_amount: float) -> void:
	add_shake(7.0)
	hurt_flash = 1.0
	blood_burst(player.global_position + player.hit_offset, Color(0.6, 0.03, 0.05), 10)
	Sfx.play("hurt", -2.0)


func on_revive() -> void:
	var pos: Vector2 = player.global_position + player.hit_offset
	add_fx_tex("twirl_02", pos, 0.9, 300.0, Color(1.0, 0.35, 0.3, 0.9))
	show_banner("UNDYING", "The oath holds", 2.0)
	explosion(pos, 160.0, 60.0)


func on_player_died() -> void:
	phase = "dead"
	var pos: Vector2 = player.global_position + player.hit_offset
	blood_burst(pos, Color(0.6, 0.03, 0.05), 50)
	add_splat(player.global_position, 60.0, Color(0.5, 0.02, 0.04), "dirt_01")
	add_shake(20.0)
	Sfx.play("die", 0.0, 0.0)
	GameState.save_game()
	get_tree().create_timer(1.6).timeout.connect(_death_screen)


# --- Pickups -----------------------------------------------------------------

func _add_pickup(kind: String, pos: Vector2, value: int) -> void:
	if pickups.size() > 400:
		return
	var pk := Pickup.new()
	pk.kind = kind
	pk.pos = pos
	pk.value = value
	pk.vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 220.0)
	pickups.append(pk)


func _update_pickups(delta: float) -> void:
	var pp: Vector2 = player.global_position + Vector2(0, -24)
	var pr: float = player.stats["pickup_radius"]
	var vacuum := phase == "portal"
	var i := pickups.size() - 1
	while i >= 0:
		var pk: Pickup = pickups[i]
		pk.t += delta
		var to := pp - pk.pos
		var d := to.length()
		if not player.dead and pk.t > 0.35 and (d < pr or (vacuum and pk.kind == "soul")):
			pk.vel = pk.vel.lerp(to.normalized() * 650.0, 1.0 - exp(-delta * 8.0))
		else:
			pk.vel = pk.vel.move_toward(Vector2.ZERO, 420.0 * delta)
		pk.pos += pk.vel * delta
		if d < 26.0 and not player.dead and pk.t > 0.2:
			if pk.kind == "soul":
				GameState.souls += pk.value
				run_souls += pk.value
				Sfx.play("pickup", -14.0, 0.25)
			else:
				player.heal(20.0)
				add_fx_tex("circle_05", pp, 0.35, 90.0, Color(1.0, 0.3, 0.3, 0.8))
				Sfx.play("heal", -4.0, 0.0)
			pickups.remove_at(i)
		elif pk.t > 30.0:
			pickups.remove_at(i)
		i -= 1


# --- Effects -----------------------------------------------------------------

func add_fx_tex(tex_name: String, pos: Vector2, dur: float, size: float, color: Color, rot := 0.0, additive := true) -> void:
	var f := Fx.new()
	f.kind = "tex"
	f.tex = Art.fx(tex_name)
	f.pos = pos
	f.dur = dur
	f.r = size
	f.color = color
	f.a = rot
	f.additive = additive
	fxs.append(f)


func add_ghost(tex: Texture2D, pos: Vector2, flip: bool, scale: float) -> void:
	var f := Fx.new()
	f.kind = "ghost"
	f.tex = tex
	f.pos = pos
	f.dur = 0.28
	f.r = scale
	f.flip = flip
	f.additive = false
	f.color = Color(0.55, 0.45, 1.0, 0.6)
	fxs.append(f)


func damage_number(pos: Vector2, amount: float, crit: bool) -> void:
	var count := 0
	for f in fxs:
		if f.kind == "num":
			count += 1
	if count > 40:
		return
	var f := Fx.new()
	f.kind = "num"
	f.pos = pos + Vector2(randf_range(-10, 10), 0)
	f.dur = 0.6
	f.r = 2.0 if crit else 1.0
	f.color = Color(1.0, 0.85, 0.2) if crit else Color(1.0, 0.95, 0.9)
	f.text = str(int(round(amount)))
	f.additive = false
	fxs.append(f)


func _sparks(pos: Vector2, color: Color, n: int) -> void:
	add_fx_tex("spark_0%d" % randi_range(1, 7), pos, 0.12, 34.0, Color(color, 0.9), randf() * TAU)
	for i in n:
		var f := Fx.new()
		f.kind = "streak"
		f.pos = pos
		f.dur = randf_range(0.12, 0.22)
		f.r = randf_range(16.0, 34.0)
		f.a = randf() * TAU
		f.color = color
		fxs.append(f)


func _update_fx(delta: float) -> void:
	var i := fxs.size() - 1
	while i >= 0:
		var f: Fx = fxs[i]
		f.t += delta
		if f.t >= f.dur:
			fxs.remove_at(i)
		i -= 1


func blood_burst(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(4, amount if hq else amount / 2)
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 260.0
	p.damping_min = 200.0
	p.damping_max = 400.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.color_ramp = fade_grad
	particles_node.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func add_splat(pos: Vector2, size: float, color: Color, tex_name := "dirt_01") -> void:
	var c := color.darkened(0.2)
	c.a = minf(color.a, 0.85)
	splats.append([pos, size, c, tex_name, randf() * TAU])
	var cap := 260 if hq else 120
	while splats.size() > cap:
		splats.pop_front()
	decal_node.queue_redraw()
	ground_dirty = true


func show_banner(text: String, sub: String, dur: float) -> void:
	banner = text
	banner_sub = sub
	banner_t = dur


# --- Drawing -----------------------------------------------------------------

func _draw_floor() -> void:
	var n := floor_node
	var tint: Color = level["floor"]
	n.draw_rect(arena.grow(GROUND_MARGIN + 10.0), Color(0.02, 0.016, 0.02))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + level_index
	var cols := int(arena.size.x / TILE)
	var rows := int(arena.size.y / TILE)
	for gy in rows:
		for gx in cols:
			var tile_name := "floor_1"
			var roll := rng.randf()
			if roll > 0.62:
				tile_name = "floor_%d" % rng.randi_range(2, 8)
			var v := rng.randf_range(0.88, 1.0)
			n.draw_texture_rect(Art.tex(tile_name), Rect2(arena.position + Vector2(gx, gy) * TILE, Vector2(TILE, TILE)), false, Color(tint.r * v, tint.g * v, tint.b * v))
	# Scattered bones and skulls.
	for i in 22:
		var p := Vector2(rng.randf_range(arena.position.x + 40, arena.end.x - 60), rng.randf_range(arena.position.y + 60, arena.end.y - 60))
		n.draw_texture_rect(Art.tex("skull"), Rect2(p.snapped(Vector2(3, 3)), Vector2(TILE, TILE)), false, Color(0.9, 0.85, 0.8))
	# North wall: brick face with a cap row above it, banners every few tiles.
	var banner_tile: String = level["banner"]
	for gx in range(-1, cols + 1):
		var x := arena.position.x + gx * TILE
		var face := "wall_mid"
		if gx > 1 and gx < cols - 2 and gx % 7 == 3:
			face = banner_tile
		elif gx % 11 == 6:
			face = "wall_hole_1"
		n.draw_texture_rect(Art.tex(face), Rect2(x, arena.position.y - TILE, TILE, TILE), false)
		n.draw_texture_rect(Art.tex("wall_mid"), Rect2(x, arena.position.y - TILE * 2.0, TILE, TILE), false, Color(0.55, 0.5, 0.5))
		n.draw_texture_rect(Art.tex("wall_top_mid"), Rect2(x, arena.position.y - TILE * 3.0, TILE, TILE), false)
	# Soft shadow cast by the north wall onto the floor.
	for i in 6:
		n.draw_rect(Rect2(arena.position.x, arena.position.y + i * 6.0, arena.size.x, 6.0), Color(0, 0, 0, 0.35 - i * 0.055))
	# South wall cap and east/west side walls.
	for gx in range(-1, cols + 1):
		n.draw_texture_rect(Art.tex("wall_top_mid"), Rect2(arena.position.x + gx * TILE, arena.end.y - TILE * 0.5, TILE, TILE), false)
	for gy in range(-2, rows + 1):
		var y := arena.position.y + gy * TILE
		n.draw_texture_rect(Art.tex("wall_edge_mid_left"), Rect2(arena.position.x - TILE, y, TILE, TILE), false)
		n.draw_texture_rect(Art.tex("wall_edge_mid_right"), Rect2(arena.end.x, y, TILE, TILE), false)


func _draw_decals() -> void:
	for s in splats:
		var size: float = s[1]
		decal_node.draw_set_transform(s[0], s[4], Vector2.ONE)
		decal_node.draw_texture_rect(Art.fx(s[3]), Rect2(-size / 2.0, -size / 2.0, size, size), false, s[2])
	decal_node.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_bullets_spr() -> void:
	for b in bullets:
		if b.style == "knife" or b.style == "arrow":
			var tex: Texture2D = Art.tex("weapon_knife" if b.style == "knife" else "weapon_arrow")
			var rot: float = b.vel.angle() + PI / 2.0
			if b.style == "knife":
				rot += b.age * 28.0
			var sz := tex.get_size() * 2.5
			bullet_spr.draw_set_transform(b.pos, rot, Vector2.ONE)
			bullet_spr.draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false)
	bullet_spr.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_bullets_add() -> void:
	var glow := Art.fx("light_01")
	var wisp := Art.fx("magic_04")
	for b in bullets:
		var c: Color = b.color
		match b.style:
			"knife", "arrow":
				var tail: Vector2 = b.pos - b.vel.normalized() * minf(b.vel.length() * 0.035, 34.0)
				bullet_add.draw_line(tail, b.pos, Color(c, 0.35), 3.0)
			"ember":
				var s := 30.0 * (0.7 + 0.3 * sin(b.age * 40.0))
				bullet_add.draw_texture_rect(glow, Rect2(b.pos - Vector2(s, s) / 2.0, Vector2(s, s)), false, c)
				bullet_add.draw_circle(b.pos, 3.0, Color(1, 0.9, 0.6))
			"wisp":
				var s := 34.0
				bullet_add.draw_set_transform(b.pos, b.age * 10.0, Vector2.ONE)
				bullet_add.draw_texture_rect(wisp, Rect2(-s / 2.0, -s / 2.0, s, s), false, c)
				bullet_add.draw_set_transform_matrix(Transform2D.IDENTITY)
				bullet_add.draw_circle(b.pos, 3.0, Color(0.85, 1.0, 0.9))
			_:
				var s: float = b.r * 6.0
				bullet_add.draw_texture_rect(glow, Rect2(b.pos - Vector2(s, s) / 2.0, Vector2(s, s)), false, c)
				bullet_add.draw_circle(b.pos, b.r * 0.55, Color(1, 0.95, 0.9))


func _draw_pickups_add() -> void:
	var glow := Art.fx("light_01")
	for pk in pickups:
		var bob: float = sin(elapsed * 5.0 + pk.pos.x * 0.1) * 3.0
		var p: Vector2 = pk.pos + Vector2(0, bob)
		if pk.kind == "soul":
			var s: float = 26.0 + sin(elapsed * 9.0 + pk.pos.y) * 4.0
			pickup_add.draw_texture_rect(glow, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(0.35, 0.7, 1.0))
			pickup_add.draw_circle(p, 3.0, Color(0.8, 0.95, 1.0))
		else:
			pickup_add.draw_texture_rect(glow, Rect2(p - Vector2(24, 24), Vector2(48, 48)), false, Color(1.0, 0.25, 0.25, 0.7))


func _draw_pickups_spr() -> void:
	var flask := Art.tex("flask_red")
	for pk in pickups:
		if pk.kind == "heal":
			var p: Vector2 = pk.pos + Vector2(0, sin(elapsed * 5.0) * 3.0)
			pickup_spr.draw_texture_rect(flask, Rect2(p - Vector2(24, 30), Vector2(48, 48)), false)


func _draw_fx_norm() -> void:
	var font: Font = Art.font
	for f in fxs:
		if f.additive:
			continue
		var k: float = f.t / f.dur
		var c: Color = f.color
		match f.kind:
			"tex":
				var s: float = f.r * (0.6 + 0.4 * sqrt(k))
				fx_norm.draw_set_transform(f.pos, f.a + k * 0.6, Vector2.ONE)
				fx_norm.draw_texture_rect(f.tex, Rect2(-s / 2.0, -s / 2.0, s, s), false, Color(c, c.a * (1.0 - k)))
				fx_norm.draw_set_transform_matrix(Transform2D.IDENTITY)
			"ghost":
				var sz: Vector2 = f.tex.get_size() * f.r
				fx_norm.draw_set_transform(f.pos, 0.0, Vector2(-1.0 if f.flip else 1.0, 1.0))
				fx_norm.draw_texture_rect(f.tex, Rect2(-sz / 2.0, sz), false, Color(c, c.a * (1.0 - k)))
				fx_norm.draw_set_transform_matrix(Transform2D.IDENTITY)
			"num":
				var p: Vector2 = f.pos + Vector2(-50, -36.0 * k)
				var size := 30 if f.r > 1.0 else 22
				fx_norm.draw_string_outline(font, p, f.text, HORIZONTAL_ALIGNMENT_CENTER, 100, size, 6, Color(0, 0, 0, 1.0 - k))
				fx_norm.draw_string(font, p, f.text, HORIZONTAL_ALIGNMENT_CENTER, 100, size, Color(c, 1.0 - k))


func _draw_fx_add() -> void:
	for f in fxs:
		if not f.additive:
			continue
		var k: float = f.t / f.dur
		var c: Color = f.color
		match f.kind:
			"tex":
				var s: float = f.r * (0.7 + 0.3 * k)
				fx_add.draw_set_transform(f.pos, f.a, Vector2.ONE)
				fx_add.draw_texture_rect(f.tex, Rect2(-s / 2.0, -s / 2.0, s, s), false, Color(c, c.a * (1.0 - k)))
				fx_add.draw_set_transform_matrix(Transform2D.IDENTITY)
			"streak":
				var d := Vector2.from_angle(f.a)
				fx_add.draw_line(f.pos + d * f.r * k, f.pos + d * (f.r * k + 9.0), Color(c, 1.0 - k), 3.0)


func _draw_portal() -> void:
	var t := elapsed
	var tw1 := Art.fx("twirl_01")
	var tw3 := Art.fx("twirl_03")
	var glow := Art.fx("light_01")
	portal.draw_texture_rect(glow, Rect2(-90, -90, 180, 180), false, Color(0.5, 0.2, 0.9, 0.6))
	portal.draw_set_transform(Vector2.ZERO, t * 2.5, Vector2(1.0, 0.85))
	portal.draw_texture_rect(tw1, Rect2(-70, -70, 140, 140), false, Color(0.7, 0.4, 1.0, 0.9))
	portal.draw_set_transform(Vector2.ZERO, -t * 1.6, Vector2(1.0, 0.85))
	portal.draw_texture_rect(tw3, Rect2(-56, -56, 112, 112), false, Color(0.9, 0.6, 1.0, 0.8))
	portal.draw_set_transform_matrix(Transform2D.IDENTITY)
	var s := 26.0 + sin(t * 4.0) * 4.0
	portal.draw_texture_rect(glow, Rect2(-s, -s, s * 2.0, s * 2.0), false, Color(1, 0.9, 1, 0.9))


# --- Level flow --------------------------------------------------------------

func _open_portal(at: Vector2) -> void:
	phase = "portal"
	var pos := arena.get_center()
	if at != Vector2.INF:
		pos = at.clamp(arena.position + Vector2(100, 140), arena.end - Vector2(100, 100))
	else:
		var pp: Vector2 = player.global_position
		for i in 40:
			var c := Vector2(randf_range(arena.position.x + 200, arena.end.x - 200), randf_range(arena.position.y + 240, arena.end.y - 200))
			if c.distance_to(pp) > 450.0 and not _in_pillar(c, 90.0):
				pos = c
				break
		show_banner("THE GATE OPENS", "Reach the portal to escape", 3.0)
	portal = Node2D.new()
	portal.position = pos
	portal.material = Art.add_mat
	portal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portal.draw.connect(_draw_portal)
	var l := PointLight2D.new()
	l.texture = GameState.light_tex
	l.color = Color(0.6, 0.3, 1.0)
	l.energy = 1.4
	l.texture_scale = 2.2
	portal.add_child(l)
	world.add_child(portal)
	world.move_child(portal, entities.get_index())
	add_fx_tex("circle_05", pos, 0.8, 400.0, Color(0.7, 0.4, 1.0, 0.9))
	Sfx.play("portal", 0.0, 0.0)
	Sfx.play("bell", -6.0, 0.0)


func _complete() -> void:
	phase = "done"
	var first := GameState.levels_cleared <= level_index
	var bonus := (50 + level_index * 30) if first else (10 + level_index * 5)
	for pk in pickups:
		if pk.kind == "soul":
			bonus += pk.value
	pickups.clear()
	GameState.souls += bonus
	run_souls += bonus
	if first:
		GameState.levels_cleared = level_index + 1
	GameState.save_game()
	Sfx.play("door", 0.0, 0.0)
	if GameState.autotest:
		print("AUTOTEST: cleared level %d, kills %d, souls %d" % [level_index + 1, kills, run_souls])
		get_tree().quit()
		return
	var unlock := ""
	if first:
		for id in Data.WEAPON_ORDER:
			if int(Data.WEAPONS[id]["req"]) == level_index + 1:
				unlock = "\nNew weapon can be forged in the Armory: %s" % Data.WEAPONS[id]["name"]
	if is_boss_level():
		_show_overlay("THE HOLLOW REIGN ENDS", "The crown of bone lies shattered.\nSouls gathered this descent: %d\n\nReplay any gate to grow stronger." % run_souls,
			Color(1.0, 0.75, 0.35), [["Main Menu", func(): _go_menu("main")], ["Fight Again", _restart]])
	else:
		_show_overlay("GATE SEALED", "%s cleared  -  %d kills\nSouls this descent: %d (gate bonus %d)%s" % [level["name"], kills, run_souls, bonus, unlock],
			Color(1.0, 0.8, 0.4), [
				["Next Gate", func(): _start(level_index + 1)],
				["Skill Tree", func(): _go_menu("skills")],
				["Armory", func(): _go_menu("armory")],
				["Main Menu", func(): _go_menu("main")],
			])


func _death_screen() -> void:
	if GameState.autotest:
		get_tree().quit()
		return
	_show_overlay("YOU HAVE FALLEN", "Souls gathered this descent: %d\nThey remain yours. Spend them, and return stronger." % run_souls,
		Color(0.9, 0.15, 0.12), [
			["Rise Again", _restart],
			["Skill Tree", func(): _go_menu("skills")],
			["Armory", func(): _go_menu("armory")],
			["Main Menu", func(): _go_menu("main")],
		])


func _pause_menu() -> void:
	_show_overlay("PAUSED", "WASD move   Mouse aim / fire   Space dash   1-5 / Q E / wheel switch weapon",
		Color(0.9, 0.85, 0.78), [["Resume", _resume], ["Restart Gate", _restart], ["Abandon to Menu", func(): _go_menu("main")]])
	paused_menu = true


func _resume() -> void:
	if overlay:
		overlay.queue_free()
	overlay = null
	paused_menu = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _restart() -> void:
	GameState.save_game()
	main.start_level(level_index)


func _start(i: int) -> void:
	main.start_level(i)


func _go_menu(page: String) -> void:
	GameState.save_game()
	main.show_menu(page)


func _show_overlay(title: String, sub: String, title_color: Color, buttons: Array) -> void:
	if overlay:
		overlay.queue_free()
	get_tree().paused = true
	paused_menu = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = Control.new()
	overlay.theme = GameState.ui_theme
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	var tl := Label.new()
	tl.text = title
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 72)
	tl.add_theme_color_override("font_color", title_color)
	tl.add_theme_constant_override("outline_size", 12)
	v.add_child(tl)
	var sl := Label.new()
	sl.text = sub
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	v.add_child(sl)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	v.add_child(spacer)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 50)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func(): Sfx.play("click"))
		btn.pressed.connect(b[1])
		v.add_child(btn)
