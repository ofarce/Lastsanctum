extends RefCounted
## Classe de base des tests. Chaque fichier res://tests/test_*.gd l'étend
## (extends "res://tests/test_case.gd") et déclare des méthodes test_*().
## Les assertions enregistrent l'échec sans interrompre le test.

var failures: PackedStringArray = []


func check(condition: bool, message: String = "condition fausse") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%sattendu %s, obtenu %s" % [message + " : " if message else "", str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%sattendu %s ± %s, obtenu %s" % [message + " : " if message else "", str(expected), str(tolerance), str(actual)])
