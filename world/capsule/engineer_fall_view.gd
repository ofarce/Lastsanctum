class_name EngineerFallView
extends Node2D
## Mort de l'Ingénieur et départ vers la capsule (planches/ingenieur-mort-planche.html, M2 « Foudroyé » puis
## R2 « Le feu follet » ; calendrier dans sim/engineer_return.gd). Deux nœuds (World) :
## - trié avec les sprites, au pied du corps : arrêt sur image blanc, corps soulevé qui bascule et retombe sur le
##   dos deux blocs plus loin, rebond, glissade, lumières de l'exo qui grésillent et meurent ; puis le corps se
##   défait de la tête aux pieds ;
## - `air` = true, par-dessus tout : grains de lumière qui se rassemblent en feu follet, vol en cloche jusqu'à la
##   colonne de la capsule, plongée dans le puits (durée fixe, quelle que soit la distance).
## Images : rangée « fall » de l'atlas (TyrienArt), centrées sur le milieu du corps (24, 31).

const CY := CapsuleView.CY
const GLOW_SHADER := preload("res://shaders/capsule_glow.gdshader")
const CENTER := Vector2(24, 31)
## Emprise du corps couché dans son image (rangées utiles), pour le défaire de haut en bas.
const ROW0 := 22
const ROW1 := 43

var air := false
var _white: Node2D


func _ready() -> void:
	visible = false
	if air:
		return
	# Silhouette blanche (coup reçu, image rémanente du vol) : même shader de teinte que l'occupant de la capsule.
	_white = Node2D.new()
	_white.name = "White"
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("tint", Color("#f2fcff"))
	_white.material = mat
	_white.draw.connect(_draw_white)
	add_child(_white)


func _process(_delta: float) -> void:
	var a := EngineerReturn.age()
	var on := a < EngineerReturn.ARRIVE
	if on != visible:
		visible = on
	if not on:
		return
	if not air:
		position = feet()
		_white.queue_redraw()
	queue_redraw()


static func feet() -> Vector2:
	return Proj.nat(GameState.engineer_fell_pos.x, 0.0, GameState.engineer_fell_pos.y).round()


static func _flick(tt: float) -> bool:
	return tt < 0.1 or (tt > 0.2 and tt < 0.27) or (tt > 0.4 and tt < 0.44)


## Pose du corps à l'âge a : image de la rangée « fall », milieu du corps par rapport aux pieds (px natifs, pour un
## Ingénieur tourné vers la droite), part de blanc, part de gris.
static func body(a: float) -> Dictionary:
	if a < 0.08:
		return {"i": 0, "c": Vector2(-2, -14), "white": 0.9, "grey": 0.0}
	if a < 0.55:
		var k := (a - 0.08) / 0.47
		return {"i": mini(4, roundi(k * 4.0)), "c": Vector2(-2.0 - 22.0 * k, -14.0 + 10.0 * k - sin(k * PI) * 9.0), "white": 0.0, "grey": 0.0, "k": k}
	var tt := a - 0.55
	var on := _flick(tt - 0.15)
	var bounce := -roundf(sin(tt / 0.2 * PI) * 2.0) if tt < 0.2 else 0.0
	var e := clampf(tt / 0.3, 0.0, 1.0)
	return {"i": 4 if on else 7, "c": Vector2(-24.0 - 3.0 * (1.0 - (1.0 - e) * (1.0 - e)), -4.0 + bounce), "white": 0.0,
		"grey": clampf((tt - 0.6) / 0.5, 0.0, 1.0) * 0.4}


## Avancée de la dissolution (0 à 1) à l'âge a.
static func _melt(a: float) -> float:
	return clampf((a - EngineerReturn.FALL - EngineerReturn.HOLD) / 0.6, 0.0, 1.0)


