extends Node
## Logique du banc de mesure (voir tests/perf/bench.gd).

const STEP := Simulation.MAX_DT
const HASH_EVERY := 10.0

var mode := "render"
var out := "tests/perf/out/bench"
var seconds := 900.0
var player: RefCounted
var sim: Simulation
var next_hash := HASH_EVERY
var hashes: Array[String] = []
var frames := PackedFloat32Array()
var ticks := PackedFloat32Array()
var thinks := PackedFloat32Array()
var csv: FileAccess
var last_frame := 0
var window_start := 0
var window: Dictionary = {}
var peaks := {"static_mb": 0.0, "vram_mb": 0.0, "nodes": 0, "objects": 0, "draw_calls": 0}
var wall_start := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
	get_tree().process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	if mode == "render":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	player = load("res://tests/test_full_game.gd").new()
	player.begin()
	sim = player.sim
	sim.profiling = true
	sim.profile.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(out.get_base_dir()))
	csv = FileAccess.open(_path("_samples.csv"), FileAccess.WRITE)
	csv.store_line("wall_s,sim_s,fps,frame_avg_ms,frame_max_ms,tick_avg_ms,think_avg_ms,process_ms,nodes,objects,static_mb,vram_mb,draw_calls,units,enemies,effects")
	wall_start = Time.get_ticks_usec()
	_reset_window()
	if mode == "sim":
		while _running():
			_step()
			if Time.get_ticks_usec() - window_start >= 1000000:
				_sample()
		_finish()
	else:
		last_frame = Time.get_ticks_usec()
		get_tree().process_frame.connect(_frame)


func _running() -> bool:
	return player.playing() and GameState.sim_time < seconds


func _frame() -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - last_frame) / 1000.0
	last_frame = now
	frames.append(dt)
	window["frames"] += 1
	window["frame_sum"] += dt
	window["frame_max"] = maxf(window["frame_max"], dt)
	if not _running():
		get_tree().process_frame.disconnect(_frame)
		_finish()
		return
	_step()
	if now - window_start >= 1000000:
		_sample()


func _step() -> void:
	var t0 := Time.get_ticks_usec()
	sim.tick(STEP)
	var t1 := Time.get_ticks_usec()
	player.think()
	var t2 := Time.get_ticks_usec()
	ticks.append((t1 - t0) / 1000.0)
	thinks.append((t2 - t1) / 1000.0)
	window["ticks"] += 1
	window["tick_sum"] += (t1 - t0) / 1000.0
	window["think_sum"] += (t2 - t1) / 1000.0
	if GameState.sim_time >= next_hash:
		next_hash += HASH_EVERY
		hashes.append("%.0f:%s" % [GameState.sim_time, state_hash()])


func _reset_window() -> void:
	window_start = Time.get_ticks_usec()
	window = {"frames": 0, "frame_sum": 0.0, "frame_max": 0.0, "ticks": 0, "tick_sum": 0.0, "think_sum": 0.0}


func _sample() -> void:
	var el := (Time.get_ticks_usec() - window_start) / 1e6
	var nf: int = maxi(1, window["frames"])
	var nt: int = maxi(1, window["ticks"])
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vram_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	peaks["static_mb"] = maxf(peaks["static_mb"], static_mb)
	peaks["vram_mb"] = maxf(peaks["vram_mb"], vram_mb)
	peaks["nodes"] = maxi(peaks["nodes"], nodes)
	peaks["objects"] = maxi(peaks["objects"], objects)
	peaks["draw_calls"] = maxi(peaks["draw_calls"], draws)
	var row := [
		"%.1f" % ((Time.get_ticks_usec() - wall_start) / 1e6), "%.1f" % GameState.sim_time,
		"%.1f" % (window["frames"] / el), "%.3f" % (window["frame_sum"] / nf), "%.3f" % window["frame_max"],
		"%.3f" % (window["tick_sum"] / nt), "%.3f" % (window["think_sum"] / nt),
		"%.3f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		nodes, objects, "%.1f" % static_mb, "%.1f" % vram_mb, draws,
		GameState.units.size(), GameState.enemies.size(), GameState.effects.size()]
	csv.store_line(",".join(row.map(func(v: Variant) -> String: return str(v))))
	_reset_window()


func _finish() -> void:
	_sample()
	csv.close()
	var prof := {}
	for phase: String in sim.profile:
		var r: Array = sim.profile[phase]
		prof[phase] = {"avg_ms": snappedf(r[0] / 1000.0 / maxi(1, r[2]), 0.0001), "max_ms": snappedf(r[1] / 1000.0, 0.001), "calls": r[2]}
	var summary := {
		"mode": mode, "seed": player.SEED, "step": STEP, "sim_time": snappedf(GameState.sim_time, 0.001),
		"wall_s": snappedf((Time.get_ticks_usec() - wall_start) / 1e6, 0.01),
		"godot": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"frame_ms": _pcts(frames), "tick_ms": _pcts(ticks), "think_ms": _pcts(thinks),
		"sim_profile": prof, "peaks": peaks,
		"final": {"units": GameState.units.size(), "enemies": GameState.enemies.size(), "wave": GameState.wave,
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT))},
		"hashes": hashes,
	}
	var f := FileAccess.open(_path("_summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  "))
	f.close()
	print("bench %s : %.0f s simulées en %.1f s ; image p50 %.2f ms p99 %.2f ms ; tick p50 %.3f ms p99 %.3f ms ; %s" % [
		mode, GameState.sim_time, summary["wall_s"], summary["frame_ms"]["p50"], summary["frame_ms"]["p99"],
		summary["tick_ms"]["p50"], summary["tick_ms"]["p99"], _path("_summary.json")])
	get_tree().quit(0)


func _pcts(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty():
		return {"n": 0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	var at := func(q: float) -> float: return snappedf(s[mini(s.size() - 1, int(q * s.size()))], 0.001)
	return {"n": s.size(), "avg": snappedf(sum / s.size(), 0.001), "p50": at.call(0.5), "p95": at.call(0.95),
		"p99": at.call(0.99), "max": snappedf(s[s.size() - 1], 0.001)}


func _path(suffix: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(out + suffix)


## Empreinte de l'état de jeu (unités, ennemis, bâtiments, ressources, vague) : doit rester identique après
## une optimisation sur la même graine et le même mode.
static func state_hash() -> String:
	var parts := PackedStringArray()
	parts.append("%s|%d|%s" % [var_to_str(GameState.sim_time), GameState.wave, var_to_str(GameState.res)])
	for u: Unit in GameState.units:
		parts.append("u%d %s %s %s %s %s" % [u.id, u.role, var_to_str(u.x), var_to_str(u.z), var_to_str(u.hp), u.job.get("type", "") if u.job is Dictionary else ""])
	for e in GameState.enemies:
		parts.append("e%s %s %s %s" % [e.kind, var_to_str(e.x), var_to_str(e.z), var_to_str(e.hp)])
	for b: Building in GameState.buildings:
		parts.append("b%s %s %s %s" % [b.type, var_to_str(b.progress), b.complete, var_to_str(b.x)])
	parts.append("p%d f%d d%d" % [GameState.placed.size(), GameState.fallen.size(), GameState.ground_items.size()])
	return "\n".join(parts).md5_text()
