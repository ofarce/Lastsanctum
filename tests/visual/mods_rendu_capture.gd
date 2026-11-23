extends Node
## Rendu animé de chacun des 15 mods, un seul porté à la fois : trois séquences d'images (repos de près,
## déclenchement de près, vue de jeu) où l'effet passe par les vraies règles (tir, coup reçu, mort, rappel, annonce…).
## Le jeu reste en pause ; le temps avance image par image (effets et chiffres compris).
## godot --path . res://tests/visual/mods_rendu_capture.tscn  →  tests/visual/out/mods_rendu/<mod>_<vue>_<nnn>.png
## puis planches/mods-rendu-en-jeu.html (WebP animés) par tools/mods/rendu.py.
const OUT := "res://tests/visual/out/mods_rendu/"
const MAIN = preload("res://main/main.tscn")
const Gear := preload("res://data/gear_items.gd")
const Ammo := preload("res://data/ammo.gd")
const MODS := ["veil", "iris", "drill", "scale", "ember", "magnet", "lens", "barrel", "frost", "seal", "wisp", "anchor", "chant", "sack", "echo"]
const HOME := Vector2(-8.0, -150.0)
## Séquences : [nom, images, pas de temps (s), zoom].
const SEQS := [["porte", 20, 0.1, 4], ["declenche", 24, 0.05, 4], ["jeu", 20, 0.06, 3]]

var _vp: SubViewport
var sim: Simulation
var world: World
var eng: Unit
var _extra: Array[Unit] = []
## Actions à lancer en cours de séquence : image → Callable.
var _at := {}


func _frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _step(dt: float) -> void:
	GameState.sim_time += dt
	for e: Dictionary in GameState.effects:
		e["age"] += dt
	for e: Dictionary in GameState.damage_numbers:
		e["age"] += dt
	GameState.effects = GameState.effects.filter(func(e: Dictionary) -> bool: return e["age"] < e["duration"])
	GameState.damage_numbers = GameState.damage_numbers.filter(func(e: Dictionary) -> bool: return e["age"] < e["duration"])


func _reset(mod: String) -> void:
	for e: Enemy in GameState.enemies:
		e.hidden = true
	GameState.enemies.clear()
	GameState.enemy_corpses.clear()
	GameState.effects.clear()
	GameState.damage_numbers.clear()
	GameState.enemy_shots.clear()
	for u: Unit in _extra:
		GameState.units.erase(u)
		u.hidden = true
	_extra.clear()
	_at.clear()
	for s: String in Gear.MODULE_SLOTS:
		eng.equipment.erase(s)
	eng.equipment["Module 1"] = "module_" + mod
	Gear.sync_pack(eng)
	eng.inventory.assign([])
	eng.mods.clear()
	eng.hp = eng.max_hp
	eng.veil_ready_at = 0.0
	eng.veil_hit_at = -INF
	eng.job = null
	eng.working = false
	eng.attack = 0.0
	eng.x = HOME.x
	eng.z = HOME.y
	eng.face = 1
	GameState.sim_time += 30.0
	GameState.ammo_changed_at = -INF
	GameState.ammo = "spirit"
	GameState.ammo_prev = "spirit"
	GameState.next_wave = INF
	world.camera.set_view(HOME, 4)
	# Profil : quelques pas vers l'est, l'Ingénieur reste tourné de côté.
	for i in 6:
		eng.x += 0.1
		await RenderingServer.frame_post_draw
	eng.tx = eng.x
	eng.tz = eng.z


func _foe(kind: String, dx: float, dz: float, hp := -1.0) -> Enemy:
	var e := Enemy.make(kind, eng.x + dx, eng.z + dz, 1.0)
	if hp > 0.0:
		e.hp = hp
	GameState.enemies.append(e)
	return e


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	sim = main.get_node("Simulation")
	sim.paused = true
	GameState.opening_stage = ""
	world = main.get_node("World")
	eng = Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	eng.equipment["Torse"] = "combinaison"
	GameState.mining_seal = true
	GameState.orb_active = true
	GameState.research_done["modular_crossbow"] = true
	for r: String in Catalog.RES_ORDER:
		GameState.res[r] = 999.0
	print("prêt")
	var only := OS.get_environment("MODS_ONLY")
	for m: String in MODS:
		if only != "" and only != m:
			continue
		for s: Array in SEQS:
			print(m, " ", s[0])
			await _reset(m)
			var cam: Vector2 = HOME
			if s[0] != "porte":
				cam = call("_" + m)
			world.camera.set_view(cam if s[0] == "jeu" else eng.pos(), s[3])
			for i in int(s[1]):
				if _at.has(i):
					(_at[i] as Callable).call()
				await _frame("%s_%s_%03d" % [m, s[0], i])
				_step(s[2])
				if m == "echo":
					Mods.tick(sim)
		print("fait ", m)
	get_tree().quit()


