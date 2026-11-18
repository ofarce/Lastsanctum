class_name WorldOverlay
extends Node2D
## Surimpression du monde à la résolution de l'écran, dessinée dans le canvas du jeu comme dans le prototype
## (donc sous le calque d'éclairage et sous le HUD) :
##  - libellés des bâtiments (nom, progression, entraînement, âmes, prière) — drawBuilding ;
##  - effets de combat et carreaux des balistes — drawEffects, drawTurretBolts (EffectsDrawer) ;
##  - Énonciation : miroir de l'Ancre et bulle d'incantation au-dessus de l'Ingénieur — drawTempleOverlays ;
##  - mode construction : cases libres et empreinte sous le pointeur — drawBuildCells, drawBuildPreview ;
##  - popups « +5 » de prière — drawPrayFeedback ;
##  - anneau de l'Ancre sélectionnée et libellé de l'Ancre — fin de draw() (Index.html, 73b410f).
## Le nœud annule la transformation du monde : son repère local est celui de l'écran.

## Palette du miroir (TempleIncantation, O).
const O: Array[Color] = [Color("#120a22"), Color("#24164a"), Color("#3c2a78"), Color("#5c46aa"), Color("#8a72d8"), Color("#c4b2ff"), Color("#efe6ff")]
const HAND := Vector2(7, -15)
## Formules d'incantation : vers récités pendant le chantier, puis mot de clôture.
const FORMULAS := {
	"templeJob": {"verses": ["Ka·ren·thal", "Vos·me·dri", "Aun·tir·ae", "Sel·va·rün", "Ix·or·tha"], "end": "Thal·de·mor !"},
	"sawmillJob": {"verses": ["Me·dei·nar", "Sil·va·ruun", "Ar·bo·thel", "Ve·rid·aa", "Lu·nem·or"], "end": "Ruun·sil·va !"},
	"foundryJob": {"verses": ["Ae·ther·ka", "Fer·ro·dun", "Ig·nar·oth", "Kal·mo·rak", "Dur·ae·tha"], "end": "Ig·nar·dun !"},
	"barracksJob": {"verses": ["In·dra·vel", "Tor·ra·kan", "Vaj·rü·na", "Ka·ru·dra", "Sha·nam·or"], "end": "Vaj·ra·kan !"},
	"turretJob": {"verses": ["Ty·rel·os", "Ba·lis·tar", "Ar·kon·ve", "Tel·mo·rae", "Sa·gi·thar"], "end": "Ty·ra·los !"},
}
## Vers de chaque bâtiment (BUILDINGS[].verse, buildings.js).
const VERSE_OF := {"sigil": "templeJob", "aether": "foundryJob", "medeina": "sawmillJob", "indra": "barracksJob",
	"warehouse": "templeJob", "library": "templeJob", "forge": "foundryJob", "workshop": "foundryJob", "creuset": "foundryJob", "bedroom": "sawmillJob", "soulwell": "sawmillJob",
	"caserne": "barracksJob"}

var world: World
var _bold: FontVariation
var _speech_font: FontVariation
var _georgia_bold: FontVariation
var _cells_key := ""
var _cells_free := PackedVector2Array()
var _cells_busy := PackedVector2Array()
var _fp_valid: Texture2D
var _fp_invalid: Texture2D
var _fp_meta: Dictionary
var _effects := EffectsDrawer.new()
## Textes affichés (faux : comme ctx.fillText neutralisé par le scénario « text » du baker).
var show_text := true


func _ready() -> void:
	var dejavu: FontFile = load("res://assets/fonts/DejaVuSans.ttf")
	_bold = FontVariation.new()
	_bold.base_font = dejavu
	_bold.variation_embolden = 0.7
	_speech_font = FontVariation.new()
	_speech_font.base_font = dejavu
	_speech_font.variation_embolden = 0.8
	_georgia_bold = FontVariation.new()
	_georgia_bold.base_font = HudStyle.font()
	_georgia_bold.variation_embolden = 0.8
	_fp_valid = load("res://assets/baked/overlay/footprint_valid.png")
	_fp_invalid = load("res://assets/baked/overlay/footprint_invalid.png")
	_fp_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["overlay"]["footprints"]


func _process(_delta: float) -> void:
	var px := float(world.camera.px)
	scale = Vector2(1.0 / px, 1.0 / px)
	position = -world.position / px
	queue_redraw()


