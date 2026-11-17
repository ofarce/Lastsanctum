class_name Pathfinder
extends RefCounted
## Déplacement autour de la roche (73b410f, galleries.js : WALK, walkCell, clearLine, nearestWalkCell,
## findPath, steer). Grille de 2 unités, A* à 8 directions (heuristique octile, pas de diagonale entre
## deux murs), budget de 60 000 nœuds, lissage par ligne de vue. Le tas binaire est porté à l'identique
## pour que les égalités soient départagées comme dans le prototype.
## Ajouts (réserve du coffre) : le long des parois, pas entre deux cases dont le bord ou le coin commun est
## de la roche ; début de ligne testé finement (clear_near) ; steer contourne un coin où l'unité est arrêtée.

const CELL := 2.0
const W := 232  # (WORLD.x1 − WORLD.x0) / 2
const H := 204  # (WORLD.z1 − WORLD.z0) / 2
const BUDGET := 60000
## Longueur du début de ligne vérifiée au pas fin (0,2) dans clear_line / clear_near.
const NEAR := 0.6
## Directions essayées (degrés depuis la visée) quand le début de la ligne est bloqué (steer).
const SIDESTEP: Array[float] = [25.0, -25.0, 50.0, -50.0, 75.0, -75.0, 100.0, -100.0]

var state: TerrainState
## 0 = inconnu, 1 = praticable, 2 = roche ; invalidé quand state.version change.
var _cache := PackedByteArray()
## Passages entre cases voisines, même codage : 3 par case k (bord est, bord sud, coin sud-est), testés au
## point milieu du bord ou au coin. Deux cases praticables au centre peuvent être séparées par une arête de
## roche (raccord en biais salle / case creusée devant la réserve du coffre) : l'A* n'y passe pas.
var _edges := PackedByteArray()
## Case praticable dont une voisine (8 directions) est de la roche : 0 inconnu, 1 non, 2 oui.
var _walled := PackedByteArray()
var _version := -1
# Tables de l'A*, réutilisées d'une recherche à l'autre : une case n'est valable que si son tampon
# vaut celui de la recherche en cours (évite de tout réinitialiser).
var _stamp := PackedInt32Array()
var _closed_stamp := PackedInt32Array()
var _g := PackedFloat64Array()
var _came := PackedInt32Array()
var _search := 0
# Tas binaire en tableaux parallèles (priorité, case), mêmes comparaisons que le tas du prototype.
var _hf := PackedFloat64Array()
var _hk := PackedInt32Array()
var _hn := 0
# Voisins dans l'ordre du prototype (di de −1 à 1, puis dj de −1 à 1) et leur coût.
const NDI: Array[int] = [-1, -1, -1, 0, 0, 1, 1, 1]
const NDJ: Array[int] = [-1, 0, 1, -1, 1, -1, 0, 1]
const NCOST: Array[float] = [1.414, 1.0, 1.414, 1.0, 1.0, 1.414, 1.0, 1.414]


func _init(terrain_state: TerrainState) -> void:
	state = terrain_state
	_cache.resize(W * H)
	_edges.resize(W * H * 3)
	_walled.resize(W * H)
	_stamp.resize(W * H)
	_closed_stamp.resize(W * H)
	_g.resize(W * H)
	_came.resize(W * H)


func _sync() -> void:
	if _version != state.version:
		_cache.fill(0)
		_edges.fill(0)
		_walled.fill(0)
		_version = state.version


func walk_cell(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= W or j >= H:
		return false
	_sync()
	return _walk(j * W + i, i, j)


## Lecture du cache sans contrôle de bornes ni de version (appelants : bornes vérifiées, _sync() fait).
func _walk(k: int, i: int, j: int) -> bool:
	var v := _cache[k]
	if v == 0:
		v = _fill(k, i, j)
	return v == 1


func _fill(k: int, i: int, j: int) -> int:
	var v := 1 if state.walkable(CaveShape.WORLD_X0 + i * 2 + 1, CaveShape.WORLD_Z0 + j * 2 + 1) else 2
	_cache[k] = v
	return v


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - CaveShape.WORLD_X0) / 2.0), floori((p.y - CaveShape.WORLD_Z0) / 2.0))


func clear_line(a: Vector2, b: Vector2) -> bool:
	_sync()
	var ax := float(a.x)
	var az := float(a.y)
	var dx := float(b.x) - ax
	var dz := float(b.y) - az
	var d := sqrt(dx * dx + dz * dz)
	# Début de la ligne au pas fin : un coin de roche rogné de quelques dixièmes échappe aux échantillons de
	# 0,6 et, contre une paroi en biais (raccord salle / case creusée devant la réserve du coffre), le
	# glissement axe par axe de Simulation.move s'y coince. Seul le début compte : steer revérifie la ligne à
	# chaque image depuis la position courante, un coin plus lointain est vu avant d'être atteint.
	if not clear_near(a, b):
		return false
	var n := ceili(d / 0.6)
	var last := -1
	for s in range(1, n + 1):
		var t := float(s) / n
		var i := floori((ax + dx * t - CaveShape.WORLD_X0) / 2.0)
		var j := floori((az + dz * t - CaveShape.WORLD_Z0) / 2.0)
		if i < 0 or j < 0 or i >= W or j >= H:
			return false
		# Point exact : une case de 2 unités dont le centre est praticable peut avoir un coin de roche (entrée de
		# la réserve du coffre) ; sans ce test, le chemin lissé coupe l'angle et l'unité reste bloquée.
		if not state.walkable(ax + dx * t, az + dz * t):
			return false
		var k := j * W + i
		if k == last:
			continue
		last = k
		var v := _cache[k]
		if v == 0:
			v = _fill(k, i, j)
		if v != 1:
			return false
	return true


