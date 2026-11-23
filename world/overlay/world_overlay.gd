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
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
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
	"warehouse": "templeJob", "library": "templeJob", "forge": "foundryJob", "workshop": "foundryJob", "creuset": "foundryJob", "scierie": "foundryJob", "archerie": "foundryJob", "etabli": "foundryJob", "bedroom": "sawmillJob", "soulwell": "sawmillJob",
	"caserne": "barracksJob", "eglise": "sawmillJob", "ecole": "sawmillJob"}

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
## Contrôle des hitboxes (F3, InputController) : silhouette touchée par les balles et les clics (rectangle) et
## rayon de corps compté par la mêlée autour des pieds (cercle), pour chaque ennemi visible.
static var show_hitboxes := false


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
	_draw_pylons()
	_draw_portals()
	_effects.ci = self
	_effects.world = world
	_effects.draw_all(GameState.sim_time)
	_draw_temple_overlays()
	_draw_build_cells()
	_draw_build_preview()
	_draw_pray_feedback()
	_draw_anchor()
	if show_hitboxes:
		_draw_hitboxes()
	var b := HudModel.selected_building()
	if b and b.rally_point != null:
		_draw_rally(b)
	_draw_move_orders()


# ---------------------------------------------------------------- Point de ralliement

const RALLY_GOLD := Color("#f2c75c")
const RALLY_GOLD_DARK := Color("#7a5418")
const RALLY_OUTLINE := Color("#1a1208")


## Ligne dorée en pointillés (qui défile vers le drapeau) du bâtiment au point, puis le drapeau.
func _draw_rally(b: Building) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var from := _project(b.x, 0.0, b.z)
	var to := _project(b.rally_point.x, 0.0, b.rally_point.y)
	# Le drapeau suit le zoom de la caméra (taille fixe en pixels natifs, pas en pixels écran).
	var k := clampf(float(_cam().px) * 0.6, 1.0, 3.0)
	_draw_marching_dashes(from, to - (to - from).limit_length(8.0 * k), t)
	draw_set_transform(to, 0.0, Vector2(k, k))
	_draw_rally_flag(Vector2.ZERO, t)
	draw_set_transform(Vector2.ZERO)


## Ordre de déplacement des unités amies sélectionnées : même ligne que le point de ralliement, de l'unité à
## sa destination, marquée d'un petit cercle. Disparaît à l'arrivée (force_move retombe, Combat).
func _draw_move_orders() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var k := clampf(float(_cam().px) * 0.6, 1.0, 3.0)
	for u: Unit in GameState.selected:
		if not u.alive() or u.hidden or u.is_enemy() or not u.force_move or u.direct_move:
			continue
		if Vector2(u.tx - u.x, u.tz - u.z).length() < 0.6:
			continue
		var from := _project(u.x, 0.0, u.z)
		var to := _project(u.tx, 0.0, u.tz)
		var r := 3.5 * k
		_draw_marching_dashes(from, to - (to - from).limit_length(r), t)
		draw_arc(to, r, 0.0, TAU, 20, Color(RALLY_OUTLINE, 0.55), 4.0, true)
		draw_arc(to, r, 0.0, TAU, 20, RALLY_GOLD, 2.0, true)
		draw_circle(to, 1.2 * k, RALLY_GOLD)


func _draw_marching_dashes(from: Vector2, to: Vector2, t: float) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	const DASH := 7.0
	const GAP := 5.0
	var d := -fmod(t * 18.0, DASH + GAP)
	while d < length:
		var a := from + dir * maxf(d, 0.0)
		var e := from + dir * minf(d + DASH, length)
		if d + DASH > 0.0:
			draw_line(a, e, Color(RALLY_OUTLINE, 0.55), 4.0)
			draw_line(a, e, RALLY_GOLD, 2.0)
		d += DASH + GAP


