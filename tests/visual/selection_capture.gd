extends Node
## Capture de la sélection alliée : halo cyan, barre de vie au survol, ligne d'ordre de déplacement, et bouton
## d'ordres tenu enfoncé (PressFx).
## godot --path . res://tests/visual/selection_capture.tscn
const OUT := "res://tests/visual/out/selection/"
const MAIN = preload("res://main/main.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(960, 600)
	var vp := get_viewport()
	load("res://sim/simulation.gd").play_opening = false
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	sim.new_game(20261114)
	main.get_node("Hud").dialogue.visible = false
	var allies: Array[Unit] = []
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and not u.is_enemy():
			allies.append(u)
	print("allies: ", allies.size())
	GameState.selected.assign(allies)
	var c := allies[0].pos()
	sim.issue_move(c + Vector2(14.0, 6.0))
	world.camera.set_view(c + Vector2(6, 3), 3)
	for i in 20:
		await RenderingServer.frame_post_draw
	# Survol : la barre de vie de la première unité.
	main.get_node("Input").set_process(false)
	UnitView.hovered = allies[0]
	for i in 10:
		UnitView.hovered = allies[0]
		await RenderingServer.frame_post_draw
	_save(vp, "units.png")
	# Bouton d'ordres tenu enfoncé.
	var btn: BaseButton = null
	for n in main.find_children("*", "ActionButton", true, false):
		if (n as Control).is_visible_in_tree() and not (n as BaseButton).disabled:
			btn = n
			break
	if btn:
		var at := btn.get_global_rect().get_center()
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		for i in 6:
			await RenderingServer.frame_post_draw
		print("pressed: ", PressFx.down(btn), " rect ", btn.get_global_rect())
		_save(vp, "button_down.png")
	get_tree().quit()


func _save(vp: Viewport, name: String) -> void:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + name))
