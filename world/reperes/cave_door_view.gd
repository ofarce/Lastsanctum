class_name CaveDoorView
extends Node2D
## Porte d'un tunnel (sim/cave_doors.gd ; planches/portes-tunnels-propositions.html, P1 « Vantaux cerclés » et
## R1 « Vantaux enfoncés ») : deux battants de chêne noirci cerclés de fer dans un cadre d'ardoise, dessinés pixel par
## pixel en pixels natifs (une case de 4 unités = 32 px, le couloir de 3 cases = 96 px, battants de 48 × 44 px).
##
## Deux poses, selon le seuil :
##  - « front » : seuil est-ouest (bouche nord, seuils franchis du sud ou du nord) ; la face des battants se voit,
##    ils pivotent vers le tunnel. Origine au milieu du pied du seuil.
##  - « edge » : seuil nord-sud (bouche est, seuils franchis par l'est ou l'ouest) ; les battants se voient par la
##    tranche, ils pivotent vers le tunnel et montrent leur face une fois ouverts. Origine au pied sud du seuil.
## Les battants sont projetés comme dans le monde (Proj : x·8, z·8, hauteur vers le haut) : chaque colonne du battant
## est posée à sa place au sol puis élevée de LEAF_H, de la plus au nord à la plus au sud.
## Porte d'une bouche (door ≥ 0) : 8 images d'ouverture et la ruine si elle est enfoncée, barre de PV entamée.
## Ruine de seuil (door = −1) : la ruine seule, glyphe du quartier sur la clef de voûte. Les débris au sol (battant
## arraché, éclats, gravats) vont dans un nœud à part sous les unités (ground).

const LEAF := 48
const LEAF_H := 44
const HALF := 48
const FRAMES := 8
## Image : marge autour de l'origine (px natifs).
const IMG := Vector2i(200, 240)
const ORIGIN := {"front": Vector2i(100, 164), "edge": Vector2i(72, 164)}

const INK := Color8(10, 11, 16)
const S := [Color8(28, 31, 39), Color8(47, 52, 64), Color8(68, 75, 90), Color8(93, 102, 120), Color8(124, 134, 154), Color8(163, 173, 191)]
const IRON := [Color8(21, 22, 27), Color8(40, 42, 51), Color8(61, 64, 76), Color8(88, 92, 107), Color8(138, 143, 159)]
const OAK := [Color8(42, 26, 16), Color8(70, 48, 30), Color8(104, 70, 41), Color8(138, 98, 56), Color8(168, 128, 80)]
const QUARTZ := [Color8(143, 138, 128), Color8(201, 196, 182), Color8(239, 234, 220)]

var world: World
## Index dans CaveDoors.MOUTHS, ou −1 pour une ruine de seuil.
var door := -1
var pose := "front"
var quarter := ""
## Sens de la chute des débris (vers la salle, ou vers la grotte pour une bouche) : (±1, 0) ou (0, ±1).
var fall := Vector2i(0, 1)
var _frames: Array[ImageTexture] = []
var _ruin: ImageTexture
var _debris: ImageTexture
var _ground := Sprite2D.new()
var _shown := -2
## Couloir plus large que les battants (4 cases au lieu de 3) : montants élargis de `wide` px de chaque côté.
var wide := 0


## Porte de la bouche i.
func setup_mouth(w: World, i: int) -> void:
	world = w
	door = i
	var m: Dictionary = CaveDoors.MOUTHS[i]
	var out: Vector2 = m["out"]
	pose = "front" if absf(out.y) > 0.5 else "edge"
	fall = Vector2i(-roundi(out.x), -roundi(out.y))
	_place(m["a"], m["b"])
	for k in FRAMES:
		_frames.append(ImageTexture.create_from_image(_door_image(float(k) / float(FRAMES - 1))))


## Ruine de seuil (CaveDoors.ruins).
func setup_ruin(w: World, r: Dictionary) -> void:
	world = w
	door = -1
	quarter = r["quarter"]
	var into: Vector2i = r["into"]
	pose = "front" if into.x == 0 else "edge"
	fall = into
	_place(r["a"], r["b"])


