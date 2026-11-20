class_name OeilFx
extends Node2D
## Attaques de l'Œil de la Matrice (sim/oeil.gd), d'après planches/oeil-maj.html :
## - au sol (ground) : couloirs d'avertissement tramés carmin (Regard, Strabisme) qui palpitent pendant l'annonce,
##   puis plus pâles pendant le torrent ; flaques de larmes (qui battent avant d'éclater) ; marque en amande de la
##   Fixation (qui se resserre) ; ombres des balles, des larmes en vol et des pupilles ;
## - par-dessus les sprites (air) : voile sombre du Clignement et éclair de réouverture, yeux des parois (Les
##   mille yeux), larmes qui coulent de l'œil (Larmes), balles (yeux, larmes, cils-dents) à OeilMatrice.BULLET.lift
##   px au-dessus de leur ombre (plus la hauteur de vol d'une larme en cloche), pupilles errantes, lueur de l'œil
##   qui vise, éclats des balles éteintes, éclaboussures, éclatement des marques, et zone touchée de l'Ingénieur.
## Repère : pixels natifs du monde.

const OUT := Color("#0b090b")
const SCLERA := [Color("#a8988e"), Color("#d6c8bc"), Color("#efe4da"), Color("#fff6ee")]
const IRIS := Color("#e2382e")
const PUPIL := Color("#060606")
const BLOOD := [Color("#4a0a0e"), Color("#7e1216"), Color("#b41c20"), Color("#e2382e"), Color("#ff8a6a")]
const MEMB := [Color("#3a1416"), Color("#6a2a2a"), Color("#9a4a44"), Color("#c47a6a"), Color("#e0a894"), Color("#f2cdb8")]
const BONE := [Color("#3a3228"), Color("#625644"), Color("#8e8068"), Color("#b8ac90"), Color("#e0d8c4")]
const PALE := [Color("#2c2024"), Color("#76605e"), Color("#a08a82")]
const SHADOW := Color(0.03, 0.01, 0.01, 0.45)
const ROT := 16
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
## Voile du Clignement (opacité max) et durée de l'éclair.
const DARK := 0.55
const FLASH := 0.5
static var _tex := {}

var world: World
var ground := true
var _dark := 0.0


func _process(delta: float) -> void:
	var r := OeilMatrice.run()
	_dark = move_toward(_dark, 1.0 if r.get("dark", false) else 0.0, delta * 4.0)
	visible = not GameState.oeil_bullets.is_empty() or not GameState.oeil_fx.is_empty() or OeilMatrice.active() or _dark > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var now := GameState.sim_time
	var lift: float = OeilMatrice.BULLET["lift"]
	if ground:
		_veil(now, true)
		for f: Dictionary in GameState.oeil_fx:
			match f["type"]:
				"lane", "sweep":
					_lane(f, now)
				"puddle":
					_puddle(f, now)
				"ret":
					_mark(f, now)
		for b: Dictionary in GameState.oeil_bullets:
			var p := Proj.nat(b["x"], 0.0, b["z"]).round()
			draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), SHADOW)
			if b["big"]:
				draw_rect(Rect2(p + Vector2(-3, 1), Vector2(7, 1)), SHADOW)
		for e: Enemy in GameState.enemies:
			if e.kind == OeilMatrice.PUPIL_KIND:
				var p := Proj.nat(e.x, 0.0, e.z).round()
				draw_rect(Rect2(p + Vector2(-5, 0), Vector2(11, 1)), SHADOW)
				draw_rect(Rect2(p + Vector2(-3, 1), Vector2(7, 1)), SHADOW)
		return
	_veil(now, false)
	for f: Dictionary in GameState.oeil_fx:
		if f["type"] == "walleyes":
			_wall_eyes(f, now)
	_weep(now)
	_glow(now)
	for b: Dictionary in GameState.oeil_bullets:
		var rot := posmod(roundi(atan2(b["vz"], b["vx"]) / TAU * ROT), ROT)
		var tex := bullet(b.get("style", "oeil"), b["big"], rot)
		var h := (tex.get_width() - 1) / 2.0
		draw_texture(tex, Proj.nat(b["x"], 0.0, b["z"]).round() - Vector2(h, h + lift + float(b.get("h", 0.0))))
	_pupils(now)
	for f: Dictionary in GameState.oeil_fx:
		var k := clampf((now - float(f["at"])) / maxf(0.01, float(f["until"]) - float(f["at"])), 0.0, 1.0) if f.has("until") else 0.0
		match f["type"]:
			"mote":
				var p := Proj.nat(f["x"], 0.0, f["z"]) + Vector2(0.0, -lift - k * 10.0)
				draw_rect(Rect2(p.round(), Vector2.ONE), Color(BLOOD[4], 1.0 - k))
			"splash":
				var c := Proj.nat(f["x"], 0.0, f["z"])
				for i in 7:
					var a := i * TAU / 7.0
					var rr := 3.0 + k * 9.0
					var q := c + Vector2(cos(a) * rr, -4.0 - absf(sin(a)) * rr * 0.8 + k * k * 6.0)
					draw_rect(Rect2(q.round(), Vector2.ONE), Color(MEMB[4], 1.0 - k))
			"boom":
				var c := Proj.nat(f["x"], 0.0, f["z"])
				for i in 28:
					var a := i * TAU / 28.0
					var rr := 6.0 + k * 26.0
					draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * rr).round(), Vector2(2, 1)), Color(BLOOD[4], 1.0 - k))
	_hitbox(now)


