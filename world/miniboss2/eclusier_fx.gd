class_name EclusierFx
extends Node2D
## Grande Écluse (sim/eclusier.gd) : deux nœuds du monde. Au sol, sous les sprites (ground) : l'eau des quarts noyés,
## tramée et ridée, électrisée pendant le court-circuit, et les trois pompes (au repos, ou tenues : jauge pleine et
## jet d'eau). Par-dessus (air) : l'annonce du harpon (trait doré pointillé), la chaîne tendue ou brisée, les touches.
## Repère : pixels natifs du monde.

const WATER := [Color("#08161c"), Color("#12343e"), Color("#1f5a68"), Color("#3a8a9a"), Color("#8ed6e0")]
const BOLT := [Color("#7ab8ff"), Color("#cfe8ff"), Color.WHITE]
const GOLD := [Color("#6a4c18"), Color("#a87c2a"), Color("#ddb457"), Color("#fff0b0")]
const IRON := [Color("#22292c"), Color("#3a4448"), Color("#5a6a6e"), Color("#8a9a9c")]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
## Hauteur de la main au harpon au-dessus du sol (px natifs), et son écart devant lui.
const HAND := Vector2(22.0, 38.0)

var world: World
var ground := true


func _process(_delta: float) -> void:
	var r := Eclusier.run()
	visible = not r.is_empty() and Eclusier.boss() != null
	if visible:
		queue_redraw()


func _draw() -> void:
	var r := Eclusier.run()
	var now := GameState.sim_time
	if ground:
		_water(r, now)
		_pumps(r, now)
	else:
		_harpoon(r, now)


func _seen(p: Vector2) -> bool:
	return world == null or world.fog.visible_at(p)


## Eau d'un quart : texture tramée et ridée (deux états qui alternent pour le scintillement), opacité selon le niveau ;
## crêtes claires qui dérivent ; éclairs pendant le court-circuit (et leur annonce, qui grésille).
func _water(r: Dictionary, now: float) -> void:
	var s: Dictionary = r.get("short", {})
	var live := not s.is_empty() and now >= float(s["live"])
	var warn := not s.is_empty() and not live
	for q: Dictionary in r.get("quarters", []):
		var lv := float(q["level"])
		if lv <= 0.02:
			continue
		var qr: Rect2 = q["rect"]
		if not _seen(qr.get_center()):
			continue
		var a := Proj.nat(qr.position.x, 0.0, qr.position.y).round()
		var b := Proj.nat(qr.end.x, 0.0, qr.end.y).round()
		var tex := _water_tex(Vector2i(b - a), int(now * 2.5) % 2)
		var tint := Color(1, 1, 1, 0.35 + 0.5 * lv)
		# Eau sous tension : elle blanchit par saccades.
		if live and fmod(now * 9.0, 3.0) < 1.0:
			tint = Color(1.5, 1.8, 2.4, 0.9)
		# Case par case (4 × 4 unités) : seulement le sol de la salle, et seulement ce qui est en vue.
		var st: TerrainState = world.terrain_state if world != null else null
		var cy := floorf(qr.position.y / 4.0) * 4.0
		while cy < qr.end.y:
			var cx := floorf(qr.position.x / 4.0) * 4.0
			while cx < qr.end.x:
				var cell := Rect2(Vector2(cx, cy), Vector2(4.0, 4.0)).intersection(qr)
				var mid := cell.get_center()
				if cell.has_area() and (st == null or st.is_gallery(mid.x, mid.y)) and _seen(mid):
					var na := Proj.nat(cell.position.x, 0.0, cell.position.y).round()
					var nb := Proj.nat(cell.end.x, 0.0, cell.end.y).round()
					draw_texture_rect_region(tex, Rect2(na, nb - na), Rect2(na - a, nb - na), tint)
				cx += 4.0
			cy += 4.0
		var n := int(qr.size.x * qr.size.y / 40.0)
		for i in n:
			var h := float((i * 7919) % 1000) / 1000.0
			var v := float((i * 104729) % 1000) / 1000.0
			var p := a + Vector2(fmod(h * (b.x - a.x) + now * 6.0, b.x - a.x), v * (b.y - a.y))
			if _wet_seen(st, p):
				draw_rect(Rect2(p.round(), Vector2(3, 1)), Color(WATER[4], 0.35 * lv))
		if live or (warn and fmod(now * 8.0, 2.0) < 1.0):
			var seed := int(now * 14.0) + int(q["i"]) * 31
			for k in (14 if live else 3):
				var p := a + Vector2(float((seed * 37 + k * 211) % 997) / 997.0 * (b.x - a.x), float((seed * 61 + k * 389) % 991) / 991.0 * (b.y - a.y))
				if not _wet_seen(st, p + Vector2(10.0, 0.0)):
					continue
				for j in 10:
					draw_rect(Rect2(p.round(), Vector2.ONE * (2.0 if live else 1.0)), BOLT[(j + k) % 3])
					p += Vector2(2.0, float(((seed + j * 13 + k) % 3) - 1) * 2.0)