func _place(a: Vector2, b: Vector2) -> void:
	name = "Porte"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wide = maxi(0, roundi((a.distance_to(b) * Proj.K - 2.0 * HALF) / 2.0))
	# Profil : battants centrés sur le seuil, pied sud des battants HALF px au sud du milieu.
	var foot := (a + b) * 0.5 if pose == "front" else (a + b) * 0.5 + Vector2(0.0, HALF / Proj.K)
	position = Proj.nat(foot.x, 0.0, foot.y).round()
	_ruin = ImageTexture.create_from_image(_ruin_image())
	_debris = ImageTexture.create_from_image(_debris_image())
	_ground.texture = _debris
	_ground.centered = false
	_ground.offset = -Vector2(ORIGIN[pose])
	_ground.position = position
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.visible = door < 0


## Le nœud des débris va sous les unités (SanctumView.ground).
func ground_node() -> Sprite2D:
	return _ground


func _exit_tree() -> void:
	if is_instance_valid(_ground):
		_ground.queue_free()


func _process(_delta: float) -> void:
	if door < 0:
		if _shown != -1:
			_shown = -1
			queue_redraw()
		return
	if GameState.cave_doors.size() <= door:
		return
	var d: Dictionary = GameState.cave_doors[door]
	var f := -1 if d["broken"] else roundi(float(d["open"]) * (FRAMES - 1))
	_ground.visible = f < 0
	var hurt := GameState.sim_time - float(d.get("hit_at", -INF)) < 0.12
	modulate = Color(1.5, 1.35, 1.25) if hurt else Color.WHITE
	if f != _shown or hurt or float(d["hp"]) < float(d["max_hp"]):
		_shown = f
		queue_redraw()


func _draw() -> void:
	var tex: Texture2D = _ruin if _shown < 0 or door < 0 else _frames[_shown]
	draw_texture(tex, -Vector2(ORIGIN[pose]))
	if door < 0 or GameState.cave_doors.size() <= door:
		return
	var d: Dictionary = GameState.cave_doors[door]
	if d["broken"] or float(d["hp"]) >= float(d["max_hp"]):
		return
	# Barre de PV au-dessus du linteau (ou au-dessus du montant sud de profil).
	var at := Vector2(-20, -84) if pose == "front" else Vector2(-14, -64)
	var k := clampf(float(d["hp"]) / maxf(float(d["max_hp"]), 1.0), 0.0, 1.0)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(42, 5)), INK)
	draw_rect(Rect2(at, Vector2(40, 3)), Color8(40, 24, 18))
	draw_rect(Rect2(at, Vector2(roundf(40 * k), 3)), Color8(214, 160, 72) if k > 0.35 else Color8(214, 72, 52))


# ---------------------------------------------------------------- Dessin des images

## Pixels posés avant le contour : {Vector2i: Color}, coordonnées locales (origine du seuil).
var _pix := {}


func _put(x: float, y: float, c: Color) -> void:
	_pix[Vector2i(roundi(x), roundi(y))] = c


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_pix[Vector2i(x + i, y + j)] = c


static func _h(a: float, b: float) -> float:
	var s := sin(a * 127.1 + b * 311.7) * 43758.5453
	return s - floorf(s)


## Image de _pix avec un contour d'encre sur les pixels vides qui touchent un pixel posé.
func _flush() -> Image:
	var img := Image.create(IMG.x, IMG.y, false, Image.FORMAT_RGBA8)
	var o: Vector2i = ORIGIN[pose]
	for p: Vector2i in _pix:
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q := p + n
			if not _pix.has(q):
				var pq := q + o
				if pq.x >= 0 and pq.y >= 0 and pq.x < IMG.x and pq.y < IMG.y:
					img.set_pixelv(pq, INK)
	for p: Vector2i in _pix:
		var pp := p + o
		if pp.x >= 0 and pp.y >= 0 and pp.x < IMG.x and pp.y < IMG.y:
			img.set_pixelv(pp, _pix[p])
	_pix.clear()
	return img


