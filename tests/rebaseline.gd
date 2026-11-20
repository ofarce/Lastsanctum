extends "res://tests/econ_case.gd"
## Régénère, depuis le jeu actuel, les références que la suite compare au terrain :
##   godot --headless --path . -s res://tests/run_tests.gd -- --rebaseline
## Ces fichiers venaient du prototype JS (tools/baker) ; depuis que la salle de départ est taillée en blocs
## et que les galeries ont changé, ils ne peuvent plus lui être identiques. Ils servent désormais de
## non-régression : à relancer après un changement VOULU du terrain, de l'A* ou de la minicarte, en
## relisant le diff. Relancer le baker sur « fixtures » écraserait ces valeurs.

const FIX := "res://assets/baked/fixtures/"
const HUD := "res://assets/baked/hud/"
## Tunnel de référence : depuis la paroi est de la salle, plein est le long de z −160…−156, jusqu'à la
## première galerie (graine 20261114). Il longe la réserve du coffre par le nord et l'ouvre au passage.
const TUNNEL_J := -40
const TUNNEL_I0 := 14
const TUNNEL_I1 := 35


func _state() -> TerrainState:
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(SEED)
	return state


func _save(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("  écrit ", path)


func rebaseline() -> void:
	_dig_scenario()
	_walkable()
	_paths()
	_minimap()
	_sites()


func _dig_scenario() -> void:
	var state := _state()
	var reg := DecorRegistry.new()
	for p: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/world/decor_placements.json"))["placements"]:
		reg.add_raw(p.duplicate())
	var cells: Array = []
	for i in range(TUNNEL_I0, TUNNEL_I1 + 1):
		cells.append([i, TUNNEL_J])
	var before := reg.size()
	var ops := TerrainOps.new(state, reg)
	var v0 := state.version
	for c: Array in cells:
		ops.dig_cell(c[0], c[1])
	var dug: Array = []
	for k: Vector2i in state.dug:
		dug.append("%d,%d" % [k.x, k.y])
	dug.sort()
	var active: Array = []
	for p: Dictionary in state.portals:
		if p["active"]:
			active.append({"x": p["x"], "z": p["z"]})
	_save(FIX + "dig_scenario.json", {"seed": SEED, "j": TUNNEL_J, "cells": cells, "dug": dug, "found": state.found,
		"open_sha1": state.open_sha1(), "active_portals": active, "objs_before": before, "objs_after": reg.size(),
		"walk_version_delta": state.version - v0})


func _walkable() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "walkable.json"))
	var state := _state()
	for s: Array in f["samples"]:
		s[2] = 1 if state.walkable(s[0], s[1]) else 0
		s[3] = 1 if CaveShape.in_cave(s[0], s[1]) else 0
		s[4] = 1 if CaveShape.in_tunnel(s[0], s[1]) else 0
	_save(FIX + "walkable.json", f)


func _paths() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "paths.json"))
	var pf := Pathfinder.new(_state())
	for c: Dictionary in f["paths"]:
		var got: Variant = pf.find_path(Vector2(c["from"]["x"], c["from"]["z"]), Vector2(c["to"]["x"], c["to"]["z"]))
		c["path"] = null if got == null else (got as Array).map(func(p: Vector2) -> Array: return [p.x, p.y])
	_save(FIX + "paths.json", f)


func _minimap() -> void:
	var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "dig_scenario.json"))
	var state := _state()
	var m := Minimap.new()
	m._meta = JSON.parse_string(FileAccess.get_file_as_string(Minimap.META))
	m.build_background(state)
	m.background().save_png(ProjectSettings.globalize_path(HUD + "minimap_initial.png"))
	var ops := TerrainOps.new(state, DecorRegistry.new())
	for c: Array in sc["cells"]:
		ops.dig_cell(int(c[0]), int(c[1]))
	m.build_background(state)
	m.background().save_png(ProjectSettings.globalize_path(HUD + "minimap_dig.png"))
	m.free()
	print("  écrit ", HUD, "minimap_initial.png, minimap_dig.png")


## Point de travail des chantiers (workSpot) : il dépend du sol praticable autour du site.
func _sites() -> void:
	var sim := game()
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HUD + "sites.json"))
	var e := engineer()
	e.x = f["engineer"][0]
	e.z = f["engineer"][1]
	for b: Dictionary in f["buildings"]:
		built(b["type"], b["x"], b["z"])
	for r: Dictionary in f["points"]:
		var p := Vector2(r["p"][0], r["p"][1])
		for t: String in ["sigil", "bedroom", "caserne"]:
			var spot := sim.work_spot(t, Simulation.snap_for(t, p))
			r[t]["snap"] = [Simulation.snap_for(t, p).x, Simulation.snap_for(t, p).y]
			r[t]["spot"] = [spot.x, spot.y]
	_save(HUD + "sites.json", f)
