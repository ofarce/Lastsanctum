extends "res://tests/test_case.gd"
## Faune hostile de la jungle (sim/wildlife.gd) : repaires, attaque des alliés comme des ennemis,
## retour au repaire, repeuplement, hors menace et hors fin de vague.

const SEED := 20261114


func _beasts() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in GameState.enemies:
		if e.neutral:
			out.append(e)
	return out


func test_lairs() -> void:
	var s := TerrainState.new()
	s.generate_galleries(SEED)
	var l := Wildlife.lairs(s, SEED)
	var crocs := l.filter(func(d: Dictionary) -> bool: return d["kind"] == "croc")
	var cats := l.filter(func(d: Dictionary) -> bool: return d["kind"] == "feline")
	check_eq(crocs.size(), Wildlife.CROCS, "crocodiles")
	check_eq(cats.size(), Wildlife.FELINES, "félins")
	for d in crocs:
		check(s.river.bank_distance(d["x"], d["z"]) < 1.0 and s.walkable(d["x"], d["z"]), "crocodile au bord de l'eau")
	for d in cats:
		check(absf(d["x"]) >= 30.0, "félin loin du chemin central")
	check_eq(Wildlife.lairs(s, SEED), l, "repaires déterministes")


func test_beast_hunts_ally_then_goes_home() -> void:
	var sim := Simulation.new()
	GameState.reset()
	var s := TerrainState.new()
	s.generate_galleries(SEED)
	var w := World.new()
	w.terrain_state = s
	w.pathfinder = Pathfinder.new(s)
	sim.world = w
	var l := {"kind": "croc", "x": 60.0, "z": s.river.center(60.0) - s.river.half_width(60.0) - 0.4}
	GameState.wildlife_lairs = [l]
	Wildlife._spawn(l)
	var croc: Enemy = l["beast"]
	var u := Unit.new()
	u.role = "paladin"
	u.hp = 200.0
	u.max_hp = 200.0
	u.x = croc.x
	u.z = croc.z - 3.0
	var alive: Array[Unit] = [u]
	for i in 60:
		Wildlife.tick(sim, 0.05, alive)
	check(u.hp < 200.0, "le crocodile mord l'allié qui s'approche")
	u.z = croc.home.y - 30.0
	for i in 200:
		Wildlife.tick(sim, 0.05, alive)
	check(croc.pos().distance_to(croc.home) < 1.0, "retour au repaire quand la proie s'éloigne")
	# Ennemi des vagues : attaqué aussi, et il riposte.
	var o := Enemy.make("creep", croc.x + 1.0, croc.z, 0.0)
	GameState.enemies.append(o)
	var hp := o.hp
	for i in 40:
		Wildlife.tick(sim, 0.05, [] as Array[Unit])
	check(o.hp < hp, "le crocodile attaque aussi les ennemis")
	check_eq(Wildlife.attacker_of(o), croc, "l'ennemi sait qui l'attaque (riposte)")
	w.free()


func test_respawn_after_three_waves() -> void:
	GameState.reset()
	var l := {"kind": "feline", "x": 100.0, "z": 0.0}
	GameState.wildlife_lairs = [l]
	Wildlife._spawn(l)
	(l["beast"] as Enemy).hp = 0.0
	GameState.enemies.clear()
	Wildlife.on_wave(1)
	Wildlife.on_wave(2)
	Wildlife.on_wave(3)
	check(GameState.enemies.is_empty(), "pas encore")
	Wildlife.on_wave(4)
	check_eq(GameState.enemies.size(), 1, "repeuplé trois vagues après")
	check(GameState.enemies[0].neutral and GameState.enemies[0].beast, "neutre, hors menace et fin de vague")


func test_feline_sees_further_at_night() -> void:
	GameState.reset()
	var e := Enemy.make("feline", 0, 0, 0)
	GameState.sim_time = 0.0
	var day := Wildlife.aggro(e)
	GameState.sim_time = (0.85 - DayNight.START) * DayNight.LENGTH
	check(Wildlife.aggro(e) > day * 1.4, "aggro plus large la nuit")
	GameState.sim_time = 0.0