## Couleur du battant en (u depuis les gonds, v depuis le haut) : planches de 8 px, deux bandes de fer cloutées,
## anneau près du bord libre ; null = manquant (ruine).
static func _oak(u: int, v: int) -> Variant:
	if v == 0:
		return OAK[4]
	if v == LEAF_H - 1:
		return OAK[0]
	for b: int in [6, 33]:
		if v >= b and v < b + 4:
			if u % 8 == 3 and v == b + 1:
				return IRON[4]
			if u % 8 == 3 and v == b + 2:
				return IRON[1]
			return IRON[3] if v == b else (IRON[1] if v == b + 3 else IRON[2])
	if u == LEAF - 1:
		return OAK[1]
	if u == 0:
		return OAK[3]
	# Anneau de tirage.
	if u >= LEAF - 9 and u <= LEAF - 5 and v >= 19 and v <= 25:
		var du := u - (LEAF - 7)
		var dv := v - 22
		if absi(du) + absi(dv) == 2 or (absi(du) == 2 and absi(dv) <= 1) or (absi(dv) == 3 and absi(du) <= 1):
			return IRON[4] if dv < 0 else IRON[3]
	if u % 8 == 7:
		return OAK[1]
	var plank := u / 8
	var grain := _h(float(plank), floorf(v / 5.0) + float(u % 8 > 3))
	if (u % 8 == 0) or v == 1:
		return OAK[3]
	if grain > 0.82:
		return OAK[1].lerp(OAK[2], 0.5)
	return OAK[2] if (plank % 2 == 0 or grain > 0.4) else OAK[2].lerp(OAK[3], 0.25)


## Battant projeté : gonds en `hinge` (px natifs, au sol), direction fermée d0, ouverte d1, angle a (0 … π/2),
## épaisseur th du côté nside (+1/−1), droop px de chute du bord libre, hole(u, v) → vrai pour les morceaux arrachés.
## Renvoie les colonnes à trier : [y au sol, rang, x, u, t].
func _leaf_cols(hinge: Vector2, d0: Vector2, d1: Vector2, a: float, nside: float, th: int, droop := 0.0, hole := Callable()) -> Array:
	var dir := (d0 * cos(a) + d1 * sin(a)).normalized()
	var n := Vector2(dir.y, -dir.x) * nside
	var cols := []
	for u in LEAF:
		for t in th:
			var base := hinge + dir * (float(u) + 0.5) + n * float(t)
			cols.append([base.y + droop * float(u) / LEAF, -t, base.x, u, t, a, hole, th])
	return cols


func _draw_cols(cols: Array) -> void:
	cols.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	for c: Array in cols:
		var u: int = c[3]
		var t: int = c[4]
		var a: float = c[5]
		var hole: Callable = c[6]
		var th: int = c[7]
		var x := roundf(c[2])
		var y0 := roundf(c[0]) - LEAF_H
		for v in LEAF_H:
			if hole.is_valid() and hole.call(u, v):
				continue
			var col: Variant = _oak(u, v)
			if col == null:
				continue
			var cc: Color = col
			if v == 0:
				cc = _top(u, t, th)
			elif t > 0:
				cc = OAK[1]
			_put(x, y0 + v, cc.lerp(INK, a * 0.42))


## Dessus du battant (vu de profil, c'est presque tout ce qu'on en voit) : bouts des planches, joints tous les 8 px,
## chants sombres, bord libre fendu d'un trait noir.
static func _top(u: int, t: int, th: int) -> Color:
	if u >= LEAF - 1:
		return INK
	if t == 0 or t == th - 1:
		return OAK[1] if th > 3 else OAK[4]
	if u % 8 == 7:
		return OAK[1]
	if t == 1:
		return OAK[4]
	return OAK[3] if (u / 8) % 2 == 0 else OAK[3].lerp(OAK[2], 0.45)


## Montant d'ardoise de w px, pied en (x, 0), haut de h px : assises tous les 10 px, plinthe.
func _post(x: int, y: int, w: int, h: int) -> void:
	_rect(x, y - h, w, h, S[3])
	_rect(x, y - h, 1, h, S[4])
	_rect(x + w - 1, y - h, 1, h, S[1])
	for j in range(y - h + 9, y - 2, 10):
		_rect(x, j, w, 1, S[2])
		_put(x + 2 + (j / 10) % 3, j - 4, S[4] if (j / 10) % 2 else S[2])
	_rect(x - 1, y - 3, w + 2, 3, S[2])
	_rect(x - 1, y - 3, w + 2, 1, S[4])
	_rect(x, y - h - 1, w, 1, S[5])


