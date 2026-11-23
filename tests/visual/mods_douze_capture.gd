extends Node
## Les douze mods du 2026-11-21 : règles (sim/mods.gd) vérifiées et imprimées, puis dessin porté et déclenchements.
## godot --path . res://tests/visual/mods_douze_capture.tscn  →  tests/visual/out/mods_douze/
const OUT := "res://tests/visual/out/mods_douze/"
const MAIN = preload("res://main/main.tscn")
const Gear := preload("res://data/gear_items.gd")
const Ammo := preload("res://data/ammo.gd")

var _vp: SubViewport
var _fails := 0


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "ÉCHEC ") + what)
	if not ok:
		_fails += 1


func _wear(eng: Unit, mods: Array) -> void:
	for s: String in Gear.MODULE_SLOTS:
		eng.equipment.erase(s)
	for i in mods.size():
		eng.equipment[Gear.MODULE_SLOTS[i]] = "module_" + mods[i]
	Gear.sync_pack(eng)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	sim.paused = true
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	eng.equipment["Torse"] = "combinaison"
	GameState.mining_seal = true
	var world: World = main.get_node("World")
	eng.x = -8.0
	eng.z = -150.0
	world.camera.set_view(Vector2(eng.x, eng.z), 4)

	# ---- Règles
	_wear(eng, ["scale", "ember", "magnet", "lens", "barrel", "frost"])
	_check(Mods.attack_mult(eng) == 1.0, "écaille : pas de bonus sans frôlement")
	Mods.graze(eng)
	_check(Mods.scale_charged(eng), "écaille : chargée après un frôlement")
	_check(Mods.attack_mult(eng) == Mods.SCALE_MULT and not Mods.scale_charged(eng), "écaille : +50 % puis déchargée")
	eng.hp = eng.max_hp * 0.2
	Mods.hurt(eng)
	_check(Mods.ember_on(eng) and is_equal_approx(Mods.cd_mult(eng), 1.0 / Mods.EMBER_RATE), "braise : cadence +25 % sous 30 % PV")
	var ready_at := Mods.at(eng, "ember_ready")
	Mods.hurt(eng)
	_check(Mods.at(eng, "ember_ready") == ready_at, "braise : une fois par minute")
	var hp := eng.hp
	var foe := Enemy.make("creep", eng.x + 3.0, eng.z, 1.0)
	Mods.killed(eng, foe)
	_check(is_equal_approx(eng.hp - hp, eng.max_hp * Mods.MAGNET_HEAL), "aimant : +3 % PV par ennemi abattu")
	_check(Mods.pierce(eng) == 1, "lentille : un ennemi de plus")
	GameState.research_done["modular_crossbow"] = true
	for r: String in Catalog.RES_ORDER:
		GameState.res[r] = 999.0
	GameState.ammo = "spirit"
	Ammo.select("indra")
	var shots := [Mods.shot_ammo(eng), Mods.shot_ammo(eng), Mods.shot_ammo(eng), Mods.shot_ammo(eng)]
	_check(shots == ["indra", "spirit", "indra", "spirit"], "barillet : munitions alternées %s" % [shots])
	GameState.sim_time = GameState.ammo_changed_at + 1.0
	eng.mods.erase("ember")
	_check(is_equal_approx(Mods.cd_mult(eng), Mods.FROST_MULT), "culasse : −30 % après un changement")
	GameState.sim_time += Mods.FROST_TIME
	_check(Mods.cd_mult(eng) == 1.0, "culasse : effet fini après 3 s")
	eng.hp = eng.max_hp
	_wear(eng, ["seal", "wisp", "anchor", "chant", "sack", "echo"])
	_check(eng.inventory_capacity == 20, "sac : paquetage de 20 cases")
	_check(Mods.pickup_reach(eng) == Mods.SACK_REACH, "sac : fouille à 6 unités")
	_check(world.fog.vision_radius(eng) == 32, "lanterne : vision 8 cases (%d)" % world.fog.vision_radius(eng))
	_check(Mods.work_mult(eng.pos() + Vector2(10, 0)) == Mods.CHANT_MULT and Mods.work_mult(eng.pos() + Vector2(60, 0)) == 1.0, "chantre : +20 % à 8 cases, rien au-delà")
	# Filon le plus proche de la zone de départ : l'Ingénieur se poste à 6 cases.
	var best := Vector2.INF
	for key: Vector2i in world.terrain_state.block_types:
		var c := Vector2(key.x * 4 + 2, key.y * 4 + 2)
		if TerrainState.Blocks.ORES.has(world.terrain_state.block_types[key]) and c.distance_to(eng.pos()) < best.distance_to(eng.pos()):
			best = c
	var seal_spot := best + Vector2(-24, 0)
	var keep := eng.pos()
	eng.x = seal_spot.x
	eng.z = seal_spot.y
	var ores := Mods.ores_near(eng, world.terrain_state)
	_check(not ores.is_empty() and ores[0][2] <= 26.0, "sceau : %d cases de filon à 12 cases, la plus proche à %.1f" % [ores.size(), ores[0][2] if not ores.is_empty() else -1.0])
	eng.x = keep.x
	eng.z = keep.y
	_check(is_equal_approx(DayNight.fraction(Mods.raid_time(3)), float(Catalog.NIGHT_RAID["at"])), "écho : heure des meutes")
	eng.inventory.assign([])
	for i in 20:
		eng.inventory.append({})
	eng.inventory[14] = {"item": "ration", "quantity": 1}
	var held := not Gear.unequip(eng, "Module 5", eng.inventory, -1, eng.inventory_capacity)
	_check(held and eng.equipment.get("Module 5") == "module_sack", "sac : ne s'enlève pas avec la 2e rangée pleine")
	eng.inventory[14] = {}
	var start := eng.pos()
	GameState.sim_time = 400.0
	GameState.incarnated_hurt_at = -INF
	var went := Mods.recall(sim, eng)
	_check(went and eng.pos().distance_to(Capsule.EXIT) < 0.01, "ancre : retour à la capsule")
	_check(not Mods.recall(sim, eng), "ancre : recharge de 3 min")
	eng.x = start.x
	eng.z = start.y

	# ---- Dessin porté
	for k: Array in [["a", ["scale", "ember", "magnet", "lens", "barrel", "frost"]], ["b", ["seal", "wisp", "anchor", "chant", "sack", "echo"]]]:
		_wear(eng, k[1])
		eng.mods.clear()
		GameState.sim_time = 1000.0
		GameState.ammo_changed_at = -INF
		await _shot("%s_1_porte" % k[0])
		# Déclenchements : frôlement, braise, mort proche, changement de munition / rappel, écho.
		eng.mods["graze"] = GameState.sim_time - 0.1
		eng.mods["ember"] = GameState.sim_time - 0.5
		eng.mods["kill"] = GameState.sim_time - 0.25
		eng.mods["kill_from"] = Vector2(8, -3)
		eng.mods["recall"] = GameState.sim_time - 0.25
		eng.mods["recall_ready"] = GameState.sim_time + 100.0
		eng.mods["echo"] = GameState.sim_time - 0.3
		GameState.ammo_changed_at = GameState.sim_time - 0.3
		await _shot("%s_2_declenche" % k[0])
		for vd: String in ["side", "back"]:
			eng.tx = eng.x + (6.0 if vd == "side" else 0.0)
			eng.tz = eng.z - (6.0 if vd == "back" else 0.0)
			for i in 6:
				GameState.sim_time += 0.05
				eng.x += (0.1 if vd == "side" else 0.0)
				eng.z -= (0.1 if vd == "back" else 0.0)
				await RenderingServer.frame_post_draw
			await _shot("%s_3_%s" % [k[0], vd])
			eng.x = start.x
			eng.z = start.y
			eng.tx = eng.x
			eng.tz = eng.z
	# Sceau sensible : vue large sur les filons voisins.
	eng.x = seal_spot.x
	eng.z = seal_spot.y
	world.camera.set_view(Vector2(eng.x + 12.0, eng.z), 2)
	for i in 3:
		GameState.sim_time += 0.6
		await RenderingServer.frame_post_draw
	await _shot("b_4_sceau_filons")
	print("échecs : ", _fails)
	get_tree().quit()
