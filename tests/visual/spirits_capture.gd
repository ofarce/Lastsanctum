extends Node
## Capture des esprits mineurs (planches/esprits-v6-propositions.html) : feu follet de Medeina en prière à son autel,
## Roue-mandala en marche, Orrery qui porte une caisse, Livre ailé au repos ; arrivée « Germe de l'autel »
## à 5 s (graine dans la statue) et à 9,7 s (esprit en trame) aux autels de Medeina et de Sigil.
## godot --path . res://tests/visual/spirits_capture.tscn
const OUT := "res://tests/visual/out/spirits/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
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
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = 6.0
	eng.z = -100.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var temples := {}
	for d: Array in [["medeina", 16.0, -116.0], ["sigil", 36.0, -116.0]]:
		var b := Building.create(GameState.buildings.size(), d[0], d[1], d[2])
		b.complete = true
		b.finished_at = -10.0
		GameState.buildings.append(b)
		temples[d[0]] = b
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(26, -114), 3)
	world.wind_scale = 0
	world.finish_painting()
	# Esprits en place.
	var med := sim.spawn("Esprit de Medeina", 0, 0, "medeina")
	var spot := sim.prayer_spot(med, temples["medeina"])
	med.x = spot.x
	med.z = spot.y
	med.tx = spot.x
	med.tz = spot.y
	med.job = {"type": "pray", "temple": temples["medeina"]}
	med.working = true
	var roles := [["indra", 12.0, -102.0], ["aether", 26.0, -101.0], ["sigil", 40.0, -102.0]]
	for r: Array in roles:
		var u := sim.spawn("Esprit", r[1], r[2], r[0])
		u.tx = u.x
		u.tz = u.z
		if r[0] == "aether":
			u.carrying = {"item": "copper", "quantity": 5}
	# Arrivées en cours.
	for d: Array in [["medeina", 5.0], ["sigil", 9.7]]:
		var b: Building = temples[d[0]]
		var p := Simulation.arrival_spot(b)
		var a := sim.spawn("Esprit", p.x, p.y, d[0])
		a.hidden = true
		a.tx = a.x
		a.tz = a.z
		a.arrival_temple = b
		a.arrival_end = GameState.sim_time + Simulation.ARRIVAL - float(d[1])
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_esprits")
	# Marche de la Roue : la vue suit le déplacement.
	var roue: Unit = GameState.units.filter(func(u: Unit) -> bool: return u.role == "indra")[0]
	roue.x += 0.4
	await _shot("2_marche")
	get_tree().quit()
