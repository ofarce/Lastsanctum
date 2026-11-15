extends RefCounted
## Applique un contexte de tools/baker/hud_contexts.json à l'état Godot, comme applyContext()
## (tools/baker/hud.js) le fait dans le prototype. Sert aux tests du HUD et aux captures de revue.

const GALLERY_SEED := 20261114
const ACTIONS := "res://assets/baked/hud/hud_actions.json"


static func load_actions() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ACTIONS))


static func apply(sim: Simulation, c: Dictionary, regenerate := true) -> void:
	if regenerate:
		sim.new_game(GALLERY_SEED)
	sim.state().dig_hits.clear()
	GameState.units.clear()
	GameState.selected.clear()
	GameState.next_uid = 0
	GameState.buildings.clear()
	GameState.fallen.clear()
	GameState.sim_time = c.get("t", 0.0)
	GameState.ended = c.get("ended", false)
	GameState.core_hp = c.get("core_hp", 100.0)
	GameState.next_wave = c.get("next_wave", 0.0)
	GameState.spawn_queue = []
	var res: Dictionary = c.get("res", {})
	for k in Catalog.RES_ORDER:
		GameState.res[k] = float(res.get(k, 0.0))
	var specs: Array = c.get("units", [])
	for s: Dictionary in specs:
		_make(sim, s)
	var i := 0
	for s: Dictionary in c.get("buildings", []):
		var b := Building.create(i, s["type"], s["x"], s["z"])
		b.complete = s.get("complete", false)
		b.progress = Catalog.BUILDINGS[b.type]["time"] if b.complete else float(s.get("progress", 0.0))
		b.queue.assign(s.get("queue", []))
		b.spot = sim.work_spot(b.type, Vector2(b.x, b.z))
		GameState.buildings.append(b)
		i += 1
	for s: Dictionary in c.get("fallen", []):
		var f := _make(sim, s)
		GameState.units.erase(f)
		f.hp = 0.0
		f.dead = true
		GameState.fallen.append(f)
	for k in specs.size():
		var s: Dictionary = specs[k]
		var u: Unit = GameState.units[k]
		if s.get("orb_job", false):
			u.orb_job = true
		if s.has("build_job"):
			var b: Building = GameState.buildings[int(s["build_job"])]
			u.build_job = b
			b.owner = u
		var job: Dictionary = s.get("job", {})
		if job.get("type") == "dig":
			var ci := int(job["cell"][0])
			var cj := int(job["cell"][1])
			u.job = {"phase": "go", "carry": 0, "work": 0.0, "type": "dig", "cell": {"i": ci, "j": cj}, "at": Vector2(ci * 4 + 2, cj * 4 + 2)}
			if job.has("hits"):
				sim.state().dig_hits[Vector2i(ci, cj)] = int(job["hits"])
		elif job.get("type") == "pray":
			u.job = {"phase": "go", "carry": 0, "work": 0.0, "type": "pray", "temple": GameState.buildings[int(job["temple"])]}
	var orb: Dictionary = c.get("orb", {})
	GameState.orb_active = orb.get("active", false)
	GameState.orb_progress = Simulation.ORB_TIME if GameState.orb_active else float(orb.get("progress", 0.0))
	GameState.orb_owner = GameState.units[int(orb["owner"])] if orb.has("owner") else null
	for k in c.get("selected", []):
		GameState.selected.append(GameState.units[int(k)])
	GameState.anchor_selected = c.get("anchor", false)
	GameState.hud_building = GameState.buildings[int(c["building"])] if c.has("building") else null
	GameState.hud_menu = c.get("menu", "")
	GameState.hud_mode = c.get("mode", "")
	GameState.hud_build_type = c.get("build_type", "")


static func _make(sim: Simulation, s: Dictionary) -> Unit:
	var role: String = s["role"]
	var u := sim.spawn(s["name"], s.get("x", 0.0), s.get("z", -147.0), role)
	if Catalog.ADEPT.has(role):
		u.hp = Catalog.ADEPT[role]["hp"]
		u.max_hp = u.hp
		u.radius = 0.55
	if s.has("hp"):
		u.hp = s["hp"]
	u.hidden = s.get("hidden", false)
	u.ability = s.get("ability", 0.0)
	u.stance = s.get("stance", "attack")
	u.level = int(s.get("level", 1))
	u.xp = s.get("xp", 0.0)
	u.working = s.get("working", false)
	return u
