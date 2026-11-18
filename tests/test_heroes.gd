extends "res://tests/fight_case.gd"
## Étape 9 : héros (Paladin, Soigneur, Tireur), compétences et drapeau D9. Référence : combat.json
## (heroes, abilities), extraite du prototype par tools/baker/hud.js.


func _usnap() -> Dictionary:
	return {
		"units": GameState.units.map(func(o: Unit) -> Array:
			return [r4(o.x), r4(o.z), r4(o.hp), r4(o.attack), r4(o.ability), r4(o.shield), r4(o.buff)]),
		"enemies": GameState.enemies.map(func(e: Enemy) -> Array: return [r4(e.x), r4(e.z), r4(e.hp)]),
		"core": r4(GameState.core_hp), "effects": GameState.effects.size()}


func _ally(sim: Simulation, role: String, x: float, z: float, hp: float) -> Unit:
	var a := sim.spawn("A", x, z, role)
	a.hp = hp
	return a


## 40 pas de 0,05 s de la boucle complète : déplacements, frappes (épée, salves, soins), ripostes, effets.
func test_hero_fights_match_js() -> void:
	for H: Dictionary in js()["heroes"]:
		var u := setup(H["role"], int(H["level"]))
		var sim := game_sim()
		var engineer_ally: Unit = null
		for a: Array in H["allies"]:
			var ally := _ally(sim, a[0], a[1], a[2], a[3])
			if ally.role == "engineer":
				engineer_ally = ally
		for f: Array in H["foes"]:
			foe(f[0], f[1], f[2], f[3])
		GameState.next_wave = 1e9
		GameState.orb_active = false
		if engineer_ally:
			# L'Ingénieur du prototype (80 dégâts à distance) n'existe plus : en armure il frappe à 1 000, sans
			# armure au corps à corps à 5. Pas de parité pas à pas : on vérifie que le combat a lieu.
			engineer_ally.unarmored = true
			var target: Enemy = GameState.enemies[0]
			var hp0 := target.hp
			for _k in H["steps"].size():
				sim.tick(0.05)
			check(target.hp < hp0, "%s niv. %d : l'ennemi est touché (%.0f → %.0f)" % [H["role"], H["level"], hp0, target.hp])
			check(u.alive(), "%s niv. %d : le héros tient" % [H["role"], H["level"]])
			continue
		var i := 0
		for want: Dictionary in H["steps"]:
			sim.tick(0.05)
			if not _same_quiet(_usnap(), want):
				check(false, "%s niv. %d, pas %d : %s ≠ %s" % [H["role"], H["level"], i, _usnap(), want])
				break
			i += 1
		check_eq(i, H["steps"].size(), "%s niv. %d : pas identiques au prototype" % [H["role"], H["level"]])
		if u.role == "paladin":
			check(u.sw >= 0, "le Paladin a donné des coups d'épée (animation)")
		if u.role == "shooter":
			check(u.sh_t0 > 0.0, "le Tireur a tiré des salves (animation)")


## Égide, Restauration, Discipline martiale, tir de précision, puis recharge.
func test_abilities_match_js() -> void:
	var p := setup("paladin", 2)
	var sim := game_sim()
	var h := _ally(sim, "healer", 1.0, -120.0, 30.0)
	h.name = "Soigneur"
	var s := _ally(sim, "shooter", -2.0, -121.0, 110.0)
	var a := sim.spawn("Archer", 3.0, -119.0, "archer")
	a.hp = Catalog.ADEPT["archer"]["hp"]
	a.max_hp = a.hp
	sim.spawn("Garde", 12.0, -120.0, "guard")
	foe("creep", 2.0, -120.0, 100.0)
	foe("creep", 8.0, -120.0, 100.0)
	foe("brute", 4.0, -121.0, 300.0)
	var i := 0
	for who: Unit in [p, h, a, s, p]:
		GameState.selected = [who]
		sim.ability()
		var want: Dictionary = js()["abilities"][i]
		var snap := _usnap()
		var fx: Dictionary = GameState.effects[-1]
		var wfx: Dictionary = want["effect"]
		snap["effect"] = [fx["type"], r4(fx["x"]), r4(fx["z"]), r4(fx.get("r", 0.0)), (fx["color"] as Color).to_html(false)]
		want = want.duplicate()
		want["effect"] = [wfx["type"], wfx["x"], wfx["z"], wfx.get("r", 0.0), String(wfx["color"]).trim_prefix("#")]
		check(_same_quiet(snap, want), "compétence %d (%s) : %s ≠ %s" % [i + 1, who.role, snap, want])
		i += 1


