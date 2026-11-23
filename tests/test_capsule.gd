extends "res://tests/test_case.gd"
## Capsule (sim/capsule.gd) : la partie commence dedans ; une fois allumée, E sort (réincarné), E entre (caché,
## désincarné, soigné). L'équipement de départ vient du Coffre Antique (tests/test_chest.gd).

const DT := 1.0 / 30.0

static var _main: Node


func _game() -> Simulation:
	_main = shared_main()
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.opening = true
	sim.new_game(20261114)
	return sim


## Joue l'intro jusqu'à la capsule allumée (étape « awake »).
func _to_awake(sim: Simulation) -> void:
	var t := 0.0
	while Opening.stage() != "awake" and t < 30.0:
		sim.tick(DT)
		t += DT


func test_enter_and_exit() -> void:
	var sim := _game()
	var eng := Capsule.engineer()
	check(GameState.in_capsule and eng.hidden, "départ dans la capsule")
	var hp0 := eng.hp
	for i in 30:
		sim.tick(DT)
	check_eq(eng.hp, hp0, "capsule éteinte : pas de soin")
	_to_awake(sim)
	check(Capsule.powered(), "capsule allumée")
	check(not eng.equipment.has("Main droite"), "sans arme")
	check(Capsule.toggle(sim), "E : Sortir")
	check(not GameState.in_capsule and not eng.hidden and GameState.incarnated == eng)
	check(Capsule.can_enter())
	check(Capsule.toggle(sim))
	check(GameState.in_capsule and eng.hidden and GameState.incarnated == null)
	check(not eng.equipment.has("Main droite"), "la capsule ne remet plus l'arme")
	for i in 90:
		sim.tick(DT)
	check(eng.hidden, "reste caché dans la capsule")
	check(Capsule.toggle(sim))
	check(not GameState.in_capsule and not eng.hidden and GameState.incarnated == eng)
	eng.hp = 10.0
	var res0: float = GameState.res["forge"]
	check(Capsule.toggle(sim) and GameState.in_capsule)
	for i in roundi(2.0 / DT):
		sim.tick(DT)
	check_near(eng.hp, 10.0 + 2.0 * Capsule.HEAL_RATE, 0.1, "dans la capsule : +5 PV par seconde")
	check_near(GameState.res["forge"], res0 + 2.0 * Capsule.MANA_RATE, 0.1, "dans la capsule : +2 de chaque mana par seconde")
	check(Capsule.toggle(sim))
	eng.x = 0.0
	eng.z = -161.0
	check(not Capsule.can_enter(), "à plus d'un bloc")
	eng.x = 0.0
	eng.z = -140.0
	check(not Capsule.can_enter())
	check(not Capsule.toggle(sim))


## Partie sans séquence d'ouverture : l'Ancre se réveille encore à la main.
func test_e_wakes_anchor() -> void:
	var sim := _game()
	sim.opening = false
	sim.new_game(20261114)
	GameState.portal_start = -100.0
	for i in 30:
		sim.tick(DT)
	var eng := Capsule.engineer()
	eng.hidden = false
	ExileGallery.incarnate(eng)
	check(not Capsule.can_wake_anchor(), "trop loin de l'Ancre")
	eng.x = CaveShape.CORE.x + 6.0
	eng.z = CaveShape.CORE.y
	eng.tx = eng.x
	eng.tz = eng.z
	check(Capsule.can_wake_anchor())
	check(Capsule.toggle(sim))
	check(eng.orb_job and GameState.orb_owner == eng, "l'Ingénieur part réveiller l'Ancre")
