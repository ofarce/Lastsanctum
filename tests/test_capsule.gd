extends "res://tests/test_case.gd"
## Capsule (sim/capsule.gd) : E entre (caché, désincarné), E sort (réincarné) ; canon équipé au départ.

const DT := 1.0 / 30.0

static var _main: Node


func _game() -> Simulation:
	_main = shared_main()
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.opening = true
	sim.new_game(20261114)
	return sim


func test_enter_and_exit() -> void:
	var sim := _game()
	for i in roundi((Opening.ARR_END + 0.5) / DT):
		sim.tick(DT)
	var eng := Capsule.engineer()
	check(not eng.equipment.has("Main droite"), "arrive sans arme")
	check_near(eng.hp, roundf(eng.max_hp / 3.0), 0.01, "arrive à un tiers de sa vie")
	check(GameState.incarnated == eng)
	check(not Capsule.can_enter() and not Capsule.toggle(sim), "capsule éteinte : inutilisable")
	GameState.capsule_on = true
	check(Capsule.can_enter())
	check(Capsule.toggle(sim))
	check(GameState.in_capsule and eng.hidden and GameState.incarnated == null)
	check_eq(eng.hp, eng.max_hp, "soigné à la première entrée")
	check_eq(eng.equipment.get("Main droite", ""), "cannon", "canon remis à la première entrée")
	check(GameState.mining_seal, "sceau de minage remis à la première entrée")
	for i in 90:
		sim.tick(DT)
	check(eng.hidden, "reste caché dans la capsule")
	check(Capsule.toggle(sim))
	check(not GameState.in_capsule and not eng.hidden and GameState.incarnated == eng)
	eng.hp = 10.0
	check(Capsule.toggle(sim) and Capsule.toggle(sim))
	check_eq(eng.hp, 10.0, "pas de second soin complet")
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


func test_e_wakes_anchor() -> void:
	var sim := _game()
	for i in roundi((Opening.ARR_END + 0.5) / DT):
		sim.tick(DT)
	var eng := Capsule.engineer()
	check(not Capsule.can_wake_anchor(), "trop loin de l'Ancre")
	eng.x = CaveShape.CORE.x + 6.0
	eng.z = CaveShape.CORE.y
	eng.tx = eng.x
	eng.tz = eng.z
	check(Capsule.can_wake_anchor())
	check(Capsule.toggle(sim))
	check(eng.orb_job and GameState.orb_owner == eng, "l'Ingénieur part réveiller l'Ancre")
