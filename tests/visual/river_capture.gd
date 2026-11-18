extends Node
## Captures de la rivière de la jungle et de ses ponts, brouillard masqué.
##   godot --path . res://tests/visual/river_capture.tscn
## Écrit tests/visual/out/riviere/*.png : raccords ouest / nord, lisière de la jungle élargie, galerie de
## l'extension révélée et cases creusées dans un bloc de roche vierge.

const WORLD := preload("res://world/world.tscn")
const SHOTS := [
	["pont_central", Vector2(0, 34), 3],
	["riviere_large", Vector2(0, 20), 1],
	["pont_ouest", Vector2(-130, 34), 3],
	["pont_est_loin", Vector2(330, 34), 2],
]


func _ready() -> void:
	var out_dir := "res://tests/visual/out/riviere/"
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
	for b: Dictionary in world.terrain_state.river.bridges:
		print("pont x = %d" % b["x"])
	var t := SHOTS.duplicate(true)
	var f := world.terrain_state.flora
	for want: int in [Flora.Zone.CLEARING, Flora.Zone.DENSE]:
		var found := false
		for x in range(-200, 200, 8):
			for z in range(-40, 20, 8):
				if not found and f.zone_at(x, z) == want and f.zone_at(x + 12, z) == want and f.zone_at(x - 12, z) == want:
					t.append(["zone_%s" % ("clairiere" if want == Flora.Zone.CLEARING else "dense"), Vector2(x, z), 3])
					found = true
	t[2][1] = Vector2(world.terrain_state.river.bridges[1]["x"], 34)
	t[3][1] = Vector2(world.terrain_state.river.bridges[4]["x"], 34)
	GameState.reset()
	var lairs := Wildlife.lairs(world.terrain_state, 20261114)
	for l in lairs:
		Wildlife._spawn(l)
	for kind: String in ["croc", "feline"]:
		for l in lairs:
			if l["kind"] == kind:
				t.append(["faune_" + kind, Vector2(l["x"], l["z"]), 4])
				# Un Paladin à côté, pour lever le brouillard et donner l'échelle.
				var u := Unit.new()
				u.role = "paladin"
				u.hp = 100.0
				u.max_hp = 100.0
				u.x = float(l["x"]) - 4.0
				u.z = float(l["z"]) - (2.0 if kind == "croc" else 0.0)
				GameState.units.append(u)
				break
	t.append(["aube_brume", Vector2(-60, 34), 3, (1.02 - DayNight.START) * DayNight.LENGTH])
	t.append(["jour_vie", Vector2(-60, 34), 4, 60.0])
	t.append(["pluie_pont", Vector2(0, 30), 2, 60.0, "pluie"])
	t.append(["orage_pont", Vector2(0, 30), 2, 61.0, "orage"])
	t.append(["crepuscule_pont", Vector2(0, 20), 2, (0.64 - DayNight.START) * DayNight.LENGTH])
	t.append(["nuit_pont", Vector2(0, 20), 2, (0.85 - DayNight.START) * DayNight.LENGTH])
	t.append(["nuit_lisiere", Vector2(0, -75), 2, (0.85 - DayNight.START) * DayNight.LENGTH])
	for shot: Array in t:
		GameState.sim_time = shot[3] if shot.size() > 3 else 30.0
		GameState.weather = {"kind": shot[4], "from": shot[4], "since": 0.0} if shot.size() > 4 else {}
		for k in 4:
			await get_tree().process_frame
		world.camera.set_view(shot[1], shot[2])
		world.apply_view()
		world.fog.refresh(world.terrain_state)
		world._sync_units()
		world._sync_enemies()
		for i in 3:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(out_dir + String(shot[0]) + ".png")
		print("capture ", shot[0], " (décor généré : %d nœuds)" % world.generated_decor_nodes())
	get_tree().quit()
