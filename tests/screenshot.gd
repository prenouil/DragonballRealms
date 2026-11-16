# Lance le jeu et enregistre une capture d'écran.
# Lancer : Godot --path . --script res://tests/screenshot.gd -- <fichier.png> [secondes]
# Variables :
#   SHOT_SEED  : graine de la partie (sinon au hasard)
#   SHOT_AUTOPLAY=1 : le joueur humain joue tout seul (pioche, défausse la 1re carte, répond aux
#                     questions) et la capture est prise 1,5 s après la fin de la partie.
#   SHOT_SPEED : pause des ordinateurs en secondes (défaut 0,9)
#   SHOT_HAND="37,44,52" : cartes données au joueur au début (échangées avec sa main)
#   SHOT_CHOICES=1 : en partie automatique, s'arrête aux choix du décompte et les photographie ;
#                    SHOT_CHOICES=picker : ouvre aussi la fenêtre du premier choix.
extends SceneTree

const Main = preload("res://scripts/main.gd")

var _out := "user://screenshot.png"
var _wait := 2.0
var _autoplay := false
var _over_since := -1.0
var _main: Node
var _hand_done := false
var _timed := false  # partie automatique : capture à [secondes] si elles sont données
var _choices_since := -1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_wait = float(args[1])
		_timed = true
	_autoplay = OS.has_environment("SHOT_AUTOPLAY")
	if OS.has_environment("SHOT_SEED"):
		Main.autostart_seed = int(OS.get_environment("SHOT_SEED"))
	if OS.has_environment("SHOT_SPEED"):
		Main.bot_delay_override = float(OS.get_environment("SHOT_SPEED"))
	change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> bool:
	if _autoplay:
		_play()
		if _timed:
			_wait -= delta
			if OS.has_environment("SHOT_EVERY"):
				_series(delta)
			if _wait <= 0.0:
				_capture()
				return false
		if _choices_since >= 0.0:
			_choices_since += delta
			if _choices_since > 1.2:
				_capture()
			return false
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
	if not _hand_done and game.hands.size() > 0:
		_hand_done = true
		if OS.has_environment("SHOT_HAND"):
			_give_hand(game, OS.get_environment("SHOT_HAND").split(","))
	if game.phase == "over" and _over_since < 0.0:
		_over_since = 0.0
	if game.current != 0:
		return
	if game.phase == "draw":
		game.human_draw_deck(0)
	elif game.phase == "discard":
		var keep := OS.get_environment("SHOT_HAND").split(",") if OS.has_environment("SHOT_HAND") else PackedStringArray()
		var drop: int = game.hands[0][0]
		for c in game.hands[0]:
			if not keep.has(str(c)):
				drop = c
				break
		game.human_discard(0, drop)


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
		"scoring":
			if OS.has_environment("SHOT_CHOICES"):
				_choices_since = 0.0
				if OS.get_environment("SHOT_CHOICES") == "picker":
					main.choices.call_deferred("_open_picker", 0)
				return
			value = load("res://scripts/scoring.gd").best(data.hand, data.ctx).choices
	# Ferme la fenêtre de question comme le ferait un clic.
	main.call_deferred("auto_answer", value)


# SHOT_EVERY=0.2 : une capture toutes les 0,2 s jusqu'à [secondes] (<fichier>_000.png, …).
var _series_left := 0.0
var _series_n := 0


func _series(delta: float) -> void:
	_series_left -= delta
	if _series_left > 0.0:
		return
	_series_left = float(OS.get_environment("SHOT_EVERY"))
	root.get_texture().get_image().save_png(_out.get_basename() + "_%03d.png" % _series_n)
	_series_n += 1


# Échange des cartes pour donner au joueur 0 les cartes voulues.
func _give_hand(game: Node, wanted: PackedStringArray) -> void:
	var mine: Array = game.hands[0]
	for w in wanted:
		var id := int(w)
		if mine.has(id):
			continue
		var give := -1
		for c in mine:
			if not wanted.has(str(c)):
				give = c
				break
		if give < 0:
			return
		for pile in [game.deck, game.discard] + game.hands.slice(1):
			var k: int = pile.find(id)
			if k >= 0:
				pile[k] = give
				mine[mine.find(give)] = id
				break
	game.changed.emit()


func _capture() -> void:
	root.get_texture().get_image().save_png(_out)
	quit()
