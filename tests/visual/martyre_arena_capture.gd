extends Node
## La Martyre de Byrsa dans son arène du quartier B (Temple en salles) : la porte de la route du boss scellée, elle se
## lève à l'entrée de l'Exilé avec son dôme, les assauts continuent ; à sa chute, la porte s'ouvre et le portail de
## retour de l'arène s'allume.
##   godot --path . res://tests/visual/martyre_arena_capture.tscn
const OUT := "res://tests/visual/out/martyre_arene/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)


func _place(u: Unit, at: Vector2) -> void:
	u.x = at.x
	u.z = at.y
	u.tx = at.x
	u.tz = at.y


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	GameState.opening_stage = ""
	GameState.in_capsule = false
	var eng := Capsule.engineer()
	eng.hidden = false
	ExileGallery.incarnate(eng)
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var st := sim.state()
	_run(sim, 0.1)
	# Porte mb2 scellée : de la roche, infranchissable.
	var door: Array = (st.door_cells.keys() as Array).filter(func(c: Vector2i) -> bool: return st.door_cells[c] == "mb2")
	var dc: Vector2i = door[1]
	var dp := Vector2(dc.x * 4.0 + 2.0, dc.y * 4.0 + 2.0)
	print("porte mb2 : fermée ", st.doors_closed["mb2"], " · praticable ", st.walkable(dp.x, dp.y), " · minable ", st.minable_block(dc.x, dc.y))
	# Un assaut en file : il ne doit pas être annulé par la Martyre.
	GameState.wave = 1
	GameState.spawn_queue = [{"at": GameState.sim_time + 999.0, "x": 0.0, "kind": "creep", "menace_tier": 0, "squad": 0}]
	GameState.menace = Martyre.MENACE + 100
	_run(sim, 0.2)
	print("menace au-delà du seuil, hors de l'arène : Martyre levée ", GameState.martyre_state != "")
	# Entrée dans l'arène.
	var arena := Martyre.arena_room(st)
	var c := Martyre.arena_center(arena)
	var rr: Rect2i = arena["rect"]
	_place(eng, Vector2(c.x, rr.end.y * 4.0 - 8.0))
	eng.hp = eng.max_hp
	_run(sim, 1.0)
	var m: Enemy = GameState.martyre
	print("dans l'arène : état ", GameState.martyre_state, " · arène ", GameState.martyre_arena, " · au centre ", m != null and m.pos().distance_to(c) < 3.0,
		" · hors vague ", m != null and m.beast, " · assaut gardé ", GameState.spawn_queue.size())
	# La caméra suit l'Exilé incarné : on le rapproche d'elle pour la voir.
	_place(eng, c + Vector2(0, 14))
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(c + Vector2(0, 8), 2)
	world.fog.refresh(st)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_arene")
	sim.paused = false
	# Chute : la porte s'ouvre, le portail de retour s'allume.
	m.hp = 0.0
	_run(sim, 1.0)
	print("chute : état ", GameState.martyre_state, " · porte fermée ", st.doors_closed["mb2"], " · praticable ", st.walkable(dp.x, dp.y),
		" · portail de retour ", GameState.room_portals.has(arena["id"]))
	GameState.spawn_queue = []
	_place(eng, dp + Vector2(0, 10))
	sim.paused = true
	world.camera.set_view(dp, 3)
	world.fog.refresh(st)
	await _shot("2_porte_ouverte")
	get_tree().quit()
