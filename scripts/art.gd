extends Node
## Loads and caches the pixel-art sprites (0x72 DungeonTileset II), Kenney effect
## textures and the pixel font, and builds SpriteFrames for animated characters.

const SPRITES := "res://assets/dungeon/"
const FX := "res://assets/fx/"
## World pixels per art pixel. Everything pixel-art is drawn at this integer scale.
const PX := 3.0

var font: FontFile
var add_mat: CanvasItemMaterial
var unshaded_mat: CanvasItemMaterial
var _tex := {}
var _frames := {}


func _ready() -> void:
	font = load("res://assets/fonts/Kenney Pixel.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	unshaded_mat = CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED


func tex(sprite_name: String) -> Texture2D:
	var key := SPRITES + sprite_name
	if not _tex.has(key):
		_tex[key] = load(SPRITES + sprite_name + ".png")
	return _tex[key]


func fx(fx_name: String) -> Texture2D:
	var key := FX + fx_name
	if not _tex.has(key):
		_tex[key] = load(FX + fx_name + ".png")
	return _tex[key]


func has_sprite(sprite_name: String) -> bool:
	return ResourceLoader.exists(SPRITES + sprite_name + ".png")


## Builds "idle", "run" and "hit" animations from <name>_idle_anim_fN / <name>_run_anim_fN /
## <name>_hit_anim_f0, falling back to <name>_anim_fN for single-animation creatures.
func frames(char_name: String) -> SpriteFrames:
	if _frames.has(char_name):
		return _frames[char_name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fallback := _load_seq(char_name + "_anim_f")
	for anim in ["idle", "run"]:
		var seq := _load_seq("%s_%s_anim_f" % [char_name, anim])
		if seq.is_empty():
			seq = fallback
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 7.0 if anim == "idle" else 11.0)
		for t in seq:
			sf.add_frame(anim, t)
	sf.add_animation("hit")
	sf.set_animation_loop("hit", false)
	var hit := _load_seq("%s_hit_anim_f" % char_name)
	if hit.is_empty():
		hit = [sf.get_frame_texture("idle", 0)]
	for t in hit:
		sf.add_frame("hit", t)
	_frames[char_name] = sf
	return sf


func first_frame(char_name: String) -> Texture2D:
	return frames(char_name).get_frame_texture("idle", 0)


func _load_seq(prefix: String) -> Array:
	var out := []
	for i in 8:
		var path := SPRITES + prefix + str(i) + ".png"
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
	return out
