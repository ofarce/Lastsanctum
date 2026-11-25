class_name PatineFx
extends Node2D
## Nef verte (sim/patine.gd) et Mines de patine (sim/mods.gd) : deux nœuds du monde. Au sol, sous les sprites
## (ground) : le sol du dôme voilé de vert-de-gris, la moitié arrière de son mur, les mines (vertes, qui clignotent
## en fin de vie), celles du mod de l'Exilé. Par-dessus (air) : les balles de cuivre (losanges à hauteur de
## poitrine, ombre au sol), la moitié avant du mur, les éclats qui s'éteignent, le canon de l'Exilé qui verdit.
## Repère : pixels natifs du monde.

const COPPER := [Color("#5e2e16"), Color("#9a5028"), Color("#c87a42"), Color("#eab07a")]
const MINE := [Color("#06200f"), Color("#11582e"), Color("#2aa452"), Color("#78e098"), Color("#e0ffe8")]
const VERD := [Color("#1f3433"), Color("#365a55"), Color("#5e8f80"), Color("#9fcab8")]
const GOLD := Color("#ddb457")
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
## Hauteur du mur du dôme (px natifs).
const WALL := 46.0

var world: World
var ground := true


func _process(_delta: float) -> void:
	visible = (not Patine.run().is_empty() and Patine.boss() != null) or not GameState.patine_mines.is_empty()
	if visible:
		queue_redraw()


func _seen(p: Vector2) -> bool:
	return world == null or world.fog.visible_at(p)


func _draw() -> void:
	var now := GameState.sim_time
	var r := Patine.run()
	var dome := Patine.active() and _seen(Patine.center())
	if ground:
		if dome:
			_floor(now)
			_wall(now, false)
		for m: Dictionary in r.get("mines", []):
			_mine(Vector2(m["x"], m["z"]), now - float(m["at"]), float(m["until"]) - now, false)
		for m: Dictionary in GameState.patine_mines:
			_mine(Vector2(m["x"], m["z"]), now - float(m["at"]), float(m["until"]) - now, true)
	else:
		for b: Dictionary in r.get("bullets", []):
			_bullet(b)
		for m: Dictionary in r.get("motes", []):
			_mote(m, now)
		if dome:
			_wall(now, true)
		_barrel(now)


## Sol du dôme : voile vert tramé, plus dense vers le bord ; liseré doré au sol, ponctué de vert.
func _floor(now: float) -> void:
	var c := Proj.nat(Patine.center().x, 0.0, Patine.center().y).round()
	var rad := Patine.RADIUS * Proj.K
	var step := 4.0
	var y := -rad
	while y <= rad:
		var x := -rad
		while x <= rad:
			var d := Vector2(x, y).length() / rad
			if d <= 1.0:
				var bi: int = BAYER[int((y + rad) / step) % 4][int((x + rad) / step) % 4]
				if bi < d * d * 7.0:
					draw_rect(Rect2(c + Vector2(x, y), Vector2(step, step)), Color(VERD[1], 0.22))
			x += step
		y += step
	var n := int(TAU * rad / 3.0)
	for i in n:
		var a := TAU * i / n
		var p := (c + Vector2(cos(a), sin(a)) * rad).round()
		draw_rect(Rect2(p, Vector2(2, 1)), MINE[3] if (i + int(now * 6.0)) % 9 == 0 else Color(GOLD, 0.8))


## Mur du dôme : bandes verticales tramées qui s'éteignent vers le haut ; moitié arrière (nord) ou avant (sud).
func _wall(now: float, front: bool) -> void:
	var c := Proj.nat(Patine.center().x, 0.0, Patine.center().y).round()
	var rad := Patine.RADIUS * Proj.K
	var n := int(TAU * rad / 3.0)
	for i in n:
		var a := TAU * i / n
		var s := sin(a)
		if (s > 0.0) != front:
			continue
		var p := (c + Vector2(cos(a), s) * rad).round()
		var h := WALL * (0.75 + 0.25 * sin(a * 7.0 + now * 1.3))
		var k := 0.0
		while k < h:
			var bi: int = BAYER[int(k / 3.0) % 4][i % 4]
			if bi > (k / h) * 16.0:
				draw_rect(Rect2(p + Vector2(0, -k), Vector2(3, 3)), Color(VERD[2] if k < h * 0.3 else VERD[3], 0.30 if front else 0.45))
			k += 3.0


