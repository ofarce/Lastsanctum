extends Node
## Capture de la mise à jour des unités (planches/unites-maj-propositions.html) : les deux camps face à face au repos,
## puis en mêlée (coups encaissés, coups annoncés de la Brute et du Strazhar, demi-tours), puis la mort des alliés
## (chute de la Caserne, dissipation des esprits) et des ennemis.
## godot --path . res://tests/visual/unites_maj_capture.tscn        (ajouter --headless : essai sans images)
const OUT := "res://tests/visual/out/unites_maj/"
const MAIN = preload("res://main/main.tscn")
const ALLIES := ["lame", "archer", "flammes", "sigil", "indra", "aether", "medeina"]
const FOES := ["creep", "spitter", "scout", "soldier", "shield", "archer", "brute", "strazhar", "croc", "feline", "beast"]

var _vp: SubViewport
var _headless := DisplayServer.get_name() == "headless"


func _shot(name: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	_vp.get_texture().get_image().save_png(path)
	print("UNITES_MAJ_CAPTURE ", path)


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
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	GameState.core_hp = 100.0
	sim.tick(1.0 / 60.0)
	var c := eng.pos()
	world.camera.input_enabled = false
	world.wind_scale = 0
	(main.get_node("Hud") as Hud).hide_notice()
	var allies: Array[Unit] = []
	for i in ALLIES.size():
		var u := sim.spawn("Adepte", c.x - 9.0 + i * 3.0, c.y + 3.0, ALLIES[i])
		u.hidden = false
		u.tx = u.x
		u.tz = u.z
		allies.append(u)
	eng.x = c.x - 12.0
	eng.z = c.y + 3.0
	# 1. Repos : les ennemis en rang, hors de portée, simulation figée.
	sim.paused = true
	for i in FOES.size():
		var e := Enemy.make(FOES[i], c.x - 13.0 + i * 2.6, c.y - 3.0, 1.0)
		e.face = 1
		GameState.enemies.append(e)
	world.fog.refresh(sim.state())
	world.finish_painting()
	world.camera.set_view(c, 4)
	for k in 6:
		world._sync_enemies()
		await get_tree().process_frame
	await _shot("1_repos")
	# 2. Mêlée : tout le monde au contact ; images prises au fil des coups.
	for i in GameState.enemies.size():
		var e: Enemy = GameState.enemies[i]
		e.x = c.x - 9.0 + (i % ALLIES.size()) * 3.0 + 1.2
		e.z = c.y + 3.0 + (0.6 if i >= ALLIES.size() else 0.0)
		e.cooldown = 0.05 * i
	sim.paused = false
	for shot in 6:
		for i in 9:
			sim.tick(1.0 / 60.0)
			await get_tree().process_frame
		world.fog.refresh(sim.state())
		await _shot("2_melee_%d" % shot)
	var winding := 0
	for e: Enemy in GameState.enemies:
		if e.windup > 0.0:
			winding += 1
	print("UNITES_MAJ coups annoncés vus : ", winding)
	# 3. Morts : les alliés tombent ou se dissipent, deux ennemis s'effondrent.
	for u in allies:
		u.hp = 0.0
	for e: Enemy in GameState.enemies:
		if e.kind == "soldier" or e.kind == "croc":
			e.hp = 0.0
	for shot in 4:
		for i in 12:
			sim.tick(1.0 / 60.0)
			await get_tree().process_frame
		await _shot("3_morts_%d" % shot)
	var fx := 0
	for n in world.ysort.get_children():
		if n is AllyDeathFx:
			fx += 1
	print("UNITES_MAJ unités ", GameState.units.size(), " · ennemis ", GameState.enemies.size(), " · dépouilles ", GameState.enemy_corpses.size(), " · morts alliées en cours ", fx)
	get_tree().quit()
