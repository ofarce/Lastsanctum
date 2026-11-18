extends Node
## Capture des attaques des armes du Creuset en jeu (planches/armes-attaques.html) : taille à une main, taille à deux
## mains et tir du canon, une ligne par arme, quelques images de l'animation, de l'arc blanc et de la balle.
## Lancement (fenêtré : le rendu headless ne produit pas d'image) :
##   godot --path . res://tests/visual/creuset_attack_capture.tscn
## Image : tests/visual/out/tyrien/creuset_attaques.png
const MAIN := preload("res://main/main.tscn")
const Storage := preload("res://sim/item_storage.gd")
const OUT := "res://tests/visual/out/tyrien/"
const ROWS := [["iron_sword", 9.0], ["iron_greatsword", 9.0], ["cannon", 16.0]]
const TIMES := [0.1, 0.22, 0.3, 0.38, 0.5]
const CELL := Vector2i(300, 210)


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	sim.new_game(20261114)
	var u: Unit = GameState.units.filter(func(x: Unit) -> bool: return x.role == "engineer")[0]
	u.hidden = false
	u.unarmored = true
	u.x = CaveShape.CORE.x - 8.0
	u.z = CaveShape.CORE.y + 6.0
	u.tx = u.x
	u.tz = u.z
	GameState.base_inventory_unlocked = true
	for i in 20:
		Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, "iron")
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(u.x + 5.0, u.z), 2)
	GameState.selected.clear()
	world.finish_painting()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sheet := Image.create(CELL.x * TIMES.size(), CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for r in ROWS.size():
		var item: String = ROWS[r][0]
		u.equipment = {"Main droite": item}
		GameState.enemies.clear()
		GameState.effects.clear()
		var e := Enemy.make("brute", u.x + float(ROWS[r][1]), u.z, 1.0)
		e.hp = 5000.0
		e.max_hp = 5000.0
		GameState.enemies.append(e)
		GameState.sim_time = 10.0
		u.attack = 0.0
		sim.combat.aimed_attack(u, Vector2(e.x, e.z))
		var t := 0.0
		for k in TIMES.size():
			var dt: float = TIMES[k] - t
			t = TIMES[k]
			GameState.sim_time += dt
			for fx: Dictionary in GameState.effects:
				fx["age"] = float(fx["age"]) + dt
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var c := world.camera.project(u.x + 4.0, 0, u.z)
			var img := viewport.get_texture().get_image().get_region(Rect2i(int(c.x) - CELL.x / 2, int(c.y) - CELL.y + 50, CELL.x, CELL.y))
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(k * CELL.x, r * CELL.y))
		print("%s : %d PV perdus" % [item, int(5000.0 - e.hp)])
	sheet.save_png(ProjectSettings.globalize_path(OUT + "creuset_attaques.png"))
	get_tree().quit()
