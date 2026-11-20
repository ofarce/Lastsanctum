extends Node
## Captures de la météo par tranches de journée (core/weather.gd) : carte du HUD avec la prévision,
## berges inondées sous l'orage et sous la pluie.
##   godot --path . res://tests/visual/weather_capture.tscn
## Écrit tests/visual/out/meteo/*.png (1440×900).

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/meteo/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.new_game(20261114)
	sim.paused = true
	# Passé l'ouverture : Ancre éveillée, pas d'assaut. La caméra suit l'Exilé, qu'on pose près de l'eau.
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.opening_stage = ""
	GameState.incarnated = null
	GameState.next_wave = 1e9
	await get_tree().process_frame
	var st := sim.state()
	# Première tranche de chaque temps, et une tranche claire suivie d'un changement.
	var first := {}
	for s in range(Weather.SLOTS, 80):
		var k := Weather.kind_at(st.seed, s)
		if not first.has(k) and Weather.slot_time(s) > 0.0:
			first[k] = s
	print("graine ", st.seed, " · tranches ", first)
	var shots := []
	for k: String in ["clair", "couvert", "pluie", "orage", "brume"]:
		if first.has(k):
			shots.append([k + "_pont", int(first[k]), Vector2(0, 24), 2])
	if first.has("orage"):
		shots.append(["orage_berge", int(first["orage"]), Vector2(30, st.river.center(30.0) - st.river.half_width(30.0) - 1.5), 3])
	for shot: Array in shots:
		# On entre dans la tranche, puis on laisse le temps s'installer (RAMP).
		GameState.weather = {}
		GameState.sim_time = Weather.slot_time(int(shot[1]) - 1) + 1.0
		Weather.tick(st)
		GameState.sim_time = Weather.slot_time(int(shot[1])) + 0.5
		Weather.tick(st)
		GameState.sim_time += Weather.RAMP + 4.0
		Weather.tick(st)
		var at: Vector2 = shot[2]
		eng.x = at.x
		eng.z = at.y
		eng.tx = at.x
		eng.tz = at.y
		world.camera.set_view(at, shot[3])
		world.apply_view()
		world.finish_painting()
		hud.hide_notice()
		# Sous l'orage : la foudre frappe l'Exilé à découvert, pour voir l'éclair.
		if String(shot[0]) == "orage_berge":
			GameState.sim_time = Weather.bolt_time(floori(GameState.sim_time / Weather.BOLT_PERIOD) + 1) + 0.05
			for n in 200:
				GameState.effects.clear()
				if sim.combat.lightning_strike(n, st.seed).distance_to(eng.pos()) < 0.01:
					break
		for i in 6:
			await get_tree().process_frame
		for i in 2:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + String(shot[0]) + ".png"))
		print("capture ", shot[0], " · ", HudModel.sky_status(), " · crue ", st.river.flood, " · vitesse de l'Exilé ×", Weather.speed_at(eng.x, eng.z))
	get_tree().quit()
