# Joue des parties complètes entre 4 ordinateurs et vérifie qu'aucune carte ne se perd.
# Lancer : Godot --headless --path . --script res://tests/test_simulation.gd [-- nombre_de_parties]
extends SceneTree

const Game = preload("res://scripts/game.gd")
const CardDB = preload("res://scripts/card_db.gd")

var _games := 10
var _done := 0
var _fails := 0
var _game: Node
var _turns := 0
var _t0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_games = int(args[0])
	_next_game()


func _next_game() -> void:
	if _game:
		_game.queue_free()
	if _done >= _games:
		print("Parties : %d, erreurs : %d" % [_done, _fails])
		quit(1 if _fails > 0 else 0)
		return
	_game = Game.new()
	_game.humans.assign([false, false, false, false])
	_game.bot_delay = 0.0
	root.add_child(_game)
	_turns = 0
	_t0 = Time.get_ticks_msec()
	_game.turn_started.connect(_on_turn)
	_game.game_over.connect(_on_game_over)
	_game.start(_done + 1)


func _on_turn(_p: int) -> void:
	_turns += 1
	_check_cards()
	if OS.has_environment("VERBOSE"):
		print("  tour %d : %d ms, défausse %d, pioche %d" % [_turns, Time.get_ticks_msec() - _t0, _game.discard.size(), _game.deck.size()])


func _check_cards() -> void:
	var seen := {}
	var total: int = _game.deck.size() + _game.discard.size()
	for c in _game.deck + _game.discard:
		seen[c] = true
	for h in _game.hands:
		total += h.size()
		for c in h:
			seen[c] = true
	if total != CardDB.COUNT or seen.size() != CardDB.COUNT:
		_fails += 1
		print("ÉCHEC : %d cartes (%d différentes)" % [total, seen.size()])


func _on_game_over(results: Array) -> void:
	_check_cards()
	var line := []
	for r in results:
		line.append("%s %d" % [r.name, r.total])
		if r.hand.size() < 7:
			_fails += 1
			print("ÉCHEC : main de %d cartes" % r.hand.size())
	print("Partie %d : %d tours, %d ms — %s" % [_done + 1, _turns, Time.get_ticks_msec() - _t0, ", ".join(line)])
	_done += 1
	_next_game.call_deferred()
