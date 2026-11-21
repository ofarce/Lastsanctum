extends Node
## Capture du phare de butin (planches/butin-propositions.html, piste 1 renforcée) : corps à fouiller de chaque
## rareté et un objet au sol, de jour puis de nuit.
## godot --path . res://tests/visual/butin_capture.tscn
const OUT := "res://tests/visual/out/butin/"
const MAIN = preload("res://main/main.tscn")
const ItemStorage := preload("res://sim/item_storage.gd")

var _vp: SubViewport
var _sim: Simulation


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(seconds: float) -> void:
	for i in int(seconds / 0.04):
		GameState.spawn_queue.clear()
		GameState.next_wave = 1e9
		GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.neutral)
		_sim.tick(0.04)


func _corpse(kind: String, x: float, z: float, loot: Array[String]) -> void:
	var e := Enemy.make(kind, x, z, 1.0)
	e.hp = 0.0
	e.dead = true
	e.died_at = GameState.sim_time - 4.0
	e.loot = loot
	GameState.enemy_corpses.append(e)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.name = "SubViewport"
	_vp.size = Vector2i(1500, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	_sim = main.get_node("Simulation")
	var world: World = main.get_node("World")
	_sim.new_game(20261114)
	_sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = 6.0
	eng.z = -112.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = (0.45 - DayNight.START) * DayNight.LENGTH
	GameState.next_wave = 1e9
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	_run(1.0)
	_corpse("soldier", -10.0, -104.0, ["arrows", "arrows", "arrows", "arrows", "arrows"])
	_corpse("strazhar", 0.0, -100.0, ["copper_greatsword"])
	_corpse("brute", 12.0, -104.0, ["module_scale"])
	_corpse("strazhar", 20.0, -98.0, ["copper_greatsword", "copper_armor", "module_veil"])
	GameState.ground_items.append(ItemStorage.drop_of("copper_armor", Vector2(-4.0, -96.0)))
	await get_tree().create_timer(0.6).timeout
	await _shot("1_jour")
	GameState.sim_time = (0.95 - DayNight.START) * DayNight.LENGTH
	_run(1.0)
	print("phase ", DayNight.phase(GameState.sim_time))
	await _shot("2_nuit")
	# Ramassage : l'Exilé passe sur le soldat, le grand Strazhar, la brute (mod : pas de ligne) puis l'armure au sol.
	print("exilé dispo ", ItemStorage.character_available(eng), " · sans armure ", eng.unarmored, " · paquetage ", eng.inventory_capacity)
	for at: Vector2 in [Vector2(-10, -104), Vector2(20, -98), Vector2(12, -104), Vector2(-4, -96)]:
		eng.x = at.x
		eng.z = at.y
		eng.tx = at.x
		eng.tz = at.y
		_run(0.3)
	var hud := get_node("SubViewport").get_child(0).get_node("Hud") as Hud
	print("lignes ", hud.loot_feed.rows.map(func(r: Dictionary) -> String: return hud.loot_feed.line(r["item"], r["count"])))
	await _shot("3_ramasse")
	await get_tree().create_timer(5.5).timeout
	print("après 5,5 s : ", hud.loot_feed.rows.size(), " ligne(s)")
	await _shot("4_efface")
	get_tree().quit()
