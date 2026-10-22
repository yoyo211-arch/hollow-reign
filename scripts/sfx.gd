extends Node
## Procedurally synthesised sound effects and ambient music, so no audio files are needed.

const RATE := 22050
const MUSIC_RATE := 11025

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var last_played := {}
var music_player: AudioStreamPlayer
var music_tracks := {}
var current_track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -6.0
	add_child(music_player)
	_build_sounds()
	music_tracks["calm"] = _make_music(false)
	music_tracks["boss"] = _make_music(true)


func play(sound: String, vol_db := 0.0, pitch_var := 0.08) -> void:
	if not sounds.has(sound):
		return
	# Throttle so a crowd dying at once doesn't turn into noise.
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(sound, -1000)) < 35:
		return
	last_played[sound] = now
	var p := players[next]
	next = (next + 1) % players.size()
	var s = sounds[sound]
	p.stream = s.pick_random() if s is Array else s
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func music(boss: bool) -> void:
	var id := "boss" if boss else "calm"
	if current_track == id:
		return
	current_track = id
	music_player.stream = music_tracks[id]
	music_player.play()


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _saw(p: float) -> float:
	return 2.0 * (p - floorf(p + 0.5))


func _build_sounds() -> void:
	sounds["shoot"] = _synth(0.16, func(t): return _noise() * exp(-t * 30.0) * 0.6 + sin(TAU * (240.0 - t * 700.0) * t) * exp(-t * 20.0) * 0.6, 0.6)
	sounds["shotgun"] = _synth(0.35, func(t): return _noise() * exp(-t * 10.0) * 0.9 + sin(TAU * 70.0 * t) * exp(-t * 12.0) * 0.7, 0.35)
	sounds["bow"] = _synth(0.2, func(t): return sin(TAU * (500.0 - t * 1200.0) * t) * exp(-t * 18.0) * 0.5 + _noise() * exp(-t * 60.0) * 0.4, 0.7)
	sounds["slash"] = _synth(0.25, func(t): return _noise() * sin(PI * t / 0.25) * 0.9, 0.22)
	sounds["hex"] = _synth(0.16, func(t): return sin(TAU * (700.0 + t * 2500.0) * t) * exp(-t * 16.0) * 0.3 + _noise() * exp(-t * 30.0) * 0.15, 0.8)
	sounds["hit"] = _synth(0.09, func(t): return sin(TAU * 150.0 * t) * exp(-t * 45.0) * 0.8 + _noise() * exp(-t * 70.0) * 0.4, 0.5)
	sounds["die"] = _synth(0.4, func(t): return _noise() * exp(-t * 8.0) * 0.8 + sin(TAU * (120.0 - t * 120.0) * t) * exp(-t * 9.0) * 0.5, 0.18)
	sounds["hurt"] = _synth(0.3, func(t): return signf(sin(TAU * (200.0 - t * 260.0) * t)) * exp(-t * 9.0) * 0.35, 0.4)
	sounds["pickup"] = _synth(0.12, func(t): return sin(TAU * (1100.0 + t * 2600.0) * t) * exp(-t * 22.0) * 0.3)
	sounds["dash"] = _synth(0.25, func(t): return _noise() * sin(PI * t / 0.25) * 0.8, 0.12)
	sounds["explode"] = _synth(0.8, func(t): return _noise() * exp(-t * 5.0) + sin(TAU * 45.0 * t) * exp(-t * 5.0) * 0.8, 0.12)
	sounds["roar"] = _synth(1.5, func(t): return ((_saw(55.0 * t) + _saw(58.3 * t) + _saw(82.0 * t) * 0.6) * 0.3 * (0.7 + 0.3 * sin(TAU * 9.0 * t)) + _noise() * 0.25) * sin(PI * t / 1.5), 0.15)
	sounds["portal"] = _synth(1.0, func(t): return (sin(TAU * (220.0 + t * 110.0) * t) + sin(TAU * (330.0 + t * 165.0) * t) * 0.6 + sin(TAU * (440.0 + t * 220.0) * t) * 0.4) * 0.25 * sin(PI * t), 0.6)
	sounds["click"] = _synth(0.06, func(t): return sin(TAU * 700.0 * t) * exp(-t * 80.0) * 0.4)
	sounds["boss_shot"] = _synth(0.3, func(t): return sin(TAU * (260.0 - t * 300.0) * t) * exp(-t * 10.0) * 0.5 + _noise() * exp(-t * 25.0) * 0.3, 0.4)
	sounds["spit"] = _synth(0.18, func(t): return _noise() * exp(-t * 20.0) * 0.6 + sin(TAU * (400.0 - t * 900.0) * t) * exp(-t * 20.0) * 0.3, 0.3)
	# Recorded foley (Kenney RPG Audio / Impact Sounds / Interface Sounds, CC0) where it fits.
	_files("shoot", ["knifeSlice", "knifeSlice2", "drawKnife3"])
	_files("bow", ["drawKnife1", "drawKnife2"])
	_files("slash", ["chop", "knifeSlice2"])
	_files("hit", ["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002"])
	_files("die", ["impactSoft_heavy_000", "impactSoft_heavy_001", "impactSoft_heavy_002"])
	_files("hurt", ["impactPunch_heavy_000", "impactPunch_heavy_001"])
	_files("pickup", ["impactGlass_light_000", "impactGlass_light_001"])
	_files("heal", ["confirmation_002"])
	_files("dash", ["cloth1", "cloth2"])
	_files("click", ["click_002"])
	_files("buy", ["handleCoins", "handleCoins2"])
	_files("bell", ["impactBell_heavy_000"])
	_files("door", ["doorOpen_1"])
	_files("parry", ["impactMetal_light_000", "impactMetal_light_001"])
	_files("thud", ["impactWood_heavy_000", "impactMining_000"])


func _files(sound: String, names: Array) -> void:
	var list := []
	for n in names:
		var path := "res://assets/sfx/%s.ogg" % n
		if ResourceLoader.exists(path):
			list.append(load(path))
	if not list.is_empty():
		sounds[sound] = list


## Renders fn(t) into a 16-bit mono clip, with a one-pole lowpass (lp = 1.0 means none).
func _synth(dur: float, fn: Callable, lp := 1.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var x: float = fn.call(t)
		y += (x - y) * lp
		var fade := minf(1.0, float(n - i) / 200.0)
		data.encode_s16(i * 2, int(clampf(y * fade, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## A seamless 8 second drone loop; every frequency completes whole cycles in 8 s.
func _make_music(boss: bool) -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * MUSIC_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var root := 49.0 if boss else 55.0
	var third := 58.25 if boss else 65.5
	var wind := 0.0
	for i in n:
		var t := float(i) / MUSIC_RATE
		var swell := 0.6 + 0.4 * sin(TAU * t / 8.0)
		var v := sin(TAU * root * t) * 0.28
		v += sin(TAU * root * 1.5 * t) * 0.14 * swell
		v += sin(TAU * third * t) * 0.1 * (1.0 - swell * 0.5)
		v += sin(TAU * root * 2.0 * t) * 0.05
		wind += (randf() * 2.0 - 1.0 - wind) * 0.06
		v += wind * 1.2 * (0.5 + 0.5 * sin(TAU * t / 4.0 + 1.0))
		if boss:
			var bt := fmod(t, 1.0)
			var beat := exp(-bt * 14.0)
			if bt >= 0.28:
				beat += exp(-(bt - 0.28) * 18.0) * 0.7
			v += sin(TAU * 50.0 * t) * beat * 0.7
		data.encode_s16(i * 2, int(clampf(v * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MUSIC_RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
