extends "res://tests/test_case.gd"
## Météo par tranches de journée (core/weather.gd) : tirage, prévision, crue qui ralentit, feu mouillé.

const SEED := 20261114


func _reset() -> void:
	GameState.sim_time = 0.0
	GameState.weather = {}
	Weather.river = null


func test_slots_follow_the_day() -> void:
	check_eq(Weather.slot(0.0), 0, "la partie commence dans la première tranche")
	for s in 12:
		check_eq(Weather.slot(Weather.slot_time(s) + 0.01), s, "début de la tranche %d" % s)
		check_eq(Weather.slot(Weather.slot_time(s + 1) - 0.01), s, "fin de la tranche %d" % s)
	check_near(Weather.slot_time(5) - Weather.slot_time(4), DayNight.LENGTH / Weather.SLOTS, 1e-6, "durée d'une tranche")


func test_draw_is_deterministic_and_gated() -> void:
	var seen := {}
	for sd in range(1, 60):
		for s in 48:
			var k := Weather.kind_at(sd, s)
			check_eq(k, Weather.kind_at(sd, s), "même graine, même temps")
			check(Weather.KINDS.has(k), "temps connu (%s)" % k)
			if s < Weather.SLOTS:
				check_eq(k, "clair", "premier jour clair")
			if s < 2 * Weather.SLOTS:
				check(k != "orage", "pas d'orage avant le troisième jour")
			seen[k] = true
	check_eq(seen.size(), Weather.KINDS.size(), "les quatre temps sortent")


func _terrain() -> TerrainState:
	var st := TerrainState.new()
	st.seed = SEED
	st.river = River.new(SEED)
	st.flora = Flora.new(SEED, st.river)
	return st


## Première tranche de pluie ou d'orage qui suit une tranche sèche.
func _rain_slot() -> int:
	for s in range(Weather.SLOTS, 200):
		if Weather.RAIN[Weather.kind_at(SEED, s)] > 0.0 and Weather.RAIN[Weather.kind_at(SEED, s - 1)] == 0.0:
			return s
	return -1


func test_tick_changes_weather_and_regrows() -> void:
	_reset()
	var st := _terrain()
	check_eq(Weather.tick(st), "", "rien à annoncer au départ (clair)")
	check_eq(Weather.kind(), "clair", "clair au départ")
	var s := _rain_slot()
	check(s > 0, "une tranche de pluie existe")
	GameState.sim_time = Weather.slot_time(s - 1) + 1.0
	Weather.tick(st)
	check(not Weather.forecast().is_empty(), "la pluie est annoncée")
	check_eq(Weather.forecast()["kind"], Weather.kind_at(SEED, s), "prévision = temps de la tranche suivante")
	check_near(float(Weather.forecast()["at"]), Weather.slot_time(s), 1e-6, "heure de la prévision")
	st.flora.burn(-60.0, 0.0, 6.0)
	var burnt := func() -> int: return st.flora.plants.filter(func(p: Dictionary) -> bool: return p["b"]).size()
	var hurt: int = burnt.call()
	check(hurt > 0, "végétation brûlée avant la pluie")
	GameState.sim_time = Weather.slot_time(s) + 0.1
	var msg := Weather.tick(st)
	check(msg != "", "le changement est annoncé")
	check(Weather.rain() < 0.1, "la pluie s'installe peu à peu")
	check_eq(burnt.call(), 0, "la pluie fait repousser la végétation brûlée d'un stade")
	check_eq(Weather.tick(st), "", "pas de second message dans la même tranche")
	GameState.sim_time += Weather.RAMP + 1.0
	Weather.tick(st)
	check(Weather.rain() >= 0.6, "pluie installée")
	check_near(st.river.flood, Weather.FLOOD[Weather.kind()], 1e-6, "la rivière sort de son lit")
	_reset()


func test_forced_weather_is_kept() -> void:
	_reset()
	var st := _terrain()
	GameState.weather = {"kind": "orage", "from": "orage", "since": -100.0}
	Weather.tick(st)
	check_eq(Weather.kind(), "orage", "un temps posé à la main n'est pas remplacé")
	check(Weather.forecast().is_empty(), "pas de prévision pour un temps posé à la main")
	_reset()


func test_flood_slows_except_bridges_and_crocs() -> void:
	_reset()
	var st := _terrain()
	GameState.weather = {"kind": "orage", "from": "orage", "since": -100.0}
	Weather.tick(st)
	var r := st.river
	var x := 50.0
	var bank := r.center(x) + r.half_width(x) + 1.0
	check_near(Weather.speed_at(x, bank), Weather.SPEED["orage"] * Weather.WADE, 1e-6, "berge inondée")
	check_near(Weather.speed_at(x, bank, false), Weather.SPEED["orage"], 1e-6, "le crocodile n'est pas gêné")
	check_near(Weather.speed_at(x, bank + 10.0), Weather.SPEED["orage"], 1e-6, "hors crue : pluie seule")
	var b: Dictionary = r.bridges[2]
	check_near(Weather.speed_at(float(b["x"]), float(b["z1"]) - 0.5), Weather.SPEED["orage"], 1e-6, "tablier au sec")
	check_eq(Weather.speed_at(0.0, -150.0), 1.0, "rien dans la caverne")
	check(Weather.wet(x, bank), "végétation trempée dehors")
	check(not Weather.wet(0.0, -150.0), "pas de pluie dans la caverne")
	GameState.weather = {"kind": "clair", "from": "clair", "since": -100.0}
	Weather.tick(st)
	check_eq(Weather.speed_at(x, bank), 1.0, "temps clair : vitesse normale")
	check(not Weather.wet(x, bank), "temps clair : le feu prend")
	_reset()


