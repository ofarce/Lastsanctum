extends Node
## Captures du HUD pour la planche « teintes des panneaux » (planches/hud-teintes-propositions.html) : même
## contexte, même bannière de dialogue, une image par teinte de HudStyle.panel_tone.
##   godot --path . res://tests/visual/hud_tones_capture.tscn
## Images : tests/visual/out/hud_teintes/<clé>.png (1440×900).

const Ctx := preload("res://tests/hud_context.gd")
const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/hud_teintes/"
## clé → [haut, bas, liseré clair, liseré bas, contour]
const TONES := {
	"1_ardoise": ["#39414f", "#171b23", "#e6e8f4", "#8a90b8", "#0a0c26"],
	"2_nuit": ["#2c3a78", "#0e1338", "#e6e8f4", "#8a90b8", "#0a0c26"],
	"3_sarcelle": ["#1f4f5c", "#0a1d24", "#d6f6fb", "#5fa9b8", "#04141a"],
	"4_mousse": ["#34503a", "#101f17", "#e4ecd6", "#8aa37c", "#07120b"],
	"5_gres": ["#6b4c3c", "#27191a", "#f0e2cc", "#b39678", "#150c0c"],
	"6_fer": ["#4b4844", "#1b1a19", "#ece6d8", "#a09a8c", "#0b0a09"],
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://sim/simulation.gd").play_opening = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	world.camera.input_enabled = false
	for c: Dictionary in Ctx.load_actions()["contexts"]:
		if c["name"] == "ingenieur_menu_construire":
			Ctx.apply(sim, c, true)
	world.camera.reset()
	world.finish_painting()
	hud.say("Ingénieur : Relevons les pierres. Le serment tient tant que l’Ancre demeure.", 600.0)
	await get_tree().create_timer(0.4).timeout
	for key: String in TONES:
		var tone: Array[Color] = []
		for hex: String in TONES[key]:
			tone.append(Color(hex))
		HudStyle.panel_tone = tone
		_redraw(hud)
		for i in 3:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + key + ".png"))
		print("capture ", key)
	get_tree().quit()


func _redraw(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw(c)
