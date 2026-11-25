extends "res://tests/econ_case.gd"
## Base des tests de combat (étape 8) : référence du prototype (assets/baked/hud/combat.json), unité et ennemis
## de test, instantané comparable aux relevés de tools/baker/hud.js.

static var _js: Dictionary


func js() -> Dictionary:
	if _js.is_empty():
		_js = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/hud/combat.json"))
	return _js


func setup(role: String, level: int) -> Unit:
	var sim := game()
	GameState.units.clear()
	GameState.next_uid = 0
	GameState.enemies.clear()
	GameState.effects.clear()
	GameState.fire_walls.clear()
	GameState.sim_time = 10.0
	# Les relevés du prototype partent d'une Ancre intacte (100) ; le jeu démarre désormais à 1.
	GameState.core_hp = 100.0
	var u := sim.spawn("U", 0.0, -120.0, role)
	if Catalog.ADEPT.has(role):
		u.hp = Catalog.ADEPT[role]["hp"]
		u.max_hp = u.hp
	u.level = level
	# Brouillard recalculé autour de l'unité : les ennemis posés près d'elle sont visibles, donc ciblés.
	sim.world.fog.refresh(sim.state())
	return u


func foe(kind: String, x: float, z: float, hp: float) -> Enemy:
	var e := Enemy.make(kind, x, z, 1.0)
	e.hp = hp
	e.max_hp = hp
	e.speed = 2.0
	e.reach = 1.5
	e.damage = 6.0
	GameState.enemies.append(e)
	return e


static func r4(v: float) -> float:
	return roundf(v * 1e4) / 1e4


func snap(u: Unit) -> Dictionary:
	return {"hp": GameState.enemies.map(func(e: Enemy) -> float: return r4(e.hp)), "attack": r4(u.attack), "orage": u.orage,
		"walls": GameState.fire_walls.size(), "xp": u.xp, "level": u.level,
		"stun": GameState.enemies.map(func(e: Enemy) -> float: return r4(e.stun)), "x": r4(u.x), "z": r4(u.z)}


func _same(got: Dictionary, want: Dictionary, what: String) -> void:
	for k: String in want:
		var a: Variant = got[k]
		var b: Variant = want[k]
		if a is Array:
			check_eq(a.size(), b.size(), "%s.%s (taille)" % [what, k])
			for i in mini(a.size(), b.size()):
				check_near(a[i], b[i], 1e-3, "%s.%s[%d]" % [what, k, i])
		else:
			check_near(float(a), float(b), 1e-3, "%s.%s" % [what, k])


func game_sim() -> Simulation:
	return _main.get_node("Simulation")


## Les relevés du prototype comptent +1 dégât par niveau ; le jeu, Catalog.lvl_bonus (+0,5 depuis le 2026-11-24).
## PV attendus d'un ennemi après `hits` coups reçus de `u` : le relevé, rehaussé de l'écart par coup. Un ennemi
## que le prototype donne mort reste attendu mort.
func lvl_hp(want_hp: float, u: Unit, hits: int) -> float:
	if want_hp <= 0.0:
		return want_hp
	return want_hp + hits * ((u.level - 1) - Catalog.lvl_bonus(u))