func test_sky_status_shows_weather() -> void:
	_reset()
	var s := HudModel.sky_status()
	check_eq(s["weather"], "Clair", "temps affiché")
	check_eq(s["next"], "", "pas de prévision sans tirage")
	GameState.weather = {"kind": "clair", "from": "clair", "since": 0.0, "slot": 0, "seed": SEED}
	var f := Weather.forecast()
	s = HudModel.sky_status()
	if f.is_empty():
		check_eq(s["next"], "", "rien ne change dans la journée")
	else:
		check(String(s["next"]).begins_with(Weather.NAMES[f["kind"]]), "prévision affichée (%s)" % s["next"])
	_reset()


func test_bolt_times() -> void:
	_reset()
	GameState.weather = {"kind": "orage", "from": "orage", "since": -100.0}
	var hits := 0
	var t := 0.0
	while t < Weather.BOLT_PERIOD * 10.0:
		var n := Weather.bolt_between(t, t + 0.04)
		if n >= 0:
			hits += 1
			check(Weather.lightning(Weather.bolt_time(n) + 0.01) > 0.0, "le flash accompagne l'impact")
		t += 0.04
	check_eq(hits, 10, "un impact par période")
	GameState.weather = {"kind": "pluie", "from": "pluie", "since": -100.0}
	check_eq(Weather.bolt_between(0.0, 100.0), -1, "pas de foudre sous la pluie simple")
	_reset()


func test_bolt_strikes_outdoors_and_spares_sheltered() -> void:
	var sim := Simulation.new()
	GameState.reset()
	_reset()
	var e := Enemy.make("brute", 20.0, 0.0, 1.0)
	GameState.enemies.append(e)
	var inside := Enemy.make("brute", 0.0, -150.0, 1.0)
	GameState.enemies.append(inside)
	var hp := e.hp
	var hp_in := inside.hp
	var on_target := 0
	for n in 60:
		var at := sim.combat.lightning_strike(n, SEED)
		if absf(at.x - 20.0) < 1e-6 and absf(at.y) < 1e-6:
			on_target += 1
	check(e.hp < hp, "l'ennemi dehors est frappé")
	check(on_target > 0 and on_target < 30, "seul dehors, il n'est frappé que rarement (%d / 60)" % on_target)
	check_eq(inside.hp, hp_in, "l'ennemi dans la caverne est épargné")
	check(GameState.effects.any(func(f: Dictionary) -> bool: return f["type"] == "bolt"), "éclair dessiné")
	# Seul un allié dehors : frappé à découvert, épargné près d'un bâtiment.
	GameState.enemies.clear()
	var u := Unit.new()
	u.role = "paladin"
	u.hp = 1e6
	u.max_hp = 1e6
	u.x = -30.0
	u.z = 10.0
	GameState.units.append(u)
	for n in 60:
		sim.combat.lightning_strike(n, SEED)
	check(u.hp < 1e6, "allié à découvert frappé")
	u.hp = 1e6
	var b := Building.create(1, "caserne", -28.0, 12.0)
	b.complete = true
	GameState.buildings.append(b)
	for n in 60:
		sim.combat.lightning_strike(n, SEED)
	check_eq(u.hp, 1e6, "allié à l'abri d'un bâtiment épargné")
	GameState.reset()
	sim.free()


func test_mist_shortens_ranged_reach_outdoors() -> void:
	GameState.reset()
	_reset()
	var u := Unit.new()
	u.role = "archer"
	u.x = 0.0
	u.z = 10.0
	var clear := Catalog.unit_reach(u)
	GameState.weather = {"kind": "brume", "from": "brume", "since": -100.0}
	check_near(Catalog.unit_reach(u), clear * Weather.REACH["brume"], 1e-6, "archer dehors dans la brume")
	u.z = -150.0
	check_near(Catalog.unit_reach(u), clear, 1e-6, "archer dans la caverne")
	check_eq(Weather.speed_at(0.0, 10.0), 1.0, "la brume ne ralentit pas")
	check(Weather.mist() >= 1.0, "voile de brume installé")
	_reset()


func test_roads_are_faster() -> void:
	_reset()
	var st := _terrain()
	st.road = Road.new(SEED, st.river)
	Weather.tick(st)
	var z := 0.0
	var mx := st.road.main_x(z)
	check_near(Weather.speed_at(mx, z), Weather.ROAD_SPEED, 1e-6, "sur la route principale")
	check_eq(Weather.speed_at(mx + 30.0, z), 1.0, "dans l'herbe")
	var j: Dictionary = st.road.junctions[0]
	var bx := (float(j["x"]) + float(j["bx"])) * 0.5
	check_near(Weather.speed_at(bx, st.road.branch_z(j, bx)), Weather.ROAD_SPEED, 1e-6, "sur un embranchement")
	GameState.weather = {"kind": "pluie", "from": "pluie", "since": -100.0}
	check_near(Weather.speed_at(mx, z), Weather.ROAD_SPEED * Weather.SPEED["pluie"], 1e-6, "route sous la pluie")
	GameState.reset()
	check_eq(Weather.speed_at(mx, z), 1.0, "nouvelle partie : plus de chemins en mémoire")
	_reset()
