class_name AmbienceLayout
## Placement des ambiances de la montagne (planche ambiances-montagne-detail.html) : champignons,
## lianes et racines de lisière, faune. Pur et déterministe (graine des galeries) ; consigne de
## parcimonie : la plupart des galeries restent sobres.

const CHUNK := 32.0
## Champignons : part des chunks qui en ont, touffes par chunk (1 ou 2).
const MUSH_CHUNK_RATE := 0.25
const MUSH_SECOND := 0.4
const LANTERN_RATE := 0.2
const PUFF_RATE := 0.2
## Lianes : bande au nord de la lisière de la jungle (≈ 3 chunks).
const VINE_BAND := 96.0
const VINES_MIN := 2
const VINES_MAX := 4
const ROOT_RATE := 0.5
## Faune : écart minimal entre deux groupes (≈ un écran).
const FAUNA_GAP := 48.0
const BAT_CLEARING_RATE := 0.4
const BEETLE_GROUPS := 8


static func build(state: TerrainState) -> Dictionary:
	var r := Rng.new(state.seed ^ 0xa3b1)
	var out := {"mushrooms": [], "vines": [], "roots": [], "bats": [], "beetles": [], "salamanders": []}
	var x0 := CaveShape.WORLD_X0
	var z0 := CaveShape.WORLD_Z0
	var cols := ceili((CaveShape.WORLD_X1 - x0) / CHUNK)
	var rows := ceili((CaveShape.WORLD_Z1 - z0) / CHUNK)
	for cj in rows:
		for ci in cols:
			var cx := x0 + ci * CHUNK
			var cz := z0 + cj * CHUNK
			if r.next() < MUSH_CHUNK_RATE:
				var n := 1 + (1 if r.next() < MUSH_SECOND else 0)
				for k in n:
					var p := _spot(state, r, cx, cz, _near_wall)
					if p != Vector2.INF:
						out["mushrooms"].append(_tuft(r, p))
			var edge := CaveShape.mountain_edge(cx + CHUNK / 2.0)
			if cz + CHUNK > edge - VINE_BAND and cz < edge:
				var nv := VINES_MIN + floori(r.next() * (VINES_MAX - VINES_MIN + 1))
				for k in nv:
					var p := _foot(state, _spot(state, r, cx, cz, _under_wall))
					if p != Vector2.INF:
						out["vines"].append({"x": p.x, "z": p.y, "len": 18 + floori(r.next() * 26.0), "seed": floori(r.next() * 9999.0)})
				if r.next() < ROOT_RATE:
					var p := _foot(state, _spot(state, r, cx, cz, _under_wall))
					if p != Vector2.INF:
						out["roots"].append({"x": p.x, "z": p.y, "len": 26 + floori(r.next() * 22.0), "seed": floori(r.next() * 9999.0)})
	# Bassins : une touffe de champignons sur la berge, une salamandre, une colonie de chauves-souris.
	var groups: Array[Vector2] = []
	for pool: Dictionary in state.pools:
		var c: Vector2 = pool["center"]
		var rim := _rim(state, pool, r)
		if rim != Vector2.INF:
			out["mushrooms"].append(_tuft(r, rim))
		var rim2 := _rim(state, pool, r)
		if rim2 != Vector2.INF:
			out["salamanders"].append({"x": rim2.x, "z": rim2.y, "seed": floori(r.next() * 9999.0)})
		var wall := _north_wall(state, c)
		if wall != Vector2.INF:
			out["bats"].append({"x": wall.x, "z": wall.y, "n": 3 + floori(r.next() * 3.0), "seed": floori(r.next() * 9999.0)})
			groups.append(wall)
	for c: Vector2 in state._clearings:
		if r.next() >= BAT_CLEARING_RATE:
			continue
		var wall := _north_wall(state, c)
		if wall != Vector2.INF and not groups.any(func(g: Vector2) -> bool: return g.distance_to(wall) < FAUNA_GAP):
			out["bats"].append({"x": wall.x, "z": wall.y, "n": 3 + floori(r.next() * 3.0), "seed": floori(r.next() * 9999.0)})
			groups.append(wall)
	var tries := 0
	while out["beetles"].size() < BEETLE_GROUPS and tries < 400:
		tries += 1
		var cx := x0 + floori(r.next() * cols) * CHUNK
		var cz := z0 + floori(r.next() * rows) * CHUNK
		var p := _foot(state, _spot(state, r, cx, cz, _under_wall))
		if p == Vector2.INF or groups.any(func(g: Vector2) -> bool: return g.distance_to(p) < FAUNA_GAP):
			continue
		out["beetles"].append({"x": p.x, "z": p.y, "n": 1 + floori(r.next() * 2.0), "seed": floori(r.next() * 9999.0)})
		groups.append(p)
	return out