func _blit(ci: CanvasItem, tex: AtlasTexture, c: Vector2, col: Color, top := 0) -> void:
	var f := GameState.engineer_fell_face
	ci.draw_set_transform(Vector2(roundf(c.x) * f, roundf(c.y)), 0.0, Vector2(f, 1))
	ci.draw_texture_rect_region(tex.atlas, Rect2(-CENTER.x, top - CENTER.y, 48, 48 - top),
		Rect2(tex.region.position + Vector2(0, top), Vector2(48, 48 - top)), col)
	ci.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	var a := EngineerReturn.age()
	if a == INF:
		return
	if air:
		_draw_air(a)
		return
	var frames := TyrienArt.anim("fall")
	if frames.is_empty():
		return
	var f := GameState.engineer_fell_face
	var b := body(a)
	var c: Vector2 = b.c
	var melt := _melt(a)
	if melt >= 1.0:
		return
	# Ombre : sous les pieds, puis qui s'allonge sous le corps couché.
	var lying := a >= 0.55
	var sw := 15.0 if lying else 5.0 + 5.0 * float(b.get("k", 0.0))
	_shadow(Vector2(roundf(c.x) * f, 0 if not lying else 2), sw, 0.3 * (1.0 - melt))
	# Coup reçu : étoile blanche à hauteur de buste, du côté d'où il vient.
	if a < 0.1:
		var r := 2 + roundi(a * 40.0)
		for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
			draw_line(Vector2(7 * f, -20) + d * 2.0, Vector2(7 * f, -20) + d * r, Color(1, 1, 1, 1.0 - a * 6.0), 1.0)
	var g := 1.0 - float(b.grey)
	var top := roundi(ROW0 + (ROW1 - ROW0) * melt) if melt > 0.0 else 0
	_blit(self, frames[b.i], c, Color(lerpf(0.55, 1.0, g), lerpf(0.58, 1.0, g), lerpf(0.66, 1.0, g)), top)
	if melt > 0.0:
		draw_rect(Rect2(roundf(c.x) * f - 16, roundf(c.y) + top - CENTER.y, 32, 1), Color(CY[4], 0.8))
	# Poussière à l'impact.
	var dt := a - 0.55
	if dt >= 0.0 and dt < 0.6:
		var e := 1.0 - (1.0 - dt / 0.6) * (1.0 - dt / 0.6)
		for i in 10:
			var ang := CapsuleView._hash(11.0 + i) * PI
			var sp := 8.0 + CapsuleView._hash(18.0 + i) * 14.0
			draw_rect(Rect2((Vector2(-26 * f, 2) + Vector2(cos(ang) * sp * e, -sin(ang) * sp * 0.35 * e - 1.0)).round(), Vector2.ONE),
				Color(Color("#9aa1b0") if i % 2 else Color("#6d7482"), (1.0 - dt / 0.6) * 0.9))


func _draw_white() -> void:
	var a := EngineerReturn.age()
	var frames := TyrienArt.anim("fall")
	if a == INF or frames.is_empty():
		return
	var b := body(a)
	if b.white > 0.0:
		_blit(_white, frames[b.i], b.c, Color(1.0, 0.0, 0.0, b.white))
	elif a < 0.55 and float(b.k) > 0.15:
		var p := body(a - 0.066)
		_blit(_white, frames[p.i], p.c, Color(1.0, 0.0, 0.0, 0.25))


func _shadow(at: Vector2, rx: float, alpha: float) -> void:
	for y in range(-1, 2):
		var hw := roundf(rx * (1.0 if y == 0 else 0.7))
		draw_rect(Rect2(at.x - hw, at.y + y, 2.0 * hw + 1.0, 1), Color(0, 0, 0, alpha))


## Par-dessus les sprites : grains qui montent du corps, feu follet, vol jusqu'à la colonne.
func _draw_air(a: float) -> void:
	var t := GameState.sim_time
	var f := GameState.engineer_fell_face
	var ft := feet()
	var box := Rect2(ft + Vector2(-27 * f - 15, -11), Vector2(30, 13))
	var w0 := Vector2(box.get_center().x, box.position.y - 9.0)
	var t0 := EngineerReturn.FALL + EngineerReturn.HOLD
	var u := a - t0
	if u < 0.0:
		return
	if u < EngineerReturn.DISSOLVE:
		for i in 36:
			var ri := CapsuleView._hash(float(i))
			var age := u - ri * 0.6
			if age < 0.0 or age > 0.4:
				continue
			var k := age / 0.4
			var from := Vector2(box.position.x + CapsuleView._hash(i + 9.0) * box.size.x, box.position.y + ri * box.size.y)
			var p := from.lerp(w0, k * k) + Vector2(sin(k * 6.0 + i) * 3.0 * (1.0 - k), 0)
			draw_rect(Rect2(p.round(), Vector2.ONE), Color(CY[3] if i % 3 else CY[4], 1.0 - k * 0.3))
		CapsuleView.wisp(self, w0 + Vector2(0, sin(t * 5.0)), clampf((u - 0.1) / 0.6, 0.0, 1.0), t)
		return
	var k := EngineerReturn.flight_k()
	if k < 0.0:
		return
	var cap := Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y).round()
	for j in range(9, 0, -1):
		var q := k - j * 0.022
		if q < 0.0:
			continue
		var s := 3.0 if j < 4 else 1.0
		draw_rect(Rect2((_path(q, w0, cap) - Vector2(s, s) * 0.5).round(), Vector2(s, s)), Color(CY[3] if j < 3 else CY[2], 1.0 - j / 10.0))
	CapsuleView.wisp(self, _path(k, w0, cap), 1.0, t)


## Trajet du feu follet : cloche jusqu'au sommet de la colonne (planche : y = 8, pied de la capsule en y = 62),
## puis plongée dans le puits.
static func _path(k: float, w0: Vector2, cap: Vector2) -> Vector2:
	var top := cap + Vector2(0, 8 - 62)
	var split := 1.0 - EngineerReturn.DIVE / EngineerReturn.FLIGHT
	if k < split:
		var x := k / split
		var e := x * x * (3.0 - 2.0 * x)
		var ctrl := Vector2((w0.x + top.x) * 0.5, minf(w0.y, top.y) - 40.0)
		return w0.lerp(ctrl, e).lerp(ctrl.lerp(top, e), e)
	var d := (k - split) / (1.0 - split)
	return top + Vector2(0, 50.0 * d * d)
