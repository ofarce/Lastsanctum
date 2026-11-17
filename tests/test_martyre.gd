extends "res://tests/fight_case.gd"
## Premier boss, la Martyre de Byrsa (sim/martyre.gd) : apparition à 500 de menace, bouclier, duel, objectif.


func _boss(sim: Simulation) -> Enemy:
	GameState.menace = Martyre.MENACE
	Martyre.tick(sim)
	return GameState.martyre


## L'Ingénieur tel qu'il est à 500 de menace : sans armure depuis la surcharge de l'Ancre.
func _bare() -> Unit:
	var u := engineer()
	u.unarmored = true
	u.hp = u.max_hp
	return u


func _into_dome(u: Unit, offset := Vector2(0.0, -6.0)) -> void:
	var p := Martyre.center() + offset
	u.x = p.x
	u.z = p.y
	u.tx = p.x
	u.tz = p.y


func test_appears_alone_at_500_menace_and_cancels_the_assault() -> void:
	var sim := game()
	GameState.menace = Martyre.MENACE - 1
	sim.combat.start_wave()
	Martyre.tick(sim)
	check(GameState.martyre == null, "pas avant 500")
	var e := _boss(sim)
	check(e != null and e.kind == Martyre.KIND, "elle apparaît")
	check_eq(e.max_hp, 500.0, "500 PV")
	check(GameState.spawn_queue.is_empty(), "le reste de l'assaut est annulé")
	check_eq(GameState.martyre_state, "waiting")
	Martyre.tick(sim)
	check_eq(GameState.enemies.filter(func(o: Enemy) -> bool: return o.kind == Martyre.KIND).size(), 1, "une seule")


func test_no_wave_while_she_lives() -> void:
	var sim := game()
	GameState.orb_active = true
	_boss(sim)
	GameState.spawn_queue = [{"at": 0.0, "x": 0.0, "kind": "creep"}]
	GameState.next_wave = GameState.sim_time
	run(sim, 6.0)
	check(GameState.enemies.all(func(o: Enemy) -> bool: return o.kind == Martyre.KIND or o.beast), "aucun assaillant")
	check_eq(GameState.wave, 0, "aucune vague lancée")


func test_shield_blocks_everyone_but_the_engineer() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	# Coups de l'extérieur et d'une autre unité : sans effet.
	eng.x = e.x + Martyre.RADIUS + 5.0
	eng.z = e.z
	sim.combat.damage(e, 50.0, eng)
	check_eq(e.hp, 500.0, "Ingénieur dehors")
	var adept := sim.spawn("A", e.x + 3.0, e.z, "indra")
	sim.combat.damage(e, 50.0, adept)
	sim.combat.damage(e, 50.0)
	check_eq(e.hp, 500.0, "autres sources")
	check(Combat.target_closest(eng, GameState.enemies, 1e9) == null, "rien ne vise à travers le bouclier")
	check(Combat.target_closest({"x": e.x - Martyre.RADIUS - 2.0, "z": e.z}, GameState.enemies, 1e9) == null, "ni les balistes")
	# L'adepte est repoussé au bord, l'Ingénieur passe.
	Martyre.enforce(sim)
	check(not Martyre.inside(adept), "adepte repoussé")
	_into_dome(eng)
	Martyre.enforce(sim)
	check(Martyre.inside(eng), "l'Ingénieur traverse")
	sim.combat.damage(e, 50.0, eng)
	check(e.hp < 500.0, "l'Ingénieur la blesse de l'intérieur")
	check(Combat.target_closest(eng, GameState.enemies, 1e9) == e, "et peut la viser")


func test_other_enemies_cannot_enter() -> void:
	var sim := game()
	var e := _boss(sim)
	var c := foe("creep", e.x + 4.0, e.z, 30.0)
	Martyre.enforce(sim)
	check(not Martyre.inside(c), "assaillant repoussé")


func test_duel_starts_inside_and_hits_for_ten() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	eng.hp = eng.max_hp
	eng.stance = "hold"
	run(sim, 0.5)
	check_eq(GameState.martyre_state, "waiting", "attend l'Ingénieur")
	_into_dome(eng, Vector2(1.5, 0.0))
	e.x = Martyre.center().x
	e.z = Martyre.center().y
	e.cooldown = 0.0
	sim.tick(DT)
	check_eq(GameState.martyre_state, "duel", "le combat commence")
	check_near(e.attack_started, GameState.sim_time, 1e-6, "frappe")
	var before := eng.hp
	run(sim, Martyre.IMPACT * 0.5)
	check_eq(eng.hp, before, "pas avant l'impact")
	run(sim, Martyre.IMPACT * 0.6)
	check_near(before - eng.hp, Martyre.DAMAGE, 1e-6, "10 dégâts")


func test_stepping_away_dodges_the_blow() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	eng.stance = "hold"
	_into_dome(eng, Vector2(1.5, 0.0))
	e.x = Martyre.center().x
	e.z = Martyre.center().y
	e.cooldown = 0.0
	sim.tick(DT)
	var before := eng.hp
	_into_dome(eng, Vector2(9.0, 0.0))
	run(sim, Martyre.IMPACT + 0.1)
	check_eq(eng.hp, before, "esquivé")


func test_leaving_the_dome_ends_the_duel_without_healing() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	_into_dome(eng)
	sim.tick(DT)
	sim.combat.damage(e, 40.0, eng)
	eng.x = Martyre.center().x + Martyre.RADIUS + 10.0
	eng.tx = eng.x
	sim.tick(DT)
	check_eq(GameState.martyre_state, "waiting")
	run(sim, 3.0)
	check(e.hp < 500.0, "pas de soin")


func test_objective_interrupts_then_resumes_quest() -> void:
	var sim := game()
	var q := Quests.new()
	q.update()
	check_eq(q.objective()["id"], "anchor")
	var e := _boss(sim)
	var o := q.objective()
	check_eq(o["id"], "martyre")
	check_eq(o["label"], "Éliminer la Martyre de Byrsa en combat singulier")
	check(o.get("interrupt", false), "interrompt la quête affichée")
	var eng := _bare()
	_into_dome(eng)
	sim.combat.damage(e, 1000.0, eng)
	sim.combat.finish_tick(DT, [eng])
	Martyre.tick(sim)
	check_eq(GameState.martyre_state, "defeated")
	check(not Martyre.active(), "bouclier tombé")
	check_eq(q.objective()["id"], "anchor", "la quête reprend")
	GameState.menace = 2000
	Martyre.tick(sim)
	check(GameState.martyre == null, "elle ne revient pas")


func test_new_game_resets_the_boss() -> void:
	var sim := game()
	_boss(sim)
	sim.new_game(SEED)
	check(GameState.martyre == null and GameState.martyre_state == "", "remise à zéro")
