extends "res://tests/test_case.gd"
## Séquence d'ouverture (sim/opening.gd) : arrivée, porte, bouclier, siège, explosion, remparts, vagues.

const DT := 1.0 / 30.0

static var _main: Node


func _game() -> Simulation:
	_main = shared_main()
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.opening = true
	sim.new_game(20261114)
	return sim


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds / DT):
		sim.tick(DT)


func _engineer() -> Unit:
	for u in GameState.units:
		if u.role == "engineer":
			return u
	return null


## Intro de la capsule (planches/intro-capsule-planche.html) : capsule éteinte, l'Ancre s'allume et se recharge
## seule, le trait part vers la capsule qui s'allume ; l'Ingénieur peut alors sortir.
func test_capsule_intro() -> void:
	if Opening.ANCHOR_SEQUENCE:
		return
	var sim := _game()
	var eng := _engineer()
	check_eq(Opening.stage(), "boot", "la partie commence dans la capsule")
	check(GameState.in_capsule and eng.hidden and eng.unarmored, "l'Ingénieur est dans la capsule, sans armure")
	check(Opening.cinematic(), "cinématique")
	check(not GameState.orb_active and not Capsule.powered() and not Capsule.chest_active(), "Ancre, capsule et Coffre éteints")
	check(not Capsule.toggle(sim), "capsule éteinte : on ne sort pas")
	_run(sim, 0.8)
	check_eq(Opening.card()[0], "Jour 1", "carton « Jour 1 »")
	_run(sim, Opening.BOOT_WAKE - 0.8 + 0.1)
	check_eq(Opening.stage(), "recharge", "l'Ancre s'allume seule")
	check(GameState.orb_active and Capsule.chest_active(), "Ancre allumée : le Coffre se rallume")
	check(GameState.core_hp >= 1.0 and GameState.core_hp < 10.0, "recharge depuis presque rien (%.1f)" % GameState.core_hp)
	check(not GameState.ended, "pas de défaite à l'allumage")
	_run(sim, Opening.RECHARGE_LEN * 0.5)
	check_near(Opening.recharge(), 0.5, 0.05, "jauge à mi-course")
	check_near(GameState.core_hp, Simulation.CORE_MAX * 0.5, 6.0, "PV de l'Ancre suivent la jauge")
	_run(sim, Opening.RECHARGE_LEN * 0.5 + 0.1)
	check_eq(Opening.stage(), "link", "jauge pleine : le trait part vers la capsule")
	check_eq(GameState.core_hp, Simulation.CORE_MAX, "Ancre pleine")
	check(Opening.cinematic() and not Capsule.powered(), "capsule encore éteinte pendant le trait")
	check(GameState.overload_at == INF and not GameState.spark_pending, "ni étincelle ni surcharge")
	_run(sim, Opening.LINK_LEN + 0.2)
	check_eq(Opening.stage(), "awake")
	check(Capsule.powered() and not Opening.cinematic(), "capsule allumée, commandes rendues")
	check(not GameState.door_closed and not GameState.shield_up and sim.state().walkable(0.0, -78.0), "ni bouclier, porte sud ouverte")
	check_eq(GameState.next_wave, DayNight.first_wave(0.0), "premier assaut à 9 h du jour 2")
	check(Capsule.toggle(sim), "E : Sortir")
	check(not GameState.in_capsule and not eng.hidden and GameState.incarnated == eng, "dehors et incarné")
	check(not eng.equipment.has("Main droite"), "sans arme : elle est dans le Coffre")


## Ancienne suite (Opening.ANCHOR_SEQUENCE), gardée de côté.
func test_full_sequence() -> void:
	if not Opening.ANCHOR_SEQUENCE:
		return
	var sim := _game()
	var st := sim.state()
	var eng := _engineer()
	check_eq(Opening.stage(), "arrival", "la partie commence par l'arrivée")
	check(Opening.cinematic() and Opening.bars() >= 0.0, "cinématique d'arrivée")
	check(eng.hidden and eng.unarmored, "l'Ingénieur attend dans le portail, sans armure")
	check(GameState.door_closed and not st.walkable(0.0, -78.0), "porte sud fermée et infranchissable")
	_run(sim, Opening.ARR_EJECT + 0.2)
	check(not eng.hidden, "expulsé du portail")
	check_near(eng.x, Opening.LAND.x, 0.01, "posé sous le portail")
	_run(sim, Opening.ARR_END - Opening.ARR_EJECT)
	check_eq(Opening.stage(), "day1", "jeu du jour 1")
	check(not Opening.cinematic(), "commandes rendues")
	# Réveil de l'Ancre : barres pendant la surcharge, pas d'assaut programmé.
	GameState.orb_active = true
	GameState.orb_finished_at = GameState.sim_time
	_run(sim, 0.5)
	check(Opening.cinematic(), "barres de cinéma après le réveil")
	check(GameState.next_wave == INF, "aucun assaut tant que le bouclier tient")
	GameState.overload_stage = 3
	_run(sim, 0.2)
	check_eq(Opening.stage(), "shield_form", "le bouclier se forme")
	check(GameState.shield_up, "bouclier levé")
	var ring: Array[Vector2i] = Opening.shield_cells()
	check(not ring.is_empty(), "anneau de cases sous la paroi")
	var c := ring[0]
	check(not st.walkable(c.x * 4.0 + 2.0, c.y * 4.0 + 2.0), "la paroi bloque la sortie")
	_run(sim, Opening.SHIELD_FORM + 0.1)
	check_eq(Opening.stage(), "shielded", "fin de la cinématique du bouclier")
	check(GameState.door_closed and not st.walkable(0.0, -78.0), "l’Ancre n’ouvre pas la porte")
	# Jour 2 : les canons arrivent et pilonnent.
	GameState.sim_time = DayNight.morning(2) - 1.0
	_run(sim, 1.2)
	check_eq(Opening.stage(), "siege_intro", "cinématique des canons au jour 2")
	check(Opening.card().size() == 0 or Opening.card()[0] == "Jour 2", "carton du jour")
	_run(sim, Opening.SIEGE_INTRO + 0.1)
	check_eq(Opening.stage(), "siege", "jeu sous le pilonnage")
	check(Opening.fire_phase(0) >= 0.0 and Opening.cannon_arrival(2) == 1.0, "canons en batterie, qui tirent")
	# Fin du jour 2 : explosion, brèche, remparts.
	var dusk := (1.0 + DayNight.DUSK_START - DayNight.START) * DayNight.LENGTH
	GameState.sim_time = dusk
	GameState.opening_at = dusk - Opening.SIEGE_MIN - 1.0
	_run(sim, 0.1)
	check_eq(Opening.stage(), "blast", "le bouclier explose au crépuscule")
	check(not st.ground(-10.0, -86.0), "le mur sud tient encore")
	_run(sim, Opening.BURST + 0.1)
	check(not GameState.shield_up and st.breach_open, "bouclier tombé, mur soufflé")
	check(st.walkable(-10.0, -86.0) and st.walkable(10.0, -86.0), "la brèche est praticable")
	check(st.walkable(c.x * 4.0 + 2.0, c.y * 4.0 + 2.0), "plus de paroi")
	_run(sim, Opening.BLAST_LEN - Opening.BURST)
	check_eq(Opening.stage(), "waves", "les vagues commencent")
	check_near(GameState.next_wave, DayNight.morning(DayNight.day(GameState.sim_time) + 1), 0.01, "premier assaut au matin suivant")
	check(not Opening.cinematic(), "plus de cinématique")