static func _bay(x: int, y: int) -> float:
	return (BAYER[posmod(y, 4)][posmod(x, 4)] + 0.5) / 16.0


## Couloir du Regard ou du Strabisme : bande tramée de 12 px depuis la base jusqu'à la paroi de la salle.
func _lane(f: Dictionary, now: float) -> void:
	var a: float = f["a"]
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	var o := OeilMatrice.emit(a)
	var warn := now < float(f["fire"])
	var pulse := 0.5 + 0.5 * sin(now * 30.0)
	var col := Color(BLOOD[3], 0.35 + 0.3 * pulse) if warn else Color(BLOOD[4], 0.22)
	var s := 0.0
	while s < 140.0:
		var w := o + d * s
		if not TerrainState.in_eye_room(w.x, w.y, 0.5):
			break
		var p := Proj.nat(w.x, 0.0, w.y)
		for k in range(-6, 7, 2):
			var q := (p + n * k).round()
			if ((int(q.x) + int(q.y)) >> 1) % 2 == 0:
				draw_rect(Rect2(q, Vector2(2, 1)), col)
		s += 0.25


## Flaque de larmes : ellipse laiteuse tramée, bord qui bat juste avant d'éclater.
func _puddle(f: Dictionary, now: float) -> void:
	var k := clampf((now - float(f["at"])) / maxf(0.01, float(f["until"]) - float(f["at"])), 0.0, 1.0)
	var beat := k > 0.75 and fmod(now * 20.0, 2.0) < 1.0
	var c := Proj.nat(f["x"], 0.0, f["z"]).round()
	var rx := 9.0 + k * 2.0
	var ry := 3.4 + k
	for j in range(-ceili(ry), ceili(ry) + 1):
		var w := roundi(rx * sqrt(maxf(0.0, 1.0 - (j / ry) * (j / ry))))
		for i in range(-w, w):
			var edge := absi(i) >= w - 1 or absf(j) >= ry - 0.5
			var col: Color = (BLOOD[3] if beat else MEMB[2]) if edge else (MEMB[1] if (i + j) & 1 else MEMB[3])
			draw_rect(Rect2(c + Vector2(i, j), Vector2.ONE), col)


