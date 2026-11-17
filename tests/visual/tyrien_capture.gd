extends Node
## Capture du vrai rendu de l'Ingénieur tyrien à côté de l'Ancre, avec différents équipements (TyrienArt) :
## une vignette par ensemble, tourné vers la droite puis vers la gauche, assemblées dans une planche.
## Lancement (fenêtré : le rendu headless ne produit pas d'image) :
##   godot --path . res://tests/visual/tyrien_capture.tscn
## Image : tests/visual/out/tyrien/tyrien_equipement.png
const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/tyrien/"
const SETS := [
	{},
	{"Torse": "gear_iron"},
	{"Tête": "gear_helm", "Torse": "gear_iron", "Gants": "gear_gauntlets", "Bottes": "gear_greaves", "Main gauche": "gear_shield", "Main droite": "gear_blade"},
	{"Torse": "gear_leather", "Gants": "gear_gloves", "Bottes": "gear_boots", "Main droite": "gear_hammer"},
	{"Tête": "gear_hood", "Capteur oculaire": "gear_lens", "Dos": "gear_pack", "Bottes": "gear_boots", "Main gauche": "gear_lantern"},
	{"Tête": "gear_circlet", "Torse": "gear_mail", "Dos": "gear_cape"},
]
const CELL := Vector2i(130, 150)


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
	u.x = CaveShape.CORE.x - 4.0
	u.z = CaveShape.CORE.y + 3.0
	u.tx = u.x
	u.tz = u.z
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(u.x + 2.0, u.z - 1.0), 3)
	GameState.selected.clear()
	world.finish_painting()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sheet := Image.create(CELL.x * SETS.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
	for i in SETS.size():
		u.equipment = (SETS[i] as Dictionary).duplicate()
		for row in 2:
			u.face = 1 if row == 0 else -1
			GameState.sim_time = 0.3
			for k in 8:
				await get_tree().process_frame
			print("ensemble %d · face %d" % [i, u.face])
			await RenderingServer.frame_post_draw
			var c := world.camera.project(u.x, 0, u.z)
			var img := viewport.get_texture().get_image().get_region(Rect2i(int(c.x) - CELL.x / 2 + 18, int(c.y) - CELL.y + 16, CELL.x, CELL.y))
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, row * CELL.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "tyrien_equipement.png"))
	print("capture tyrien : %d ensembles" % SETS.size())
	get_tree().quit()
