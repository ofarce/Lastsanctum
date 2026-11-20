extends RefCounted
## Classe de base des tests. Chaque fichier res://tests/test_*.gd l'étend
## (extends "res://tests/test_case.gd") et déclare des méthodes test_*().
## Les assertions enregistrent l'échec sans interrompre le test.

var failures: PackedStringArray = []

static var _shared_main: Node


## Scène du jeu (main.tscn), une seule par processus de test : chaque instance pèse ~500 Mo et plusieurs
## secondes de chargement. Rendue en pause, séquence d'ouverture coupée ; à chaque test de lancer sa partie
## (Simulation.new_game).
static func shared_main() -> Node:
	if _shared_main == null:
		_shared_main = load("res://main/main.tscn").instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(_shared_main)
	var sim: Node = _shared_main.get_node("Simulation")
	sim.paused = true
	sim.opening = false
	return _shared_main


func check(condition: bool, message: String = "condition fausse") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%sattendu %s, obtenu %s" % [message + " : " if message else "", str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%sattendu %s ± %s, obtenu %s" % [message + " : " if message else "", str(expected), str(tolerance), str(actual)])