## Marque de la Fixation : amande carmin pointillée qui se resserre, pupille noire au centre, fond tramé.
func _mark(f: Dictionary, now: float) -> void:
	var r: float = float(f["r"]) * Proj.K
	var k := clampf((now - float(f["at"])) / maxf(0.01, float(f["until"]) - float(f["at"])), 0.0, 1.0)
	var c := Proj.nat(f["x"], 0.0, f["z"]).round()
	var col: Color = BLOOD[4] if k > 0.8 and fmod(now * 24.0, 2.0) < 1.0 else BLOOD[3]
	var fill := Color(BLOOD[3], 0.08 + 0.16 * k)
	var ry := r * 0.62
	for j in range(-ceili(ry), ceili(ry) + 1, 2):
		var w := r * sqrt(maxf(0.0, 1.0 - (j / ry) * (j / ry)))
		for i in range(-ceili(w), ceili(w), 2):
			if ((i + j) >> 1) % 2 == 0:
				draw_rect(Rect2(c + Vector2(i, j), Vector2(2, 1)), fill)
	for i in 96:
		if i % 6 > 3:
			continue
		var a := i * TAU / 96.0
		var q := c + Vector2(cos(a) * r, sin(a) * ry * (0.55 + 0.45 * absf(cos(a))))
		draw_rect(Rect2(q.round(), Vector2.ONE), col)
	draw_rect(Rect2(c - Vector2(3, 0), Vector2(7, 1)), BLOOD[2])
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), PUPIL)


## Voile sombre du Clignement sur le sol de la salle (sous les sprites : l'Ingénieur reste visible, OeilView assombrit
## le boss), puis éclair blanc par-dessus tout à chaque réouverture.
func _veil(now: float, floor_only: bool) -> void:
	var c := TerrainState.eye_room_center()
	var a := Proj.nat(c.x - TerrainState.EYE_ROOM_RX - 2.0, 0.0, c.y - TerrainState.EYE_ROOM_RZ - 6.0)
	var b := Proj.nat(c.x + TerrainState.EYE_ROOM_RX + 2.0, 0.0, c.y + TerrainState.EYE_ROOM_RZ + 2.0)
	var rect := Rect2(a, b - a)
	if floor_only:
		if _dark > 0.0:
			draw_rect(rect, Color(0.012, 0.004, 0.008, DARK * _dark))
		return
	var fl := (now - float(OeilMatrice.run().get("flash_at", -INF))) / FLASH
	if fl >= 0.0 and fl < 1.0:
		draw_rect(rect, Color(1.0, 0.9, 0.86, 0.28 * (1.0 - fl)))


## Yeux des parois (Les mille yeux) : le long de la paroi du fond et de la paroi ouest, ils s'ouvrent au réveil.
func _wall_eyes(f: Dictionary, now: float) -> void:
	var op := clampf((now - float(f["at"])) / OeilMatrice.WALLS["wake"], 0.0, 1.0)
	if now > float(f["until"]) - 0.4:
		op = clampf((float(f["until"]) - now) / 0.4, 0.0, 1.0)
	var c := TerrainState.eye_room_center()
	for i in 41:
		var a := lerpf(PI * 1.06, PI * 1.94, i / 40.0)
		_wall_eye(_edge(c, a), op, PI / 2.0, now + i)
	for i in 13:
		var a := lerpf(PI * 0.62, PI * 1.38, i / 12.0)
		_wall_eye(_edge(c, a), op, 0.0, now + i * 1.7)


static func _edge(c: Vector2, a: float) -> Vector2:
	var s := TerrainState.eye_room_scale(a) - 0.04
	return c + Vector2(cos(a) * TerrainState.EYE_ROOM_RX * s, sin(a) * TerrainState.EYE_ROOM_RZ * s)


func _wall_eye(p: Vector2, op: float, a: float, ph: float) -> void:
	var tex := bullet("oeil", true, posmod(roundi(a / TAU * ROT), ROT))
	var c := Proj.nat(p.x, 0.0, p.y).round() + Vector2(0, -10)
	draw_rect(Rect2(c - Vector2(6, 5), Vector2(13, 11)), PALE[2])
	draw_rect(Rect2(c - Vector2(6, 5), Vector2(13, 1)), PALE[0])
	draw_rect(Rect2(c + Vector2(-6, 5), Vector2(13, 1)), PALE[0])
	var h := roundi(5.0 * op * (0.75 + 0.25 * sin(ph * 2.0)))
	if h > 0:
		draw_texture_rect_region(tex, Rect2(c + Vector2(-5, -h), Vector2(11, h * 2 + 1)), Rect2(0, 5 - h, 11, h * 2 + 1))
	else:
		draw_rect(Rect2(c + Vector2(-5, 0), Vector2(11, 1)), OUT)