## Fanion bleu ondulant à liseré doré sur une hampe, avec ombre et anneau pulsé au sol.
func _draw_rally_flag(p: Vector2, t: float) -> void:
	# Anneau au sol qui pulse.
	var pulse := fmod(t * 0.9, 1.0)
	var ring := 6.0 + pulse * 10.0
	_draw_ellipse_outline(p, Vector2(ring, ring * 0.45), Color(RALLY_GOLD, 0.8 * (1.0 - pulse)), 1.5)
	# Ombre portée.
	_draw_ellipse_filled(p + Vector2(2, 0), Vector2(7, 2.6), Color(0, 0, 0, 0.35))
	const H := 30.0
	var top := p + Vector2(0, -H)
	# Hampe (contour sombre puis bois doré).
	draw_line(p, top, RALLY_OUTLINE, 4.0)
	draw_line(p, top + Vector2(0, 1), Color("#c9a25a"), 2.0)
	draw_line(p + Vector2(-0.5, 0), top + Vector2(-0.5, 1), Color("#ffe8b0"), 0.8)
	# Fanion à queue d'aronde, ondulant.
	const W := 18.0
	const FH := 12.0
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var u := float(i) / steps
		var wave := sin(u * 5.0 - t * 6.0) * 1.8 * u
		var x := 1.5 + u * W
		upper.append(top + Vector2(x, 1.0 + wave))
		lower.append(top + Vector2(x, 1.0 + FH - u * 1.5 + wave))
	var notch := top + Vector2(1.5 + W * 0.72, 1.0 + FH * 0.5 + sin(3.6 - t * 6.0) * 1.3)
	var poly := PackedVector2Array(upper)
	poly.append(notch)
	for i in range(lower.size() - 1, -1, -1):
		poly.append(lower[i])
	var outline := PackedVector2Array(poly)
	outline.append(poly[0])
	draw_polyline(outline, RALLY_OUTLINE, 3.0)
	draw_colored_polygon(poly, Color("#2f7fd0"))
	# Reflet supérieur et liseré doré.
	var shine := PackedVector2Array()
	for i in range(upper.size()):
		shine.append(upper[i] + Vector2(0, 1.5))
	draw_polyline(shine, Color("#7cc8ff"), 1.5)
	draw_polyline(outline, RALLY_GOLD, 1.0)
	# Emblème : petit losange doré.
	var c := top + Vector2(1.5 + W * 0.32, 1.0 + FH * 0.5 + sin(1.6 - t * 6.0) * 0.6)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(2.5, 0), c + Vector2(0, 3), c + Vector2(-2.5, 0)]), RALLY_GOLD)
	# Pommeau doré.
	draw_circle(top, 3.2, RALLY_OUTLINE)
	draw_circle(top, 2.2, RALLY_GOLD)
	draw_circle(top + Vector2(-0.7, -0.7), 0.9, Color("#fff4c8"))


