class_name PixelDraw
## Outils de dessin « pixel par pixel » du prototype (npx, plotPath, smoothArc ; Index.html, 73b410f).
## Les coordonnées sont des pixels natifs ; npx arrondit avec Math.round (floor(v + 0,5)).

## Écart voulu D16 (charte graphique) : éclairs noirs ourlés de pourpre autour de l'Ancre noire.
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
## npx développé sur place (un appel de moins par pixel) : mêmes rectangles, dans le même ordre.
static func plot_path(ci: CanvasItem, pts: PackedVector2Array, c: Color, thick: bool, origin := Vector2.ZERO) -> void:
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var n := maxi(1, ceili(sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))))
		for t in n + 1:
			var x := a.x + (b.x - a.x) * t / n
			var y := a.y + (b.y - a.y) * t / n
			ci.draw_rect(Rect2(Vector2(floorf(x + 0.5), floorf(y + 0.5)) - origin, Vector2.ONE), c)
			if thick:
				ci.draw_rect(Rect2(Vector2(floorf(x + 1.0 + 0.5), floorf(y + 0.5)) - origin, Vector2.ONE), c)


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
		var o := ((vnoise_cached(j * 0.55 + i * 17, t * 3.2, 7) - 0.5) * 1.4 + (vnoise_cached(j * 1.4 + i * 5, t * 6.5, 9) - 0.5) * 0.6) * amp * env
		pts.append(Vector2(x0 + dx * u + nx * o, y0 + dy * u + ny * o))
	return pts


## Coins du réseau de Rng.vnoise déjà calculés ([a, b, c, d] en flottants 64 bits), par (xi, yi, s). Les arcs
## évaluent toujours les mêmes nœuds entiers (y = temps × 3,2 ou 6,5 : quelques nœuds par seconde) : sans ce
## cache, 700 Rng.hash3 par image pour les arcs de l'Ancre. Vidé au-delà de VNOISE_CACHE_MAX entrées.
const VNOISE_CACHE_MAX := 4096
static var _vnoise_corners := {}


## Rng.vnoise avec ses quatre coins mémorisés : même formule, même résultat au bit près (tests/test_rng_hash.gd).
static func vnoise_cached(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var key := Vector3i(xi, yi, s)
	var k: Array = _vnoise_corners.get(key, [])
	if k.is_empty():
		if _vnoise_corners.size() >= VNOISE_CACHE_MAX:
			_vnoise_corners.clear()
		k = [Rng.hash3(xi, yi, s), Rng.hash3(xi + 1, yi, s), Rng.hash3(xi, yi + 1, s), Rng.hash3(xi + 1, yi + 1, s)]
		_vnoise_corners[key] = k
	var a: float = k[0]
	var b: float = k[1]
	var c: float = k[2]
	var d: float = k[3]
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