## Larmes qui coulent sous l'œil pendant l'attaque Larmes (laiteuses, de sang en phase III).
func _weep(now: float) -> void:
	var e: Enemy = GameState.oeil
	if e == null or not OeilMatrice.run().get("weep", false):
		return
	var m := OeilView.meta()
	var eye: Dictionary = m["eye"]
	var base := Proj.nat(e.x, 0.0, e.z).round() - Vector2(float(m["ax"]), float(m["ay"])) \
		+ Vector2(float(eye["x"]), float(eye["y"]) + float(eye["ry"]) + 4.0)
	var col: Array = BLOOD if int(OeilMatrice.run().get("phase", 0)) >= 2 else MEMB
	for i in 5:
		var x := (i - 2) * 6.0
		var k := fmod(now * 1.1 + i * 0.31, 1.0)
		for j in roundi(k * 14.0):
			draw_rect(Rect2(base + Vector2(x, j), Vector2.ONE), col[2])
		draw_rect(Rect2(base + Vector2(x, k * 22.0), Vector2(1, 2)), Color(col[4], 1.0 - k))


## Pupilles errantes : globe blanc, iris tourné vers l'Ingénieur, lueur carmin ; trait de sang vers l'orbite tant
## qu'elles sortent ou rentrent.
func _pupils(now: float) -> void:
	var u := OeilMatrice.duelist()
	var e: Enemy = GameState.oeil
	for p: Enemy in GameState.enemies:
		if p.kind != OeilMatrice.PUPIL_KIND or p.hp <= 0.0:
			continue
		var h := float(p.memo.get("h", 16.0)) + OeilMatrice.BULLET["lift"]
		var c := Proj.nat(p.x, 0.0, p.z).round() - Vector2(0, h)
		var a := (u.pos() - p.pos()).angle() if u != null else PI / 2.0
		for j in range(-11, 12, 2):
			for i in range(-11, 12, 2):
				if i * i + j * j < 121 and ((i + j) >> 1) % 2 == 0:
					draw_rect(Rect2(c + Vector2(i, j), Vector2.ONE), Color(BLOOD[3], 0.2 + 0.1 * sin(now * 9.0)))
		var tex := pupil(posmod(roundi(a / TAU * ROT), ROT))
		var tint := Color(1.6, 0.8, 0.75) if now - p.hurt_at < 0.12 else Color.WHITE
		draw_texture(tex, c - Vector2(8, 8), tint)
		if e != null and h > OeilMatrice.PUPILS["h1"] + OeilMatrice.BULLET["lift"] + 1.0:
			var m := OeilView.meta()
			var eye: Dictionary = m["eye"]
			var o := Proj.nat(e.x, 0.0, e.z).round() - Vector2(float(m["ax"]), float(m["ay"])) + Vector2(float(eye["x"]), float(eye["y"]))
			for i in 5:
				draw_rect(Rect2(c.lerp(o, i / 5.0).round(), Vector2.ONE), BLOOD[3])


## Lueur carmin autour de l'iris quand l'œil est ouvert.
func _glow(now: float) -> void:
	var e: Enemy = GameState.oeil
	if e == null:
		return
	var r0 := OeilMatrice.run()
	var open: float = r0.get("open", 0.0)
	if open < 0.2 or r0.get("iris_out", false):
		return
	var m := OeilView.meta()
	var eye: Dictionary = m["eye"]
	var look: float = r0.get("look", PI / 2.0)
	var c := Proj.nat(e.x, 0.0, e.z).round() - Vector2(float(m["ax"]), float(m["ay"])) + Vector2(float(eye["x"]), float(eye["y"])) \
		+ Vector2(cos(look) * float(eye["look_x"]), sin(look) * float(eye["look_y"]))
	var r := 19.0
	for y in range(-19, 20):
		for x in range(-19, 20):
			var dd := Vector2(x, y).length() / r
			if dd >= 1.0 or dd < 0.52:
				continue
			var al := open * 0.7 * (1.0 - dd) * (0.85 + 0.15 * sin(now * 9.0))
			if al > _bay(x, y):
				draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), BLOOD[3] if dd > 0.7 else BLOOD[4])


