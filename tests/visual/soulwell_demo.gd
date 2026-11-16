extends Node
## Démonstration du Puits des Âmes (planche « Puits des Âmes · Lotus de pierre ») en jeu réel, fenêtrée :
## halo diffus, Paladin blessé qui entre dans le halo (« + » verts), Tireur rappelé (bulle qui devient l'unité).
## Lancement : godot --path . res://tests/visual/soulwell_demo.tscn
## Captures : tests/visual/out/puits/puits_<n>.png.

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/puits/"
const WELL := Vector2(-30.0, -104.0)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	GameState.next_wave = 1e9
	var b := Building.create(GameState.buildings.size(), "soulwell", WELL.x, WELL.y)
	b.complete = true
	b.progress = Catalog.BUILDINGS["soulwell"]["time"]
	b.finished_at = -10.0
	GameState.buildings.append(b)
	var pal := sim.spawn("Paladin", WELL.x + 15.0, WELL.y + 5.0, "paladin")
	pal.hp = pal.max_hp * 0.3
	pal.tx = WELL.x + 7.0
	pal.tz = WELL.y + 5.0
	pal.force_move = true
	var sh := sim.spawn("Tireur", WELL.x - 6.0, WELL.y + 6.0, "shooter")
	sh.hp = 0.0
	sim.on_unit_death(sh)
	GameState.res["vie"] = 5000.0
	world.camera.set_view(Vector2(WELL.x - 2.0, WELL.y + 2.0), 4)
	# Soin : deux captures pendant que le Paladin est dans le halo ; rappel : captures à âge fixe de l'effet.
	var n := 0
	for at: float in [1.0, 1.8]:
		while GameState.sim_time < at:
			await get_tree().process_frame
		n = await _shot(n, pal)
	sim.revive_unit(b, sh)
	for age: float in [0.3, 1.0, 1.7, 2.2, 2.5, 2.8, 3.1, 3.4, 3.8, 4.5]:
		while ReviveFx.age(sh) < age:
			await get_tree().process_frame
		n = await _shot(n, pal)
	get_tree().quit()


func _shot(n: int, pal: Unit) -> int:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "puits_%d.png" % n))
	print("capture %d à %.2f s · Paladin %d/%d PV" % [n, GameState.sim_time, int(pal.hp), int(pal.max_hp)])
	return n + 1
