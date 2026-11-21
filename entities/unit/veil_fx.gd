extends Node2D
## Voile de la Martyre porté : « Pendentif rayonnant » (planches/mods-exile-propositions.html, tour 2, Linceul C3).
## Porté : liseré d'améthyste clair qui bat tout autour de la silhouette, cristal en pendentif sur la poitrine qui
## lance quatre petits rayons toutes les 1,6 s. Coup absorbé (Loot.veil_absorbs, veil_hit_at) : la silhouette
## blanchit, onde violette autour du corps, le liseré éclate en éclats qui tombent ; le cristal reste noir et le
## liseré repousse depuis lui pendant les VEIL_TIME secondes de recharge.
## Le liseré suit l'image exacte du corps : contour calculé une fois par image de l'atlas et gardé en cache.

const Gear := preload("res://data/gear_items.gd")
const VEIL_TIME := 20.0
const V := [Color("#2a1640"), Color("#5a2d82"), Color("#8a4fc0"), Color("#b98ae6"), Color("#e6d2ff")]
const DARK := [Color("#2a2438"), Color("#3a3448"), Color("#4a4458")]
## Temps forts après le coup (s) : silhouette blanche, liseré éclatant, éclats, puis repousse jusqu'à la fin.
const WHITE_T := 0.06
const BRIGHT_T := 0.3
const SHATTER_T := 1.1
## Cristal, en pixels de l'image (48 × 48, pieds en 24, 45) : de profil, et de face.
const CRYSTAL_SIDE := Vector2(20, 28)
const CRYSTAL_FRONT := Vector2(23, 28)
const RAY_PERIOD := 1.6
var view: UnitView
var _frame: Texture2D
var _offset := Vector2.ZERO
var _vdir := ""
static var _shapes := {}
static var _images := {}


static func worn(u: Unit) -> bool:
	return u.role == "engineer" and not u.is_enemy() and u.alive() and Gear.has_module(u, "veil")


func tick(body: Sprite2D, vdir: String, body_shown: bool) -> void:
	visible = worn(view.unit) and body_shown and body.texture != null
	if not visible:
		return
	position = body.position
	scale = body.scale
	_frame = body.texture
	_offset = body.offset
	_vdir = vdir
	queue_redraw()


## Contour (pixels vides touchant le corps), halo (un cran plus loin) et pixels pleins d'une image de l'atlas.
static func shape(frame: Texture2D) -> Dictionary:
	var key := frame.get_instance_id()
	if _shapes.has(key):
		return _shapes[key]
	var img: Image
	var region := Rect2i(Vector2i.ZERO, frame.get_size())
	if frame is AtlasTexture:
		var atlas: Texture2D = (frame as AtlasTexture).atlas
		var ak := atlas.get_instance_id()
		if not _images.has(ak):
			var full := atlas.get_image()
			if full and full.is_compressed():
				full.decompress()
			_images[ak] = full
		img = _images[ak]
		region = Rect2i((frame as AtlasTexture).region)
	else:
		img = frame.get_image()
		if img and img.is_compressed():
			img.decompress()
	var out := {"ct": PackedVector2Array(), "hl": PackedVector2Array(), "fill": PackedVector2Array()}
	if img == null:
		_shapes[key] = out
		return out
	var w := region.size.x
	var h := region.size.y
	var m := PackedByteArray()
	m.resize(w * h)
	for y in h:
		for x in w:
			var on := img.get_pixel(region.position.x + x, region.position.y + y).a > 0.16
			m[y * w + x] = 1 if on else 0
			if on:
				out["fill"].append(Vector2(x, y))
	var at := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == 1
	for y in h:
		for x in w:
			if m[y * w + x] == 1:
				continue
			if at.call(x - 1, y) or at.call(x + 1, y) or at.call(x, y - 1) or at.call(x, y + 1):
				out["ct"].append(Vector2(x, y))
			elif at.call(x - 2, y) or at.call(x + 2, y) or at.call(x, y - 2) or at.call(x, y + 2) \
					or at.call(x - 1, y - 1) or at.call(x + 1, y + 1) or at.call(x - 1, y + 1) or at.call(x + 1, y - 1):
				out["hl"].append(Vector2(x, y))
	_shapes[key] = out
	return out