## Mine : pastille verte, croix pâle autour ; clignote sa dernière seconde. Celles du mod de l'Exilé sont plus petites.
func _mine(p: Vector2, age: float, left: float, own: bool) -> void:
	if not _seen(p):
		return
	if left < 1.0 and fmod(left * 8.0, 2.0) < 1.0:
		return
	var c := Proj.nat(p.x, 0.0, p.y).round()
	var grow := clampf(age / 0.2, 0.3, 1.0)
	var r := (2.0 if own else 3.0) * grow
	draw_circle(c, r + 1.0, MINE[0])
	draw_circle(c, r, MINE[2])
	draw_rect(Rect2(c + Vector2(-1, -1), Vector2(1, 1)), MINE[4])
	var arm := roundf((4.0 if own else 5.0) * grow)
	for o: Vector2 in [Vector2(arm, 0), Vector2(-arm, 0), Vector2(0, arm), Vector2(0, -arm)]:
		draw_rect(Rect2(c + o, Vector2.ONE), Color(MINE[3], 0.6))
	draw_circle(c, r + 5.0, Color(MINE[2], 0.08))


## Balle de cuivre : perle cerclée de sombre à hauteur de poitrine (lisible sur le sol vert), ombre au sol ; les éclats
## de l'oxydation ont un liseré vert.
func _bullet(b: Dictionary) -> void:
	var p := Vector2(b["x"], b["z"])
	if not _seen(p):
		return
	var g := Proj.nat(p.x, 0.0, p.y).round()
	draw_rect(Rect2(g + Vector2(-2, 0), Vector2(5, 1)), Color(0, 0, 0, 0.35))
	var tex := _bead(not b["mine"])
	draw_texture(tex, g - Vector2(5.0, 5.0 + Patine.BULLET["lift"]))


static var _beads := {}


## Perle de 11 px : cœur clair, corps de cuivre ombré en haut à gauche, deux rangs de bord sombre (vert pour un éclat).
static func _bead(green: bool) -> Texture2D:
	if _beads.has(green):
		return _beads[green]
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	var rim: Array = [MINE[0], MINE[2]] if green else [Color("#140804"), COPPER[0]]
	for y in 11:
		for x in 11:
			var dx := x - 5
			var dy := y - 5
			var d := Vector2(dx, dy).length()
			if d > 5.3:
				continue
			var c: Color = rim[0]
			if d <= 4.3:
				c = rim[1]
			if d <= 3.4:
				c = COPPER[2] if dx + dy > 0 else COPPER[3]
			if d <= 1.6:
				c = Color("#fff0c0")
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_beads[green] = t
	return t


## Éclat qui s'éteint : poussière verte (dorée pour une mine polie) qui monte et pâlit.
func _mote(m: Dictionary, now: float) -> void:
	var k := clampf((now - float(m["at"])) / 0.9, 0.0, 1.0)
	var c := Proj.nat(m["x"], 0.0, m["z"]).round() - Vector2(0, 4.0 + k * 10.0)
	var col: Color = GOLD if m.get("polish", false) else MINE[3]
	for i in 4:
		var a := TAU * i / 4.0 + k * 2.0
		draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * (2.0 + k * 5.0)).round(), Vector2.ONE), Color(col, 1.0 - k))


## Mines de patine : le canon de l'Exilé verdit un instant quand une de ses mines éclate.
func _barrel(now: float) -> void:
	for u: Unit in GameState.units:
		if u.role != "engineer" or not u.alive() or u.hidden:
			continue
		var k := 1.0 - (now - Mods.at(u, "patine")) / 0.6
		if k <= 0.0:
			continue
		var c := Proj.nat(u.x, 0.0, u.z).round() + Vector2(6.0 * (1.0 if u.face >= 0 else -1.0), -16.0)
		for i in 3:
			draw_circle(c, 2.0 + i * 2.0, Color(MINE[3], (0.4 - i * 0.12) * k))
