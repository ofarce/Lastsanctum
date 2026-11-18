extends Node
## Captures du sol généré hors de la zone d'origine (monde procédural, étape 3), brouillard masqué.
##   godot --path . res://tests/visual/world_edge_capture.tscn
## Écrit tests/visual/out/monde/*.png : raccords ouest / nord, lisière de la jungle élargie, galerie de
## l'extension révélée et cases creusées dans un bloc de roche vierge.

const WORLD := preload("res://world/world.tscn")
const SHOTS := [
	["raccord_ouest_jungle", Vector2(-236, -70), 3],
	["raccord_nord", Vector2(0, -336), 3],
	["jungle_est", Vector2(330, -60), 2],
	["extension_creusee", Vector2(-330, -420), 3],
	["jungle_ouest_loin", Vector2(-400, -40), 2],
	["montagne_biome2", Vector2(200, -600), 2],
]


func _ready() -> void:
	var out_dir := "res://tests/visual/out/monde/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world: World = WORLD.instantiate()
	viewport.add_child(world)
	world.camera.input_enabled = false
	world.reset_world(20261114)
	for c in world.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 3:
			(c as CanvasLayer).visible = false
	# Extension : quelques cases creusées en roche vierge, puis révélation d'une galerie voisine.
	var st := world.terrain_state
	var t0 := Time.get_ticks_usec()
	for i in range(-86, -78):
		world.terrain_ops.dig_cell(i, -105)
	world.terrain_ops.painter.finish()
	print("creusement en roche vierge : %.1f ms, blocs peints : %d" % [(Time.get_ticks_usec() - t0) / 1000.0, world.terrain.materialized])
	for shot: Array in SHOTS:
		world.camera.set_view(shot[1], shot[2])
		world.apply_view()
		for i in 3:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(out_dir + String(shot[0]) + ".png")
		print("capture ", shot[0], " (décor généré : %d nœuds)" % world.generated_decor_nodes())
	get_tree().quit()