func _cam() -> WorldCamera:
	return world.camera


func _z() -> float:
	return 8.0 * _cam().px / 0.86


func _project(x: float, y: float, z: float) -> Vector2:
	return _cam().project(x, y, z)


## Position native (monde) → écran.
func _screen(native: Vector2) -> Vector2:
	return (native + world.native_offset) * _cam().px


func _draw() -> void:
	if world == null or world.terrain_state == null:
		return
	_draw_building_labels()
	_effects.ci = self
	_effects.world = world
	_effects.draw_all(GameState.sim_time)
	_draw_temple_overlays()
	_draw_build_cells()
	_draw_build_preview()
	_draw_pray_feedback()
	_draw_anchor()
	var b := HudModel.selected_building()
	if b and b.rally_point != null:
		var p := _project(b.rally_point.x, 0, b.rally_point.y)
		draw_line(p, p + Vector2(0, -22), Color("#ffe095"), 2)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -22), p + Vector2(14, -17), p + Vector2(0, -12)]), Color("#5ce8ff"))


# ---------------------------------------------------------------- Bâtiments

func _text_c(font: Font, p: Vector2, text: String, size: int, c: Color) -> void:
	if not show_text:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(p.x - w / 2.0, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _draw_building_labels() -> void:
	var kk := float(_cam().px)
	for b in GameState.buildings:
		var D := b.def()
		var p := _project(b.x, 0.0, b.z)
		var y := p.y + b.half() * kk * 7.3
		var name := String(D["name"]).to_upper()
		if GameState.hud_building == b:
			_text_c(_bold, Vector2(p.x, y), name if b.complete else "%s · %d %%" % [name, floori(b.progress / D["time"] * 100.0)], 10, Color("#ead6a5"))
		if not b.complete:
			continue
		var jobs := building_jobs(b)
		var view := world.building_view(b)
		var roof := view.top_offset if view else -100.0
		for i in range(jobs.size()):
			# Au-dessus du sommet du sprite, à la résolution écran.
			var top := _project(b.x, 0.0, b.z) - Vector2(0, -roof * kk + 18.0)
			_draw_job(top + Vector2((i - (jobs.size() - 1) * 0.5) * 84, 0), jobs[i])
		if b.type == "soulwell" and not GameState.fallen.is_empty():
			var n := GameState.fallen.size()
			_text_c(_bold, Vector2(p.x, y + 13.0), "%d ÂME%s EN ATTENTE" % [n, "S" if n > 1 else ""], 10, Color("#9be27a"))
		if b.is_temple():
			var n := 0
			var rate := 0
			for u in GameState.units:
				if u.alive() and u.working and u.job != null and u.job["type"] == "pray" and u.job["temple"] == b:
					n += 1
					rate += Simulation.pray_rate(u)
			if n:
				_text_c(_bold, Vector2(p.x, y + 13.0), "%d EN PRIÈRE · +%d %s / s" % [n, rate, String(Catalog.RES_INFO[Catalog.DEITY_RES[D["deity"]]]["name"]).to_upper()], 10, Color("#bfe8ff"))


## drawPrayFeedback : « +5 Savoir » qui monte et s'efface au-dessus du temple.
func _draw_pray_feedback() -> void:
	var s := _z() / 16.0
	for p in GameState.pray_popups:
		var a: float = GameState.sim_time - p["at"]
		var alpha := a / 0.3 if a < 0.3 else (1.0 if a < 1.3 else maxf(0.0, 1.0 - (a - 1.3) / 0.5))
		var q := _project(p["x"], 0.0, p["z"])
		var at := Vector2(q.x, q.y - (90.0 + 20.0 * minf(1.0, a / 0.6)) * s)
		draw_set_transform(at, 0.0, Vector2(s, s))
		_text_c(_georgia_bold, Vector2.ZERO, "+%d %s" % [p["amount"], Catalog.RES_INFO[p["res"]]["name"]], 16, Color(Color("#f8e5b7"), alpha))
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- Énonciation (drawTempleOverlays)

## incantationSites : chantiers et Ancre (les balistes s'ajoutent à l'étape 8).
func _sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in GameState.buildings:
		var view := world.building_view(b)
		out.append({"owner": b.owner, "complete": b.complete, "progress": b.progress, "dur": float(b.def()["time"]),
			"at": b.spot, "tol": 0.5, "finished": b.finished_at, "verse": VERSE_OF[b.type],
			"job_ok": b.owner != null and b.owner.build_job == b, "stones": view.stones if view else []})
	out.append({"owner": GameState.orb_owner, "complete": GameState.orb_active, "progress": GameState.orb_progress,
		"dur": Simulation.ORB_TIME, "at": Simulation.ORB_SPOT, "tol": 0.6, "finished": GameState.orb_finished_at,
		"verse": "turretJob", "job_ok": GameState.orb_owner != null and GameState.orb_owner.orb_job, "stones": []})
	return out


func _draw_temple_overlays() -> void:
	var k := float(_cam().px)
	var t := GameState.sim_time
	for c in _sites():
		var u: Unit = c["owner"]
		if u == null:
			continue
		var at: Vector2 = c["at"]
		var fin: float = t - c["finished"] if c["complete"] and not is_inf(c["finished"]) else INF
		var active: bool = not c["complete"] and c["progress"] > 0.0 and c["job_ok"] and Vector2(u.x - at.x, u.z - at.y).length() <= c["tol"]
		if not active and not fin < 2.4:
			continue
		var n := Proj.nat(u.x, 0.0, u.z)
		# natP : position native à l'écran arrondie (Math.round), puis ×PX.
		var foot := Vector2(floorf(n.x + world.native_offset.x + 0.5), floorf(n.y + world.native_offset.y + 0.5)) * k
		var view: Variant = world.unit_view(u)
		var face: int = view._face if view else 1
		var act := minf(1.0, c["progress"] / 0.8) if active else 0.0
		var stones: Array = c["stones"] if active else []
		_draw_mirror(foot, k, t, act, stones, fin, face)
		_draw_speech(foot.x, foot.y - 58.0 * k, k, verse(1.0 if c["complete"] else c["progress"] / c["dur"], fin, c["verse"]), t)


static func verse(progress: float, since: float, kind: String) -> String:
	var F: Dictionary = FORMULAS.get(kind, FORMULAS["templeJob"])
	var V: Array = F["verses"]
	if progress >= 1.0:
		return F["end"] if since < 2.4 else ""
	var n := V.size()
	var i := mini(n - 1, floori(progress * n))
	var u := progress * n - i
	var line: String = V[i]
	var cut := line.left(ceili(line.length() * clampf(u * 1.7, 0.0, 1.0)))
	return cut if cut else "…"


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x + 0.5), floorf(y + 0.5), w, h), c)