static func _hash(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


func _px(p: Vector2, c: Color, a: float = 1.0) -> void:
	if a > 0.0:
		draw_rect(Rect2((_offset + p).round(), Vector2.ONE), Color(c, minf(1.0, a)))


func _draw() -> void:
	if _frame == null:
		return
	var u := view.unit
	var t := GameState.sim_time
	var s := shape(_frame)
	var ct: PackedVector2Array = s["ct"]
	var k := t - u.veil_hit_at
	var ready := t >= u.veil_ready_at
	var cry := CRYSTAL_FRONT if _vdir == "d" else CRYSTAL_SIDE
	if ready:
		for p in ct:
			_px(p, V[4], 0.8 + 0.15 * sin(t * 3.0))
	elif k < WHITE_T:
		for p in s["fill"]:
			_px(p, Color.WHITE, 0.55)
		for p in ct:
			_px(p, Color.WHITE)
		for p in s["hl"]:
			_px(p, V[4], 0.9)
	elif k < BRIGHT_T:
		for p in ct:
			_px(p, V[4])
		for p in s["hl"]:
			_px(p, V[3], 0.85)
	elif k < SHATTER_T:
		var q := (k - BRIGHT_T) / (SHATTER_T - BRIGHT_T)
		for i in range(0, ct.size(), 2):
			var p := ct[i]
			var fall := q * q * (10.0 + _hash(i) * 30.0)
			var dx := (p.x - 24.0) * 0.25 * q + (_hash(i + 7) - 0.5) * q * 8.0
			_px(p + Vector2(dx, fall), V[4], 1.0 - q)
			_px(p + Vector2(dx + 1.0, fall), V[2], 1.0 - q)
	else:
		# Recharge : le liseré repousse depuis le cristal, jusqu'à recouvrir toute la silhouette quand le voile est prêt.
		var r := clampf((k - SHATTER_T) / maxf(0.1, VEIL_TIME - SHATTER_T), 0.0, 1.0) * 34.0
		for p in ct:
			if p.distance_to(cry) < r:
				_px(p, V[3], 0.75)
	if not ready and k < 0.4:
		var q := k / 0.4
		_ring(Vector2(24, 30), 14.0 + q * 12.0, V[4], 1.0 - q)
		_ring(Vector2(24, 30), 12.0 + q * 9.0, V[3], (1.0 - q) * 0.6)
	if _vdir != "u":
		_crystal(cry, not ready and k >= WHITE_T, t)


## Losange 3 × 5, facette claire en haut, chaînette vers le cou ; quatre rayons toutes les RAY_PERIOD s.
func _crystal(c: Vector2, dark: bool, t: float) -> void:
	var col := DARK if dark else [V[1], V[3], V[4]]
	_px(c + Vector2(1, -1), col[1])
	_px(c, col[1])
	_px(c + Vector2(1, 0), col[2])
	_px(c + Vector2(2, 0), col[1])
	_px(c + Vector2(0, 1), col[0])
	_px(c + Vector2(1, 1), col[1])
	_px(c + Vector2(2, 1), col[0])
	_px(c + Vector2(1, 2), col[0])
	_px(c + Vector2(1, 3), col[0])
	_px(c + Vector2(2, -2), V[1], 0.8)
	_px(c + Vector2(3, -3), V[1], 0.6)
	if dark:
		return
	var k := fposmod(t, RAY_PERIOD) / RAY_PERIOD
	if k < 0.35:
		var a := 1.0 - k / 0.35
		var l := 1 + roundi(k * 8.0)
		for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			for st in range(1, l + 1):
				_px(c + Vector2(1, 0.5) + d * (st + 1), V[4], a * (1.0 - float(st) / (l + 1)))


func _ring(c: Vector2, r: float, col: Color, alpha: float) -> void:
	var n := maxi(8, roundi(r * 7.0))
	var seen := {}
	for i in n + 1:
		var a := TAU * i / n
		var p := (c + Vector2(cos(a), sin(a)) * r).round()
		if seen.has(p):
			continue
		seen[p] = true
		_px(p, col, alpha)
