class_name DeityFx
extends Node2D
## Effets des portails divins actifs (deityFx, Index.html, 73b410f) : arcs d'Indra, glyphes de Sigil,
## lucioles et feuilles de Medeina, éclats d'Aether. Calculés en pixels natifs de l'écran, comme le
## prototype (certains effets dépendent de la position à l'écran), puis ramenés dans le repère du nœud.

const DECO_OFF := 6.2
const PORTAL_Z := -167.7
## C.leaf[6] et C.leaf[7] (decor.js).
const LEAF := [Color("#529248"), Color("#71ac58")]

var deity_id := ""
var deity_x := 0.0
var glow: Array[Color] = []
var world: World


func _process(_delta: float) -> void:
	queue_redraw()


func _nat_p(x: float, z: float) -> Vector2:
	var n := Proj.nat(x, 0.0, z) + world.native_offset
	return Vector2(floorf(n.x + 0.5), floorf(n.y + 0.5))


func _draw() -> void:
	if world == null or not GameState.deity_active.get(deity_id, false):
		return
	# Repère du nœud en pixels natifs du monde : écart entre coordonnées écran natives et locales.
	var o := world.native_offset + world.to_local(global_position)
	var z := PORTAL_Z + 1.6
	var L := _nat_p(deity_x - DECO_OFF, z)
	var Rr := _nat_p(deity_x + DECO_OFF, z)
	var t := GameState.sim_time
	var G := glow
	match deity_id:
		"indra":
			var ph := fmod(t + deity_x, 2.4)
			for q in [L, Rr]:
				if sin(t * 9.0 + q.x) > 0.3:
					PixelDraw.npx(self, q.x, q.y - 60.0, G[4], o)
			if ph < 0.35:
				var pts := PixelDraw.smooth_arc(3, L.x, L.y - 59.0, Rr.x, Rr.y - 59.0, t * 3.0, 7.0)
				PixelDraw.plot_path(self, pts, G[2], true, o)
				PixelDraw.plot_path(self, pts, Color("#ffffff") if ph < 0.15 else G[3], false, o)
			elif ph > 1.2 and ph < 1.38:
				var m := _nat_p(deity_x, PORTAL_Z)
				var src: Vector2 = L if int(ph * 10.0) % 2 else Rr
				PixelDraw.plot_path(self, PixelDraw.smooth_arc(5, src.x, src.y - 59.0, m.x, m.y - 36.0, t * 4.0, 5.0), G[3], false, o)
		"sigil":
			for q in [L, Rr]:
				for k in 4:
					var u := fmod(t * 0.35 + k / 4.0 + q.x * 0.01, 1.0)
					var x: float = q.x + sin(t * 1.3 + k * 2.0) * 5.0
					var y: float = q.y - 42.0 - u * 30.0
					if u > 0.85:
						continue
					var c := G[4] if u < 0.5 else G[3]
					PixelDraw.npx(self, x, y, c, o)
					if k % 2:
						PixelDraw.npx(self, x + 1.0, y, c, o)
						PixelDraw.npx(self, x, y + 1.0, c, o)
					else:
						PixelDraw.npx(self, x - 1.0, y + 1.0, c, o)
						PixelDraw.npx(self, x + 1.0, y + 1.0, c, o)
		"medeina":
			for k in 10:
				var a := k * 2.4 + t * (0.3 + (k % 3) * 0.15)
				var r := 6.0 + (k * 7) % 14
				var src: Vector2 = L if k % 2 else Rr
				var b := sin(t * 3.0 + k * 1.7)
				if b > 0.0:
					PixelDraw.npx(self, src.x + cos(a) * r, src.y - 20.0 + sin(a * 1.3) * 12.0, G[4] if b > 0.7 else G[3], o)
			for k in 3:
				var u := fmod(t * 0.25 + k / 3.0, 1.0)
				PixelDraw.npx(self, L.x - 8.0 + k * 7 + sin(t * 2.0 + k) * 3.0, L.y - 38.0 + u * 38.0, LEAF[k % 2], o)
		_:
			for q in [Rr, L]:
				for k in 3:
					var a: float = t * 1.1 + k * 2.094 + q.x * 0.01
					var x: float = q.x + cos(a) * 8.0
					var y: float = q.y - 36.0 + sin(a) * 3.0 - 6.0 + sin(t * 2.0 + k) * 2.0
					var h := 4 + (k % 2) * 2
					for j in h:
						var w := j if j < h / 2.0 else h - j
						for i in range(-w, w + 1):
							PixelDraw.npx(self, x + i, y - j, G[4] if i < 0 else G[2], o)
			for k in 6:
				var u := fmod(t * 0.4 + k / 6.0, 1.0)
				var src: Vector2 = L if k % 2 else Rr
				if sin(t * 5.0 + k) > -0.2:
					PixelDraw.npx(self, src.x + sin(k * 3.0 + t) * 10.0, src.y - 20.0 - u * 36.0, G[3], o)
