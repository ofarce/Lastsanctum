class_name ArchipretreMarks
extends Node2D
## Au sol de l'arène de l'Archiprêtre (sim/archipretre.gd), en pixels natifs : la nappe (disque tramé qui respire,
## violacé), les quatre places de prière (cadre et pastille à la couleur du culte, pleins quand un esprit y prie) ;
## par-dessus les sprites (`air`), les racines annoncées : ligne pointillée qui se remplit jusqu'à l'impact.

## Couleurs des cultes (world_overlay.gd, BEAM_CULT).
const CULT := {"aether": Color8(122, 134, 255), "indra": Color8(255, 154, 58), "medeina": Color8(111, 224, 122), "sigil": Color8(216, 212, 202)}
const NAPPE := Color(0.42, 0.14, 0.24, 0.32)
const NAPPE_EDGE := Color(0.82, 0.25, 0.30, 0.55)
const ROOT := Color("#c8a078")

var world: World
## Faux : calque au sol (nappe, places) ; vrai : calque des annonces (racines).
var air := false


func _process(_delta: float) -> void:
	var r := Archipretre.run()
	visible = Archipretre.boss() != null and String(r.get("mode", "sleep")) not in ["sleep", "dead"]
	if visible:
		queue_redraw()


func _draw() -> void:
	var r := Archipretre.run()
	var now := GameState.sim_time
	if air:
		_draw_roots(r, now)
		return
	var c := Archipretre.center()
	if world != null and not world.fog.visible_at(c):
		return
	var rad := float(r.get("nappe", 0.0))
	if rad > 0.5:
		# Disque tramé (une case sur deux, damier qui glisse), liseré pointillé.
		var step := 4
		var o := int(now * 4.0) % 2
		var lo := _nat(c.x - rad, c.y - rad)
		var hi := _nat(c.x + rad, c.y + rad)
		for py in range(int(lo.y), int(hi.y), step):
			@warning_ignore("integer_division")
			var shift := ((py / step + o) % 2) * step
			for pxx in range(int(lo.x) + shift, int(hi.x), step * 2):
				# Au sol (y = 0), un pixel natif vaut 1 / K unité sur chaque axe.
				if Vector2(pxx / Proj.K, py / Proj.K).distance_to(c) <= rad:
					draw_rect(Rect2(Vector2(pxx, py), Vector2(step, step)), NAPPE)
		for i in 64:
			if (i + int(now * 6.0)) % 3 == 0:
				continue
			var a := TAU * i / 64.0
			draw_rect(Rect2(_nat(c.x + cos(a) * rad, c.y + sin(a) * rad).round(), Vector2.ONE * 2.0), NAPPE_EDGE)
	var held := Archipretre.held_cults()
	for cult: String in r.get("places", {}):
		var at: Vector2 = r["places"][cult]
		var p := _nat(at.x, at.y).round()
		var col: Color = CULT[cult]
		var on := held.has(cult)
		var pulse := 0.5 + 0.5 * sin(now * 3.0 + p.x)
		var a := 0.9 if on else 0.35 + 0.25 * pulse
		var half := Archipretre.PLACE_R * Proj.K * 0.7
		draw_rect(Rect2(p - Vector2(half, half * 0.6), Vector2(half * 2.0, half * 1.2)), Color(col, a), false, 2.0)
		draw_circle(p, 4.0 if on else 3.0, Color(col, a))


func _draw_roots(r: Dictionary, now: float) -> void:
	for m: Dictionary in r.get("roots", []):
		var a: Vector2 = m["a"]
		var b: Vector2 = m["b"]
		var k := clampf((now - float(m["from"])) / maxf(0.01, float(m["at"]) - float(m["from"])), 0.0, 1.0)
		var n := maxi(2, int(a.distance_to(b) * 2.0))
		var side := (b - a).normalized().orthogonal() * float(Archipretre.ROOT["width"])
		for i in n:
			var t := float(i) / n
			var q := a.lerp(b, t)
			if world != null and not world.fog.visible_at(q):
				continue
			# Bords pointillés qui défilent ; le cœur se remplit depuis l'autel jusqu'à l'impact.
			if (i + int(now * 10.0)) % 2 == 0:
				for s: float in [-1.0, 1.0]:
					draw_rect(Rect2(_nat(q.x + side.x * s, q.y + side.y * s).round(), Vector2.ONE * 2.0), Color(ROOT, 0.9))
			if t <= k:
				draw_rect(Rect2(_nat(q.x, q.y).round() - Vector2.ONE, Vector2.ONE * 3.0), Color(ROOT, 0.45 + 0.5 * k))


static func _nat(x: float, z: float) -> Vector2:
	return Proj.nat(x, 0.0, z)
