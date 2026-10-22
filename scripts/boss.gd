extends CharacterBody2D
## The Hollow King: a crowned demon lord with three phases of bullet rings, spirals,
## summons and charges. Drawn with the big_demon sprite; origin at its feet.

const PX := 4.5

var game
var kind := "boss"
var max_hp := 2200.0
var hp := 2200.0
var radius := 56.0
var hit_offset := Vector2(0, -72)
var dead := false
var flash := 0.0
var t := 0.0
var state := "rise"
var state_t := 2.0
var attack_cd := 2.0
var cur_phase := 1
var face := Vector2.DOWN
var charge_dir := Vector2.DOWN
var spiral_a := 0.0
var shot_t := 0.0
var souls_value := 0
var blood_color := Color(0.45, 0.06, 0.08)
var sprite: AnimatedSprite2D
var glow: Node2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius * 0.6
	cs.shape = sh
	cs.position = Vector2(0, -radius * 0.5)
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("big_demon")
	sprite.scale = Vector2(PX, PX)
	var h := float(Art.first_frame("big_demon").get_height())
	sprite.position = Vector2(0, -h * PX / 2.0 + 3.0)
	sprite.play("idle")
	add_child(sprite)
	hit_offset = Vector2(0, -h * PX * 0.45)
	var light := PointLight2D.new()
	light.texture = GameState.light_tex
	light.texture_scale = 2.6
	light.energy = 0.9
	light.color = Color(1.0, 0.35, 0.3)
	light.position = hit_offset
	add_child(light)
	var aura := CPUParticles2D.new()
	aura.material = Art.add_mat
	aura.texture = Art.fx("magic_02")
	aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	aura.amount = 20 if game.hq else 8
	aura.lifetime = 1.4
	aura.position = hit_offset
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = radius * 0.8
	aura.direction = Vector2.UP
	aura.spread = 25.0
	aura.gravity = Vector2(0, -60)
	aura.initial_velocity_min = 10.0
	aura.initial_velocity_max = 40.0
	aura.angle_min = 0.0
	aura.angle_max = 360.0
	aura.scale_amount_min = 0.12
	aura.scale_amount_max = 0.25
	aura.color = Color(1.0, 0.35, 0.25, 0.7)
	aura.color_ramp = game.fade_grad
	aura.local_coords = false
	add_child(aura)
	glow = Node2D.new()
	glow.material = Art.add_mat
	glow.draw.connect(_draw_glow)
	add_child(glow)
	modulate.a = 0.0


