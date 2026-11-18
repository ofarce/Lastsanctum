class_name FaunaView
extends AmbienceView
## Petite faune inoffensive (piste 05), purement visuelle, hors simulation :
## colonie de chauves-souris (se décroche au passage), scarabées d'ardoise (longent la paroi),
## salamandre (file se cacher). Yeux ambrés ou noirs : le rouge reste à la Bête.

enum Kind { BATS, BEETLES, SALAMANDER }

const BAT_UP := ["X.X.......X.X", "XmXX.....XXmX", ".XmmX.X.XmmX.", "..XmmXbXmmX..", "...XXbebXX...", ".....XbX.....", "......X......"]
const BAT_MID := [".............", "XX.X.....X.XX", "XmmmXX.XXmmmX", ".XXmmXbXmmXX.", "....XbebX....", ".....XbX.....", "......X......"]
const BAT_DN := [".............", ".............", "....XX.XX....", "..XXmXbXmXX..", ".XmmmbebmmmX.", "XmXXXXbXXXXmX", "X.....X.....X"]
const BAT_HANG := ["..X.X..", ".XbXbX.", "XmbbbmX", "XmmbmmX", "XmmemmX", ".XmmmX.", "..XXX.."]
const BEETLE := [["X....X", ".X..X.", "XXshXX", "XsshsX", "XsslsX", "XsslsX", ".XXXX."], [".X..X.", ".X..X.", "XXshX.", "XsshsX", "XsslsX", "XsslsX", ".XXXX."]]
## Distances de réaction (unités).
const BAT_WAKE := 12.0
const BAT_RETURN := 24.0
const SALA_FLEE := 9.0

var kind := Kind.BATS
var count := 1
var _pal_bat := {}
var _pal_beetle := {}
## Chauves-souris : -1 = suspendue, sinon temps de vol écoulé.
var _flight: Array[float] = []
var _away := 0.0
## Scarabées : position x relative (px), sens, pause.
var _bx: Array[float] = []
var _bdir: Array[float] = []
var _bpause: Array[float] = []
## Salamandre : 0 = au repos, > 0 fuite en cours, < 0 cachée (temps restant).
var _sala := 0.0
var _sx := 0.0


func setup(terrain_state: TerrainState, d: Dictionary, k: Kind) -> void:
	place(terrain_state, d)
	kind = k
	count = d.get("n", 1)
	name = "Fauna_%d_%d" % [k, seed]
	if k == Kind.BATS:
		position.y += VineView.SORT_BIAS
	_pal_bat = {"X": OUT, "m": Color8(77, 70, 86), "b": Color8(47, 42, 54), "e": Color8(217, 164, 65)}
	_pal_beetle = {"X": OUT, "s": Color8(61, 74, 92), "h": Color8(143, 162, 189), "l": Color8(36, 48, 63)}
	for i in count:
		_flight.append(-1.0)
		_bx.append((h(i, 1) - 0.5) * 40.0)
		_bdir.append(1.0 if h(i, 2) > 0.5 else -1.0)
		_bpause.append(0.0)


func tick() -> void:
	var dt := get_process_delta_time()
	var near := nearest_unit()
	match kind:
		Kind.BATS:
			for i in count:
				# Décrochage en cascade : retard de 0,18 s par rang (-1 reste réservé à « suspendue »).
				if _flight[i] == -1.0 and near < BAT_WAKE:
					_flight[i] = -0.01 - i * 0.18
			for i in count:
				if _flight[i] != -1.0:
					_flight[i] += dt
			if near > BAT_RETURN and _flight.all(func(f: float) -> bool: return f == -1.0 or f > 4.0):
				_away += dt
				if _away > 20.0:
					_away = 0.0
					for i in count:
						_flight[i] = -1.0
			else:
				_away = 0.0
		Kind.BEETLES:
			for i in count:
				if _bpause[i] > 0.0:
					_bpause[i] -= dt
					continue
				var speed := 9.0 * (3.0 if near < 4.0 else 1.0)
				var nx := _bx[i] + _bdir[i] * speed * dt
				var wxn := wx + nx / 8.0
				if absf(nx) > 48.0 or not state.is_gallery(wxn, wz) or state.is_gallery(wxn, wz - 1.0):
					_bdir[i] *= -1.0
				else:
					_bx[i] = nx
				if Rng.hash3(int(t() * 2.0), i, seed) > 0.985:
					_bpause[i] = 0.6 + h(i, int(t())) * 1.2
		Kind.SALAMANDER:
			if _sala == 0.0 and near < SALA_FLEE:
				_sala = 0.001
			elif _sala > 0.0:
				_sala += dt
				_sx -= dt * 40.0
				if _sala > 1.0:
					_sala = -15.0
			elif _sala < 0.0:
				_sala += dt
				if _sala >= 0.0:
					_sala = 0.0 if near > SALA_FLEE * 2.0 else -5.0
					_sx = 0.0


