extends CharacterBody2D
## The player: an animated pixel-art hero (skin chosen in the Wardrobe), movement, dash,
## weapons and health. The node origin is at the hero's feet so y-sorting works.

const Data = preload("res://scripts/data.gd")
const PX := 3.0

var game
var stats: Dictionary
var hp := 100.0
var radius := 13.0
var hit_offset := Vector2(0, -30)
var weapons: Array = []
var cur := 0
var cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var invuln := 0.0
var hurt_t := 0.0
var revived := false
var dead := false
var aim := Vector2.RIGHT
var face := 1.0
var recoil := 0.0
var swing := 0.0
var ghost_t := 0.0
var test_switch_t := 0.0
var hand_y := -30.0

var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var weapon_spr: Sprite2D
var light: PointLight2D
var muzzle_light: PointLight2D


func _ready() -> void:
	stats = GameState.get_stats()
	hp = stats["max_hp"]
	for id in Data.WEAPON_ORDER:
		if GameState.unlocked_weapons.has(id):
			weapons.append(id)
	if weapons.is_empty():
		weapons.append("pistol")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 11.0
	cs.shape = sh
	cs.position = Vector2(0, -10)
	add_child(cs)

	weapon_pivot = Node2D.new()
	add_child(weapon_pivot)
	weapon_spr = Sprite2D.new()
	weapon_spr.scale = Vector2(PX, PX)
	weapon_pivot.add_child(weapon_spr)

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames(GameState.skin)
	sprite.scale = Vector2(PX, PX)
	var h := float(Art.first_frame(GameState.skin).get_height())
	sprite.position = Vector2(0, -h * PX / 2.0 + 3.0)
	sprite.play("idle")
	add_child(sprite)
	hit_offset = Vector2(0, -h * PX * 0.42)
	hand_y = -h * PX * 0.3

	light = PointLight2D.new()
	light.texture = GameState.light_tex
	light.texture_scale = 3.6
	light.energy = 1.0
	light.color = Color(1.0, 0.86, 0.72)
	light.position = Vector2(0, -24)
	light.shadow_enabled = game.hq
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color(0, 0, 0, 0.8)
	add_child(light)
	muzzle_light = PointLight2D.new()
	muzzle_light.texture = GameState.light_tex
	muzzle_light.texture_scale = 1.5
	muzzle_light.energy = 0.0
	add_child(muzzle_light)
	_update_weapon_sprite()


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.45))


func _physics_process(delta: float) -> void:
	if dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var firing := Input.is_action_pressed("fire")
	if GameState.autotest:
		input = _autotest(delta)
		firing = true
	else:
		var to_mouse := get_global_mouse_position() - (global_position + Vector2(0, hand_y))
		if to_mouse.length() > 4.0:
			aim = to_mouse.normalized()

	cd -= delta
	dash_cd -= delta
	invuln -= delta
	hurt_t -= delta
	recoil = maxf(recoil - delta * 40.0, 0.0)
	swing = maxf(swing - delta * 5.0, 0.0)
	if float(stats["regen"]) > 0.0:
		heal(float(stats["regen"]) * delta)

	var speed: float = stats["move_speed"]
	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * speed * 3.4
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.03
			game.add_ghost(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame), sprite.global_position, sprite.flip_h, PX)
	else:
		velocity = velocity.lerp(input * speed, 1.0 - exp(-delta * 14.0))
		if (Input.is_action_just_pressed("dash") or (GameState.autotest and randf() < 0.01)) and dash_cd <= 0.0:
			dash_dir = input.normalized() if input != Vector2.ZERO else aim
			dash_t = 0.17
			dash_cd = stats["dash_cd"]
			invuln = maxf(invuln, 0.25)
			game.add_fx_tex("smoke_02", global_position + Vector2(0, -8), 0.4, 50.0, Color(0.6, 0.55, 0.7, 0.5), randf() * TAU, false)
			Sfx.play("dash", -4.0)
	move_and_slide()

	if firing and cd <= 0.0:
		_fire()
	_animate()