## D9 : sans le drapeau, seul l'Ingénieur ; avec, Paladin, Soigneur et Tireur comme avant leur mise de côté.
func test_legacy_heroes_flag() -> void:
	var sim := game()
	check_eq(GameState.units.size(), 1, "par défaut : l'Ingénieur seul")
	check_eq(GameState.units[0].role, "engineer", "par défaut : Ingénieur")
	check_eq(Simulation.legacy_heroes, false, "drapeau désactivé par défaut")
	Simulation.legacy_heroes = true
	sim.new_game(SEED)
	Simulation.legacy_heroes = false
	var roles := GameState.units.map(func(u: Unit) -> String: return u.role)
	check_eq(roles, ["paladin", "healer", "shooter", "engineer"], "avec le drapeau : trois héros puis l'Ingénieur")
	check_eq(GameState.units[0].pos(), Vector2(-2.5, 13.0), "Paladin en (−2,5 ; 13)")
	check_eq(GameState.units[0].max_hp, 180.0, "Paladin : 180 PV")
	check_eq(GameState.units[1].max_hp, 115.0, "Soigneur : 115 PV")
	check_eq(GameState.units[0].radius, 0.85, "Paladin : rayon 0,85")
	check(GameState.selected == [GameState.units[0]], "selected = [units[0]] : le Paladin")
	check(GameState.units[3].hidden, "l'Ingénieur attend toujours le portail")


## Effets de l'étape 9 : achèvement d'un chantier, sortie d'un adepte, résurrection, Ancre éveillée.
func test_deferred_effects() -> void:
	var sim := game()
	give(1000.0)
	var b := Building.create(0, "sigil", -27.0, -119.0)
	b.complete = true
	GameState.buildings.append(b)
	GameState.effects.clear()
	sim.summon_adept(b)
	check(GameState.effects.is_empty(), "invocation : plus d'éclair au portail (arrivée à l'autel)")
	GameState.effects.clear()
	var u := engineer()
	GameState.orb_owner = u
	u.orb_job = true
	u.x = Simulation.ORB_SPOT.x
	u.z = Simulation.ORB_SPOT.y
	GameState.orb_progress = Simulation.ORB_TIME
	sim.update_orb(0.0)
	check(GameState.orb_active, "Ancre éveillée")
	check_eq([GameState.effects[0]["r"], GameState.effects[1]["r"]], [7.0, 12.0], "Ancre : ondes de 7 et 12")
	check_eq(GameState.effects[0]["color"], Color("#bba7ff"), "Ancre : onde violette")


func _same_quiet(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in b:
			if not a.has(k) or not _same_quiet(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for k in a.size():
			if not _same_quiet(a[k], b[k]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 1e-3
	return a == b


## Creusement : éclair à chaque coup, onde de la case creusée, ondes de la galerie révélée (et des portails
## maléfiques éveillés). Scénario de creusement de référence (fixtures/dig_scenario.json).
func test_dig_and_gallery_effects() -> void:
	var sim := game()
	var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/fixtures/dig_scenario.json"))
	GameState.effects.clear()
	var c0: Array = sc["cells"][0]
	sim.world.dig_cell(int(c0[0]), int(c0[1]))
	var fx: Dictionary = GameState.effects[0]
	check_eq([fx["type"], fx["x"], fx["z"], fx["r"], fx["color"]], ["zone", c0[0] * 4.0 + 2.0, c0[1] * 4.0 + 2.0, 2.0, Color("#a89c86")],
		"case creusée : onde de rayon 2")
	for c: Array in sc["cells"]:
		sim.world.dig_cell(int(c[0]), int(c[1]))
	var blue := GameState.effects.filter(func(e: Dictionary) -> bool: return e["color"] == Color("#8fd6f0"))
	check(sim.state().found >= 1, "le scénario révèle au moins une galerie")
	check_eq(blue.size(), sim.state().found, "une onde bleue (rayon 6) par galerie révélée")
	check(blue.all(func(e: Dictionary) -> bool: return e["r"] == 6.0), "ondes de galerie de rayon 6")


## D9 : les héros du drapeau apparaissent sur un sol praticable (jungle au sud de l'entrée de la grotte).
func test_legacy_heroes_ground() -> void:
	var sim := game()
	for p: Vector2 in [Vector2(-2.5, 13.0), Vector2(1.0, 15.0), Vector2(3.0, 12.0)]:
		check(sim.state().walkable(p.x, p.y), "héros en %s : sol praticable" % p)
