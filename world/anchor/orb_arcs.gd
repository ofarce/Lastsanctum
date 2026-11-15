class_name OrbArcs
extends Node2D
## Arcs électriques de l'Ancre (drawOrbArcs, Index.html, 73b410f). Enfant du sprite de l'orbe : son
## origine est la position continue (non arrondie) de l'orbe, comme ctx.translate(nx·PX, ny·PX).
## Visibles quand l'Ancre est active ; pendant la réactivation, ils crépitent de plus en plus souvent.

const ORB_TIME := 8.0

## Six cycles d'arcs indépendants (ORB_SLOTS).
var _slots: Array[Dictionary] = []


func _init() -> void:
	for i in 6:
		_slots.append({
			"base": i * 1.047 + (i % 2) * 0.4,
			"period": 0.9 + fmod(i * 0.37, 0.8),
			"off": i * 0.29,
			"spin": (1.0 if i % 2 else -1.0) * (0.35 + (i % 3) * 0.15),
			"span": 0.7 + (i % 3) * 0.45,
			"out": i % 3 == 2,
		})


func _process(_delta: float) -> void:
	queue_redraw()


func visible_now() -> bool:
	var t := GameState.sim_time
	return GameState.orb_active or (GameState.orb_progress > 0.0 and sin(t * 23.0) > 1.0 - GameState.orb_progress / ORB_TIME * 1.4)


func _draw() -> void:
	if visible_now():
		draw_arcs(0.0, -8.0 - Overload.sphere_lift())


func draw_arcs(cx: float, cy: float) -> void:
	var c := PixelDraw.ORB_ARC
	var r := 10.5
	var t := GameState.sim_time
	for i in _slots.size():
		var S: Dictionary = _slots[i]
		var ph := fmod((t + S["off"]) / S["period"], 1.0)
		var life := sin(ph * PI)
		if life < 0.12:
			continue
		var a0: float = S["base"] + t * S["spin"] + floorf((t + S["off"]) / S["period"]) * 2.1
		var pts: PackedVector2Array
		if not S["out"]:
			var a1: float = a0 + S["span"]
			var mid := (a0 + a1) / 2.0
			var lift := 5.0 + life * 6.0
			pts = PixelDraw.smooth_arc(i, cx + cos(a0) * r, cy + sin(a0) * r * 0.95, cx + cos(a1) * r, cy + sin(a1) * r * 0.95, t, 4.8)
			for j in pts.size():
				var b := sin(float(j) / (pts.size() - 1) * PI) * lift
				pts[j] = Vector2(pts[j].x + cos(mid) * b, pts[j].y + sin(mid) * b)
		else:
			var len := 10.0 + life * 18.0
			var a1 := a0 + sin(t * 1.3 + i) * 0.35
			pts = PixelDraw.smooth_arc(i, cx + cos(a0) * r, cy + sin(a0) * r, cx + cos(a1) * (r + len), cy + sin(a1) * (r + len), t, 4.4)
		var col: Color = c["hot"] if life > 0.75 else c["mid"] if life > 0.4 else c["cold"]
		if life > 0.3:
			PixelDraw.plot_path(self, pts, c["glow"], true)
		PixelDraw.plot_path(self, pts, col, false)
		if life > 0.85:
			PixelDraw.npx(self, pts[7].x, pts[7].y, c["core"])
		PixelDraw.npx(self, cx + cos(a0) * r, cy + sin(a0) * r, c["core"] if life > 0.5 else c["hot"])
		# Rameau qui pousse puis se rétracte avec la vie de l'arc.
		if i % 2 == 0 and life > 0.45:
			var p := pts[5]
			var ang := a0 + 1.2 + sin(t * 2.0 + i)
			var l := 2.0 + (life - 0.45) * 18.0
			PixelDraw.plot_path(self, PixelDraw.smooth_arc(i + 40, p.x, p.y, p.x + cos(ang) * l, p.y + sin(ang) * l, t, 1.2), c["cold"], false)
	# Étincelles en orbite lente autour de la sphère.
	for k in 6:
		var a := k * 1.047 + t * (0.9 if k % 2 else -0.6)
		var d := r + 6.0 + sin(t * 2.3 + k * 1.7) * 6.0
		var tw := sin(t * 7.0 + k * 2.1)
		if tw > 0.1:
			PixelDraw.npx(self, cx + cos(a) * d, cy + sin(a) * d * 0.9, c["hot"] if tw > 0.7 else c["cold"])