func _ring(cx: float, cy: float, rx: float, ry: float, c: Color, n: int, rot := 0.0, dash := 0) -> void:
	for i in n:
		if dash and i % dash == 0:
			continue
		var a := float(i) / n * 6.2832 + rot
		_r(cx + cos(a) * rx, cy + sin(a) * ry, 1, 1, c)


func _disc(cx: float, cy: float, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		var w := floori(sqrt(r * r - y * y + 0.5))
		_r(cx - w, cy + y, w * 2 + 1, 1, c)


static func _hs(n: float) -> float:
	return BuildingView.hs(n)


## drawMirror : sphère noire, bulles et éclairs violets au-dessus de l'Ingénieur agenouillé ; onde finale.
## Repère : 120×110 pixels natifs, pieds de l'Ingénieur en (60, 90), mis à l'échelle k (nearest).
func _draw_mirror(foot: Vector2, k: float, t: float, act: float, targets: Array, fin: float, face: int) -> void:
	if act <= 0.0 and fin > 0.6:
		return
	var ox0 := 60.0
	var oy0 := 90.0
	var hx := ox0 + HAND.x * face
	var hy := oy0 + HAND.y
	var ox := hx - 6.0 * face
	var oy := hy - 26.0 + sin(t * 2.0) * 1.5
	var x0 := foot.x - ox0 * k
	var y0 := foot.y - oy0 * k
	draw_set_transform(Vector2(x0, y0), 0.0, Vector2(k, k))
	if act > 0.0:
		var A := func(c: Color, a: float) -> Color: return Color(c, c.a * a)
		_r(hx, hy, 1, 1, A.call(O[6], act))
		_ring(ox, oy, 8, 3, A.call(O[4], act), 40, t * 2.0, 4)
		_disc(ox, oy, 4, A.call(Color("#07060c"), act))
		_r(ox - 2, oy - 2, 1, 1, A.call(O[5], act))
		_ring(ox, oy, 5, 5, A.call(O[3], act), 30)
		var pos := _bubbles(t, ox, oy + 30.0, 18.0, 8, act, 91)
		for b: Vector3 in pos:
			if b.z > 0.5:
				var w := (b.z - 0.5) / 0.5
				_r(lerpf(b.x, ox, w), lerpf(b.y, oy, w), 1, 1, A.call(O[5], act))
	if fin < 0.6:
		_ring(ox, oy, 4.0 + fin * 90.0, (4.0 + fin * 90.0) * 0.35, Color(O[5], 1.0 - fin / 0.6), 120)
	draw_set_transform(Vector2.ZERO)
	# Éclairs vers les pierres en vol, à l'écran.
	var f := floori(t * 6.0)
	if act > 0.0 and not targets.is_empty() and _hs(f) > 0.45:
		var m: Vector2 = _screen(targets[f % targets.size()])
		var sx := x0 + ox * k
		var sy := y0 + oy * k
		var px := sx
		var py := sy
		var col := Color(O[5], act)
		for i in range(1, 6):
			var u := i / 5.0
			var j := (_hs(f * 3 + i) * 2.0 - 1.0) * 4.0 * k if i < 5 else 0.0
			var nx := lerpf(sx, m.x, u) + j
			var ny := lerpf(sy, m.y, u) + j * 0.5
			var n := ceili(Vector2(nx - px, ny - py).length() / k)
			for s in n + 1:
				var q := float(s) / n if n > 0 else 0.0
				draw_rect(Rect2(roundf(lerpf(px, nx, q)), roundf(lerpf(py, ny, q)), maxf(1.0, k), maxf(1.0, k)), col)
			px = nx
			py = ny


## bubbles : bulles qui montent vers le miroir ; renvoie (x, y, phase).
func _bubbles(t: float, cx: float, cy: float, spread: float, n: int, inten: float, seed: int) -> Array[Vector3]:
	var pos: Array[Vector3] = []
	for i in n:
		var life := 2.2 + _hs(seed + i) * 1.6
		var q := (t + _hs(seed + i * 3) * life) / life
		var ph := fmod(q, 1.0)
		var cyc := floori(q)
		var x := cx + (_hs(seed + i * 7 + cyc) * 2.0 - 1.0) * spread + sin(ph * 9.0 + i) * 2.0
		var y := cy - ph * (38.0 + _hs(seed + i * 5) * 26.0)
		var r := 1 if ph < 0.1 or ph > 0.9 else (3 if _hs(seed + i) > 0.6 else 2)
		var a := inten * minf(1.0, (1.0 - ph) * 1.6)
		_ring(x, y, r, r, Color(O[4], a), r * 8)
		_r(x - r * 0.5, y - r * 0.5, 1, 1, Color(O[6], a))
		pos.append(Vector3(x, y, ph))
	return pos


## drawSpeech : bulle d'incantation (texte net, police système semi-grasse ; « Pixelify Sans » n'est pas
## chargée par le prototype).
func _draw_speech(x: float, y: float, k: float, text: String, t: float) -> void:
	if text.is_empty():
		return
	var u := maxf(1.0, roundf(k))
	var fs := maxi(11, roundi(5.2 * k))
	var w := _speech_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.4
	var h := fs * 2.0
	var bx := roundf(x - w * 0.3)
	var by := roundf(y - h)
	var ink := Color("#1a1028")
	var paper := Color("#ece6cc")
	draw_rect(Rect2(bx - u, by, w + 2.0 * u, h), ink)
	draw_rect(Rect2(bx, by - u, w, h + 2.0 * u), ink)
	draw_rect(Rect2(bx, by, w, h), paper)
	for i in 3:
		draw_rect(Rect2(x + i * u - u, by + h + u + i * u, (4 - i) * u, u), ink)
		draw_rect(Rect2(x + i * u, by + h + i * u, (3 - i) * u - u, u), paper)
	draw_rect(Rect2(bx, by + h - u, w, u), Color("#5c46aa"))
	var base := by + h / 2.0 + (_speech_font.get_ascent(fs) - _speech_font.get_descent(fs)) / 2.0
	if show_text:
		draw_string(_speech_font, Vector2(bx + fs * 0.7, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#24164a"))
	var ends := FORMULAS.values().map(func(f: Dictionary) -> String: return f["end"])
	if not ends.has(text):
		draw_rect(Rect2(bx + w - u * 3.0, by + u * 2.0, u * 2.0, u * 2.0), Color("#8a72d8") if floori(t * 6.0) % 2 else Color("#c4b2ff"))


# ---------------------------------------------------------------- Mode construction

func _footprint_poly(x: float, z: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c: Vector2 in [Vector2(x - h, z - h), Vector2(x + h, z - h), Vector2(x + h, z + h), Vector2(x - h, z + h)]:
		pts.append(_project(c.x, 0.0, c.y))
	return pts


## drawBuildCells : cases de 4 × 4 constructibles à l'écran (vertes si libres, rouges si occupées), puis
## l'empreinte du bâtiment sous le pointeur.
func _draw_build_cells() -> void:
	if GameState.hud_mode != "build" or GameState.hud_build_type.is_empty():
		return
	var sim := world.simulation
	if sim == null:
		return
	var ss := _cam().screen_size()
	var a := _cam().ground_from_screen(Vector2.ZERO)
	var b := _cam().ground_from_screen(ss)
	var key := "%s|%s|%d|%d|%d" % [a, b, world.terrain_state.version, GameState.buildings.size(), _cam().px]
	if key != _cells_key:
		_cells_key = key
		_cells_free = PackedVector2Array()
		_cells_busy = PackedVector2Array()
		var C := Simulation.CELL
		var x := floorf(a.x / C) * C
		while x < b.x:
			var z := floorf(a.y / C) * C
			while z < b.y:
				var cx := x + C / 2.0
				var cz := z + C / 2.0
				if sim.buildable_ground(cx, cz) and sim.buildable_ground(x + 0.5, z + 0.5) and sim.buildable_ground(x + 3.5, z + 3.5):
					var busy := GameState.buildings.any(func(o: Building) -> bool: return absf(o.x - cx) < o.half() and absf(o.z - cz) < o.half())
					var poly := _footprint_poly(cx, cz, C / 2.0)
					var target := _cells_busy if busy else _cells_free
					for i in 4:
						target.append(poly[i])
						target.append(poly[(i + 1) % 4])
				z += C
			x += C
	# Les cases sont recalculées à la projection courante : une caméra qui bouge invalide la clé.
	if not _cells_free.is_empty():
		draw_multiline(_cells_free, Color("#a4f2ca40"), 1.0)
	if not _cells_busy.is_empty():
		draw_multiline(_cells_busy, Color("#f28d8040"), 1.0)
	var p: Variant = GameState.build_pointer
	if p != null:
		var q := Simulation.snap_for(GameState.hud_build_type, p)
		var ok := sim.site_visible(GameState.hud_build_type, q) and sim.valid_site(GameState.hud_build_type, q)
		_draw_footprint(q.x, q.y, Simulation.half_of(GameState.hud_build_type), Color("#a4f2ca") if ok else Color("#f28d80"),
			Color("#a4f2ca30") if ok else Color("#f28d8030"))


## drawFootprint : contour de l'emprise au sol, épaisseur max(1, Z·0,12).
func _draw_footprint(x: float, z: float, h: float, stroke: Color, fill: Color) -> void:
	var poly := _footprint_poly(x, z, h)
	if fill.a > 0.0:
		draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, stroke, maxf(1.0, _z() * 0.12), true)


## drawBuildPreview : empreinte animée de TempleKit (verte ou rouge) sous le pointeur.
func _draw_build_preview() -> void:
	if GameState.hud_mode != "build" or GameState.hud_build_type.is_empty() or GameState.build_pointer == null or world.simulation == null:
		return
	var type := GameState.hud_build_type
	var p := Simulation.snap_for(type, GameState.build_pointer)
	var ok := world.simulation.site_visible(type, p) and world.simulation.valid_site(type, p)
	var F: Dictionary = _fp_meta["valid" if ok else "invalid"]
	var tex := _fp_valid if ok else _fp_invalid
	var q := _project(p.x, 0.0, p.y)
	var s := _z() / 16.0 * int(Catalog.BUILDINGS[type]["size"]) / 3.0 / 2.0
	var fi := floori(GameState.sim_time * 12.0) % int(F["count"])
	var cols := int(F["cols"])
	var src := Rect2((fi % cols) * float(F["frame_w"]), (fi / cols) * float(F["frame_h"]), F["frame_w"], F["frame_h"])
	draw_set_transform(q - Vector2(F["ax"], F["ay"]) * s, 0.0, Vector2(s, s))
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, src.size), src)
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- Ancre

## Anneau de l'Ancre sélectionnée et libellé de l'Ancre (ÉTEINTE, RÉACTIVATION n %, ANCRE), gras 10 px.
func _draw_anchor() -> void:
	var c := CaveShape.CORE
	if GameState.anchor_selected:
		var z := _z()
		var p := _project(c.x, 0.15, c.y)
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(p + Vector2(cos(a) * 1.8 * z * 0.9, sin(a) * 1.8 * z * 0.42).rotated(-0.02))
		draw_colored_polygon(pts, Color("#e8bc5b55"))
	if not GameState.anchor_selected:
		return
	var text := "ANCRE ÉTEINTE"
	if GameState.orb_active:
		text = "ANCRE"
	elif GameState.orb_owner and GameState.orb_progress > 0.0:
		text = "ANCRE · RÉACTIVATION %d %%" % floori(GameState.orb_progress / Simulation.ORB_TIME * 100.0)
	var q := _project(c.x, 0.0, c.y)
	_text_c(_bold, Vector2(q.x, q.y + 15.0 * 0.9), text, 10, Color("#c9afd0"))


## Activités affichées au-dessus du bâtiment avec leur progression.
static func building_jobs(b: Building) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	if not b.complete:
		return jobs
	for id: String in GameState.research_jobs:
		var job: Dictionary = GameState.research_jobs[id]
		if job["building"] == b:
			jobs.append({"icon": "mining_seal", "progress": clampf(job["progress"] / Catalog.RESEARCH_TIME, 0, 1)})
	if Simulation.Recipes.has_station(b.type) and b.recipe != "":
		jobs.append({"icon": HudModel.CRAFT_ICON.get(b.recipe, "hammer"), "item": b.recipe,
			"stock": Production.count_in(b.output_box, b.recipe),
			"blocked": Production.craft_workers(b) == 0,
			"progress": clampf(b.craft / Simulation.Recipes.craft_time(b.type), 0, 1)})
	if b.type == "caserne" and not b.queue.is_empty():
		for unit: Dictionary in Catalog.CASERNE_UNITS:
			if unit["id"] == b.queue[0]:
				jobs.append({"icon": unit["icon"], "progress": clampf(b.train / Catalog.CASERNE_TIME, 0, 1)})
	return jobs


func _draw_job(at: Vector2, job: Dictionary) -> void:
	var panel := Rect2(at - Vector2(38, 43), Vector2(76, 55))
	var icon_at := at - Vector2(14, 38)
	var label := ""
	if job.has("stock"):
		label = "En stock : %d" % job["stock"]
		var width := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var padding := maxf(0, (width + 12 - panel.size.x) / 2)
		panel = panel.grow_individual(padding, 16, padding, 0)
		icon_at.y -= 16
	draw_style_box(_job_panel(), panel)
	if label != "":
		draw_string(_bold, Vector2(panel.position.x, at.y - 8), label, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 11)
	# Arme du Creuset : son icône dessinée plutôt que le pictogramme générique.
	var wi := TyrienArt.weapon_icon(String(job.get("item", "")))
	if wi:
		draw_texture_rect(wi, Rect2(icon_at - Vector2(2, 2), Vector2(32, 32)), false)
	else:
		draw_texture_rect(HudStyle.icon(job["icon"], 28), Rect2(icon_at, Vector2(28, 28)), false)
	if job.get("blocked", false):
		var badge := icon_at + Vector2(27, 4)
		draw_circle(badge, 8, Color("#13212b"))
		draw_string(_bold, badge + Vector2(-8, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 15, Color("#ffdb44"))
	var bar := Rect2(at + Vector2(-31, -2), Vector2(62, 6))
	draw_rect(bar, Color("#132c33"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * job["progress"], bar.size.y)), Color("#5ce8ff"))
	draw_rect(bar, Color("#1f9fb8"), false)


static var _job_style: StyleBoxFlat
static func _job_panel() -> StyleBoxFlat:
	if _job_style == null:
		_job_style = StyleBoxFlat.new()
		_job_style.bg_color = Color("#06121ae8")
		_job_style.border_color = Color("#1f9fb8")
		_job_style.set_border_width_all(1)
		_job_style.set_corner_radius_all(4)
	return _job_style