func _draw() -> void:
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.5))


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	var p = game.player
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var center := global_position + hit_offset
	var aim_dir: Vector2 = (p.global_position + p.hit_offset - center).normalized()
	if state != "charge":
		face = face.slerp(dir, 1.0 - exp(-delta * 5.0))
	var new_phase := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if new_phase != cur_phase:
		cur_phase = new_phase
		game.on_boss_phase(cur_phase)
		state = "summon"
		state_t = 0.8
	state_t -= delta
	match state:
		"rise":
			modulate.a = clampf(1.0 - state_t / 2.0, 0.0, 1.0)
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				_to_chase(1.2)
		"chase":
			velocity = dir * (60.0 + cur_phase * 25.0)
			attack_cd -= delta
			if attack_cd <= 0.0:
				_choose_attack()
		"ring":
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				_ring()
				if cur_phase >= 3:
					state = "ring2"
					state_t = 0.35
				else:
					_to_chase()
		"ring2":
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				_ring()
				_to_chase()
		"spiral":
			velocity = dir * 25.0
			shot_t -= delta
			if shot_t <= 0.0:
				shot_t = 0.08
				var arms := 2 + cur_phase
				for k in arms:
					var d := Vector2.from_angle(spiral_a + TAU * k / arms)
					game.spawn_enemy_bullet(center + d * radius * 0.6, d * 210.0, 11.0, Color(1.0, 0.35, 0.3))
				spiral_a += 0.22
				Sfx.play("boss_shot", -14.0)
			if state_t <= 0.0:
				_to_chase()
		"telegraph":
			velocity = Vector2.ZERO
			if state_t > 0.25:
				charge_dir = aim_dir
			if state_t <= 0.0:
				state = "charge"
				state_t = 0.6
				Sfx.play("dash", 2.0, 0.0)
		"charge":
			velocity = charge_dir * 780.0
		"summon":
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				for i in 2 + cur_phase:
					var kinds := ["shambler", "runner", "runner", "exploder"]
					game.spawn_enemy(kinds.pick_random(), global_position + Vector2.from_angle(randf() * TAU) * randf_range(110.0, 170.0))
				_to_chase()
	move_and_slide()
	if state == "charge" and (state_t <= 0.0 or get_slide_collision_count() > 0):
		game.add_shake(12.0)
		game.add_fx_tex("circle_05", global_position, 0.5, 320.0, Color(1.0, 0.4, 0.3, 0.8))
		game.add_fx_tex("smoke_03", global_position, 0.7, 260.0, Color(0.4, 0.35, 0.35, 0.6), randf() * TAU, false)
		Sfx.play("thud", 0.0)
		if cur_phase >= 3:
			_ring()
		_to_chase(0.9)

	if state != "rise" and not p.dead and dist < radius + float(p.radius):
		p.hurt(30.0 if state == "charge" else 20.0, global_position)

	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0.0
	var anim := "run" if velocity.length() > 20.0 else "idle"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 1.6 if state == "charge" else 1.0
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(4, 4, 4)
	elif state == "telegraph" or cur_phase >= 3:
		var pulse := 0.5 + 0.5 * sin(t * (30.0 if state == "telegraph" else 6.0))
		sprite.modulate = Color(1.0 + pulse * 0.8, 1.0 - pulse * 0.3, 1.0 - pulse * 0.3)
	else:
		sprite.modulate = Color.WHITE
	glow.queue_redraw()


func _to_chase(cd := -1.0) -> void:
	state = "chase"
	attack_cd = cd if cd >= 0.0 else 2.6 - cur_phase * 0.45


func _choose_attack() -> void:
	var opts := ["ring", "ring", "summon"]
	if cur_phase >= 2:
		opts = ["ring", "spiral", "spiral", "summon"]
	if cur_phase >= 3:
		opts = ["ring", "spiral", "charge", "charge", "summon"]
	match opts.pick_random():
		"ring":
			state = "ring"
			state_t = 0.5
		"spiral":
			state = "spiral"
			state_t = 2.0 + cur_phase * 0.4
		"summon":
			state = "summon"
			state_t = 0.8
			game.add_fx_tex("twirl_02", global_position + hit_offset, 0.8, 260.0, Color(0.8, 0.3, 1.0, 0.8))
		"charge":
			state = "telegraph"
			state_t = 0.85
			Sfx.play("roar", -6.0, 0.15)


func _ring() -> void:
	var n := 16 + cur_phase * 6
	var off := randf() * TAU
	var center := global_position + hit_offset
	for i in n:
		var d := Vector2.from_angle(off + TAU * i / n)
		game.spawn_enemy_bullet(center + d * radius * 0.6, d * (200.0 + cur_phase * 35.0), 12.0, Color(1.0, 0.3, 0.35))
	game.add_fx_tex("circle_05", center, 0.35, 180.0, Color(1.0, 0.3, 0.3, 0.7))
	Sfx.play("boss_shot", -2.0)


func take_damage(amount: float, _kdir: Vector2, crit := false) -> void:
	if dead or state == "rise":
		return
	hp -= amount
	flash = 0.05
	game.damage_number(global_position + hit_offset + Vector2(0, -radius), amount, crit)
	Sfx.play("hit", -8.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		game.kill_boss(self)


func _draw_glow() -> void:
	if state == "telegraph":
		var a := 0.2 + 0.15 * sin(t * 30.0)
		glow.draw_line(hit_offset, hit_offset + charge_dir * 900.0, Color(1.0, 0.15, 0.1, a), radius * 1.2)
		glow.draw_line(hit_offset, hit_offset + charge_dir * 900.0, Color(1.0, 0.4, 0.3, a), 4.0)