func _animate() -> void:
	if absf(aim.x) > 0.1:
		face = signf(aim.x)
	sprite.flip_h = face < 0.0
	var anim := "idle"
	if hurt_t > 0.0:
		anim = "hit"
	elif velocity.length() > 30.0:
		anim = "run"
	if sprite.animation != anim:
		sprite.play(anim)
	var blink := invuln > 0.0 and dash_t <= 0.0 and int(invuln * 20.0) % 2 == 0
	sprite.modulate = Color(2.0, 0.6, 0.6) if hurt_t > 0.0 else Color(1, 1, 1, 0.45 if blink else 1.0)

	var w: Dictionary = Data.WEAPONS[weapons[cur]]
	var ang := aim.angle()
	if w["kind"] == "melee":
		ang += lerpf(1.6, -1.6, swing) * face if swing > 0.0 else 0.9 * face
	weapon_pivot.position = Vector2(face * 5.0, hand_y)
	weapon_pivot.rotation = ang
	weapon_spr.position = Vector2(16.0 - recoil, 0)
	weapon_spr.rotation = 0.0 if w["hold"] == "bow" else PI / 2.0
	weapon_spr.flip_h = w["hold"] != "bow" and aim.x < 0.0
	# Draw the weapon behind the hero when aiming upward.
	var behind := aim.y < -0.35
	if behind and weapon_pivot.get_index() > sprite.get_index():
		move_child(weapon_pivot, sprite.get_index())
	elif not behind and weapon_pivot.get_index() < sprite.get_index():
		move_child(weapon_pivot, sprite.get_index())
	muzzle_light.energy = maxf(muzzle_light.energy - get_physics_process_delta_time() * 12.0, 0.0)
	muzzle_light.position = Vector2(0, hand_y) + aim * 30.0


func _update_weapon_sprite() -> void:
	weapon_spr.texture = Art.tex(Data.WEAPONS[weapons[cur]]["sprite"])


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_5:
			switch_weapon(k - KEY_1)
	if event.is_action_pressed("next_weapon"):
		switch_weapon((cur + 1) % weapons.size())
	elif event.is_action_pressed("prev_weapon"):
		switch_weapon((cur - 1 + weapons.size()) % weapons.size())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon((cur + 1) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_weapon((cur - 1 + weapons.size()) % weapons.size())


func switch_weapon(i: int) -> void:
	if i < 0 or i >= weapons.size() or i == cur:
		return
	cur = i
	cd = maxf(cd, 0.12)
	_update_weapon_sprite()
	Sfx.play("click", -6.0)


func _fire() -> void:
	var w: Dictionary = Data.WEAPONS[weapons[cur]]
	cd = 1.0 / (float(w["rate"]) * float(stats["fire_rate_mult"]))
	var hand := global_position + Vector2(0, hand_y)
	var muzzle := hand + aim * 34.0
	if w["kind"] == "melee":
		game.melee_attack(hand, aim, w, stats)
		swing = 1.0
	else:
		var count: int = w["count"]
		var spread: float = w["spread"]
		var dmg: float = float(w["damage"]) * float(stats["damage_mult"])
		for i in count:
			var ang := aim.angle()
			if count > 1:
				ang += lerpf(-spread, spread, float(i) / float(count - 1)) + randf_range(-0.04, 0.04)
			else:
				ang += randf_range(-spread, spread)
			var crit := randf() < float(stats["crit"])
			var spd: float = float(w["speed"]) * randf_range(0.92, 1.08)
			game.spawn_bullet(muzzle, Vector2.from_angle(ang) * spd, dmg * (2.0 if crit else 1.0), crit,
				int(w["pierce"]) + int(stats["pierce"]), float(w["life"]), w["color"], float(w["width"]),
				w["kind"] == "homing", w["proj"])
		muzzle_light.energy = 1.3
		muzzle_light.color = w["color"]
		recoil = 6.0
		velocity -= aim * float(w["shake"]) * 14.0
		if w["proj"] != "knife" and w["proj"] != "arrow":
			game.add_fx_tex("muzzle_0%d" % randi_range(1, 5), muzzle + aim * 6.0, 0.08, 40.0, Color(w["color"], 0.9), aim.angle())
	game.add_shake(float(w["shake"]))
	Sfx.play(w["sound"], -4.0)


func hurt(amount: float, from: Vector2) -> void:
	if dead or invuln > 0.0 or GameState.autotest:
		return
	amount *= 1.0 - float(stats["armor"])
	hp -= amount
	invuln = 0.7
	hurt_t = 0.2
	velocity += (global_position - from).normalized() * 380.0
	game.on_player_hurt(amount)
	if hp <= 0.0:
		if stats["revive"] and not revived:
			revived = true
			hp = float(stats["max_hp"]) * 0.5
			invuln = 2.0
			game.on_revive()
		else:
			hp = 0.0
			dead = true
			visible = false
			game.on_player_died()


func heal(amount: float) -> void:
	hp = minf(hp + amount, float(stats["max_hp"]))


func _autotest(delta: float) -> Vector2:
	test_switch_t -= delta
	if test_switch_t <= 0.0:
		test_switch_t = 3.0
		switch_weapon((cur + 1) % weapons.size())
	var tgt = game.nearest_enemy(global_position, 2000.0)
	if tgt != null:
		aim = (tgt.global_position + tgt.hit_offset - (global_position + Vector2(0, hand_y))).normalized()
	if game.portal:
		return (game.portal.global_position - global_position).normalized()
	return Vector2.from_angle(game.elapsed * 0.6)
