extends Node
## Capture du réseau des portails (sim/portal_net.gd) : orbe suspendu au seuil d'un pylône canalisé, carte des
## portails, voyage de l'Exilé, trajet d'un adepte par le réseau, reflux annoncé puis sortie de la meute.
## godot --path . res://tests/visual/portal_capture.tscn
const OUT := "res://tests/visual/out/portails/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)


func _channel(sim: Simulation, p: Dictionary) -> Array[Unit]:
	var c := Vector2(p["x"], p["z"])
	var out: Array[Unit] = []
	for cult: String in Pylons.CULTS:
		var corner: Vector2 = Pylons.CORNER[cult]
		var u := sim.spawn("Esprit", c.x + corner.x, c.y + corner.y, cult)
		sim.set_job(u, {"type": "pray_pylon", "pylon": p})
		out.append(u)
	return out


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
	var hud: Hud = main.get_node("Hud")
	sim.new_game(20261114)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var st := sim.state()
	# Les deux pylônes les plus proches de la salle.
	var ps: Array = st.portals.duplicate()
	ps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["x"], a["z"]).length() < Vector2(b["x"], b["z"]).length())
	var p: Dictionary = ps[0]
	var q: Dictionary = ps[1]
	for d: Dictionary in [p, q]:
		world.terrain_ops.reveal_gallery(float(d["x"]), float(d["z"]))
		world.terrain_ops.wake_pylon(d)
	_run(sim, 0.5)
	# Ancre sans pylône canalisé : pas de portail.
	sim.paused = true
	world.camera.input_enabled = false
	world.camera.set_view(PortalNet.anchor_threshold(), 3)
	world.fog.refresh(st)
	world.finish_painting()
	hud.hide_notice()
	print("avant canalisation : nœuds ", PortalNet.nodes(st).size())
	await _shot("0a_ancre_sans_portail")
	sim.paused = false
	for d: Dictionary in [p, q]:
		for e: Enemy in GameState.enemies:
			if e.pylon == d:
				e.hp = 0.0
	_channel(sim, p)
	# Le second pylône est canalisé par la prière de l'Ingénieur : 10 s d'affilée, puis plus rien à tenir.
	eng.x = float(q["x"])
	eng.z = float(q["z"]) + 4.6
	eng.tx = eng.x
	eng.tz = eng.z
	eng.hp = eng.max_hp
	GameState.incarnated = eng
	print("E au socle : ", Pylons.toggle_bless(sim))
	_run(sim, 5.0)
	print("  à 5 s : course ", q.get("bless_run"), " · canalisé ", q["channeled"])
	sim.paused = true
	world.camera.set_view(Vector2(q["x"], q["z"]) + Vector2(0, -2), 3)
	world.fog.refresh(st)
	hud.hide_notice()
	await _shot("0c_priere_ingenieur")
	sim.paused = false
	_run(sim, 5.5)
	print("  à 10,5 s : canalisé ", q["channeled"], " · scellé ", q.get("sealed"), " · prière ", eng.job != null)
	GameState.incarnated = null
	_run(sim, 8.0)
	print("  8 s plus tard : canalisé ", q["channeled"])
	print("canalisés ", p["channeled"], " ", q["channeled"], " · nœuds ouverts ", PortalNet.open_nodes(st).size())
	for n in PortalNet.nodes(st):
		print("  nœud ", n["id"], " ", n["name"], " seuil ", n["pos"], " ouvert ", n["open"])
	sim.paused = true
	world.camera.set_view(PortalNet.anchor_threshold(), 3)
	world.fog.refresh(st)
	hud.hide_notice()
	await _shot("0b_ancre_portail")
	sim.paused = false
	# Errants des galeries autour des deux salles : retirés, la capture montre le voyage hors combat.
	GameState.enemies = GameState.enemies.filter(func(e: Variant) -> bool:
		return Vector2(e.x, e.z).distance_to(Vector2(p["x"], p["z"])) > 60.0 and Vector2(e.x, e.z).distance_to(Vector2(q["x"], q["z"])) > 60.0)
	var tp := PortalNet.threshold(st, p)
	GameState.incarnated = eng
	GameState.selected = [eng]
	eng.x = tp.x
	eng.z = tp.y + 0.8
	eng.tx = eng.x
	eng.tz = eng.z
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(Vector2(p["x"], p["z"]) + Vector2(0, 2), 3)
	world.fog.refresh(st)
	world.finish_painting()
	hud.hide_notice()
	await _shot("1_orbe_seuil")
	for e: Variant in GameState.enemies:
		if e.hp > 0.0 and Combat.hyp(e.x - eng.x, e.z - eng.z) < 30.0:
			print("  ennemi proche ", e.kind, " ", e.pos(), " pv ", e.hp, " caché ", e.hidden, " pylône ", e.pylon != null)
	print("danger ", PortalNet.danger(eng), " · nœud au seuil ", PortalNet.node_at(st, eng.pos()).get("id", "aucun"))
	print("E au seuil → carte : ", PortalNet.toggle_map(sim), " · depuis ", PortalNet.map_from)
	hud.minimap_overlay.set("_hover", int(q["id"]))
	hud.refresh(true)
	await _shot("2_carte")
	var ok := PortalNet.travel(sim, eng, int(q["id"]))
	print("voyage : ", ok)
	Events.portal_map.emit(PortalNet.NO_MAP)
	hud.hide_notice()
	_run(sim, 0.25)
	await _shot("3_bulle")
	_run(sim, 0.4)
	await _shot("4_rapetisse")
	_run(sim, 0.75)
	world.camera.set_view(Vector2(q["x"], q["z"]) + Vector2(0, 2), 3)
	world.fog.refresh(st)
	await _shot("5_arrivee")
	_run(sim, 1.0)
	print("Exilé en ", eng.pos(), " (seuil d'arrivée ", PortalNet.threshold(st, q), ") · en voyage ", PortalNet.warping(eng))
	# Un adepte d'Aether près de l'Ancre envoyé au second pylône : il passe par l'Ancre.
	var ad := sim.spawn("Adepte", CaveShape.CORE.x + 6.0, CaveShape.CORE.y + 12.0, "aether")
	ad.tx = float(q["x"]) + 10.0
	ad.tz = float(q["z"]) + 12.0
	ad.force_move = true
	var start := ad.pos()
	var warped := false
	for i in 60 * 40:
		sim.tick(1.0 / 60.0)
		warped = warped or PortalNet.warping(ad)
		if ad.pos().distance_to(Vector2(ad.tx, ad.tz)) < 1.0:
			break
	print("adepte ", start, " → ", ad.pos(), " · par un portail ", warped)
	# Reflux du premier pylône (caméra libre : plus d'Exilé incarné qu'elle suivrait).
	GameState.incarnated = null
	GameState.selected = []
	hud.hide_notice()
	GameState.reflux_next = GameState.sim_time
	_run(sim, 0.1)
	var rp: Dictionary = p if p.has("reflux") else q
	print("reflux sur ", rp["id"], " : ", rp.get("reflux", {}))
	world.camera.set_view(Vector2(rp["x"], rp["z"]) + Vector2(0, -2), 3)
	world.fog.refresh(st)
	_run(sim, 30.0)
	hud.hide_notice()
	await _shot("6_annonce_mi")
	_run(sim, 28.0)
	hud.hide_notice()
	await _shot("7_annonce_fin")
	_run(sim, 3.0)
	var pack := GameState.enemies.filter(func(e: Enemy) -> bool: return e.memo.get("reflux", false) and e.hp > 0.0)
	print("sortie : ", rp.get("reflux", {}), " · meute ", pack.size())
	await _shot("8_sortie")
	_run(sim, 20.0)
	print("après : reflux ", rp.has("reflux"), " · canalisé ", rp["channeled"], " · couverture ", rp["cover"])
	await _shot("9_retour")
	# Reflux du pylône scellé par l'Ingénieur, sans défenseurs : la meute survit, la canalisation cède.
	var sq: Dictionary = q if q.get("sealed", false) else p
	for e: Enemy in GameState.enemies:
		if e.memo.get("reflux", false):
			e.hp = 0.0
	sq["reflux"] = {"stage": "warn", "at": GameState.sim_time - PortalNet.WARN + 0.5}
	_run(sim, 4.0)
	world.camera.set_view(Vector2(sq["x"], sq["z"]) + Vector2(0, -2), 3)
	world.fog.refresh(st)
	hud.hide_notice()
	print("scellé en reflux : ", sq.get("reflux", {}), " · meute ", PortalNet.pack_alive(sq))
	await _shot("10_meute_scellee")
	_run(sim, 18.0)
	print("après : scellé ", sq.get("sealed"), " · canalisé ", sq["channeled"], " · meute ", PortalNet.pack_alive(sq))
	get_tree().quit()
