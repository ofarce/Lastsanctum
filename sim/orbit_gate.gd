class_name OrbitGate
## Porte de l'Orbite (porte « mb2 » du Temple, route du boss), choix du 2026-11-25 (planches/porte-boss-veilleuses.html) :
## deux veilleuses, une par gardien (or = l'Archiprêtre, améthyste = la Martyre), nourries chacune par une rigole qui
## vient de l'arène de son gardien. La porte ne s'ouvre qu'une fois les deux gardiens tombés ; à l'approche de la porte
## scellée, la bannière dit qui la tient encore. Rendu : world/reperes/orbit_gate_view.gd et orbit_rill_view.gd.

const KEY := "mb2"
const OPEN_SAY := "La porte de l’Orbite s’ouvre : la route de l’Œil est libre."
## Zone d'approche : devant la face sud, jusqu'à NEAR unités ; la bannière revient après SAY_AGAIN s si on y reste.
const NEAR := 12.0
const SAY_AGAIN := 25.0
## Décalage des deux rigoles dans les couloirs (unités), pour qu'elles courent côte à côte sans se chevaucher.
const RILL_OFFSET := {"a": Vector2(-1.5, -1.5), "m": Vector2(1.5, 1.5)}
## Pied de chaque niche sur la face (unités depuis le milieu de la porte) : Archiprêtre à l'ouest, Martyre à l'est.
const NICHE_X := {"a": -5.25, "m": 5.25}
## Délai entre la chute du dernier gardien et l'ouverture : sa rigole s'éteint jusqu'à la porte, puis sa flamme
## s'emballe, vacille et meurt (OrbitGateView.OUT_AT, mêmes chiffres).
const OPEN_DELAY := 3.4

static var _near := false
static var _said_at := -INF
## Heure (sim) de l'ouverture de la porte, pour la herse ; NAN avant (ou porte trouvée déjà ouverte).
static var opened_at := NAN


static func archi_down(st: TerrainState) -> bool:
	return st != null and st.doors_closed.has("mb1") and not st.doors_closed["mb1"]


static func martyre_down() -> bool:
	return GameState.martyre_state == "defeated"


## En vie : « a » l'Archiprêtre, « m » la Martyre.
static func alive(st: TerrainState) -> Dictionary:
	return {"a": not archi_down(st), "m": not martyre_down()}


## Heure (sim) de la chute du gardien `k`, −1e6 s'il est tombé sans heure connue (partie chargée), NAN en vie.
static func down_at(st: TerrainState, k: String) -> float:
	if k == "a":
		return float(GameState.archipretre.get("down_at", -1e6)) if archi_down(st) else NAN
	if not martyre_down():
		return NAN
	return GameState.martyre_down_at if GameState.martyre_down_at < INF else -1e6


## Un gardien vient de tomber, ou chaque tic : la porte s'ouvre quand les deux sont tombés et que la dernière
## veilleuse s'est éteinte (OPEN_DELAY).
static func guard_fell(sim: Simulation) -> void:
	var st := sim.state()
	if st == null or not st.doors_closed.get(KEY, false):
		return
	if archi_down(st) and martyre_down():
		if GameState.sim_time < maxf(down_at(st, "a"), down_at(st, "m")) + OPEN_DELAY:
			return
		RoomEncounters.open_door(sim, KEY)
		opened_at = GameState.sim_time
		sim.say(OPEN_SAY, 4.0)


## Face sud de la porte : {"x": milieu, "z": pied de la face, "w": largeur} en unités, ou {} sans porte.
static func face(st: TerrainState) -> Dictionary:
	if st == null:
		return {}
	var x0 := INF
	var x1 := -INF
	var j := -INF
	for c: Vector2i in st.door_cells:
		if st.door_cells[c] != KEY:
			continue
		x0 = minf(x0, c.x * 4.0)
		x1 = maxf(x1, c.x * 4.0 + 4.0)
		j = maxf(j, c.y)
	if x0 == INF:
		return {}
	return {"x": (x0 + x1) / 2.0, "z": j * 4.0 + 4.0, "w": x1 - x0}


static func message(st: TerrainState) -> String:
	var a := alive(st)
	if a["a"] and a["m"]:
		return "Deux gardiens tiennent encore la porte : l’Archiprêtre et la Martyre."
	if a["a"]:
		return "Un gardien tient encore la porte : l’Archiprêtre."
	if a["m"]:
		return "Un gardien tient encore la porte : la Martyre."
	return ""


