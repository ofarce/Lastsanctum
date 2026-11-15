class_name PixelDraw
## Outils de dessin « pixel par pixel » du prototype (npx, plotPath, smoothArc ; Index.html, 73b410f).
## Les coordonnées sont des pixels natifs ; npx arrondit avec Math.round (floor(v + 0,5)).

## Écart voulu D15 (charte graphique) : éclairs noirs ourlés de pourpre autour de l'Ancre noire.
const ORB_ARC := {
	"core": Color("#e0a0ff"), "hot": Color("#08000e"), "mid": Color("#12041c"),
	"cold": Color("#24082e"), "glow": Color("#8a32a8"),
}


static func jround(v: float) -> float:
	return floorf(v + 0.5)


## npx(x, y, c) : un pixel natif. `origin` est l'écart entre le repère de calcul et celui du nœud.
static func npx(ci: CanvasItem, x: float, y: float, c: Color, origin := Vector2.ZERO) -> void:
	ci.draw_rect(Rect2(Vector2(jround(x), jround(y)) - origin, Vector2.ONE), c)


## plotPath : segments tracés point par point (épaissi d'un pixel à droite si `thick`).
static func plot_path(ci: CanvasItem, pts: PackedVector2Array, c: Color, thick: bool, origin := Vector2.ZERO) -> void:
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var n := maxi(1, ceili(sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))))
		for t in n + 1:
			var x := a.x + (b.x - a.x) * t / n
			var y := a.y + (b.y - a.y) * t / n
			npx(ci, x, y, c, origin)
			if thick:
				npx(ci, x + 1.0, y, c, origin)


## smoothArc : arc qui ondule selon un bruit continu dans le temps (14 segments).
static func smooth_arc(i: int, x0: float, y0: float, x1: float, y1: float, t: float, amp: float) -> PackedVector2Array:
	const N := 14
	var dx := x1 - x0
	var dy := y1 - y0
	var l := sqrt(dx * dx + dy * dy)
	if l == 0.0:
		l = 1.0
	var nx := -dy / l
	var ny := dx / l
	var pts := PackedVector2Array()
	for j in N + 1:
		var u := float(j) / N
		var env := sin(u * PI)
		var o := ((Rng.vnoise(j * 0.55 + i * 17, t * 3.2, 7) - 0.5) * 1.4 + (Rng.vnoise(j * 1.4 + i * 5, t * 6.5, 9) - 0.5) * 0.6) * amp * env
		pts.append(Vector2(x0 + dx * u + nx * o, y0 + dy * u + ny * o))
	return pts
