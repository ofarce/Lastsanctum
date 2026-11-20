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
	check_eq(e.max_hp, 2000.0, "2000 PV")
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
	check_eq(e.hp, 2000.0, "Ingénieur dehors")
	var adept := sim.spawn("A", e.x + 3.0, e.z, "indra")
	sim.combat.damage(e, 50.0, adept)
	sim.combat.damage(e, 50.0)
	check_eq(e.hp, 2000.0, "autres sources")
	check(Combat.target_closest(eng, GameState.enemies, 1e9) == null, "rien ne vise à travers le bouclier")
	check(Combat.target_closest({"x": e.x - Martyre.RADIUS - 2.0, "z": e.z}, GameState.enemies, 1e9) == null, "ni les balistes")
	# L'adepte est repoussé au bord, l'Ingénieur passe.
	Martyre.enforce(sim)
	check(not Martyre.inside(adept), "adepte repoussé")
	_into_dome(eng)
	Martyre.enforce(sim)
	check(Martyre.inside(eng), "l'Ingénieur traverse")
	sim.combat.damage(e, 50.0, eng)
	check(e.hp < 2000.0, "l'Ingénieur la blesse de l'intérieur")
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
	check_near(before - eng.hp, Martyre.DAMAGE * Martyre.DAMAGE_MULT, 1e-6, "20 dégâts")


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
	check(e.hp < 2000.0, "pas de soin")


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


## Boss au centre, Ingénieur immobile à `dist` unités à l'est, attaques à distance prêtes ou non.
func _range_duel(sim: Simulation, dist: float, fissure: bool, seals: bool) -> Array:
	var e := _boss(sim)
	var eng := _bare()
	eng.stance = "hold"
	e.x = Martyre.center().x
	e.z = Martyre.center().y
	_into_dome(eng, Vector2(dist, 0.0))
	var now := GameState.sim_time
	GameState.martyre_next = ["fissure"] if fissure else ["rosace"] if seals else []
	GameState.martyre_next_at = now if fissure or seals else INF
	return [e, eng]


func test_cadence_is_thirty_percent_faster() -> void:
	check_near(Catalog.ENEMY[Martyre.KIND]["cd"], 3.0 / 1.3, 1e-6, "recharge de la frappe")
	check_near(Martyre.IMPACT, 0.5 / 1.3, 1e-6, "impact")
	check_near(Martyre.SEALS["charge"], 1.3 / 1.3, 1e-6)
	var meta: Dictionary = EnemyArt.all()[Martyre.KIND]
	check_near(float(meta["attack"]["duration"]), 1.0 / 1.3, 1e-3, "animation de frappe")
	check_near(float(meta["idle"]["duration"]), 4.0 / 1.3, 1e-3, "boucle de repos")


func test_fissure_runs_to_the_aimed_spot_then_erupts() -> void:
	var sim := game()
	var pair := _range_duel(sim, 12.0, true, false)
	var eng: Unit = pair[1]
	sim.tick(DT)
	check_eq(GameState.martyre_hit_kind, "fissure", "geste de la fissure")
	run(sim, Martyre.IMPACT + 0.05)
	var f: Array = GameState.martyre_fx.filter(func(o: Dictionary) -> bool: return o["type"] == "fissure")
	check_eq(f.size(), Martyre.FISSURE["count"], "trois failles en éventail")
	var end := Vector2(f[1]["x1"], f[1]["z1"])
	check(end.distance_to(eng.pos()) < 0.5, "vers la position visée")
	var before := eng.hp
	run(sim, float(f[0]["erupt"]) - GameState.sim_time + 0.05)
	check_near(before - eng.hp, Martyre.FISSURE["damage"] * Martyre.DAMAGE_MULT, 1e-6, "24 dégâts à l'éruption")
	check(eng.stunned_until > GameState.sim_time, "étourdi")
	run(sim, Martyre.FISSURE["erupt"] + Martyre.FISSURE["cool"] + 0.1)
	check(GameState.martyre_fx.is_empty(), "la faille s'éteint")


func test_leaving_the_aimed_spot_dodges_the_fissure() -> void:
	var sim := game()
	var pair := _range_duel(sim, 12.0, true, false)
	var eng: Unit = pair[1]
	sim.tick(DT)
	# Hors de l'éventail : au-delà de la faille latérale (35°).
	_into_dome(eng, Vector2(12.0, 14.0))
	var before := eng.hp
	# Avant que l'anneau de l'éruption ou les braises n'atteignent l'écart.
	run(sim, 1.2)
	check_eq(eng.hp, before, "esquivée")


func test_seals_fall_under_the_engineer() -> void:
	var sim := game()
	var pair := _range_duel(sim, 18.0, false, true)
	var e: Enemy = pair[0]
	var eng: Unit = pair[1]
	sim.tick(DT)
	check_near(e.cast_started, GameState.sim_time, 1e-6, "incantation")
	run(sim, Martyre.SEALS["place"] + 0.05)
	var seals: Array = GameState.martyre_fx.filter(func(o: Dictionary) -> bool: return o["type"] == "seal")
	check_eq(seals.size(), 3, "trois sceaux")
	check(seals.any(func(o: Dictionary) -> bool: return Vector2(o["x"], o["z"]).distance_to(eng.pos()) < 0.1), "un sous l'Ingénieur")
	var before := eng.hp
	run(sim, Martyre.SEALS["charge"] * 0.5)
	check_eq(eng.hp, before, "pas pendant la charge")
	run(sim, Martyre.SEALS["charge"] * 0.6)
	check_near(before - eng.hp, Martyre.SEALS["damage"] * Martyre.DAMAGE_MULT, 1e-6, "28 dégâts")