## Point natif p sur le sol de la salle, en vue.
func _wet_seen(st: TerrainState, p: Vector2) -> bool:
	var g := p / Proj.K
	return (st == null or st.is_gallery(g.x, g.y)) and _seen(g)


static var _water_cache := {}


## Texture d'eau d'un quart (taille en px natifs) : rides en diagonale, trame de Bayer entre deux teintes.
static func _water_tex(size: Vector2i, phase: int) -> Texture2D:
	var key := Vector3i(size.x, size.y, phase)
	if _water_cache.has(key):
		return _water_cache[key]
	var img := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var wave := sin(x * 0.09 + y * 0.21 + phase * 1.3) * 0.5 + 0.5
			var bi: int = BAYER[(y >> 1) % 4][(x >> 1) % 4]
			var c: Color = WATER[1]
			if wave * 16.0 > bi + 4.0:
				c = WATER[2]
			if wave > 0.94 and bi < 6:
				c = WATER[3]
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_water_cache[key] = t
	return t


func _pumps(r: Dictionary, now: float) -> void:
	for q: Dictionary in r.get("quarters", []):
		var pp: Vector2 = q["pump"]
		if pp == Vector2.INF or not _seen(pp):
			continue
		var held := bool(q["manned"])
		var anim := "pump_held" if held else "pump_free"
		var at := Proj.nat(pp.x, 0.0, pp.y).round()
		# La pompe ouest crache vers l'est, la pompe est vers l'ouest (vers le centre de la salle).
		var flip := pp.x > Eclusier.center().x
		MiniBoss2Art.draw(self, "pump", anim, MiniBoss2Art.frame("pump", anim, now), at, flip)
		if held:
			for k in 2:
				draw_circle(at + Vector2(0, -12), 5.0 + k * 3.0, Color(0.45, 0.8, 0.85, 0.07))


func _harpoon(r: Dictionary, now: float) -> void:
	var h: Dictionary = r.get("harpoon", {})
	var e := Eclusier.boss()
	if h.is_empty() or e == null or e.hp <= 0.0 or not _seen(e.pos()):
		return
	var hand := Proj.nat(e.x, 0.0, e.z).round() + Vector2(HAND.x * (1.0 if e.face > 0 else -1.0), -HAND.y)
	var stage := String(h["stage"])
	var u: Unit = h["u"]
	if stage == "warn" and u != null:
		# Trait doré pointillé de la main à la cible, qui défile.
		var to := Proj.nat(u.x, 0.0, u.z).round() + Vector2(0, -14)
		var n := int(hand.distance_to(to) / 3.0)
		for i in n:
			if (i + int(now * 16.0)) % 3 == 0:
				continue
			draw_rect(Rect2(hand.lerp(to, float(i) / n).round(), Vector2.ONE * 2.0), Color(GOLD[2], 0.9))
		return
	var head: Vector2 = h["head"]
	var tip := Proj.nat(head.x, 0.0, head.y).round() + Vector2(0, -14)
	var broken := stage == "broken"
	var gap := -1.0
	if broken:
		var bp: Vector2 = h.get("break_at", head)
		gap = clampf(e.pos().distance_to(bp) / maxf(0.1, e.pos().distance_to(head)), 0.0, 1.0)
	var links := maxi(2, int(hand.distance_to(tip) / 3.0))
	var sag := 0.0 if stage == "pull" else 6.0
	for i in links + 1:
		var t := float(i) / links
		if broken and absf(t - gap) < 0.08:
			continue
		var drop := sag * sin(t * PI) + (((t - gap) * 30.0) if broken and t > gap else 0.0)
		var p := hand.lerp(tip, t) + Vector2(0, drop)
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 2)), IRON[1 + (i % 2)])
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(1, 1)), IRON[3])
	if not broken:
		# Tête du harpon : pointe de fer et barbelures.
		var d := (tip - hand).normalized()
		for k in 4:
			draw_rect(Rect2((tip + d * k).round(), Vector2(2, 2)), IRON[3] if k > 1 else IRON[2])
		draw_rect(Rect2((tip - d * 2.0 + d.orthogonal() * 2.0).round(), Vector2.ONE), IRON[2])
		draw_rect(Rect2((tip - d * 2.0 - d.orthogonal() * 2.0).round(), Vector2.ONE), IRON[2])
	# Touches sur la chaîne : un point doré par touche, à la main.
	for k in int(h.get("hits", 0)):
		draw_rect(Rect2(hand + Vector2(-4 + k * 4, -6), Vector2(2, 2)), GOLD[3])
