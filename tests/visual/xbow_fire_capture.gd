extends Node
## Captures des effets de tir de l'Arbalestrie (planches/arbalestrie-tir-planche.html) : chaque munition à
## quatre instants après le tir, vers la droite puis en diagonale.
## godot --path . res://tests/visual/xbow_fire_capture.tscn
const OUT := "res://tests/visual/out/xbow_fire/"
const MAIN = preload("res://main/main.tscn")
const Ammo := preload("res://data/ammo.gd")
const AGES: Array[float] = [0.02, 0.06, 0.13, 0.3]

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


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
	eng.x = -4.0
	eng.z = -150.0
	ExileGallery.incarnate(eng)
	world.camera.set_view(Vector2(-1.0, -150.0), 3)
	for id: String in Ammo.ORDER:
		for aim: Vector2 in [Vector2(20.0, 0.0), Vector2(12.0, -12.0)]:
			GameState.effects.clear()
			GameState.ammo = id
			eng.attack = 0.0
			sim.combat.gear_attack(eng, Vector2(eng.x, eng.z) + aim)
			var age := 0.0
			for k in AGES.size():
				var dt := AGES[k] - age
				age = AGES[k]
				GameState.sim_time += dt
				for e: Dictionary in GameState.effects:
					e["age"] += dt
				await _shot("%s_%s_%d" % [id, "droite" if aim.y == 0.0 else "diag", k])
			GameState.sim_time += 1.0
	get_tree().quit()
