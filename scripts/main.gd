extends Node
## Root scene: swaps between the menu and a running level.
## Debug args (after `--`): --level=N starts a level, --autotest plays it automatically,
## --shot=SECONDS saves a screenshot to user:// and quits.

const MenuScript = preload("res://scripts/menu.gd")
const GameScript = preload("res://scripts/game.gd")

var current: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest":
			GameState.enable_autotest()
		elif a == "--low":
			GameState.settings["quality"] = 0
		elif a == "--top":
			GameState.debug_top = true
		elif a.begins_with("--shot="):
			get_tree().create_timer(float(a.get_slice("=", 1))).timeout.connect(_screenshot)
	for a in args:
		if a.begins_with("--level="):
			start_level(int(a.get_slice("=", 1)))
			return
		if a.begins_with("--page="):
			show_menu(a.get_slice("=", 1))
			return
	show_menu()


func _screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://shot.png"
	if current and "level_index" in current:
		path = "user://shot_level%d.png" % current.level_index
	elif current:
		path = "user://shot_menu.png"
	img.save_png(path)
	print("Saved screenshot: ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func show_menu(page := "main") -> void:
	get_tree().paused = false
	var m := MenuScript.new()
	m.main = self
	m.page = page
	_swap(m)


func start_level(i: int) -> void:
	get_tree().paused = false
	var g := GameScript.new()
	g.main = self
	g.level_index = clampi(i, 0, 5)
	_swap(g)
