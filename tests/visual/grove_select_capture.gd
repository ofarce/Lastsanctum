extends Node
## Bosquet pétrifié sélectionnable : clic gauche sur son feuillage (fiche HUD + halo), puis un adepte sélectionné
## et clic droit sur le feuillage (il part récolter). godot --path . res://tests/visual/grove_select_capture.tscn
const OUT := "res://tests/visual/out/groves/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var ic = main.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("hit_grove"))[0]
	sim.new_game(20261114)
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	var ts: TerrainState = world.terrain_state
	var o: Vector2i = ts.wood_left.keys().filter(func(k: Vector2i) -> bool:
		return (Vector2(k * 4) + Vector2(4, 4)).distance_to(ts.START_GROVE_AT) < 16.0)[0]
	var c := Vector2(o * 4) + Vector2(4, 4)
	GameState.units[0].x = c.x
	GameState.units[0].z = c.y + 7
	GameState.units[0].hidden = false
	world.camera.set_view(c, 3)
	world.finish_painting()
	world.fog.refresh(ts)
	await _shot("select_0")
	world.camera.set_view(c, 3)
	await get_tree().process_frame
	# Feuillage : au-dessus de l'emprise.
	var leaf: Vector2 = ic.project(c.x, 0.0, c.y - 3.0)
	print("hit_grove feuillage ", ic.hit_grove(leaf), " origine ", o)
	ic._incarnated_pick(leaf) if GameState.incarnated else ic._left_click(leaf, false)
	print("hud_grove ", GameState.hud_grove)
	await _shot("select_1_grove")
	var u := sim.spawn("Adepte", c.x + 10.0, c.y + 10.0, "indra")
	GameState.hud_grove = null
	GameState.selected = [u] as Array[Unit]
	print("grove_cell ", sim.grove_cell(o), " u ", u.pos(), " alive ", u.alive(), " hidden ", u.hidden, " adept ", Catalog.is_adept(u), " can_mine ", sim.can_mine(u))
	leaf = ic.project(c.x, 0.0, c.y - 3.0)
	print("hit_grove clic droit ", ic.hit_grove(leaf), " orb ", ic.hit_orb(leaf), " chest ", ic.hit_chest(leaf), " box ", ic.hit_production_chest(leaf))
	ic._right_click(leaf)
	print("job ", u.job)
	sim.paused = false
	await get_tree().create_timer(4.0).timeout
	print("adepte ", u.pos(), " travaille ", u.working, " porte ", u.carrying)
	await _shot("select_2_mine")
	get_tree().quit()
