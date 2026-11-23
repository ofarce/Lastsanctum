extends Node
## Capture des rencontres de salle (sim/rooms.gd) dans le Temple en salles : l'Ingénieur entre dans une salle de
## combat, le groupe se lève et se bat ; groupe tué, salle nettoyée ; nuits passées, salle repeuplée.
##   godot --path . res://tests/visual/room_encounter_capture.tscn
const OUT := "res://tests/visual/out/rencontres/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)


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
	# Sans la séquence d'ouverture ; l'Ingénieur hors de sa capsule.
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
	# Une première passe pour tirer les tanières, puis la salle de combat légère hors chemin protégé la plus proche.
	_run(sim, 0.1)
	var prot := RoomEncounters.protected_rooms(st)
	var dens: Array = GameState.roamers["dens"]
	var d: Dictionary = {}
	for x: Dictionary in dens:
		if x.has("room") and x["tier"] == "L" and not prot.has(x["room"]):
			if d.is_empty() or Vector2(x["x"], x["z"]).distance_to(CaveShape.CORE) < Vector2(d["x"], d["z"]).distance_to(CaveShape.CORE):
				d = x
	var room: Dictionary = st.temple_layout["rooms"][d["room"]]
	var rr: Rect2i = room["rect"]
	var c := Vector2(d["x"], d["z"])
	print("salle %d (%s, quartier %s) en %s · %s · rencontres : %d" % [d["room"], d["tier"], d["quarter"], c, d["kinds"], dens.filter(func(x: Dictionary) -> bool: return x.has("room")).size()])
	world.terrain_ops.reveal_gallery(c.x, c.y)
	# Avant : l'Ingénieur à la porte de la salle, rien ne s'est levé.
	eng.x = rr.position.x * 4.0 - 6.0
	eng.z = c.y
	eng.tx = eng.x
	eng.tz = eng.z
	_run(sim, 0.5)
	print("avant l'entrée : groupe levé ", d.has("members"), " · PV ", eng.hp, " / ", eng.max_hp)
	# Entrée : le groupe se lève.
	eng.x = rr.position.x * 4.0 + 6.0
	eng.tx = eng.x
	GameState.selected = []
	_run(sim, 1.5)
	var members: Array = d.get("members", [])
	print("après l'entrée : groupe levé ", d.has("members"), " · ", members.size(), " ennemis · dans la salle ",
		members.all(func(e: Enemy) -> bool: return st.temple_room(e.x, e.z).get("id", -1) == d["room"]), " · PV ", eng.hp, " / ", eng.max_hp)
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(c + Vector2(-8, -2), 3)
	world.fog.refresh(st)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_salle_levee")
	# Groupe tué : salle nettoyée.
	for e: Enemy in members:
		e.hp = 0.0
	sim.paused = false
	eng.hp = eng.max_hp
	_run(sim, 1.0)
	print("groupe tué : nettoyée le jour ", d.get("cleared_day", "?"), " (jour ", DayNight.day(GameState.sim_time), ")")
	# L'Ingénieur sort ; trois nuits passent (deux dans C).
	eng.x = rr.position.x * 4.0 - 10.0
	eng.tx = eng.x
	var nights := RoomEncounters.REPOP_NIGHTS_C if d["quarter"] == "C" else RoomEncounters.REPOP_NIGHTS
	GameState.sim_time += DayNight.LENGTH * nights
	_run(sim, 0.2)
	print("après %d nuits : dormante %s · repeuplements %d · nouveau tirage %s" % [nights, not d.has("members"), d["repop"], d["kinds"]])
	eng.x = rr.position.x * 4.0 + 6.0
	eng.tx = eng.x
	_run(sim, 1.0)
	print("nouvelle entrée : groupe levé ", d.has("members"), " · ", (d.get("members", []) as Array).size(), " ennemis")
	get_tree().quit()
