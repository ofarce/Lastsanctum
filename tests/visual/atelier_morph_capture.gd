extends Node
## Capture des pièces de l'Atelier (WorkshopMorph) : dix ateliers au travail, un par recette, à quatre instants
## (pièces en vol, silhouette assemblée, éclat et icône, icône en route vers le coffre rouge).
## godot --path . res://tests/visual/atelier_morph_capture.tscn
const OUT := "res://tests/visual/out/atelier_morph/"
const MAIN = preload("res://main/main.tscn")
const Recipes := preload("res://data/recipes.gd")

var _vp: SubViewport
var _world: World


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(Vector2(-1, -111), 3)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = -40.0
	eng.z = -112.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 31.7
	var items: Array = Recipes.RECIPES["workshop"].keys()
	var shops: Array[Building] = []
	for k in items.size():
		var b := Building.create(k, "workshop", -25.0 + (k % 5) * 12.0, -118.0 + (k / 5) * 14.0)
		b.complete = true
		b.finished_at = -10.0
		b.recipe = items[k]
		GameState.buildings.append(b)
		shops.append(b)
		var u := sim.spawn("Adepte", b.x, b.z, Production.staff_role(b))
		u.job = {"type": "staff", "building": b, "post": "worker", "step": "post"}
		var p := Production.post_spot(b, 0)
		u.x = p.x
		u.z = p.y
		u.tx = p.x
		u.tz = p.y
		u.working = true
	world.camera.input_enabled = false
	_world = world
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	var total := Recipes.craft_time("workshop")
	await get_tree().create_timer(1.0).timeout
	for step: Array in [["1_vol", 0.4], ["2_silhouette", 0.97]]:
		for b in shops:
			b.craft = total * float(step[1])
		GameState.sim_time += 0.5
		await _shot(step[0])
	for b in shops:
		b.craft = 0.0
	await get_tree().create_timer(0.2).timeout
	GameState.sim_time += 0.3
	await _shot("3_eclat")
	GameState.sim_time += 0.75
	await _shot("4_vers_le_coffre")
	get_tree().quit()
