extends Node
## Décor du monastère (planche couloirs-boss-decor-propositions.html) : les trois arènes et un couloir par famille.
##   godot --path . res://tests/visual/monastere_capture.tscn [-- --down]   (--down : boss tombés, trophées posés)
const OUT := "res://tests/visual/out/monastere/"
const MAIN = preload("res://main/main.tscn")
const KINDS := ["arcade", "niche_lit", "celldoor", "table", "bell", "ossuary"]

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


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
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var st := sim.state()
	for i in 6:
		sim.tick(1.0 / 60.0)
	var down := OS.get_cmdline_user_args().has("--down")
	if down:
		st.doors_closed["mb1"] = false
		st.doors_closed["mb2"] = false
		GameState.oeil_state = "defeated"
	var S := Sanctum.data(st)
	var layout: Dictionary = S["layout"]
	for i in layout["braziers"].size():
		S["lit"][i] = true
	var counts := {}
	for e: Dictionary in layout["props"]:
		counts[e["k"]] = int(counts.get(e["k"], 0)) + 1
	print("Décor : %d objets" % layout["props"].size())
	print(counts)
	var spots := []
	for role: String in ["mb1", "mb2"]:
		for room: Dictionary in st.temple_layout["rooms"]:
			if room["role"] == role:
				var rr: Rect2i = room["rect"]
				spots.append([role, Vector2(rr.get_center()) * 4.0])
				print(role, " ", rr)
				if role == "mb2":
					for o: Vector2 in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
						spots.append(["mb2_coin", Vector2(rr.get_center()) * 4.0 + Vector2(rr.size) * 4.0 * o])
	spots.append(["oeil", TerrainState.eye_room_center()])
	for k: String in KINDS:
		for e: Dictionary in layout["props"]:
			if e["k"] == k:
				spots.append([k, Vector2(e["x"], e["z"])])
				break
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	(main.get_node("Hud") as CanvasLayer).visible = false
	var eng := Capsule.engineer()
	eng.hidden = false
	# Incarné, l'Exilé voit deux fois plus loin : la salle entière est hors du voile.
	ExileGallery.incarnate(eng)
	var n := 0
	for s: Array in spots:
		var c: Vector2 = s[1]
		# Le Temple est voilé hors de la vue des alliés : l'Ingénieur se tient au point de vue.
		var at := c + Vector2(0, 4)
		eng.x = at.x
		eng.z = at.y
		eng.tx = at.x
		eng.tz = at.y
		world.camera.set_view(c + Vector2(0, 2), 1 if s[0] in ["mb1", "mb2", "oeil", "mb2_coin"] else 3)
		world.fog.refresh(st)
		world.finish_painting()
		await get_tree().create_timer(2.5 if n == 0 else 0.3).timeout
		print(s[0], " ", c)
		await _shot("%d_%s%s" % [n, s[0], "_vaincu" if down else ""])
		n += 1
	get_tree().quit()