func _lintel(broken: bool) -> void:
	for i in range(-HALF - 12 - wide, HALF + 12 + wide):
		if broken and i > -30 and i < -14:
			continue
		for j in 6:
			var c: Color = S[5] if j == 0 else (S[1] if j == 5 else (S[2] if (i + HALF + 12 + wide) % 22 == 0 else S[3]))
			if j == 1 and _h(float(i), 3.0) > 0.8:
				c = S[4]
			_put(i, -LEAF_H - 12 + j, c)
	if broken:
		_rect(-30, -LEAF_H - 7, 1, 2, S[2])
		_rect(-14, -LEAF_H - 12, 1, 3, S[1])


## Clef de voûte : glyphe du quartier à sa couleur (ruine), ou losange de quartz (porte de la grotte).
func _keystone(cracked: bool) -> void:
	var y := -LEAF_H - 12 - 22
	_rect(-11, y, 22, 22, S[3])
	_rect(-11, y, 22, 1, S[5])
	_rect(-11, y, 1, 22, S[4])
	_rect(10, y, 1, 22, S[1])
	_rect(-11, y + 21, 22, 1, S[2])
	var g: Array = QuarterMarks.GLYPH.get(quarter, [])
	var col: Color = QuarterMarks.COLOR.get(quarter, QUARTZ[2])
	if g.is_empty():
		for j in 9:
			var w := 4 - absi(j - 4)
			for i in range(-w, w + 1):
				_put(i, y + 6 + j, QUARTZ[2] if absi(i) + absi(j - 4) < 3 else QUARTZ[1])
	else:
		for j in 7:
			for i in 7:
				if (g[j] as String)[i] == "#":
					var dim := cracked and i > 3 and j > 3 and _h(float(i * 3 + j), 1.0) > 0.4
					var c: Color = S[1] if dim else col.lerp(S[2], 0.25)
					_rect(-7 + i * 2, y + 4 + j * 2, 2, 2, c)
	if cracked:
		for j in 21:
			_put(3 - j / 6, y + j, INK)


## Porte intacte, ouverture o (0 fermée … 1 contre les parois).
func _door_image(o: float) -> Image:
	var a := o * PI * 0.5
	var cols := []
	if pose == "front":
		cols += _leaf_cols(Vector2(-HALF, 0), Vector2.RIGHT, Vector2.UP, a, 1.0, 3)
		cols += _leaf_cols(Vector2(HALF, 0), Vector2.LEFT, Vector2.UP, a, -1.0, 3)
		_draw_cols(cols)
		_post(-HALF - 10 - wide, 0, 10 + wide, LEAF_H + 6)
		_post(HALF, 0, 10 + wide, LEAF_H + 6)
		_lintel(false)
		_keystone(false)
		if o < 0.05:
			# Verrou : une barre de fer en travers des deux battants.
			_rect(-6, -24, 12, 3, IRON[3])
			_rect(-6, -24, 12, 1, IRON[4])
	else:
		var into := Vector2(-fall.x, 0)
		cols += _leaf_cols(Vector2(3, -2 * HALF), Vector2.DOWN, into, a, -signf(into.x), 7)
		cols += _leaf_cols(Vector2(3, 0), Vector2.UP, into, a, signf(into.x), 7)
		_edge_posts(cols)
	return _flush()


## Profil : montant nord derrière les battants, montant sud devant ; chaperon de fer qui les relie en haut.
func _edge_posts(cols: Array) -> void:
	# Couloir plus large : le montant nord se prolonge vers le nord, le sud vers le sud, par pas de 4 px.
	for f in range(-2 * HALF - wide, -2 * HALF + 1, 4):
		_post(-4, f, 8, LEAF_H + 8)
	_draw_cols(cols)
	for f in range(0, wide + 1, 4):
		_post(-4, f, 8, LEAF_H + 8)


