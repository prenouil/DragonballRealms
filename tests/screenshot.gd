# Lance le jeu et enregistre une capture d'écran.
# Lancer : Godot --path . --script res://tests/screenshot.gd -- <fichier.png> [secondes]
# Variables :
#   SHOT_SEED  : graine de la partie (sinon au hasard)
#   SHOT_AUTOPLAY=1 : le joueur humain joue tout seul (pioche, défausse la 1re carte, répond aux
#                     questions) et la capture est prise 1,5 s après la fin de la partie.
#   SHOT_SPEED : pause des ordinateurs en secondes (défaut 0,9)
extends SceneTree

const Main = preload("res://scripts/main.gd")

var _out := "user://screenshot.png"
var _wait := 2.0
var _autoplay := false
var _over_since := -1.0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_wait = float(args[1])
	_autoplay = OS.has_environment("SHOT_AUTOPLAY")
	if OS.has_environment("SHOT_SEED"):
		Main.autostart_seed = int(OS.get_environment("SHOT_SEED"))
	if OS.has_environment("SHOT_SPEED"):
		Main.bot_delay_override = float(OS.get_environment("SHOT_SPEED"))
	change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> bool:
	if _autoplay:
		_play()
		if _over_since >= 0.0:
			_over_since += delta
			if _over_since > 1.5:
				_capture()
		return false
	_wait -= delta
	if _wait <= 0.0:
		_capture()
	return false


func _play() -> void:
	var main := current_scene
	if main == null or not main.get("game"):
		return
	var game: Node = main.game
	if not game.choice_requested.is_connected(_on_choice):
		game.choice_requested.connect(_on_choice)
	if game.phase == "over" and _over_since < 0.0:
		_over_since = 0.0
	if game.current != 0:
		return
	if game.phase == "draw":
		game.human_draw_deck(0)
	elif game.phase == "discard":
		game.human_discard(0, game.hands[0][0])


func _on_choice(kind: String, data: Dictionary) -> void:
	var main := current_scene
	var value = false
	match kind:
		"detector":
			value = data.options[0]
		"end_mask", "end_take":
			value = -1
		"sangoku":
			value = true
	# Ferme la fenêtre de question comme le ferait un clic.
	main.call_deferred("_close_dialog", value)


func _capture() -> void:
	root.get_texture().get_image().save_png(_out)
	quit()
