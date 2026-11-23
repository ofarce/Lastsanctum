extends Node
## Boucle de 30 minutes en jeu (Temple en salles) : portail du hub allumé à la première visite, voyage hub → Ancre
## par la carte des portails, antichambre sûre (le groupe de la salle dure voisine n'y poursuit pas l'Exilé),
## rappel d'assaut gratuit, une fois par assaut.
##   godot --path . res://tests/visual/room_portals_capture.tscn
const OUT := "res://tests/visual/out/boucle/"
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


func _room(st: TerrainState, role: String) -> Dictionary:
	for r: Dictionary in st.temple_layout["rooms"]:
		if r["role"] == role:
			return r
	return {}


func _center(r: Dictionary) -> Vector2:
	var rr: Rect2i = r["rect"]
	return Vector2(rr.position.x * 4.0 + rr.size.x * 2.0, rr.position.y * 4.0 + rr.size.y * 2.0)


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
	# 1. Portail du hub : éteint avant la visite, allumé à l'entrée.
	var hub := _room(st, "hub")
	print("avant : portail du hub allumé ", GameState.room_portals.has(hub["id"]), " · nœuds ", PortalNet.nodes(st).size())
	_place(eng, _center(hub) + Vector2(6, 0))
	_run(sim, 0.3)
	var nodes := PortalNet.nodes(st)
	print("dans le hub : allumé ", GameState.room_portals.has(hub["id"]), " · nœuds ", nodes.map(func(n: Dictionary) -> String: return n["name"]))
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(_center(hub), 3)
	world.fog.refresh(st)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_portail_hub")
	sim.paused = false
	# 2. Voyage du hub à l'Ancre.
	var seuil := PortalNet.room_threshold(st, hub)
	_place(eng, seuil)
	var ok := PortalNet.travel(sim, eng, PortalNet.ANCHOR_ID)
	_run(sim, PortalNet.DEPART + PortalNet.TRANSIT + PortalNet.LAND + 0.5)
	print("voyage hub → Ancre : parti ", ok, " · arrivé à ", eng.pos().distance_to(PortalNet.anchor_threshold()) < 2.0, " (", eng.pos(), ")")
	# 3. Antichambre sûre : lever le groupe de la salle dure voisine, puis s'y réfugier.
	var ante := _room(st, "antechamber")
	var dens: Array = GameState.roamers["dens"]
	var near: Dictionary = {}
	for d: Dictionary in dens:
		if d.has("room") and d["tier"] == "D" and d["quarter"] == "R":
			if near.is_empty() or Vector2(d["x"], d["z"]).distance_to(_center(ante)) < Vector2(near["x"], near["z"]).distance_to(_center(ante)):
				near = d
	_place(eng, Vector2(near["x"], near["z"]) + Vector2(0, 6))
	eng.hp = eng.max_hp
	_run(sim, 0.5)
	print("salle dure ", near["room"], " levée ", near.has("members"), " · ", near["kinds"])
	_place(eng, _center(ante))
	eng.hp = eng.max_hp
	_run(sim, 6.0)
	var hunting := (near.get("members", []) as Array).filter(func(e: Enemy) -> bool: return e.alive() and st.safe_at(e.x, e.z)).size()
	print("dans l'antichambre : sûre ", st.safe_at(eng.x, eng.z), " · proie du groupe ", near.get("prey") != null,
		" · ennemis entrés ", hunting, " · PV ", eng.hp, " / ", eng.max_hp)
	# 4. Rappel d'assaut : un assaut en cours, l'Exilé loin dans le quartier A.
	for e: Enemy in near.get("members", []):
		e.hp = 0.0
	_run(sim, 0.2)
	GameState.wave = 1
	GameState.spawn_queue = [{"at": GameState.sim_time + 999.0, "x": 0.0, "kind": "creep", "menace_tier": 0, "squad": 0}]
	var thr_a: Dictionary = {}
	for r: Dictionary in st.temple_layout["rooms"]:
		if r["role"] == "threshold" and r["quarter"] == "A":
			thr_a = r
	_place(eng, _center(thr_a))
	GameState.incarnated_hurt_at = -INF
	_run(sim, 0.3)
	print("assaut en cours ", PortalNet.assault_on(), " · rappel prêt ", PortalNet.assault_recall_ready(eng))
	var first := PortalNet.assault_recall(sim, eng)
	print("rappel d'assaut : parti ", first, " · à la capsule ", eng.pos().distance_to(Capsule.EXIT) < 0.5)
	_place(eng, _center(thr_a))
	var second := PortalNet.assault_recall(sim, eng)
	print("deuxième rappel du même assaut : ", second)
	GameState.spawn_queue = []
	get_tree().quit()