## Ruine R1 : un battant pend de travers, la planche du bas arrachée ; l'autre a disparu (il gît au sol, _debris).
func _ruin_image() -> Image:
	var hole := func(u: int, v: int) -> bool:
		return (u > 34 and v > LEAF_H - 10) or (u > 40 and v < 10) or (u >= 16 and u < 24 and v > LEAF_H - 14) \
			or (u > 44 and _h(float(u), float(v)) > 0.5)
	if pose == "front":
		var cols := _leaf_cols(Vector2(-HALF, 0), Vector2.RIGHT, Vector2(fall), 0.38, 1.0, 3, 9.0, hole)
		_draw_cols(cols)
		# Penture arrachée côté est.
		_rect(HALF - 6, -38, 6, 3, IRON[2])
		_rect(HALF - 4, -14, 4, 3, IRON[2])
		_put(HALF - 7, -37, IRON[4])
		_post(-HALF - 10 - wide, 0, 10 + wide, LEAF_H + 6)
		_post(HALF, 0, 10 + wide, LEAF_H + 6)
		_lintel(true)
		_keystone(true)
	else:
		var into := Vector2(fall.x, 0)
		var cols := _leaf_cols(Vector2(3, -2 * HALF), Vector2.DOWN, into, 0.45, -signf(into.x), 7, 7.0, hole)
		_edge_posts(cols)
		_rect(-3, -18, 6, 3, IRON[2])
	return _flush()


## Débris au sol : le second battant à plat (planches vues de dessus), éclats et gravats, côté `fall`.
func _debris_image() -> Image:
	var f := Vector2(fall)
	var side := Vector2(f.y, f.x).abs()
	var c := f * 26.0 + side * 10.0 + (Vector2(0, -2 * HALF / 2.0) if pose == "edge" else Vector2.ZERO)
	var ang := 0.28 if fall.x == 0 else -0.35
	var ax := Vector2(cos(ang), sin(ang))
	var ay := Vector2(-ax.y, ax.x)
	for j in 30:
		for i in LEAF - 6:
			if (i > LEAF - 12 and j < 7) or (i < 5 and j > 24):
				continue
			var p := c + ax * (float(i) - 21.0) + ay * (float(j) - 15.0)
			var col: Color = OAK[2]
			if j == 0:
				col = OAK[3]
			elif j == 29:
				col = OAK[1]
			elif i == 8 or i == 9 or i == 32 or i == 33:
				col = IRON[3] if i % 2 == 0 else IRON[1]
			elif j % 8 == 7:
				col = OAK[1]
			elif _h(float(j / 8), float(i / 6)) > 0.75:
				col = OAK[2].lerp(OAK[3], 0.4)
			_put(p.x, p.y, col)
	# Éclats de bois et gravats d'ardoise au pied du seuil.
	for k in 16:
		var o := Vector2((_h(float(k), 2.0) - 0.5) * 80.0, f.y * 4.0 + f.x * 4.0 + _h(float(k), 5.0) * 10.0 - 2.0)
		if pose == "edge":
			o = Vector2(f.x * 6.0 + _h(float(k), 5.0) * 10.0 * f.x, (_h(float(k), 2.0) - 0.5) * 80.0 - HALF)
		var l := 2 + int(_h(float(k), 7.0) * 4.0)
		var dx := 1.0 if _h(float(k), 9.0) > 0.5 else -1.0
		for j in l:
			_put(o.x + j * dx, o.y + floorf(j / 2.0), OAK[3] if j == 0 else OAK[2])
	for k in 7:
		var o := Vector2((_h(float(k), 12.0) - 0.5) * 70.0, f.y * 6.0 + _h(float(k), 13.0) * 8.0)
		if pose == "edge":
			o = Vector2(f.x * 8.0 + _h(float(k), 13.0) * 8.0 * f.x, (_h(float(k), 12.0) - 0.5) * 70.0 - HALF)
		var r := 2 + int(_h(float(k), 14.0) * 3.0)
		for j in range(-r, r + 1):
			for i in range(-r - 1, r + 2):
				if i * i * 0.7 + j * j * 1.4 <= r * r:
					_put(o.x + i, o.y + j, S[4] if i + j < -1 else (S[3] if i + j < 2 else S[2]))
	return _flush()
