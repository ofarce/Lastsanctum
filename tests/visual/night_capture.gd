extends Node
## Une nuit jouée pas à pas (sim/night.gd) : flot de squelettes venus du sud et meutes des pylônes non canalisés.
## Affiche les effectifs dans la console et capture l'entrée sud.
## godot --path . res://tests/visual/night_capture.tscn
const OUT := "res://tests/visual/out/night/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _world: World
var _sim: Simulation
var _look := Vector2(0, -20)


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(_look, 3)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _count(kind: String, raid := false) -> int:
	return GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind == kind and e.raid == raid and not e.neutral and e.pylon == null and e.roam == null).size()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	_sim = main.get_node("Simulation")
	_world = main.get_node("World")
	_sim.new_game(20261114)
	_sim.paused = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.wave = 3
	GameState.menace = 250
	GameState.next_wave = 1e9
	GameState.sim_time = (0.6 - DayNight.START) * DayNight.LENGTH
	_world.camera.input_enabled = false
	_world.wind_scale = 0
	_world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	var st := _sim.state()
	print("pylônes : ", st.portals.size())
	# Avec « --open » : la galerie du pylône 5 est découverte et un tunnel creusé jusqu'à la salle de départ.
	if OS.get_cmdline_user_args().has("--open"):
		var q: Dictionary = st.portals[5]
		_world.terrain_ops.reveal_galleries_near(q["x"] - 20.0, q["z"] - 20.0, q["x"] + 20.0, q["z"] + 20.0)
		for i in range(floori(float(q["x"]) / 4.0) - 1, -13):
			for j in [floori(float(q["z"]) / 4.0), floori(float(q["z"]) / 4.0) + 1]:
				_world.terrain_ops.dig_cell(i, j)
	for p: Dictionary in st.portals:
		if Night.raid_start(_sim, p) != null:
			print("  pylône %s (%.0f, %.0f) actif %s · relié à l'Ancre" % [p["id"], p["x"], p["z"], p["active"]])
	var spawned := 0
	var seen := {}
	var shot := false
	var t0 := Time.get_ticks_msec()
	while DayNight.fraction(GameState.sim_time) >= 0.5:
		GameState.next_wave = 1e9
		_sim.tick(0.04)
		for e: Enemy in GameState.enemies:
			if e.raid and not seen.has(e):
				seen[e] = null
				print("  chien de meute né en ", e.pos(), " · dans la salle de départ : ", CaveShape.in_cave(e.x, e.z))
			if e.kind == "skeleton" and not seen.has(e):
				seen[e] = Vector2(e.x, e.z)
				if not CaveShape.outdoors(e.x, e.z) or not st.walkable(e.x, e.z):
					print("  HORS ZONE : ", e.pos())
				spawned += 1
		if not shot and spawned >= 8:
			shot = true
			var sk: Array = GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind == "skeleton")
			_look = sk[-1].pos()
			var eng: Unit = GameState.units[0]
			eng.hidden = false
			eng.x = _look.x + 6.0
			eng.z = _look.y
			eng.tx = eng.x
			eng.tz = eng.z
			_sim.tick(0.04)
			await _shot("1_squelettes")
		if int(GameState.sim_time / 0.04) % 250 == 0:
			var far := 1e9
			for e: Enemy in GameState.enemies:
				if e.raid:
					far = minf(far, Combat.dist(e, {"x": CaveShape.CORE.x, "z": CaveShape.CORE.y}))
			print("%s f=%.2f · squelettes sortis %d, vivants %d · chiens de meute %d (au plus près de l'Ancre : %.0f u) · menace %d" % [
				DayNight.clock(GameState.sim_time), DayNight.fraction(GameState.sim_time), spawned, _count("skeleton"), _count("beast", true),
				far, GameState.menace])
	var xs: Array = seen.values().filter(func(v: Variant) -> bool: return v != null).map(func(p: Vector2) -> float: return p.x)
	var zs: Array = seen.values().filter(func(v: Variant) -> bool: return v != null).map(func(p: Vector2) -> float: return p.y)
	print("levés entre x %.0f..%.0f, z %.0f..%.0f" % [xs.min(), xs.max(), zs.min(), zs.max()])
	var near := 1e9
	for e: Enemy in GameState.enemies:
		if e.kind == "skeleton":
			near = minf(near, e.pos().distance_to(CaveShape.CORE))
	print("squelette le plus proche de l'Ancre à l'aube : %.0f u" % near)
	print("aube · squelettes de la nuit : %d · %d ms" % [spawned, Time.get_ticks_msec() - t0])
	get_tree().quit()