func _draw() -> void:
	if kind == Kind.BATS:
		draw_set_transform(Vector2(0, -VineView.SORT_BIAS))
	match kind:
		Kind.BATS: _draw_bats()
		Kind.BEETLES: _draw_beetles()
		Kind.SALAMANDER: _draw_salamander()


func _draw_bats() -> void:
	var tt := t()
	for i in count:
		var hx := (i - (count - 1) / 2.0) * 8.0
		var f := _flight[i]
		if f == -1.0 or f < 0.0:
			# Suspendue sous le rebord (pied de paroi − hauteur de la face).
			spr(BAT_HANG, Vector2(hx - 3, -30), _pal_bat)
			continue
		var life := f / 3.0
		if life > 1.4:
			continue
		var frames := [BAT_UP, BAT_MID, BAT_DN, BAT_MID]
		var fr: Array = frames[int(tt * 12.0 + i) % 4]
		var dir := 1.0 if i % 2 else -0.7
		var p := Vector2(hx + life * 160.0 * dir + sin(life * 5.0 + i) * 6.0, -30.0 + sin(life * 3.0) * 14.0 - life * life * 60.0)
		spr(fr, p + Vector2(-6, 0), _pal_bat, i % 2 == 0)


func _draw_beetles() -> void:
	var tt := t()
	for i in count:
		var x := _bx[i]
		var moving := _bpause[i] <= 0.0
		var f: Array = BEETLE[int(tt * 10.0) % 2 if moving else 0]
		var dir := _bdir[i]
		var at := Vector2(roundf(x), 1.0 + i * 2.0)
		# Vu de dessus, avance selon x : les lignes du sprite deviennent des colonnes.
		for j in f.size():
			var row: String = f[j]
			for k in row.length():
				var ch := row[k]
				if ch == ".":
					continue
				var xx := (f.size() - 1 - j) if dir > 0 else j
				px(at + Vector2(xx - 3, k - 3), _pal_beetle[ch])
		var leg := int(tt * 12.0) % 2 if moving else 0
		for l in 3:
			var lx := at.x - 2 + l * 2
			px(Vector2(lx + (leg ^ (l & 1)), at.y - 4), OUT)
			px(Vector2(lx + ((leg + 1) % 2 ^ (l & 1)), at.y + 3), OUT)


func _draw_salamander() -> void:
	if _sala < 0.0:
		return
	var tt := t() * (3.0 if _sala > 0.0 else 0.6)
	var dir := -1.0
	var base := Vector2(_sx + sin(t() * 0.5 + seed) * 3.0, 0)
	var pts: Array[Vector2] = []
	for i in 16:
		pts.append(base + Vector2(-dir * i, sin(tt * 7.0 - i * 0.55) * (i / 16.0) * 2.4))
	for i in range(15, -1, -1):
		var p := pts[i]
		var w := 2.0 if i < 3 else (1.6 if i < 9 else (1.0 if i < 13 else 0.5))
		for k in range(-ceili(w), ceili(w) + 1):
			var edge := absf(k) >= w
			px(p + Vector2(0, k), OUT if edge else (Color8(217, 162, 79) if k < 0 else Color8(168, 112, 44)))
		if i > 3 and i < 11 and i % 3 == 0:
			px(p, Color8(90, 58, 26))
	var step := 1.0 if sin(tt * 14.0) > 0.0 else -1.0
	for leg: Array in [[3, 1], [3, -1], [9, 1], [9, -1]]:
		var p := pts[leg[0]]
		px(p + Vector2((1.0 if leg[1] * step > 0 else -1.0) * dir, leg[1] * 3), OUT)
		px(p + Vector2(0, leg[1] * 3), Color8(168, 112, 44))
	var hd := pts[0]
	px(hd + Vector2(dir, 0), Color8(217, 162, 79))
	px(hd + Vector2(dir * 2, 0), OUT)
	px(hd + Vector2(dir, -1), Color8(26, 20, 16))
	px(hd + Vector2(dir, 1), Color8(26, 20, 16))