## Début de la ligne a → b (NEAR unités) praticable point par point, au pas de 0,2.
func clear_near(a: Vector2, b: Vector2) -> bool:
	var dx := float(b.x) - float(a.x)
	var dz := float(b.y) - float(a.y)
	var d := sqrt(dx * dx + dz * dz)
	if d == 0.0:
		return true
	var fine := minf(d, NEAR)
	var m := ceili(fine / 0.2)
	for s in range(1, m + 1):
		var t := fine / d * float(s) / m
		if not state.walkable(float(a.x) + dx * t, float(a.y) + dz * t):
			return false
	return true


func nearest_walk_cell(c: Vector2i, r: int = 6) -> Variant:
	if walk_cell(c.x, c.y):
		return c
	for d in range(1, r + 1):
		for a in range(-d, d + 1):
			for o: Vector2i in [Vector2i(a, -d), Vector2i(a, d), Vector2i(-d, a), Vector2i(d, a)]:
				if walk_cell(c.x + o.x, c.y + o.y):
					return c + o
	return null


## findPath : liste de points (x, z) à suivre ; [] si départ et arrivée sont dans la même case ; null si
## aucun chemin. Le dernier point (la cellule d'arrivée) est retiré, comme dans le prototype.
func find_path(from: Vector2, to: Vector2) -> Variant:
	var s: Variant = nearest_walk_cell(cell_of(from), 3)
	var g: Variant = nearest_walk_cell(cell_of(to), 8)
	if s == null or g == null:
		return null
	var start: int = s.y * W + s.x
	var goal: int = g.y * W + g.x
	if start == goal:
		return []
	_sync()
	_search += 1
	var cur := _search
	var gx: int = g.x
	var gy: int = g.y
	_stamp[start] = cur
	_g[start] = 0.0
	_hn = 0
	_push(0.0, start)
	var found := false
	var budget := BUDGET
	while _hn > 0 and budget > 0:
		budget -= 1
		var k := _pop()
		if k == goal:
			found = true
			break
		if _closed_stamp[k] == cur:
			continue
		_closed_stamp[k] = cur
		var i := k % W
		var j := (k - i) / W
		var base: float = _g[k]
		var inner := i > 0 and j > 0 and i < W - 1 and j < H - 1
		# Une voisine est de la roche : on longe une paroi, les passages entre cases sont à vérifier.
		var wl := _walled[k]
		if wl == 0:
			wl = 1 if inner else 2
			if inner:
				for n in 8:
					var wk := (j + NDJ[n]) * W + i + NDI[n]
					var wv := _cache[wk]
					if wv == 0:
						wv = _fill(wk, i + NDI[n], j + NDJ[n])
					if wv != 1:
						wl = 2
						break
			_walled[k] = wl
		var walled := wl == 2
		for n in 8:
			var di: int = NDI[n]
			var dj: int = NDJ[n]
			var ni := i + di
			var nj := j + dj
			if not inner and (ni < 0 or nj < 0 or ni >= W or nj >= H):
				continue
			var nk := nj * W + ni
			var v := _cache[nk]
			if v == 0:
				v = _fill(nk, ni, nj)
			if v != 1:
				continue
			if di != 0 and dj != 0:
				# Pas de diagonale entre deux murs ; (ni, j) et (i, nj) sont dans la grille.
				var k1 := j * W + ni
				var v1 := _cache[k1]
				if v1 == 0:
					v1 = _fill(k1, ni, j)
				if v1 != 1:
					continue
				var k2 := nj * W + i
				var v2 := _cache[k2]
				if v2 == 0:
					v2 = _fill(k2, i, nj)
				if v2 != 1:
					continue
			if walled:
				# Passage entre les deux cases : coin commun (diagonale), sinon milieu du bord commun.
				var mi := mini(i, ni)
				var mj := mini(j, nj)
				var kind := 2 if di != 0 and dj != 0 else 0 if di != 0 else 1
				var e := (mj * W + mi) * 3 + kind
				var ve := _edges[e]
				if ve == 0:
					ve = 1 if state.walkable(CaveShape.WORLD_X0 + mi * 2 + (1 if kind == 1 else 2), \
							CaveShape.WORLD_Z0 + mj * 2 + (1 if kind == 0 else 2)) else 2
					_edges[e] = ve
				if ve != 1:
					continue
			var cost: float = base + NCOST[n]
			if _stamp[nk] != cur or cost < _g[nk]:
				_stamp[nk] = cur
				_g[nk] = cost
				_came[nk] = k
				var hdx := absi(ni - gx)
				var hdz := absi(nj - gy)
				_push(cost + (maxi(hdx, hdz) + 0.414 * mini(hdx, hdz)), nk)
	if not found:
		return null
	var cells: Array[Vector2] = []
	var k2 := goal
	while k2 != start:
		var ci := k2 % W
		var cj := (k2 - ci) / W
		cells.append(Vector2(CaveShape.WORLD_X0 + ci * 2 + 1, CaveShape.WORLD_Z0 + cj * 2 + 1))
		k2 = _came[k2]
	cells.reverse()
	# Lissage : on saute directement au point le plus lointain visible.
	var out: Array[Vector2] = []
	var curp := from
	var idx := 0
	while idx < cells.size():
		var jdx := idx
		for kk in range(mini(cells.size() - 1, idx + 24), idx, -1):
			if clear_line(curp, cells[kk]):
				jdx = kk
				break
		out.append(cells[jdx])
		curp = cells[jdx]
		idx = jdx + 1
	out.pop_back()
	return out