## Pied de la paroi nord de la case du point : premier point ouvert sous la case de roche,
## comme la face posée par TerrainOps.reveal_gallery (bz).
static func _foot(state: TerrainState, p: Vector2) -> Vector2:
	if p == Vector2.INF:
		return p
	var top := floorf(p.y / 4.0) * 4.0
	var cx := floorf(p.x / 4.0) * 4.0 + 2.0
	var t := top
	while t < top + 4.0 and not state.is_gallery(cx, t):
		t += 0.5
	return Vector2(p.x, t)


static func _tuft(r: Rng, p: Vector2) -> Dictionary:
	return {"x": p.x, "z": p.y, "seed": floori(r.next() * 9999.0),
		"lantern": r.next() < LANTERN_RATE, "puff": r.next() < PUFF_RATE}


## Point libre de galerie dans le chunk qui satisfait test (30 essais), ou Vector2.INF.
static func _spot(state: TerrainState, r: Rng, cx: float, cz: float, test: Callable) -> Vector2:
	for i in 30:
		var x := floorf(cx + r.next() * CHUNK) + 0.5
		var z := floorf(cz + r.next() * CHUNK) + 0.5
		if _free(state, x, z) and test.call(state, x, z):
			return Vector2(x, z)
	return Vector2.INF


static func _free(state: TerrainState, x: float, z: float) -> bool:
	if not state.is_gallery(x, z) or z > CaveShape.mountain_edge(x) - 4.0:
		return false
	var key := Vector2i(floori(x / 4.0), floori(z / 4.0))
	if state.grove_cells.has(key) or state.lode_cells.has(key) or state.block_types.has(key) or state.water_cells.has(key):
		return false
	var pool := state.pool_at(x, z)
	return pool.is_empty() or TerrainState.pool_field(pool, x, z) < TerrainState.POOL_WET


## Même règle que les parois de TerrainOps.reveal_gallery : une case est dessinée en roche
## quand son centre n'est pas en galerie.
static func _cell_open(state: TerrainState, ci: int, cj: int) -> bool:
	return state.is_gallery(ci * 4.0 + 2.0, cj * 4.0 + 2.0)


static func _cell_rock(state: TerrainState, ci: int, cj: int) -> bool:
	return not _cell_open(state, ci, cj)


## Case ouverte dont une voisine (4 directions) est en roche.
static func _near_wall(state: TerrainState, x: float, z: float) -> bool:
	var ci := floori(x / 4.0)
	var cj := floori(z / 4.0)
	if not _cell_open(state, ci, cj):
		return false
	for o: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if _cell_rock(state, ci + o.x, cj + o.y):
			return true
	return false


## Case ouverte sous une case de roche (paroi nord) ; le point est ramené au pied de la paroi.
static func _under_wall(state: TerrainState, x: float, z: float) -> bool:
	var ci := floori(x / 4.0)
	var cj := floori(z / 4.0)
	return _cell_open(state, ci, cj) and _cell_rock(state, ci, cj - 1) and _cell_open(state, ci, cj + 1)


## Paroi nord la plus proche au-dessus de c (pied de paroi), ou Vector2.INF.
static func _north_wall(state: TerrainState, c: Vector2) -> Vector2:
	for dx: int in [0, -1, 1, -2, 2]:
		var ci := floori(c.x / 4.0) + dx
		var cj := floori(c.y / 4.0)
		if not _cell_open(state, ci, cj):
			continue
		for k in 5:
			if _cell_rock(state, ci, cj - 1):
				return _foot(state, Vector2(ci * 4.0 + 2.0, cj * 4.0 + 1.0))
			if not _cell_open(state, ci, cj - 1):
				break
			cj -= 1
	return Vector2.INF


## Point de berge (champ entre berge mouillée et eau), libre.
static func _rim(state: TerrainState, pool: Dictionary, r: Rng) -> Vector2:
	var c: Vector2 = pool["center"]
	for i in 60:
		var a := r.next() * TAU
		var d := 4.0 + r.next() * 7.0
		var p := c + Vector2(cos(a) * d, sin(a) * d * 0.7)
		var f := TerrainState.pool_field(pool, p.x, p.y)
		if f > 0.35 and f < TerrainState.POOL_WET and state.is_gallery(p.x, p.y):
			return p
	return Vector2.INF
