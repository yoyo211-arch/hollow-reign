extends CharacterBody2D
## A regular monster: shambler, runner, spitter, brute or exploder, drawn as an animated
## pixel-art sprite. The node origin is at its feet; hit_offset points at its body centre.

const Data = preload("res://scripts/data.gd")

var game
var kind := "shambler"
var hp := 30.0
var max_hp := 30.0
var speed := 80.0
var dmg := 10.0
var radius := 15.0
var souls_value := 1
var knock_res := 1.0
var blood_color := Color.DARK_RED
var sprite_name := "skelet"
var px := 3.0
var hit_offset := Vector2(0, -24)
var dead := false
var flash := 0.0
var t := 0.0
var spawn_t := 0.0
var shoot_cd := 2.0
var fuse := -1.0
var strafe := 1.0
var knock := Vector2.ZERO
var face := Vector2.RIGHT
var sprite: AnimatedSprite2D


func setup(k: String, hp_mult: float) -> void:
	kind = k
	var d: Dictionary = Data.ENEMIES[k]
	max_hp = float(d["hp"]) * hp_mult
	hp = max_hp
	speed = float(d["speed"]) * randf_range(0.9, 1.1)
	dmg = d["dmg"]
	radius = d["radius"]
	souls_value = d["souls"]
	knock_res = d["knock"]
	blood_color = d["blood"]
	px = d["scale"]
	sprite_name = d["sprites"].pick_random()
	t = randf() * 10.0
	strafe = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius * 0.7
	cs.shape = sh
	cs.position = Vector2(0, -radius * 0.5)
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames(sprite_name)
	sprite.scale = Vector2(px, px)
	var h := float(Art.first_frame(sprite_name).get_height())
	sprite.position = Vector2(0, -h * px / 2.0 + 2.0)
	sprite.play("run")
	sprite.frame = randi() % 4
	add_child(sprite)
	hit_offset = Vector2(0, -h * px * 0.45)
	modulate.a = 0.0


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.0, Color(0, 0, 0, 0.45))


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	spawn_t += delta
	if modulate.a < 1.0:
		modulate.a = minf(1.0, spawn_t * 3.0)
	var p = game.player
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	face = dir
	var want := dir * speed
	if p.dead:
		want = -dir * speed * 0.3
	else:
		match kind:
			"runner":
				want = (dir + dir.orthogonal() * sin(t * 5.0) * 0.5).normalized() * speed
			"spitter":
				if dist < 230.0:
					want = -dir * speed
				elif dist < 360.0:
					want = dir.orthogonal() * speed * 0.7 * strafe
				shoot_cd -= delta
				if shoot_cd <= 0.0 and dist < 620.0 and spawn_t > 1.0:
					shoot_cd = randf_range(1.8, 2.6)
					var from := global_position + hit_offset
					var aim: Vector2 = (p.global_position + p.hit_offset - from).normalized()
					game.spawn_enemy_bullet(from + aim * radius, aim * 290.0, dmg, Color(0.55, 1.0, 0.3))
					Sfx.play("spit", -6.0)
			"exploder":
				if fuse < 0.0 and dist < 60.0:
					fuse = 0.45
				if fuse >= 0.0:
					fuse -= delta
					want = Vector2.ZERO
					if fuse <= 0.0:
						dead = true
						game.explosion(global_position + hit_offset, 95.0, dmg)
						game.kill_enemy(self)
						return
	velocity = want + knock
	knock = knock.move_toward(Vector2.ZERO, 2000.0 * delta)
	move_and_slide()

	if kind != "exploder" and spawn_t > 0.35 and not p.dead and dist < radius + float(p.radius) + 2.0:
		p.hurt(dmg, global_position)

	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0.0
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(4, 4, 4)
	elif fuse >= 0.0:
		var pulse := 0.5 + 0.5 * sin(t * 40.0)
		sprite.modulate = Color(1.0 + pulse * 2.0, 1.0 + pulse * 0.6, 0.6)
		sprite.scale = Vector2(px, px) * (1.0 + (0.45 - fuse) * 0.5)
	else:
		sprite.modulate = Color.WHITE


func take_damage(amount: float, kdir: Vector2, crit := false) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.06
	knock += kdir * knock_res
	game.damage_number(global_position + hit_offset + Vector2(0, -radius), amount, crit)
	Sfx.play("hit", -8.0)
	if hp <= 0.0:
		dead = true
		if kind == "exploder":
			game.explosion(global_position + hit_offset, 80.0, dmg * 0.5)
		game.kill_enemy(self)
