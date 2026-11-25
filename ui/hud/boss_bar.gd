class_name BossBar
extends Control
## Barre de vie du boss en haut de l'écran (Martyre de Byrsa, sim/martyre.gd) : nom en capitales au-dessus,
## grande barre rouge coupée en paliers (un par phase, Martyre.PHASE_HP), traînée claire qui rattrape les
## dégâts, phase en cours et PV à droite du nom. Visible tant qu'elle vit ; les bannières (SnesBanner)
## passent dessous (top()). Même barre pour l'Œil de la Matrice (sim/oeil.gd), pendant le combat singulier.

const TOP := SnesBanner.TOP
const MAX_W := 640.0
const NAME_H := 24.0
const BAR_H := 18.0
const HEIGHT := NAME_H + BAR_H + 4.0
const GAP := 4.0
const FADE := 0.6
const RED := Color("#d8261e")
const RED_LIGHT := Color("#ff6a4a")
const RED_DEEP := Color("#3a0808")
const TRAIL := Color("#f6d2a0")
const FRAME := Color("#0a0c26")
const RIM := Color("#e6c889")

var _trail := 1.0
var _shown_at := INF


## Haut des bannières de texte : sous la barre quand elle est affichée.
static func top() -> float:
	return TOP + HEIGHT + 10.0 if _boss() != null else TOP


## Boss affiché : la Martyre tant qu'elle vit, sinon l'Œil de la Matrice en duel.
static func _boss() -> Enemy:
	if Martyre.active():
		return GameState.martyre
	if OeilMatrice.active() and GameState.oeil_state == "duel":
		return GameState.oeil
	if Gorge.active():
		return Gorge.boss()
	if Archipretre.active():
		return Archipretre.boss()
	if Eclusier.active():
		return Eclusier.boss()
	if Patine.active():
		return Patine.boss()
	return null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "BossBar"


func _process(delta: float) -> void:
	var on := _boss() != null
	if on and not visible:
		_trail = 1.0
		_shown_at = GameState.sim_time
	visible = on
	if not on:
		return
	var e: Enemy = _boss()
	var f := clampf(e.hp / maxf(1.0, e.max_hp), 0.0, 1.0)
	# La traînée attend un instant puis rattrape la vie restante.
	_trail = maxf(f, _trail - delta * 0.35) if _trail > f else f
	var s := get_viewport_rect().size
	var w := minf(MAX_W, s.x - 32.0)
	size = Vector2(w, HEIGHT)
	position = Vector2(roundf((s.x - w) / 2.0), TOP)
	modulate.a = clampf((GameState.sim_time - _shown_at) / FADE, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var e: Enemy = _boss()
	if e == null:
		return
	var eye := e.kind == OeilMatrice.KIND
	var font := HudStyle.font()
	var w := size.x
	var f := clampf(e.hp / maxf(1.0, e.max_hp), 0.0, 1.0)
	var gorge := e.kind == Gorge.KIND
	var priest := e.kind == Archipretre.KIND
	var lock := e.kind == Eclusier.KIND
	var patina := e.kind == Patine.KIND
	var title := "GORGE-CUIVRE" if gorge else "ARCHIPRÊTRE AUX RACINES" if priest else "ŒIL DE LA MATRICE" if eye \
		else "ÉCLUSIER DE BYRSA" if lock else "MARTYRE DE LA PATINE" if patina else "MARTYRE DE BYRSA"
	var phase := "Phase %s" % (Gorge.PHASE_NAMES[Gorge.phase_of(e)] if gorge else Archipretre.PHASE_NAMES[Archipretre.phase_of(e)] if priest \
		else Eclusier.PHASE_NAMES[Eclusier.phase_of(e)] if lock else Patine.PHASE_NAMES[int(Patine.run().get("phase", 0))] if patina \
		else OeilMatrice.PHASE_NAMES[int(OeilMatrice.run().get("phase", 0))] if eye \
		else Martyre.PHASE_NAMES[mini(GameState.martyre_phase, Martyre.PHASE_NAMES.size() - 1)])
	var hp := "%d / %d" % [ceili(e.hp), roundi(e.max_hp)]
	# Nom au centre, ombré ; phase à gauche, PV à droite.
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var base := NAME_H - 6.0
	draw_string(font, Vector2(roundf((w - tw) / 2.0) + 2.0, base + 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(roundf((w - tw) / 2.0), base), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, RIM)
	draw_string(font, Vector2(2.0, base), phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.IVORY)
	var hw := font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(w - hw - 2.0, base), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.IVORY)
	# Barre : cadre sombre, liseré d'or, paliers séparés par un jour.
	var bar := Rect2(0.0, NAME_H, w, BAR_H)
	draw_rect(Rect2(bar.position + Vector2(3, 3), bar.size), Color(0, 0, 0, 0.35))
	draw_rect(bar, FRAME)
	draw_rect(bar.grow(-1.0), RIM, false, 1.0)
	var inner := bar.grow(-3.0)
	# Bornes des paliers, de gauche (0) à droite (1) : 0, 1/3, 2/3, 1.
	var cuts: Array[float] = [0.0, 1.0]
	for t: float in Martyre.PHASE_HP:
		cuts.append(t)
	cuts.sort()
	for i in cuts.size() - 1:
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		var x0 := inner.position.x + inner.size.x * a + (GAP / 2.0 if i > 0 else 0.0)
		var x1 := inner.position.x + inner.size.x * b - (GAP / 2.0 if i < cuts.size() - 2 else 0.0)
		var seg := Rect2(x0, inner.position.y, x1 - x0, inner.size.y)
		draw_rect(seg, RED_DEEP)
		var tr := clampf((_trail - a) / (b - a), 0.0, 1.0)
		if tr > 0.0:
			draw_rect(Rect2(seg.position, Vector2(seg.size.x * tr, seg.size.y)), TRAIL)
		var fill := clampf((f - a) / (b - a), 0.0, 1.0)
		if fill > 0.0:
			var r := Rect2(seg.position, Vector2(roundf(seg.size.x * fill), seg.size.y))
			draw_rect(r, RED)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), RED_LIGHT)
			draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 3.0), Vector2(r.size.x, 3.0)), Color(0.45, 0.04, 0.03))
	# Garde de la Martyre : WARD_MAX losanges d'or sous la barre, celui qui se recharge se remplit.
	if e.kind == Martyre.KIND:
		var ward := GameState.martyre_ward
		for i in Martyre.WARD_MAX:
			var c := Vector2(w / 2.0 + (i - (Martyre.WARD_MAX - 1) / 2.0) * 18.0, bar.end.y + 7.0)
			var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
			draw_colored_polygon(pts, FRAME)
			var k := clampf(ward - i, 0.0, 1.0)
			if k > 0.0:
				var r := 4.0 * k if k < 1.0 else 4.0
				var q := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
				draw_colored_polygon(q, RIM if k >= 1.0 else Color(RIM, 0.5))
			draw_polyline(pts + PackedVector2Array([pts[0]]), RIM, 1.0)
	# Bouclier qui se resserre (phase III) : liseré qui rougeoie.
	if not eye and GameState.sim_time - GameState.martyre_shrink_at < Martyre.SHRINK:
		var g := 0.5 + 0.5 * sin(GameState.sim_time * 18.0)
		draw_rect(bar.grow(-1.0), Color(RED_LIGHT, 0.4 + 0.5 * g), false, 1.0)