# Chaque fonction lance le déclenchement et rend le centre de la vue de jeu.

func _veil() -> Vector2:
	_at[2] = func() -> void: sim.combat.damage(eng, 8.0, null)
	return HOME


func _iris() -> Vector2:
	_foe("creep", 70.0, -50.0)
	return HOME + Vector2(10, -6)


func _drill() -> Vector2:
	eng.job = {"type": "dig", "cell": {"i": int(floor((eng.x + 6.0) / 4.0)), "j": int(floor(eng.z / 4.0))}}
	eng.working = true
	return HOME


func _shoot(at: Vector2) -> void:
	eng.attack = 0.0
	sim.combat.gear_attack(eng, at)


func _scale() -> Vector2:
	var e := _foe("soldier", 9.0, 0.0)
	_at[2] = func() -> void: Mods.graze(eng)
	_at[12] = func() -> void: _shoot(e.pos())
	return HOME + Vector2(4, 0)


func _ember() -> Vector2:
	var e := _foe("soldier", 9.0, 0.0)
	eng.hp = eng.max_hp * 0.25
	_at[2] = func() -> void: Mods.hurt(eng)
	for k in [8, 14, 20]:
		_at[k] = func() -> void: _shoot(e.pos())
	return HOME + Vector2(4, 0)


func _magnet() -> Vector2:
	eng.hp = eng.max_hp * 0.6
	var e := _foe("creep", 8.0, -2.0, 1.0)
	_at[2] = func() -> void: sim.combat.damage(e, 5.0, eng)
	return HOME + Vector2(3, 0)


func _lens() -> Vector2:
	_foe("soldier", 7.0, 0.0)
	_foe("soldier", 13.0, 0.0)
	_at[2] = func() -> void: _shoot(Vector2(eng.x + 20.0, eng.z))
	_at[12] = func() -> void: _shoot(Vector2(eng.x + 20.0, eng.z))
	return HOME + Vector2(8, 0)


func _barrel() -> Vector2:
	Ammo.select("indra")
	var e := _foe("brute", 14.0, 0.0)
	for k in [2, 6, 10, 14, 18]:
		_at[k] = func() -> void: _shoot(e.pos())
	return HOME + Vector2(8, 0)


func _frost() -> Vector2:
	_at[2] = func() -> void: Ammo.select("medeina")
	return HOME


func _seal() -> Vector2:
	var st := world.terrain_state
	var best := Vector2.INF
	for key: Vector2i in st.block_types:
		var c := Vector2(key.x * 4 + 2, key.y * 4 + 2)
		if TerrainState.Blocks.ORES.has(st.block_types[key]) and c.distance_to(HOME) < best.distance_to(HOME):
			best = c
	eng.x = best.x - 24.0
	eng.z = best.y
	eng.tx = eng.x
	eng.tz = eng.z
	return eng.pos() + Vector2(14, 0)


func _wisp() -> Vector2:
	return HOME


func _anchor() -> Vector2:
	GameState.incarnated_hurt_at = -INF
	_at[3] = func() -> void:
		Mods.recall(sim, eng)
		world.camera.set_view(eng.pos(), world.camera.px)
	return HOME


func _chant() -> Vector2:
	var a := sim.spawn("Adepte", eng.x + 6.0, eng.z + 2.0, "archer")
	a.working = true
	_extra.append(a)
	return HOME + Vector2(3, 0)


func _sack() -> Vector2:
	for i in 20:
		eng.inventory.append({})
	for i in 13:
		eng.inventory[i] = {"item": ["ration", "wood", "copper", "arrows", "torch"][i % 5], "quantity": 1 + i}
	var e := Enemy.make("soldier", eng.x + 5.0, eng.z, 1.0)
	e.hp = 0.0
	e.died_at = GameState.sim_time - 2.0
	e.loot.append("copper_shield")
	GameState.enemy_corpses.append(e)
	_at[8] = func() -> void: Loot.collect(eng)
	return HOME


func _echo() -> Vector2:
	GameState.next_wave = GameState.sim_time + 15.3
	return HOME
