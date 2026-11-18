extends Node
## Capture de la galerie des Exilés : survol du portrait (bouton Incarner), puis mode incarné.
## Lancement (fenêtré) : godot --path . res://tests/visual/incarnation_capture.tscn
## Images : tests/visual/out/incarnation/{1_survol,2_incarne}.png

const OUT := "res://tests/visual/out/incarnation/"


func _ready() -> void:
	get_window().size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var m: Node = load("res://main/main.tscn").instantiate()
	add_child(m)
	for i in 30:
		await get_tree().process_frame
	var eng: Unit = null
	for u: Unit in GameState.units:
		if u.role == "engineer":
			eng = u
	eng.hidden = false
	for i in 5:
		await get_tree().process_frame
	var g: ExileGallery = (m.get_node("Hud") as Hud).exile_gallery
	var slot: Control = g.get_child(2)
	get_viewport().warp_mouse(slot.get_global_rect().get_center())
	g._on_slot_enter(slot)  # warp_mouse ne déclenche pas mouse_entered
	for i in 10:
		await get_tree().process_frame
	await _shot("1_survol")
	ExileGallery.incarnate(eng)
	for i in 10:
		await get_tree().process_frame
	await _shot("2_incarne")
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
