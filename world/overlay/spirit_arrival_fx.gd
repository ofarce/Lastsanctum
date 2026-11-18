class_name SpiritArrivalFx
extends Node2D
## Arrivée d'un esprit à l'autel, « Germe de l'autel » (planches/esprits-v3-propositions.html, durée
## Simulation.ARRIVAL = 10 s) : une graine de lumière grossit au cœur de la statue par paliers (toutes les
## 2,5 s) dans un anneau de 20 points qui s'allument un à un (compte à rebours) ; à 8,5 s elle se détache et
## glisse en arc jusqu'au pied de l'autel, où l'esprit se déplie (AdeptView : silhouette unie puis trame).
## Repère : pixels natifs du monde, au-dessus des sprites.

## Cœur de la statue des autels (art da-<dieu>, scale 1) par rapport au point d'ancrage du bâtiment.
const STATUE := Vector2(0, -32)
const RING := 11.0
const DOTS := 20
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const WHITE := Color("#ffffff")

var world: World


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for u: Unit in GameState.units:
		if u.arrival_end <= 0.0 or u.arrival_temple == null or not u.alive():
			continue
		var b: Building = u.arrival_temple
		var el := Simulation.ARRIVAL - (u.arrival_end - GameState.sim_time)
		_germ(Proj.nat(b.x, 0.0, b.z) + STATUE, Proj.nat(u.x, 0.0, u.z) + Vector2(0, -16), el,
			Catalog.DEITY_GLOW.get(u.role, WHITE))


func _germ(c: Vector2, to: Vector2, el: float, col: Color) -> void:
	var dk := col.darkened(0.6)
	var lit := floori(minf(el, Simulation.ARRIVAL) / Simulation.ARRIVAL * DOTS)
	for i in DOTS:
		var a := -PI / 2.0 + TAU * i / DOTS
		# Points allumés éclaircis : ils doivent se lire sur la statue de la même couleur.
		_px(c + Vector2(cos(a), sin(a)) * RING, col.lerp(WHITE, 0.45) if i < lit else dk)
	if el < 8.5:
		var r := 2 + floori(el / 2.5)
		for y in range(-r - 3, r + 4):
			for x in range(-r - 3, r + 4):
				var d := Vector2(x, y).length()
				if d > r and d <= r + 3 and BAYER[(y + 64) & 3][(x + 64) & 3] / 16.0 < 0.35:
					_px(c + Vector2(x, y), dk)
		var pulse := sin(el * TAU * (0.6 + el * 0.12)) > 0.0
		_disc(c, r, col if pulse else col.lerp(WHITE, 0.3))
		if r > 2:
			_disc(c, r - 2, WHITE)
		_px(c, WHITE)
	elif el < 9.2:
		var v := (el - 8.5) / 0.7
		for i in 6:
			var w := maxf(0.0, v - i * 0.05)
			var p := c.lerp(to, w) - Vector2(0, sin(w * PI) * 14.0)
			if i == 0:
				_disc(p, 3, col)
				_px(p, WHITE)
			else:
				_px(p, col if i < 3 else dk)
	elif el < 9.5:
		var rr := 4.0 + (el - 9.2) * 40.0
		for k in 16:
			var a := TAU * k / 16.0
			_px(to + Vector2(cos(a) * rr, sin(a) * rr * 0.7), col)


func _px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.round(), Vector2.ONE), c)


func _disc(p: Vector2, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + r * 0.8:
				_px(p + Vector2(x, y), c)
