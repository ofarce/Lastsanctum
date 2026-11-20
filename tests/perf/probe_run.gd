extends "res://tests/perf/bench_run.gd"
## Sonde d'ablation (mode rendu) : à partir de PROBE_FROM s de simulation, chaque groupe de nœuds d'affichage est
## coupé tour à tour (process désactivé et caché) pendant WIN s, encadré par des fenêtres de référence ; le gain
## de temps d'image mesure son coût. Les fonctions de World._process sont chronométrées par un appel en plus.
##   godot --path . -s res://tests/perf/probe.gd -- --out=tests/perf/out/probe
## La simulation n'est pas affectée (le banc la fait avancer lui-même) : seul l'affichage est coupé.

## Instant de la sonde (s de simulation) ; variable d'environnement PROBE_FROM pour le changer.
var PROBE_FROM := 150.0
const WIN := 1.5
const CYCLES := 3
const SETTLE := 0.4

var groups: Array = []   # [nom, Array[Node]]
var gi := -1
var phase := ""          # "base" ou "off"
var phase_t0 := 0
var acc := {"sum": 0.0, "n": 0}
var base_ms := 0.0
var cycle := 0
var diffs: Array[float] = []
var bases: Array[float] = []
var results: Array = []
var world_parts := {}


func _ready() -> void:
	super._ready()
	if OS.get_environment("PROBE_FROM") != "":
		PROBE_FROM = float(OS.get_environment("PROBE_FROM"))
	mode = "render"
	seconds = 100000.0


func _frame() -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - last_frame) / 1000.0
	last_frame = now
	# Simulation figée pendant la sonde : état constant, seul l'affichage tourne (bruit de mesure réduit).
	if GameState.sim_time < PROBE_FROM:
		_step()
		return
	if groups.is_empty():
		_collect_groups()
		_next_group()
		return
	_time_world_parts()
	if (now - phase_t0) / 1e6 < SETTLE:
		return
	acc["sum"] += dt
	acc["n"] += 1
	if (now - phase_t0) / 1e6 < SETTLE + WIN:
		return
	var avg: float = acc["sum"] / maxi(1, acc["n"])
	if phase == "base":
		base_ms = avg
		_set_enabled(groups[gi][1], false)
		_phase("off")
		return
	_set_enabled(groups[gi][1], true)
	diffs.append(base_ms - avg)
	bases.append(base_ms)
	cycle += 1
	if cycle < CYCLES:
		_phase("base")
		return
	diffs.sort()
	bases.sort()
	var gain: float = diffs[diffs.size() / 2]
	var spread: float = diffs[-1] - diffs[0]
	results.append({"group": groups[gi][0], "nodes": groups[gi][1].size(), "base_ms": snappedf(bases[bases.size() / 2], 0.01),
		"gain_ms": snappedf(gain, 0.01), "spread_ms": snappedf(spread, 0.01), "sim_s": snappedf(GameState.sim_time, 0.1)})
	print("  %-40s %4d nœuds  base %6.2f ms  gain %+6.2f ms (écart %.2f)" % [groups[gi][0], groups[gi][1].size(), bases[bases.size() / 2], gain, spread])
	_next_group()


func _phase(p: String) -> void:
	phase = p
	phase_t0 = Time.get_ticks_usec()
	acc = {"sum": 0.0, "n": 0}


func _next_group() -> void:
	gi += 1
	cycle = 0
	diffs.clear()
	bases.clear()
	if gi >= groups.size():
		get_tree().process_frame.disconnect(_frame)
		_write()
		return
	_phase("base")


func _set_enabled(nodes: Array, on: bool) -> void:
	if nodes == ["lighting"]:
		sim.world.lighting.enabled = on
		return
	for n: Node in nodes:
		if not is_instance_valid(n):
			continue
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if n is CanvasItem:
			if on:
				(n as CanvasItem).visible = n.get_meta("probe_vis", true)
			else:
				n.set_meta("probe_vis", (n as CanvasItem).visible)
				(n as CanvasItem).visible = false
		elif n is CanvasLayer:
			if on:
				(n as CanvasLayer).visible = n.get_meta("probe_vis", true)
			else:
				n.set_meta("probe_vis", (n as CanvasLayer).visible)
				(n as CanvasLayer).visible = false


