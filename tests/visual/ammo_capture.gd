extends Node
## Captures de l'Arbalestrie modulaire : chaque munition en vol et à l'impact, puis le barillet du HUD
## (fermé, ouvert avec survol). godot --path . res://tests/visual/ammo_capture.tscn
const OUT := "res://tests/visual/out/ammo/"
const MAIN = preload("res://main/main.tscn")
const Ammo := preload("res://data/ammo.gd")

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


## Vieillit effets et chiffres de `dt` sans faire tourner la simulation.
func _age(dt: float) -> void:
	for e: Dictionary in GameState.effects:
		e["age"] += dt
	for e: Dictionary in GameState.damage_numbers:
		e["age"] += dt


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	GameState.orb_active = true
	GameState.research_done[Ammo.RESEARCH] = true
	for r: String in Catalog.RES_ORDER:
		GameState.res[r] = 500.0
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	eng.x = -8.0
	eng.z = -150.0
	ExileGallery.incarnate(eng)
	world.camera.set_view(Vector2(-1.0, -150.0), 3)
	for id: String in Ammo.ORDER:
		GameState.enemies.clear()
		GameState.effects.clear()
		GameState.damage_numbers.clear()
		var target := Enemy.make("scout", 6.0, -150.0, 0.5)
		GameState.enemies.append(target)
		if id == "aether":
			GameState.enemies.append(Enemy.make("scout", 8.0, -152.5, 0.5))
			GameState.enemies.append(Enemy.make("scout", 4.5, -147.5, 0.5))
			GameState.enemies.append(Enemy.make("scout", 12.0, -146.0, 0.5))
		eng.hp = eng.max_hp * 0.6
		GameState.ammo = id
		eng.attack = 0.0
		sim.combat.gear_attack(eng, Vector2(target.x, target.z))
		_age(0.17)
		await _shot("%s_1_vol" % id)
		_age(0.22)
		await _shot("%s_2_impact" % id)
		_age(0.25)
		await _shot("%s_3_suite" % id)
		_age(0.3)
		await _shot("%s_4_fin" % id)
	GameState.enemies.clear()
	GameState.effects.clear()
	GameState.damage_numbers.clear()
	GameState.ammo = "indra"
	GameState.res["savoir"] = 1.0
	var barrel: Control = null
	for n in main.find_children("*", "Control", true, false):
		if n.get_script() == preload("res://ui/hud/ammo_barrel.gd"):
			barrel = n
	await _shot("hud_1_ferme")
	barrel._open = true
	barrel._hover = 2
	await _shot("hud_2_ouvert_survol_medeina")
	barrel._hover = 3
	await _shot("hud_3_survol_sigil_insuffisant")
	get_tree().quit()
