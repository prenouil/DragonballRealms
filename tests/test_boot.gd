# Vérifie que la scène principale se charge et tourne quelques images sans erreur.
# Lancer : Godot --headless --path . --script res://tests/test_boot.gd
extends SceneTree

var _frames := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 30:
		print("OK : scène principale chargée (%s)" % current_scene.name)
		quit(0)
	return false