## Bannière à l'approche de la porte scellée (Exilé incarné).
static func tick(sim: Simulation) -> void:
	var st := sim.state()
	var u := GameState.incarnated
	if st != null and st.doors_closed.get(KEY, false):
		opened_at = NAN
		guard_fell(sim)
	if st == null or u == null or not st.doors_closed.get(KEY, false):
		_near = false
		return
	var f := face(st)
	if f.is_empty():
		return
	var near := absf(u.x - float(f["x"])) < float(f["w"]) * 0.5 + 4.0 and u.z > float(f["z"]) - 1.0 and u.z < float(f["z"]) + NEAR
	if near and (not _near or GameState.sim_time - _said_at > SAY_AGAIN):
		var text := message(st)
		if text != "":
			sim.say(text, 4.0)
			_said_at = GameState.sim_time
	_near = near


## Rigoles : pour chaque gardien, ligne brisée (unités, sol) depuis le centre de son arène jusqu'au pied de sa niche,
## le long des couloirs du plan (arène → … → hub → porte). {} sans plan du Temple.
static func rills(st: TerrainState) -> Dictionary:
	if st == null or st.temple_layout.is_empty():
		return {}
	var lay: Dictionary = st.temple_layout
	var f := face(st)
	if f.is_empty():
		return {}
	var rooms := {}
	for r: Dictionary in lay["rooms"]:
		rooms[r["id"]] = r
	var gate: Dictionary = {}
	var adj := {}
	for l: Dictionary in lay["links"]:
		if l["kind"] != "corridor":
			continue
		if l["door"] == KEY:
			gate = l
			continue
		(adj.get_or_add(l["a"], []) as Array).append(l)
		(adj.get_or_add(l["b"], []) as Array).append(l)
	if gate.is_empty():
		return {}
	var hub: int = gate["a"]
	var out := {}
	for k: String in ["a", "m"]:
		var arena := -1
		for id in rooms:
			if rooms[id]["role"] == ("mb1" if k == "a" else "mb2"):
				arena = id
		if arena < 0:
			continue
		# Plus court chemin en salles (largeur d'abord).
		var prev := {arena: null}
		var queue: Array = [arena]
		while not queue.is_empty() and not prev.has(hub):
			var id: int = queue.pop_front()
			for l: Dictionary in adj.get(id, []):
				var o: int = l["b"] if l["a"] == id else l["a"]
				if not prev.has(o):
					prev[o] = [id, l]
					queue.append(o)
		if not prev.has(hub):
			continue
		var chain: Array = []
		var cur := hub
		while prev[cur] != null:
			chain.push_front(prev[cur])
			cur = prev[cur][0]
		var pts := PackedVector2Array()
		pts.append(_case_center(rooms[arena]["rect"]))
		for step: Array in chain:
			var l: Dictionary = step[1]
			var seg := _world_path(l["path"], l["a"] != step[0])
			_join(pts, seg[0])
			for p in seg:
				_push(pts, p)
		# Hub → porte : le couloir de la porte, coupé à trois unités de la face.
		var seg := _world_path(gate["path"], gate["a"] != hub)
		_join(pts, seg[0])
		var stop := float(f["z"]) + 3.0
		for i in seg.size():
			if seg[i].y <= stop:
				var a := seg[i - 1] if i > 0 else seg[i]
				_push(pts, Vector2(seg[i].x, stop) if absf(seg[i].x - a.x) < 0.01 else seg[i])
				break
			_push(pts, seg[i])
		var off: Vector2 = RILL_OFFSET[k]
		for i in pts.size():
			pts[i] += off
		var nx := float(f["x"]) + float(NICHE_X[k])
		_push(pts, Vector2(nx, pts[pts.size() - 1].y))
		_push(pts, Vector2(nx, float(f["z"])))
		out[k] = pts
	return out


static func _case_center(rr: Rect2i) -> Vector2:
	return Vector2(rr.position.x * 4.0 + rr.size.x * 2.0, rr.position.y * 4.0 + rr.size.y * 2.0)


static func _world_path(path: Array, reverse: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c: Vector2i in path:
		out.append(Vector2(c.x * 4.0 + 2.0, c.y * 4.0 + 2.0))
	if reverse:
		out.reverse()
	return out


## Coude en L dans la salle entre la fin du tracé et le début du couloir suivant.
static func _join(pts: PackedVector2Array, to: Vector2) -> void:
	var last := pts[pts.size() - 1]
	if absf(last.x - to.x) > 0.01 and absf(last.y - to.y) > 0.01:
		_push(pts, Vector2(to.x, last.y))
	_push(pts, to)


static func _push(pts: PackedVector2Array, p: Vector2) -> void:
	if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.01:
		pts.append(p)
