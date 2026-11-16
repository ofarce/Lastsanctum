extends Node2D
## Sceau équipé : « Ronde en cascade · Relais électrique ». Repère en pixels natifs,
## depuis les pieds ; l'orientation et la lévitation suivent le sprite de l'Ingénieur.

const ORBIT := 5.0
const RELAY := 2.4
const STEP := 0.24
const FLASH := 0.13
const SILVER := [Color("#202832"), Color("#465461"), Color("#6d7b88"), Color("#b5c1ca"), Color("#eff4f5")]
var view: UnitView


static func equipped(u: Unit) -> bool:
	return u.role == "engineer" and not u.is_enemy() and u.alive() and GameState.research_done.has("mining_artifact")


static func sphere(index: int, time: float) -> Vector2:
	var angle := -PI / 2.0 + time * TAU / ORBIT + index * TAU / 3.0
	return Vector2(-15.5 + cos(angle) * 4.5, -17.5 + sin(angle) * 9.5)


static func relay_pair(time: float) -> int:
	var phase := fposmod(time, RELAY)
	var pair := floori(phase / STEP)
	return pair if pair < 3 and fposmod(phase, STEP) < FLASH else -1


func tick(face: int, offset: Vector2, body_shown: bool) -> void:
	visible = equipped(view.unit) and body_shown
	position = offset
	scale = Vector2(face, 1)
	if visible:
		queue_redraw()


func _draw() -> void:
	var time := GameState.sim_time
	var points: Array[Vector2] = []
	for i in 3:
		points.append(sphere(i, time))
	var pair := relay_pair(time)
	if pair >= 0:
		var direction := (points[(pair + 1) % 3] - points[pair]).normalized()
		var start := points[pair] + direction * 2.25
		var end := points[(pair + 1) % 3] - direction * 2.25
		var normal := Vector2(-direction.y, direction.x)
		var previous := start.round()
		for k in range(1, 6):
			var wobble := sin(pair * 17.0 + k * 23.0 + floorf(time * 14.0) * 7.0) * 0.8 if k < 5 else 0.0
			var next := (start.lerp(end, k / 5.0) + normal * wobble).round()
			draw_line(previous, next, Color("#cce7f4"), 1.0, false)
			previous = next
	for point in points:
		var at := point.round()
		draw_circle(at, 2.5, SILVER[0])
		draw_circle(at, 1.8, SILVER[2])
		draw_rect(Rect2(at + Vector2(-1, -1), Vector2(2, 2)), SILVER[3])
		draw_rect(Rect2(at + Vector2(-1, -1), Vector2.ONE), SILVER[4])
		draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), SILVER[1])