func _hitbox(now: float) -> void:
	var u := OeilMatrice.duelist()
	if u == null:
		return
	var c := Proj.nat(u.x, 0.0, u.z).round() + Vector2(0.0, -OeilMatrice.BULLET["lift"])
	for b: Dictionary in GameState.oeil_bullets:
		if absf(b["x"] - u.x) < 3.0 and absf(b["z"] - u.z) < 3.0 and float(b.get("h", 0.0)) < 4.0:
			var r: float = (OeilMatrice.BULLET["hit"] + OeilMatrice.BULLET["r"]) * Proj.K
			draw_arc(c + Vector2(0.5, 0.5), r, 0.0, TAU, 24, Color(0.62, 0.94, 1.0, 0.45 + 0.25 * sin(now * 20.0)), 1.0)
			break
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), Color("#10123a"))
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)


## Texture d'une balle (mise en cache) : style "oeil", "larme" ou "cil", grosse ou non, orientée selon rot/ROT tour.
static func bullet(style: String, big: bool, rot: int) -> Texture2D:
	var key := "%s_%d_%d" % [style, 1 if big and style == "oeil" else 0, rot]
	if _tex.has(key):
		return _tex[key]
	var a := rot * TAU / ROT
	var ca := cos(a)
	var sa := sin(a)
	var n := 11 if big and style == "oeil" else 7 if style == "oeil" else 9 if style == "larme" else 11
	var hh := (n - 1) / 2.0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var fill := {}
	for y in n:
		for x in n:
			var dx := x - hh
			var dy := y - hh
			var u := dx * ca + dy * sa
			var v := -dx * sa + dy * ca
			var c := Color(0, 0, 0, 0)
			match style:
				"oeil":
					var s := 1.6 if big else 1.0
					if Vector2(dx, dy).length() / s > 2.9:
						continue
					var di := Vector2(u / s - 0.9, v / s).length()
					c = PUPIL if di < 0.6 else IRIS if di < 1.4 else (SCLERA[1] if dy > 0.9 * s else SCLERA[2])
				"larme":
					var q := (pow(u / 3.8, 2.0) if u < 0.0 else pow(u / 2.2, 2.0)) + pow(v / (1.9 * (1.0 + u / 9.0 if u < 0.0 else 1.0)), 2.0)
					if q > 1.0:
						continue
					c = SCLERA[3] if q < 0.2 and u > 0.2 else MEMB[4] if q < 0.55 else BLOOD[2] if u < -1.5 else MEMB[3]
				_:
					var w := (4.6 - u) * 0.32 if u > 2.0 else 0.35 if u < -3.6 else 0.62
					if u < -4.6 or u > 4.6 or absf(v) > w:
						continue
					c = BLOOD[2] if u < -2.8 else BONE[4] if u > 2.6 else BONE[1] if v > 0.0 else BONE[3]
			img.set_pixel(x, y, c)
			fill[Vector2i(x, y)] = true
	_outline(img, fill)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


## Pupille errante : globe de 15 px, iris décalé dans la direction rot/ROT tour.
static func pupil(rot: int) -> Texture2D:
	var key := "pupil_%d" % rot
	if _tex.has(key):
		return _tex[key]
	var a := rot * TAU / ROT
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	var fill := {}
	for y in 17:
		for x in 17:
			var dx := x - 8.0
			var dy := y - 8.0
			var d := Vector2(dx, dy).length()
			if d > 7.2:
				continue
			var di := Vector2(dx - cos(a) * 2.6, dy - sin(a) * 2.2).length()
			var c: Color
			if di < 1.5:
				c = PUPIL
			elif di < 3.6:
				c = BLOOD[4] if di < 2.3 else IRIS
			elif dx + dy < -6.5:
				c = SCLERA[3]
			else:
				var v := 0.8 - (dx + dy) * 0.05 - d * 0.04
				c = SCLERA[clampi(floori(v * 3.0 + _bay(x, y) - 0.5), 0, 3)]
			img.set_pixel(x, y, c)
			fill[Vector2i(x, y)] = true
	_outline(img, fill)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static func _outline(img: Image, fill: Dictionary) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if fill.has(Vector2i(x, y)):
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if fill.has(Vector2i(x, y) + o):
					img.set_pixel(x, y, OUT)
					break


## Compatibilité : balle « œil » (utilisée ailleurs sous ce nom).
static func eye_bullet(big: bool, rot: int) -> Texture2D:
	return bullet("oeil", big, rot)
