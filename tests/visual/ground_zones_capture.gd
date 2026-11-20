extends Node
## Captures du sol teinté par sous-zone (world/terrain/ground_zones.gd), brouillard masqué.
##   godot --path . res://tests/visual/ground_zones_capture.tscn
## Écrit tests/visual/out/sol_zones/*.png : une vue large, puis une vue par sous-zone.

const WORLD := preload("res://world/world.tscn")
const OUT := "res://tests/visual/out/sol_zones/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world: World = WORLD.instantiate()
	viewport.add_child(world)
	world.camera.input_enabled = false
	var t0 := Time.get_ticks_msec()
	world.reset_world(20261114)
	print("monde prêt en ", Time.get_ticks_msec() - t0, " ms")
	for c in world.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 3:
			(c as CanvasLayer).visible = false
	GameState.reset()
	var f := world.terrain_state.flora
	var shots := [["large_centre", Vector2(0, 0), 1], ["large_ouest", Vector2(-140, 0), 1], ["large_est", Vector2(140, 0), 1]]
	var names := {Flora.Zone.MARSH: "marais", Flora.Zone.CLEARING: "clairiere", Flora.Zone.DENSE: "dense", Flora.Zone.ROCKY: "rocheux"}
	for want: int in names:
		var found := false
		for x in range(-200, 200, 6):
			for z in range(-50, 24, 6):
				if not found and f.zone_at(x, z) == want and f.zone_at(x + 8, z) == want and f.zone_at(x - 8, z) == want:
					shots.append([names[want], Vector2(x, z), 3])
					found = true
	# Caches de la jungle (sim/loot.gd) : un dépôt de pont écarté et une épave, avec leur trait de lumière.
	GameState.caches = Loot.place_caches(world.terrain_state.road, 20261114)
	var seen := {}
	for c: Dictionary in GameState.caches:
		if not seen.has(c["kind"]):
			seen[c["kind"]] = true
			shots.append(["cache_" + String(c["kind"]), Vector2(c["x"], c["z"]), 4])
	# Rivière variée : la mare la plus large (banc de sable) en vue rapprochée et en vue large.
	var river := world.terrain_state.river
	print("mares ", river.pools, " · bancs ", river.bars)
	if not river.bars.is_empty():
		var bar: Dictionary = river.bars[0]
		shots.append(["mare_banc", Vector2(bar["x"], bar["z"]), 3])
		shots.append(["mare_large", Vector2(bar["x"], bar["z"] - 6.0), 1])
	for shot: Array in shots:
		GameState.sim_time = 60.0
		GameState.weather = {}
		for k in 4:
			await get_tree().process_frame
		world.camera.set_view(shot[1], shot[2])
		world.apply_view()
		world.fog.refresh(world.terrain_state)
		for i in 3:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + String(shot[0]) + ".png"))
		print("capture ", shot[0], " ", shot[1])
	get_tree().quit()