func test_stunned_engineer_neither_moves_nor_attacks() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	_into_dome(eng, Vector2(1.0, 0.0))
	eng.tx = eng.x + 10.0
	eng.force_move = true
	eng.stunned_until = GameState.sim_time + 1.0
	var at := eng.pos()
	var hp := e.hp
	sim.combat.update_units(DT, [eng])
	check(eng.pos() == at, "immobile")
	check_eq(e.hp, hp, "aucun coup")


func test_hurt_reaction_at_most_once_per_second() -> void:
	var sim := game()
	var e := _boss(sim)
	var eng := _bare()
	_into_dome(eng)
	sim.combat.damage(e, 5.0, eng)
	var first := e.hurt_at
	check_near(first, GameState.sim_time, 1e-6, "réaction")
	GameState.sim_time += 0.5
	sim.combat.damage(e, 5.0, eng)
	check_eq(e.hurt_at, first, "pas deux fois dans la seconde")


func test_view_plays_cast_and_hurt() -> void:
	var sim := game()
	var world: World = sim.get_node("../World")
	var e := _boss(sim)
	world.fog.refresh(sim.state())
	var v := UnitView.new()
	world.ysort.add_child(v)
	v.setup(e, EnemyArt.all()[Martyre.KIND], sim, world)
	var body: Sprite2D = v.get("_body")
	e.cast_started = GameState.sim_time - 0.1
	v._update()
	check((body.texture as AtlasTexture).atlas.resource_path.ends_with("martyre_cast.png"), "incantation")
	e.cast_started = -INF
	e.hurt_at = GameState.sim_time - 0.05
	v._update()
	check((body.texture as AtlasTexture).atlas.resource_path.ends_with("martyre_hit.png"), "touchée")
	v.queue_free()


func test_bullet_hits_once_then_engineer_is_invulnerable() -> void:
	var sim := game()
	var pair := _range_duel(sim, 10.0, false, false)
	var eng: Unit = pair[1]
	sim.tick(DT)
	var before := eng.hp
	for k in 3:
		Martyre.shoot(eng.x - 0.1 * k, eng.z, 0.0, 0.0)
	sim.tick(DT)
	check_near(before - eng.hp, Martyre.BULLET["damage"] * Martyre.DAMAGE_MULT, 1e-6, "une seule balle porte")
	check(GameState.martyre_iframe_until > GameState.sim_time, "invulnérable un instant")
	run(sim, Martyre.IFRAMES * 0.5)
	check_near(before - eng.hp, Martyre.BULLET["damage"] * Martyre.DAMAGE_MULT, 1e-6, "les autres le traversent")


func test_litanie_walls_leave_the_announced_gap() -> void:
	var sim := game()
	var pair := _range_duel(sim, 10.0, false, false)
	GameState.martyre_next = ["litanie"]
	GameState.martyre_next_at = GameState.sim_time
	sim.tick(DT)
	run(sim, Martyre.LITANIE["warn"] + 0.05)
	var lanes: Array = GameState.martyre_fx.filter(func(f: Dictionary) -> bool: return f["type"] == "lane")
	check_eq(lanes.size(), 1, "un couloir annoncé")
	check(GameState.martyre_bullets.size() > 30, "le mur part")
	var th: float = lanes[0]["th"]
	var g: float = lanes[0]["g"]
	var p := Vector2(-sin(th), cos(th))
	check(GameState.martyre_bullets.all(func(b: Dictionary) -> bool:
		return absf((Vector2(b["x"], b["z"]) - Martyre.center()).dot(p) - g) >= Martyre.LITANIE["gap"] - 1e-3), "brèche libre")
	check(pair[1] != null, "duel")


func test_phase_change_extinguishes_bullets_then_phase_three_shrinks_the_dome() -> void:
	var sim := game()
	var pair := _range_duel(sim, 10.0, false, false)
	var e: Enemy = pair[0]
	var eng: Unit = pair[1]
	sim.tick(DT)
	Martyre.ring(e.x, e.z, 12, 3.0, 0.0)
	e.hp = e.max_hp * 0.5
	sim.tick(DT)
	check_eq(GameState.martyre_phase, 1, "phase II")
	check(GameState.martyre_bullets.is_empty(), "balles éteintes")
	check(GameState.martyre_fx.any(func(f: Dictionary) -> bool: return f["type"] == "mote"), "en éclats")
	check_near(Martyre.radius(), Martyre.RADIUS, 1e-6, "bouclier entier")
	e.hp = e.max_hp * 0.2
	sim.tick(DT)
	check_eq(GameState.martyre_phase, 2, "phase III")
	eng.hp = 1e6
	run(sim, Martyre.SHRINK + 0.1)
	check_near(Martyre.radius(), Martyre.RADIUS_III, 1e-6, "18 cases")
	check(Martyre.inside(eng), "l'Ingénieur reste dedans")
