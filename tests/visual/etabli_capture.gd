extends Node
## Établi d’exo (dessin provisoire de l’Atelier) à côté de l’Atelier et de la Scierie : rangée du haut au repos,
## rangée du bas au travail. godot --path . res://tests/visual/etabli_capture.tscn
const OUT := "res://tests/visual/out/etabli/"
const MAIN = preload("res://main/main.tscn")
const TYPES := ["etabli", "workshop", "scierie"]

var _vp: SubViewport
var _world: World


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(Vector2(-13, -111), 3)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	# Hors séquence d'ouverture : sa cinématique reprendrait la caméra.
	GameState.opening_stage = ""
	GameState.in_capsule = false
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = -30.0
	eng.z = -112.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 31.7
	for row in 2:
		for k in TYPES.size():
			var b := Building.create(row * 10 + k, TYPES[k], -25.0 + k * 12.0, -118.0 + row * 14.0)
			b.complete = true
			b.finished_at = -10.0
			GameState.buildings.append(b)
			if row == 1:
				var role: String = Production.staff_role(b)
				var u := sim.spawn("Adepte", b.x, b.z, role)
				u.job = {"type": "staff", "building": b, "post": "worker", "step": "post"}
				var p := Production.post_spot(b, 0)
				u.x = p.x
				u.z = p.y
				u.tx = p.x
				u.tz = p.y
				u.working = true
	world.camera.input_enabled = false
	_world = world
	world.camera.set_view(Vector2(-13, -111), 3)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await get_tree().create_timer(1.0).timeout
	await _shot("salle")
	# Mod Analyse porté : loupe à la ceinture sans ennemi, levée devant l'œil avec un ennemi proche.
	_world = null
	eng.equipment["Module 1"] = "module_analyse"
	eng.x = -30.0
	eng.z = -100.0
	world.camera.set_view(Vector2(-30, -102), 6)
	# La révélation du mod obtenu (ui/hud/mod_reveal.gd) passe d'abord au-dessus de l'Ingénieur.
	await get_tree().create_timer(5.0).timeout
	await _shot("loupe_ceinture")
	var e := Enemy.make("scout", -22.0, -100.0, 0.0)
	GameState.enemies.append(e)
	for i in 20:
		GameState.sim_time += 0.05
		await get_tree().process_frame
	world.camera.set_view(Vector2(-27, -102), 4)
	await _shot("loupe_levee")
	get_tree().quit()