static func _h(k: int, g: Vector2i) -> float:
	var i := k % W
	var j := (k - i) / W
	var dx := absi(i - g.x)
	var dz := absi(j - g.y)
	return maxi(dx, dz) + 0.414 * mini(dx, dz)


func _push(f: float, k: int) -> void:
	if _hn == _hf.size():
		_hf.resize(maxi(64, _hn * 2))
		_hk.resize(maxi(64, _hn * 2))
	var c := _hn
	_hf[c] = f
	_hk[c] = k
	_hn += 1
	while c > 0:
		var p := (c - 1) >> 1
		if _hf[p] <= _hf[c]:
			break
		var tf := _hf[p]
		_hf[p] = _hf[c]
		_hf[c] = tf
		var tk := _hk[p]
		_hk[p] = _hk[c]
		_hk[c] = tk
		c = p


func _pop() -> int:
	var top := _hk[0]
	_hn -= 1
	if _hn > 0:
		_hf[0] = _hf[_hn]
		_hk[0] = _hk[_hn]
		var c := 0
		while true:
			var l := c * 2 + 1
			var r := l + 1
			var m := c
			if l < _hn and _hf[l] < _hf[m]:
				m = l
			if r < _hn and _hf[r] < _hf[m]:
				m = r
			if m == c:
				break
			var tf := _hf[m]
			_hf[m] = _hf[c]
			_hf[c] = tf
			var tk := _hk[m]
			_hk[m] = _hk[c]
			_hk[c] = tk
			c = m
	return top


## steer : prochain point à rejoindre pour atteindre `goal` depuis `pos`. `memo` porte le chemin en cache
## de l'unité (u._path, u._pg, u._pv du prototype) ; il est recalculé si la cible bouge de plus de 2 unités
## ou si le terrain change.
func steer(pos: Vector2, goal: Vector2, memo: Dictionary) -> Vector2:
	if clear_line(pos, goal):
		memo.erase("path")
		return goal
	if not memo.has("path") or memo.get("version") != state.version or (memo["goal"] as Vector2).distance_to(goal) > 2.0:
		memo["goal"] = goal
		memo["version"] = state.version
		memo["from"] = pos
		var p: Variant = find_path(pos, goal)
		memo["path"] = p if p != null else []
	var path: Array = memo["path"]
	while not path.is_empty() and ((path[0] as Vector2).distance_to(pos) < 0.6 or (path.size() > 1 and clear_line(pos, path[1]))):
		path.pop_front()
	var target: Vector2 = path[0] if not path.is_empty() else goal
	# Unité immobile depuis l'appel précédent : le point visé, vu depuis plus loin (lissage, raccourci vers
	# path[1]), est bloqué juste devant elle par un coin de roche contre une paroi en biais, où le glissement
	# de Simulation.move ne passe pas. Testé seulement à l'arrêt (le cas courant ne coûte rien de plus).
	var stuck := memo.has("at") and (memo["at"] as Vector2).distance_squared_to(pos) < 1e-8
	memo["at"] = pos
	if not stuck or clear_near(pos, target):
		return target
	# Chemin recalculé d'ici (au plus une fois par 0,5 unité parcourue)…
	if (memo["from"] as Vector2).distance_to(pos) > 0.5:
		memo["from"] = pos
		var p2: Variant = find_path(pos, goal)
		path = p2 if p2 != null else []
		memo["path"] = path
		while not path.is_empty() and (path[0] as Vector2).distance_to(pos) < 0.6:
			path.pop_front()
		target = path[0] if not path.is_empty() else goal
		if clear_near(pos, target):
			return target
	# … sinon (deux cases praticables séparées par une arête de roche) on longe l'obstacle par la direction
	# dégagée la plus proche de la visée, le temps de passer le coin.
	var dir := (target - pos).normalized()
	for deg: float in SIDESTEP:
		var probe := pos + dir.rotated(deg_to_rad(deg))
		if clear_near(pos, probe):
			return probe
	return target
