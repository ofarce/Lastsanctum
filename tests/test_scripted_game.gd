extends "res://tests/fight_case.gd"
## Étape 8 (v2) : partie scriptée accélérée de 5 vagues (Ingénieur, balistes, deux combattants), sans erreur,
## avec un journal d'événements identique sur 3 exécutions (graine fixée). Pas de simulation de 0,045 s
## (le plus long admis par le jeu) ; la 6e vague démarre vers 377 s.

const STEP := Simulation.MAX_DT
const STEPS := 12000


func _play() -> PackedStringArray:
	var sim := game()
	sim.combat.log_events = true
	sim.combat.events.clear()
	var u := engineer()
	u.x = -5.0
	u.z = -150.0
	u.tx = u.x
	u.tz = u.z
	sim.order_orb(u)
	for k: String in ["archer", "lame"]:
		var a := sim.spawn(Catalog.ADEPT[k]["name"], 0.0, -110.0, k)
		a.hp = Catalog.ADEPT[k]["hp"]
		a.max_hp = a.hp
	for i in STEPS:
		sim.tick(STEP)
		if GameState.wave >= 6 or GameState.ended:
			break
	var log := sim.combat.events.duplicate()
	sim.combat.log_events = false
	return log


func test_five_waves_deterministic() -> void:
	var a := _play()
	var waves := Array(a).filter(func(l: String) -> bool: return l.contains("vague"))
	check(waves.size() >= 5, "au moins 5 vagues (%d) ; fin : %s" % [waves.size(), GameState.ended])
	var kills := Array(a).filter(func(l: String) -> bool: return l.contains("abattu")).size()
	check(kills >= 4 + 7 + 10 + 13 + 16, "les 5 vagues abattues (%d ennemis)" % kills)
	check(not GameState.ended, "le sanctuaire tient")
	var b := _play()
	var c := _play()
	check_eq(b, a, "2e exécution identique")
	check_eq(c, a, "3e exécution identique")
	print("     (partie scriptée : %d événements, %s)" % [a.size(), a[a.size() - 1] if a.size() else "—"])