func _draw_ellipse_filled(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw_ellipse_outline(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w, true)


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


# ---------------------------------------------------------------- Pylônes de Merenor

static var _pylon_style: StyleBoxFlat
static var _beast_icon: AtlasTexture


## Minuteur de renaissance au-dessus de l'obélisque (comme la formation des unités, en rouge), état de la
## canalisation sous le socle.
func _draw_pylons() -> void:
	if _pylon_style == null:
		_pylon_style = StyleBoxFlat.new()
		_pylon_style.bg_color = Color("#100a0ce6")
		_pylon_style.border_color = Color("#6e1a1c")
		_pylon_style.set_border_width_all(2)
		_pylon_style.set_corner_radius_all(4)
		_beast_icon = AtlasTexture.new()
		_beast_icon.atlas = load(EnemyArt.ROOT + "beast_idle.png")
		_beast_icon.region = Rect2(18, 16, 48, 30)  # corps du chien dans le cadre 84 × 48
	var kk := float(_cam().px)
	for p: Dictionary in world.terrain_state.portals:
		if not p["active"] or not p.has("slots") or not world.fog.visible_at(Vector2(p["x"], p["z"])):
			continue
		var base := _project(p["x"], 0.0, p["z"])
		var praying: Array = p.get("praying", [])
		_draw_prayer_beams(p, base, kk)
		if p.has("reflux"):
			_text_c(_bold, base + Vector2(0, 7.0 * kk), "REFLUX DE MERENOR", 10, Color("#ffb48a"))
		elif p["channeled"]:
			_text_c(_bold, base + Vector2(0, 7.0 * kk), "PYLÔNE CANALISÉ", 10, Color("#ece8dc"))
		elif float(p.get("bless_run", 0.0)) > 0.0:
			_text_c(_bold, base + Vector2(0, 7.0 * kk), "CANALISATION · %d / %d s" % [floori(p["bless_run"]), int(Pylons.BLESS_CHANNEL)], 10, Color("#5ce8ff"))
		elif not praying.is_empty():
			_text_c(_bold, base + Vector2(0, 7.0 * kk), "CANALISATION · %d / 4" % praying.size(), 10, Color("#ffb48a"))
		var top := base - Vector2(0, 100.0 * kk)
		# Jamais sous le bandeau du jour (haut de l'écran, ~115 px) : la pile des panneaux monte depuis là.
		top.y = maxf(top.y, 160.0)
		# Bénédiction de l'Ingénieur : répit restant (il grandit pendant la prière, s'écoule ensuite).
		var blessing := float(p.get("blessing", 0.0))
		if blessing > 0.0:
			var bw := 132.0
			var bp := Rect2(top - Vector2(bw / 2.0, 26.0), Vector2(bw, 24.0))
			draw_style_box(_job_panel(), bp)
			var bs := ceili(blessing)
			var label := "BÉNÉDICTION %d:%02d" % [bs / 60, bs % 60]
			draw_string(_bold, bp.position + Vector2(0, 16), label, HORIZONTAL_ALIGNMENT_CENTER, bw, 11, Color("#5ce8ff") if p.get("blessing_now", false) else Color("#b8f6ff"))
			top.y -= 30.0
		# Reflux annoncé (PortalNet) : minuteur rouge jusqu'à la sortie de la meute.
		var rem := PortalNet.reflux_remaining(p)
		if rem >= 0.0:
			var rw := 132.0
			var rp := Rect2(top - Vector2(rw / 2.0, 40.0), Vector2(rw, 38.0))
			draw_style_box(_pylon_style, rp)
			draw_string(_bold, rp.position + Vector2(8, 19), "REFLUX", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e0583a"))
			var rs := ceili(rem)
			draw_string(_bold, rp.position + Vector2(58, 21), "%d:%02d" % [rs / 60, rs % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffb48a"))
			var rb := Rect2(rp.position + Vector2(6, 28), Vector2(rw - 12, 5))
			draw_rect(rb, Color("#2a0c10"))
			draw_rect(Rect2(rb.position, Vector2(rb.size.x * PortalNet.reflux_k(p), rb.size.y)), Color("#e0583a"))
			top.y -= 44.0
		# Pylône scellé par l'Ingénieur : la meute du reflux doit tomber avant la fin, sinon il redevient sauvage.
		var orem := PortalNet.reflux_out_remaining(p)
		var alive := PortalNet.pack_alive(p)
		if orem >= 0.0 and p.get("sealed", false) and alive > 0:
			var mw := 132.0
			var mp := Rect2(top - Vector2(mw / 2.0, 40.0), Vector2(mw, 38.0))
			draw_style_box(_pylon_style, mp)
			draw_string(_bold, mp.position + Vector2(8, 19), "MEUTE · %d" % alive, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e0583a"))
			var ms := ceili(orem)
			draw_string(_bold, mp.position + Vector2(76, 21), "%d:%02d" % [ms / 60, ms % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffb48a"))
			var mb := Rect2(mp.position + Vector2(6, 28), Vector2(mw - 12, 5))
			draw_rect(mb, Color("#2a0c10"))
			draw_rect(Rect2(mb.position, Vector2(mb.size.x * orem / PortalNet.OUT, mb.size.y)), Color("#e0583a"))
			top.y -= 44.0
		var tm := Pylons.timer(p)
		if tm.is_empty():
			continue
		var w := 96.0
		var panel := Rect2(top - Vector2(w / 2.0, 44.0), Vector2(w, 44.0))
		draw_style_box(_pylon_style, panel)
		draw_rect(Rect2(panel.position + Vector2(5, 5), Vector2(32, 24)), Color("#2a1216"))
		draw_texture_rect(_beast_icon, Rect2(panel.position + Vector2(-3, 2), Vector2(48, 30)), false)
		var sec := ceili(float(tm["rem"]))
		draw_string(_bold, panel.position + Vector2(44, 23), "%d:%02d" % [sec / 60, sec % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffb48a"))
		if int(tm["waiting"]) > 0:
			draw_string(_bold, panel.position + Vector2(78, 14), "+%d" % int(tm["waiting"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e0583a"))
		var bar := Rect2(panel.position + Vector2(6, 33), Vector2(w - 12, 5))
		draw_rect(bar, Color("#2a0c10"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(tm["progress"]), bar.size.y)), Color("#e0583a"))
		draw_rect(bar, Color("#a8302a"), false)


## Rayons de prière de la planche v2 : de la poitrine de chaque esprit qui canalise au foyer de
## l'obélisque, couleur du culte éclaircie, trois étincelles blanches qui montent le long du rayon.
const BEAM_CULT := {"aether": Color8(122, 134, 255), "indra": Color8(255, 154, 58), "medeina": Color8(111, 224, 122), "sigil": Color8(216, 212, 202)}


func _draw_prayer_beams(p: Dictionary, base: Vector2, kk: float) -> void:
	var focus := base - Vector2(0, Pylons.FOCUS * kk)
	var t := GameState.sim_time
	for u: Unit in GameState.units:
		if not u.alive() or u.hidden or not u.working or not (u.job is Dictionary) \
				or u.job.get("type") != "pray_pylon" or u.job.get("pylon") != p:
			continue
		var c: Color = BEAM_CULT.get(u.role, Color.WHITE)
		var from := _project(u.x, 0.0, u.z) - Vector2(0, Pylons.BEAM_FROM * kk)
		var i := Pylons.CULTS.find(u.role)
		var rk := PortalNet.reflux_k(p)
		if rk > 0.0:
			# Reflux annoncé : le rayon ondule, se troue et vire au rouge vers le foyer.
			_draw_weak_beam(from, focus, c, rk, i, t, kk)
			continue
		draw_line(from, focus, Color(c, 0.18), 3.0 * kk)
		draw_line(from, focus, c.lerp(Color.WHITE, 0.35), kk)
		draw_circle(from, 6.0 * kk, Color(c, 0.12))
		for k in 3:
			var q := fposmod(t * 0.8 + k / 3.0 + i * 0.1, 1.0)
			draw_rect(Rect2(from.lerp(focus, q) - Vector2(kk, kk) * 0.5, Vector2(kk, kk) * 1.5), Color(1, 1, 1, 0.85))
	draw_circle(focus, 10.0 * kk, Color(0.92, 0.91, 0.87, 0.10 * float(p.get("praying", []).size()) / 4.0))


const REFLUX_RED := Color8(224, 88, 58)
const REFLUX_CORE := Color8(255, 240, 216)


func _draw_weak_beam(from: Vector2, focus: Vector2, c: Color, rk: float, i: int, t: float, kk: float) -> void:
	var n := 28
	var nrm := (focus - from).normalized().orthogonal()
	var prev := from
	for k in range(1, n + 1):
		var q := float(k) / n
		var w := rk * 6.0 * kk * sin(q * 18.0 - t * 9.0 + i) * sin(q * PI)
		var pt := from.lerp(focus, q) + nrm * w
		var hole := fposmod(q * 7.0 - t * 1.3 + i * 0.3, 1.0) < rk * 0.35
		if not hole:
			var col := c.lerp(Color.WHITE, 0.35).lerp(REFLUX_RED, clampf(rk * 1.4 - q * 0.4, 0.0, 1.0))
			draw_line(prev, pt, Color(col, 0.18), 3.0 * kk)
			draw_line(prev, pt, col, kk)
		prev = pt


# ---------------------------------------------------------------- Portails (PortalNet, Orbe suspendu)

## Hauteur de l'orbe au-dessus du seuil (px natifs), rayon (px natifs), montée de l'orbe qui emporte un voyageur.
const ORB_H := 18.0
const ORB_R := 6.0
const ORB_RISE := 70.0


func _draw_portals() -> void:
	var kk := float(_cam().px)
	var t := GameState.sim_time
	var st := world.terrain_state
	var eng: Unit = GameState.incarnated
	var travellers: Array[Unit] = []
	for u in GameState.units:
		if u.alive() and PortalNet.warping(u):
			travellers.append(u)
	for n: Dictionary in PortalNet.nodes(st):
		var at: Vector2 = n["pos"]
		if not world.fog.visible_at(at):
			continue
		var base := _project(at.x, 0.0, at.y)
		var orb := base - Vector2(0, ORB_H * kk)
		var p: Dictionary = n["pylon"]
		if not n["open"]:
			if not p.is_empty():
				_draw_rift(base, kk, t, PortalNet.reflux_k(p))
			continue
		if not p.is_empty():
			# Fils des quatre rayons : du foyer de l'obélisque jusqu'à l'orbe, en pointillés qui descendent.
			var focus := _project(p["x"], 0.0, p["z"]) - Vector2(0, Pylons.FOCUS * kk)
			for k in 4:
				var c: Color = BEAM_CULT[Pylons.CULTS[k]]
				var off := Vector2((k - 1.5) * 0.8 * kk, 0)
				var seg := 14
				for j in seg:
					if fposmod(float(j) / seg * 4.0 - t * 1.6 + k * 0.25, 1.0) < 0.5:
						draw_line(focus.lerp(orb, float(j) / seg) + off * (1.0 - float(j) / seg), focus.lerp(orb, float(j + 1) / seg) + off * (1.0 - float(j + 1) / seg), c.lerp(Color.WHITE, 0.3), kk)
		var busy := false
		for u in travellers:
			if u.pos().distance_to(at) < 1.5:
				busy = true
		draw_set_transform(base, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 9.0 * kk, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
		if not busy:
			_draw_orb(orb, ORB_R * kk, t, false)
		if eng != null and eng.alive() and not PortalNet.warping(eng) and eng.pos().distance_to(at) <= PortalNet.REACH:
			_prompt_at(base + Vector2(0, 6.0 * kk), "E : Voyager", kk)
	for u in travellers:
		_draw_bubble(u, kk, t)


## Orbe aux quatre quartiers (couleurs des cultes) qui tournent, cœur blanc ; `bubble` : bulle transparente.
func _draw_orb(c: Vector2, r: float, t: float, bubble: bool) -> void:
	draw_circle(c, r + 10.0 * float(_cam().px), Color(0.86, 0.88, 1.0, 0.10))
	if bubble:
		draw_circle(c, r, Color(0.86, 0.9, 1.0, 0.10))
		for k in 4:
			var a0 := t * 2.0 + k * PI / 2.0
			draw_arc(c, r, a0, a0 + PI / 2.0, 10, BEAM_CULT[Pylons.CULTS[k]].lerp(Color.WHITE, 0.5), maxf(1.0, r * 0.08))
		return
	for k in 4:
		var a0 := t * 2.0 + k * PI / 2.0
		var pts := PackedVector2Array([c])
		for j in 7:
			pts.append(c + Vector2.from_angle(a0 + PI / 2.0 * j / 6.0) * r)
		draw_colored_polygon(pts, BEAM_CULT[Pylons.CULTS[k]].lerp(Color.WHITE, 0.15))
	draw_arc(c, r, 0.0, TAU, 20, Color8(97, 90, 110), maxf(1.0, r * 0.18))
	draw_circle(c, r * 0.35, Color(1, 1, 1, 0.9))
	draw_circle(c + Vector2(-r * 0.4, -r * 0.4), r * 0.16, Color.WHITE)


## Voyageur dans la bulle (planche, modèle 5) : elle gonfle autour de lui, se referme, puis l'orbe remonte.
func _draw_bubble(u: Unit, kk: float, t: float) -> void:
	var wv := PortalNet.warp_view(u)
	var k := float(wv["k"])
	var base := _project(u.x, 0.0, u.z)
	var orb := base - Vector2(0, ORB_H * kk)
	var body := base - Vector2(0, 14.0 * kk)
	if k < 0.35:
		var q := k / 0.35
		_draw_orb(orb.lerp(body, q), (ORB_R + q * 14.0) * kk, t, q > 0.3)
	elif k < 0.6:
		var q := (k - 0.35) / 0.25
		_draw_orb(body.lerp(orb, q), (20.0 - q * 16.0) * kk, t, q < 0.8)
	else:
		var q := (k - 0.6) / 0.4
		var c := orb - Vector2(0, q * ORB_RISE * kk)
		_draw_orb(c, 3.0 * kk, t, false)
		draw_circle(c, 8.0 * kk, Color(1, 1, 1, 0.25 * (1.0 - q)))


## Fêlure au seuil (reflux) : une déchirure rouge qui s'ouvre au rythme d'un cœur qui accélère, et un cercle
## tramé au sol qui marque d'où sortira la meute.
func _draw_rift(base: Vector2, kk: float, t: float, rk: float) -> void:
	if rk <= 0.0:
		return
	var beat := fposmod(t * (1.0 + rk * 2.5), 1.0)
	var pul := 1.0 if beat < 0.12 else 0.4 if beat < 0.24 else 0.0
	if rk > 0.15:
		var R := 34.0 * kk
		for a in 60:
			if (a + floori(t * 8.0)) % 4 < 2:
				var a0 := float(a) / 60.0 * TAU
				draw_line(base + Vector2(cos(a0) * R, sin(a0) * R * 0.4), base + Vector2(cos(a0 + TAU / 60.0) * R, sin(a0 + TAU / 60.0) * R * 0.4), REFLUX_RED.lerp(REFLUX_CORE, pul * 0.4), 1.5 * kk)
	var h := (4.0 + rk * 30.0) * kk
	var cy := base.y - 14.0 * kk
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var core_l := PackedVector2Array()
	var core_r := PackedVector2Array()
	for j in 13:
		var v := float(j) / 12.0 * 2.0 - 1.0
		var y := cy + v * h / 2.0
		var w := (1.0 - v * v) * (1.2 + rk * 3.0 + pul * 1.5) * kk
		var off := sin(y / kk * 0.7) * 1.5 * kk
		left.append(Vector2(base.x + off - w, y))
		right.append(Vector2(base.x + off + w, y))
		core_l.append(Vector2(base.x + off - w * 0.4, y))
		core_r.append(Vector2(base.x + off + w * 0.4, y))
	right.reverse()
	core_r.reverse()
	draw_circle(Vector2(base.x, cy), (16.0 + rk * 14.0) * kk, Color(REFLUX_RED, 0.12 + 0.12 * pul))
	draw_colored_polygon(left + right, REFLUX_RED)
	draw_colored_polygon(core_l + core_r, REFLUX_CORE)
	for i in 10:
		var u := fposmod(t * 1.4 + i / 10.0, 1.0)
		var a := float((i * 7919 + floori(t * 1.4 + i / 10.0) * 104729) % 628) / 100.0
		draw_rect(Rect2(Vector2(base.x + cos(a) * u * 20.0 * kk, cy + sin(a) * u * 14.0 * kk), Vector2(kk, kk)), Color8(255, 180, 138))


## Invite « E : … » dans la petite bannière bleue (comme la capsule), à l'échelle du monde.
func _prompt_at(top: Vector2, label: String, kk: float) -> void:
	var size := 12
	var w := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Rect2((top + Vector2(-w / 2.0 - 9.0, 0.0)).round(), Vector2(roundf(w + 18.0), 20.0))
	SnesBanner.paint(self, box, SnesBanner.DIALOGUE, true)
	draw_string(_bold, box.position + Vector2(9, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SnesBanner.INK)


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
			pts.append(p + Vector2(cos(a) * 3.3 * z * 0.9, sin(a) * 3.3 * z * 0.42).rotated(-0.02))
		draw_colored_polygon(pts, Color("#e8bc5b55"))
	if not GameState.anchor_selected:
		return
	var text := "ANCRE ÉTEINTE"
	if GameState.orb_active:
		text = "ANCRE"
	elif GameState.orb_owner and GameState.orb_progress > 0.0:
		text = "ANCRE · RÉACTIVATION %d %%" % floori(GameState.orb_progress / Simulation.ORB_TIME * 100.0)
	var q := _project(c.x, 0.0, c.y + 2.2)
	_text_c(_bold, Vector2(q.x, q.y + 15.0 * 0.9), text, 10, Color("#c9afd0"))


## Activités affichées au-dessus du bâtiment avec leur progression.
static func building_jobs(b: Building) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	if not b.complete:
		return jobs
	# Recherche qui avance (une par bâtiment ; les suivantes attendent en file).
	for id: String in Simulation.research_queue(b).slice(0, 1):
		var job: Dictionary = GameState.research_jobs[id]
		if true:
			jobs.append({"icon": String(Catalog.RESEARCH[id].get("icon", "mining_seal")), "progress": clampf(job["progress"] / Catalog.RESEARCH_TIME, 0, 1)})
	if Simulation.Recipes.has_station(b.type) and b.recipe != "":
		jobs.append({"icon": HudModel.CRAFT_ICON.get(b.recipe, "hammer"), "item": b.recipe,
			"stock": Production.count_in(b.output_box, b.recipe),
			"blocked": Production.craft_workers(b) == 0,
			"progress": clampf(b.craft / Simulation.Recipes.craft_time(b.type), 0, 1)})
	if Catalog.TRAINERS.has(b.type) and not b.queue.is_empty():
		for unit: Dictionary in Catalog.TRAINERS[b.type]:
			if unit["id"] == b.queue[0]:
				jobs.append({"icon": unit["icon"], "progress": clampf(b.train / Catalog.CASERNE_TIME, 0, 1)})
	# Temple : l'esprit qui naît à l'autel (portrait et progression), puis la file des suivants.
	if b.is_temple():
		var u := Simulation.temple_arrival(b)
		if u != null or not b.queue.is_empty():
			var waiting: Array[String] = []
			waiting.assign(b.queue)
			var progress := 0.0
			var current := ""
			if u != null:
				current = u.role
				progress = clampf(1.0 - (u.arrival_end - GameState.sim_time) / Simulation.ARRIVAL, 0, 1)
			else:
				current = waiting.pop_front()
			jobs.append({"portrait": current, "progress": progress, "waiting": waiting})
	return jobs


## Piste 1 « Laiton et objet franc » (comme les boutons de fabrication) : tuile de laiton, objet 32 × 32 en pixels
## entiers, jauge claire en pied, compteur grenat du coffre rouge et pastille « ! » quand l'atelier est bloqué.
func _draw_job(at: Vector2, job: Dictionary) -> void:
	var tile := Rect2((at - Vector2(23, 44)).round(), Vector2(46, 46))
	_laiton_panel(tile)
	var center := tile.get_center() - Vector2(0, 2)
	var icon_r := Rect2(center - Vector2(16, 16), Vector2(32, 32))
	if job.has("portrait"):
		_draw_portrait(icon_r, job["portrait"], 1.0)
		_draw_waiting(Vector2(at.x, tile.position.y - 4.0), job["waiting"])
	elif job.has("item"):
		ItemIcon.draw_item(self, job["item"], center, 1.0)
	else:
		var tint := Color.WHITE if job["icon"] == "mining_seal" else Color("#e9ce9e")
		draw_texture_rect(HudStyle.icon(job["icon"], 28, 1.6), Rect2(center - Vector2(14, 14), Vector2(28, 28)), false, tint)
	# Jauge : filet clair sur fond sombre, en pied de tuile.
	var bar := Rect2(tile.position + Vector2(4, tile.size.y - 6), Vector2(tile.size.x - 8, 2))
	draw_rect(bar, Color("#2a2414"))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * job["progress"]), bar.size.y)), Color("#ffe0a0"))
	if job.has("stock"):
		_draw_stock(Vector2(tile.end.x + 4.0, tile.end.y - 9.0), job["stock"])
	if job.get("blocked", false):
		var badge := Rect2(tile.position + Vector2(tile.size.x - 9, -5), Vector2(14, 14))
		draw_rect(badge, Color("#5a1e22"))
		HudStyle.ring(self, badge, 1.0, Color("#ffdb44"))
		draw_string(_bold, Vector2(badge.position.x, badge.position.y + 11), "!", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 11, Color("#ffdb44"))


## Tuile de laiton des boutons d'ordres (ActionButton, état normal).
func _laiton_panel(r: Rect2) -> void:
	HudStyle.linear_gradient(self, r, 145.0, [[0.0, Color("#2d2b21")], [0.65, Color("#121712")], [1.0, Color("#121712")]])
	HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#131710"))
	HudStyle.ring(self, r, 1.0, Color("#aa8851"))


## Compteur grenat du coffre rouge (pictogramme de coffre et nombre), ancré par son coin bas droit.
func _draw_stock(bottom_right: Vector2, n: int) -> void:
	var t := str(n)
	var w := HudStyle.text_width(t, 10) + 16.0
	var r := Rect2((bottom_right - Vector2(w, 13)).round(), Vector2(w, 13))
	draw_rect(r, Color("#5a1e22"))
	HudStyle.ring(self, r, 1.0, Color("#c0584c"))
	var g := r.position + Vector2(3, 4)
	draw_rect(Rect2(g, Vector2(7, 1)), Color("#ffd6c8"))
	draw_rect(Rect2(g + Vector2(0, 2), Vector2(7, 4)), Color("#e8a090"))
	draw_rect(Rect2(g + Vector2(3, 3), Vector2(1, 1)), Color("#5a1e22"))
	draw_string(HudStyle.font(), Vector2(r.position.x + 13.0, r.position.y + 10.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffe0d4"))


const PORTRAITS := "res://assets/baked/hud/portraits/%s.png"
const WAIT_SIZE := 24.0


## Portraits composés une fois sur le fond du panneau (opaques) : le calque du monde blanchissait les pixels
## semi-transparents des esprits, presque entièrement translucides.
static var _portrait_cache := {}


static func _opaque_portrait(role: String) -> Texture2D:
	if _portrait_cache.has(role):
		return _portrait_cache[role]
	var tex: Texture2D = null
	var path := PORTRAITS % role
	if ResourceLoader.exists(path):
		var src: Image = (load(path) as Texture2D).get_image()
		src.convert(Image.FORMAT_RGBA8)
		var img := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
		img.fill(Color("#06121a"))
		img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
		tex = ImageTexture.create_from_image(img)
	_portrait_cache[role] = tex
	return tex


func _draw_portrait(r: Rect2, role: String, alpha: float) -> void:
	var tex := _opaque_portrait(role)
	if tex:
		draw_texture_rect(tex, r, false, Color(alpha, alpha, alpha))
	draw_rect(r, Color("#1f9fb8"), false)


## File d'attente : portraits des esprits suivants, centrés au-dessus du panneau, du prochain au dernier.
func _draw_waiting(bottom: Vector2, waiting: Array) -> void:
	if waiting.is_empty():
		return
	var gap := 3.0
	var w := waiting.size() * WAIT_SIZE + (waiting.size() - 1) * gap
	var strip := Rect2(Vector2(bottom.x - w / 2.0 - 4.0, bottom.y - WAIT_SIZE - 8.0), Vector2(w + 8.0, WAIT_SIZE + 8.0))
	_laiton_panel(strip)
	for i in waiting.size():
		var r := Rect2(Vector2(strip.position.x + 4.0 + i * (WAIT_SIZE + gap), strip.position.y + 4.0), Vector2(WAIT_SIZE, WAIT_SIZE))
		_draw_portrait(r, waiting[i], 0.75)


static var _job_style: StyleBoxFlat
static func _job_panel() -> StyleBoxFlat:
	if _job_style == null:
		_job_style = StyleBoxFlat.new()
		_job_style.bg_color = Color("#06121ae8")
		_job_style.border_color = Color("#1f9fb8")
		_job_style.set_border_width_all(1)
		_job_style.set_corner_radius_all(4)
	return _job_style


# ---------------------------------------------------------------- Hitboxes (F3)

const HITBOX_RECT := Color("#ff4fd8")
const HITBOX_MELEE := Color("#5fe8ff")


func _draw_hitboxes() -> void:
	var k := _z() * 0.86
	for e: Enemy in GameState.enemies:
		if not e.alive() or (world.fog != null and not world.fog.visible_at(e.pos())):
			continue
		var r := e.body_rect()
		var a := _project(r.position.x, 0.0, r.position.y)
		var b := _project(r.end.x, 0.0, r.end.y)
		draw_rect(Rect2(a, b - a), Color(HITBOX_RECT, 0.12), true)
		draw_rect(Rect2(a, b - a), HITBOX_RECT, false, 1.0)
		var f := _project(e.x, 0.0, e.z)
		var m := (Enemy.MELEE_BASE + e.melee_body()) * k
		draw_arc(f, m, 0.0, TAU, 40, HITBOX_MELEE, 1.0)
		draw_line(f - Vector2(3, 0), f + Vector2(3, 0), Color.WHITE, 1.0)
		draw_line(f - Vector2(0, 3), f + Vector2(0, 3), Color.WHITE, 1.0)
		_text_c(_bold, Vector2(f.x, b.y + 12.0), "%s%s" % [e.kind, " α" if e.alpha else ""], 10, HITBOX_RECT)