func _label(n: Node) -> String:
	var s: Script = n.get_script()
	if s:
		var g := s.get_global_name()
		return String(g) if g else s.resource_path.get_file()
	return n.get_class()


## Enfants directs de World (et de ses CanvasLayer), enfants du tri en Y regroupés par type, HUD entier.
func _collect_groups() -> void:
	var world: Node = sim.world
	var by_kind := {}
	var ysort: Node = world.get("ysort")
	var add := func(key: String, n: Node) -> void:
		if not by_kind.has(key):
			by_kind[key] = []
		by_kind[key].append(n)
	for c: Node in world.get_children():
		if c == ysort:
			continue
		if c is CanvasLayer:
			for cc: Node in c.get_children():
				add.call("World/%s/%s (%s)" % [c.name, cc.name, _label(cc)], cc)
		else:
			add.call("World/%s (%s)" % [c.name, _label(c)], c)
	if ysort:
		for c: Node in ysort.get_children():
			add.call("ysort: " + _label(c), c)
			# Descendants scriptés des emplacements de décor (portails, orbe, effets divins).
			if _label(c) == "Node2D":
				for d: Node in c.find_children("*", "", true, false):
					if d.get_script():
						add.call("ysort/décor: " + _label(d), d)
	for k: String in by_kind:
		if OS.get_environment("PROBE_ONLY") == "" or k.contains(OS.get_environment("PROBE_ONLY")):
			groups.append([k, by_kind[k]])
	var hud := sim.get_node("../Hud")
	groups.append(["Hud (tout)", [hud]])
	for c: Node in _hud_parts(hud):
		groups.append(["Hud/%s (%s)" % [c.name, _label(c)], [c]])
	groups.append(["Lighting (enabled = false)", ["lighting"]])
	print("sonde : %d groupes à %.0f s de simulation" % [groups.size(), GameState.sim_time])


## Enfants du HUD (sous son Control racine s'il n'y en a qu'un).
func _hud_parts(hud: Node) -> Array:
	var kids := hud.get_children()
	if kids.size() == 1 and kids[0].get_child_count() > 0:
		kids = kids[0].get_children()
	return kids


## Coût des étapes de World._process (appel supplémentaire, idempotent).
func _time_world_parts() -> void:
	var w: Node = sim.world
	for part: String in ["_sync_units", "_sync_buildings", "_sync_placed", "_sync_enemies", "_sync_turrets", "_update_dynamic"]:
		var t := Time.get_ticks_usec()
		w.call(part)
		_acc_part(part, Time.get_ticks_usec() - t)
	var t0 := Time.get_ticks_usec()
	w.fog.refresh(w.terrain_state)
	_acc_part("fog.refresh", Time.get_ticks_usec() - t0)
	t0 = Time.get_ticks_usec()
	w.lighting.collect()
	_acc_part("lighting.collect", Time.get_ticks_usec() - t0)


func _acc_part(k: String, us: int) -> void:
	var r: Array = world_parts.get(k, [0, 0, 0])
	r[0] += us
	r[1] = maxi(r[1], us)
	r[2] += 1
	world_parts[k] = r


func _write() -> void:
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["gain_ms"] > b["gain_ms"])
	var parts := {}
	print("\nWorld._process (ms par appel) :")
	for k: String in world_parts:
		var r: Array = world_parts[k]
		parts[k] = {"avg_ms": snappedf(r[0] / 1000.0 / r[2], 0.001), "max_ms": snappedf(r[1] / 1000.0, 0.001)}
		print("  %-20s avg %.3f  max %.3f" % [k, parts[k]["avg_ms"], parts[k]["max_ms"]])
	var f := FileAccess.open(_path("_probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"groups": results, "world_process": parts,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}, "  "))
	f.close()
	print("sonde écrite : " + _path("_probe.json"))
	get_tree().quit(0)
