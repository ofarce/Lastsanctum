class_name CapsuleView
extends Node2D
## Capsule de l'Ingénieur (sim/capsule.gd) : « Puits de lumière » (planches/capsule-dais-propositions.html,
## variante 14C retenue le 2026-11-19), dessiné en pixels natifs du monde. Un puits rond à marches creusé
## dans le dallage, une margelle et quatre bornes basses à pointe de quartz ; allumé, une colonne de
## lumière en jaillit en s'évasant au pied, et l'Ingénieur, quand il est dedans, lévite au-dessus du vide
## (vrai atlas TyrienArt, mêlé à la teinte de la colonne par shaders/capsule_glow.gdshader).
##
## Quatre nœuds (World) : `ground` = true sous les sprites (puits, halo, onde, trait d'énergie depuis l'Ancre) ;
## `layer` « back » (bornes arrière, colonne, Ingénieur) et « front » (bornes avant, voyant) triés avec les
## sprites (YSort, au pied de leurs bornes) pour qu'un passant devant la capsule la couvre ; le dernier
## par-dessus tout (poussière, vapeur, lucioles, invites, PV). Coordonnées de dessin = celles de la
## planche : pied de la capsule en (60, 62).
##
## États : éteinte (avant l'Ancre, voyant rouge qui bat), allumage (étape « link » puis les 2,2 premières
## secondes d'« awake » : impact du trait, secousse, montée de la lumière, éclair, vapeur, onde au sol),
## allumée (colonne qui respire, étincelles et grains qui montent, halo, lucioles), occupée (voyant cyan).

const K := Color("#0b090b")
const IRON := [Color("#1e232b"), Color("#2c333d"), Color("#3e4652"), Color("#58626f"), Color("#7d8896")]
const BRZ := [Color("#3a2512"), Color("#5c3d1d"), Color("#8a5f2e"), Color("#c08a48"), Color("#e8c07a")]
const CY := [Color("#1d4f66"), Color("#2f86a8"), Color("#5fd0ee"), Color("#9fe6ff"), Color("#f2fcff")]
const STONE := [Color("#272d37"), Color("#333a46"), Color("#404955"), Color("#4a5361"), Color("#5a6474")]
const INK := Color("#ece5d2")
const LINE := Color("#9fe6ff")
const LINE_CORE := Color("#f2fcff")
const GLOW_SHADER := preload("res://shaders/capsule_glow.gdshader")

## Lévitation de l'Ingénieur au-dessus du fond du puits (px natifs).
const HOVER := 4
## Durée de l'allumage après l'arrivée du trait (étape « awake ») avant l'état allumé stable.
const BOOT_END := 3.0

var ground := false
## « back » / « front » : parties triées dans le YSort ; vide = calque du dessus (effets et invites).
var layer := ""

var _ci: CanvasItem = self
var _base := Vector2.ZERO
var _occupant: Node2D
var _front: Node2D
var _beam_rows: Array = []
var _beam_core: Array[bool] = []
var _beam_base := PackedFloat64Array()
## Emprise de tout ce que dessinent les deux nœuds (capsule, lucioles, invites, trait et invite de l'Ancre), en
## pixels natifs : hors écran, rien n'est redessiné.
var _bounds := Rect2()


func _ready() -> void:
	for y in range(4, 58):
		var hw := roundi(8.0 + maxf(0.0, (y - 40) / 17.0) * 4.0)
		_beam_rows.append([y, 60 - hw, 59 + hw])
		# Par pixel de la rangée : cœur de la colonne (d < 0,25) et opacité de base, qui ne dépendent pas du temps.
		var half: float = (2 * hw) / 2.0
		for x in range(60 - hw, 60 + hw):
			var d := absf(x + 0.5 - 60.0) / half
			_beam_core.append(d < 0.25)
			_beam_base.append(0.22 if d > 0.8 else (0.4 if d > 0.5 else 0.66))
	if ground or layer == "":
		return
	# Pied des bornes (y = 55 arrière, 63 avant ; pied de la capsule en 62) : clé du tri avec les sprites.
	position = Vector2(0.0, Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y).round().y + (-7.0 if layer == "back" else 1.0))
	if layer != "back":
		return
	_occupant = Node2D.new()
	_occupant.name = "Occupant"
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	_occupant.material = mat
	_occupant.draw.connect(_draw_occupant)
	add_child(_occupant)


func _process(_delta: float) -> void:
	if not _on_screen():
		return
	queue_redraw()
	if _occupant:
		_occupant.queue_redraw()


## Vrai si la capsule, l'Ancre ou le trait qui les relie peuvent toucher l'écran (marge large : invites, lucioles,
## onde au sol). Hors écran, l'image gardée n'est pas vue ; le retour à l'écran redessine aussitôt.
func _on_screen() -> bool:
	if _bounds.size == Vector2.ZERO:
		var c := Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y)
		_bounds = Rect2(c, Vector2.ZERO).expand(Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y + 1.0)) \
			.expand(Proj.nat(CaveShape.CORE.x, 0.0, CaveShape.CORE.y - 1.5)).expand(Proj.nat(CaveShape.CORE.x, 6.0, CaveShape.CORE.y)).grow(160.0)
	# Emprise en coordonnées du monde : on retire le décalage des parties triées (posées au pied de leurs bornes).
	return (get_global_transform_with_canvas().translated_local(-position) * _bounds).intersects(get_viewport_rect())


# ---------- état ----------

## État affiché : celui de la capsule (_base_state), ou, à la mort de l'Ingénieur, celui de son retour
## (sim/engineer_return.gd, planches/ingenieur-mort-planche.html) : attente « Les quatre bornes » (colonne en filet,
## bornes rallumées une à une, feu follet nourri par des arcs), puis résurrection « Le souffle » (la colonne se
## resserre, un instant de noir, tout repart d'un coup).
func _state() -> Dictionary:
	var s := _base_state()
	var wk := EngineerReturn.wait_k()
	var rt := EngineerReturn.res_t()
	if wk < 0.0 and rt == INF:
		return s
	s.merge({"mode": 2, "rise": 1.0, "lit": 1.0, "flash": 0.0, "bt": 9.0, "settle": 9.0, "lamp": "on"}, true)
	if rt != INF:
		s["res"] = rt
		if rt < -EngineerReturn.RES_DARK:
			var k := _ph(rt, -EngineerReturn.RES_PRE, -EngineerReturn.RES_DARK)
			s["ws"] = 1.0 - 0.8 * (1.0 - (1.0 - k) * (1.0 - k))
			s["occ"] = false
		elif rt < 0.0:
			s.merge({"lit": 0.0, "beam": 0.0, "pit": 0.0, "lamp": "dim", "occ": false, "pyl": [false, false, false, false]}, true)
		else:
			s["flash"] = 0.8 * (1.0 - _ph(rt, 0.0, 0.25))
			s["occ"] = GameState.in_capsule
		return s
	# Bornes dans l'ordre des aiguilles d'une montre : arrière gauche, arrière droite, avant droite, avant gauche.
	var n := mini(4, floori(wk * 4.0 + 0.000001))
	var pyl := [false, false, false, false]
	var order := [0, 1, 3, 2]
	for r in 4:
		pyl[order[r]] = r < n or (r == n and fmod(s.t * 5.0, 1.0) < 0.5)
	s.merge({"wait": wk, "lit_n": n, "ws": 0.4, "beam": 0.22, "pit": 0.35 + 0.65 * wk, "lit": 0.3 + 0.7 * wk, "occ": false, "pyl": pyl,
		"arrive": 1.0 - _ph(EngineerReturn.age(), EngineerReturn.ARRIVE, EngineerReturn.ARRIVE + 0.35)}, true)
	return s


func _base_state() -> Dictionary:
	var t := GameState.sim_time
	var s := {"t": t, "occ": GameState.in_capsule, "mode": 0, "rise": 0.0, "lit": 0.0, "flash": 0.0,
		"bt": -9.0, "settle": -9.0, "lamp": "off"}
	var bt := -9.0
	if GameState.opening_stage == "link":
		bt = clampf(Opening.elapsed() / Opening.LINK_LEN, 0.0, 1.0) * 0.8 - 0.001
	elif Capsule.powered():
		bt = 9.0
		if GameState.opening_stage == "awake":
			bt = 0.8 + Opening.elapsed()
	if bt <= -9.0:
		return s
	if bt >= BOOT_END:
		s.merge({"mode": 2, "rise": 1.0, "lit": 1.0, "bt": 9.0, "settle": 9.0, "lamp": "on"}, true)
		return s
	s.mode = 1
	s.bt = bt
	s.settle = bt - 2.0
	s.rise = _ease(_ph(bt, 1.0, 2.0))
	s.flash = 1.0 - (bt - 2.0) / 0.45 if bt >= 2.0 and bt < 2.45 else 0.0
	s.lit = 0.0 if bt < 1.0 else (0.4 * s.rise + 0.1 if bt < 2.0 else 1.0)
	s.lamp = "off" if bt < 1.0 else ("boot" if bt < 2.0 else "on")
	s.occ = false
	return s


# ---------- dessin ----------

func _draw() -> void:
	_ci = self
	# Les parties triées sont posées au pied de leurs bornes : on dessine quand même en coordonnées du monde.
	draw_set_transform(-position)
	_base = Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y).round()
	var S := _state()
	if ground:
		_draw_pit(S)
		_draw_link()
		return
	if layer == "":
		_draw_top(S)
		return
	if S.mode == 1 and S.bt > 0.8 and S.bt < 1.15:
		_base.x += 1.0 if int(floorf(S.bt * 40.0)) % 2 else -1.0
	var rt: float = S.get("res", INF)
	if rt >= 0.0 and rt < 0.12:
		_base.x += 1.0 if int(floorf(rt * 40.0)) % 2 else -1.0
	if layer == "front":
		_draw_front(S)
		return
	_pylon(45, 55, 0, S)
	_pylon(75, 55, 1, S)
	_beam(S, 1.0)
	if S.has("wait"):
		_draw_wait(S)
	if S.rise > 0.0:
		_motes(S)
	if S.flash > 0.0:
		for r: Array in _beam_rows:
			_R(r[1], r[0], r[2] - r[1] + 1, 1, CY[4], S.flash * 0.9)


## Sous les sprites : puits, lueur du fond, halo, onde au sol.
func _draw_pit(S: Dictionary) -> void:
	if S.lit > 0.0:
		var a: float = S.lit * (0.15 + 0.06 * sin(S.t * PI))
		_EL(60, 62, 20, 5, CY[2], a)
		_EL(60, 62, 14, 3, CY[3], a * 0.8)
	_EL(60, 58, 16, 6, K)
	_EL(60, 58, 15, 5, STONE[4])
	_EL(60, 58, 14, 5, STONE[3])
	_EL(60, 59, 13, 4, STONE[1])
	_EL(60, 60, 11, 3, STONE[0])
	_EL(60, 61, 9, 2, Color("#0b0e14"))
	_RING(60, 59, 13, 4, STONE[2], 1.0, 1)
	_RING(60, 60, 11, 5, STONE[2], 1.0, 1)
	var g: float = S.get("pit", maxf(S.lit, S.rise))
	if g > 0.0:
		_EL(60, 61, 9, 2, CY[2], 0.7 * g)
		_EL(60, 61, 5, 1, CY[4], 0.8 * g)
		_EL(60, 58, 14, 4, CY[1], 0.18 * g)
	if S.mode == 1 and S.settle >= 0.0 and S.settle < 0.8:
		var k: float = S.settle / 0.8
		var r := 8.0 + 36.0 * k
		_RING(60, 62, r, r * 0.3, CY[3], 1.0 - k)
		_RING(60, 62, r - 3.0, (r - 3.0) * 0.3, CY[4], (1.0 - k) * 0.5)
	# Retour de l'Ingénieur : éclat à l'arrivée du feu follet, puis souffle au sol à la résurrection (anneau, grains).
	var arrive: float = S.get("arrive", 0.0)
	if arrive > 0.0:
		_EL(60, 61, 9, 2, CY[4], arrive)
		var ra := 8.0 + 30.0 * (1.0 - arrive)
		_RING(60, 62, ra, ra * 0.3, CY[3], arrive)
	var rt: float = S.get("res", INF)
	if rt >= 0.0 and rt < 0.6:
		var rk := rt / 0.6
		var rr := 8.0 + 40.0 * rk
		_RING(60, 62, rr, rr * 0.3, CY[4], 1.0 - rk)
		_RING(60, 62, rr - 2.0, (rr - 2.0) * 0.3, CY[3], (1.0 - rk) * 0.7)
		var out := 1.0 - (1.0 - rk) * (1.0 - rk)
		for i in 16:
			var ga := i / 16.0 * TAU + 0.2
			var q := (10.0 + 34.0 * out) * (0.8 + 0.4 * _hash(i))
			_R(60.0 + cos(ga) * q, 62.0 + sin(ga) * q * 0.3 - sin(rk * PI) * 3.0 * _hash(i + 3.0), 1, 1, CY[3] if i % 2 else Color("#9aa1b0"), 1.0 - rk)


## Attente du retour (« Les quatre bornes ») : le feu follet flotte dans le filet de lumière, les bornes rallumées
## lui lancent des arcs, il grossit à chaque borne ; éclat de la colonne à son arrivée.
func _draw_wait(S: Dictionary) -> void:
	var t: float = S.t
	var k: float = S.wait
	var arrive: float = S.get("arrive", 0.0)
	if arrive > 0.0:
		for r: Array in _beam_rows:
			if r[0] > 30:
				_R(r[1], r[0], r[2] - r[1] + 1, 1, CY[4], arrive * 0.5 * (r[0] - 30) / 27.0)
	var oy := 34 + roundi(sin(t * 1.6) * 2.0)
	var tops := [Vector2(45, 45), Vector2(75, 45), Vector2(47, 53), Vector2(73, 53)]
	var order := [0, 1, 3, 2]
	for r in int(S.lit_n):
		var i: int = order[r]
		var sd := floorf(t * 10.0) + i * 13.0
		if _hash(sd) < 0.5:
			continue
		var prev: Vector2 = tops[i]
		for st in range(1, 5):
			var q := Vector2(60, oy)
			if st < 4:
				q = Vector2(roundf(lerpf(tops[i].x, 60.0, st / 4.0) + (_hash(sd + st) - 0.5) * 5.0),
					roundf(lerpf(tops[i].y, oy, st / 4.0) + (_hash(sd + st + 5.0) - 0.5) * 5.0))
			var steps := maxi(1, int(maxf(absf(q.x - prev.x), absf(q.y - prev.y))))
			for j in steps + 1:
				var pt := prev.lerp(q, float(j) / steps).round()
				_R(pt.x, pt.y, 1, 1, CY[4], 0.85)
			prev = q
	wisp(_ci, _base + Vector2(0, oy - 62), 0.35 + 0.65 * k, t)
	if k > 0.5:
		_R(58, oy - 2, 5, 5, CY[3], 0.35)
	for j in 2:
		var g := t * 3.0 + j * PI
		var rr := 4.0 + 3.0 * k
		_R(60.0 + cos(g) * rr, oy + sin(g) * rr * 0.5, 1, 1, CY[4], 0.9)


## Feu follet (retour de l'Ingénieur) : halo, croix, cœur blanc qui scintille ; s = taille de 0 à 1.
static func wisp(ci: CanvasItem, at: Vector2, s: float, t: float) -> void:
	if s <= 0.0:
		return
	var p := at.round()
	ci.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 5)), Color(CY[2], 0.25 * s))
	ci.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(3, 5)), Color(CY[2], 0.3 * s))
	ci.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 3)), Color(CY[2], 0.3 * s))
	if s > 0.5:
		ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), CY[3])
		ci.draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 5)), Color(CY[3], 0.8))
		ci.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), Color(CY[3], 0.8))
	ci.draw_rect(Rect2(p, Vector2.ONE), CY[4])
	var g := int(floorf(t * 14.0))
	ci.draw_rect(Rect2(p + Vector2(g % 3 - 1, (g * 5) % 3 - 1), Vector2.ONE), Color(CY[4], 0.9))


## Colonne de lumière : jaillit du puits en s'évasant au pied ; stries et étincelles qui montent.
func _beam(S: Dictionary, m: float) -> void:
	var t: float = S.t
	var k := _ease(_ph(S.rise, 0.3, 1.0))
	m *= float(S.get("beam", 1.0))
	if k <= 0.0 or m <= 0.0:
		return
	var ws: float = S.get("ws", 1.0)
	var top := roundi(57.0 - 53.0 * k)
	var pulse := 0.8 + 0.2 * sin(t * PI) if S.lit >= 1.0 else 1.0
	# Un rectangle d'un pixel par point de la colonne : boucle resserrée (même calcul que _R, sans l'appel).
	var c4: Color = CY[4]
	var c3: Color = CY[3]
	var c2: Color = CY[2]
	var ox := _base.x - 60.0
	var oy := _base.y - 62.0
	var k0 := 0
	for r: Array in _beam_rows:
		var y: int = r[0]
		var x0: int = r[1]
		var x1: int = r[2]
		if y < top:
			k0 += x1 - x0 + 1
			continue
		var fade := clampf((y - top) / 12.0, 0.0, 1.0)
		var ph := (y + t * 30.0) * 0.5
		var half := (x1 - x0 + 1) * 0.5 * ws
		for x in range(x0, x1 + 1):
			if ws < 1.0 and absf(x + 0.5 - 60.0) > half:
				k0 += 1
				continue
			var s := 0.5 + 0.5 * sin(x * 1.7 + ph)
			var col: Color = c4 if _beam_core[k0] else (c3 if s > 0.7 else c2)
			var a := m * _beam_base[k0] * fade * pulse * (0.75 + 0.25 * s)
			k0 += 1
			if a > 0.0:
				_ci.draw_rect(Rect2(ox + x, oy + y, 1.0, 1.0), Color(col, col.a * minf(a, 1.0)))
	if S.lit >= 1.0 and ws >= 1.0:
		for i in 6:
			var f := fmod(t * 0.9 + i / 6.0, 1.0)
			_R(53 + (i * 5) % 14, roundi(56.0 - f * 48.0), 1, 1, CY[4], m * (1.0 - f))
	if S.rise < 1.0:
		_R(53, top, 14, 1, CY[4], 0.9 * m)


## Grains de lumière qui montent dans la colonne (L2).
func _motes(S: Dictionary) -> void:
	var top: float = 4.0 + 54.0 * (1.0 - S.rise)
	for i in 7:
		var k := fmod(S.t * 0.3 + i * 0.157, 1.0)
		var yb := roundi(57.0 - k * 53.0)
		if yb < top:
			continue
		var x := 49 + (i * 5 + 3) % 22 + (1 if sin(S.t * 2.5 + i * 2) > 0.4 else 0)
		if absf(x - 59.5) > 8.0 + maxf(0.0, (yb - 40) / 17.0) * 4.0:
			continue
		_R(x, yb, 1, 1, CY[4], 0.9 * (1.0 - k * 0.6))


## Ingénieur en lévitation au-dessus du puits (nœud Occupant, shader de teinte).
func _draw_occupant() -> void:
	var S := _state()
	var rt: float = S.get("res", INF)
	var frames := TyrienArt.anim("idle")
	if frames.is_empty():
		return
	_occupant.draw_set_transform(-position)
	if rt < 0.0:
		# Le souffle, avant le retour : la silhouette de lumière se forme dans la colonne qui se resserre, yeux clos.
		var a := _ph(rt, -EngineerReturn.RES_PRE, -EngineerReturn.RES_PRE + 0.35)
		_occupant.draw_texture(frames[30 % frames.size()], _base + Vector2(-24, 57 - HOVER - 62 - 45), Color(1.0, 0.0, 0.0, a))
		return
	if not GameState.in_capsule or S.lit < 1.0:
		return
	# Il rouvre les yeux 0,4 s après le souffle (image 30 du repos = paupières closes).
	var tex: AtlasTexture = frames[30 % frames.size()] if rt < 0.4 else frames[int(floorf(S.t * 12.0)) % frames.size()]
	var fy := 57 - HOVER + roundi(sin(S.t * 1.6))
	var p := _base + Vector2(60 - 60 - 24, fy - 62 - 45)
	if rt < 0.3:
		_occupant.draw_texture(tex, p, Color(0.45 + 0.55 * (1.0 - rt / 0.3), 0.0, 0.0, 1.0))
		return
	for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
		_occupant.draw_texture(tex, p + o, Color(1.0, 0.0, 0.0, 0.55))
	_occupant.draw_texture(tex, p, Color(0.45, 0.0, 0.0, 1.0))


## Devant l'Ingénieur : voile de la colonne, bornes avant, voyant.
func _draw_front(S: Dictionary) -> void:
	if S.occ and S.lit >= 1.0:
		_beam(S, 0.16)
	_pylon(47, 63, 2, S)
	_pylon(73, 63, 3, S)
	_R(56, 63, 8, 3, K)
	_R(57, 64, 6, 1, STONE[2])
	_lamp(59, 64, S)
	# Le souffle : le cercle runique se rallume en dernier (Templier), éclat en croix sur le plastron.
	var rt: float = S.get("res", INF)
	if rt >= 0.55 and rt < 0.8 and not TyrienArt.ragged():
		var a := 1.0 - (rt - 0.55) / 0.25
		var y := 57 - HOVER + roundi(sin(S.t * 1.6)) - 14
		_R(60, y, 7, 1, CY[4], a)
		_R(63, y - 3, 1, 7, CY[4], a)
		_R(62, y - 1, 3, 3, CY[4], a)


## Par-dessus les sprites : poussière, vapeur, lucioles, invites, PV de l'Exilé.
func _draw_top(S: Dictionary) -> void:
	_front = self
	_overlays(S)
	var top := _base + Vector2(0, -36)
	var label := ""
	if Opening.cinematic():
		pass
	elif GameState.in_capsule:
		label = "E : Sortir" if Capsule.powered() else ""
	elif Capsule.can_enter():
		label = "E : Entrer"
	# Dans la capsule, l'invite passe sous son pied : au-dessus, l'horloge du HUD la cache quand la caméra est
	# sur l'Ingénieur (fin de l'intro, planches/intro-capsule-planche.html).
	_prompt(_base + Vector2(0, 30) if GameState.in_capsule else top, label)
	# Coffre Antique allumé et encore fermé, Ingénieur à un bloc.
	if Capsule.can_open_chest() and not Opening.cinematic():
		_prompt(Proj.nat(CaveShape.CHEST.x, 0.0, CaveShape.CHEST.y).round() + Vector2(0, -40), "E : Ouvrir le Coffre Antique")
	# Ouverture : jauge de recharge de l'Ancre au-dessus du puits.
	var k := Opening.recharge()
	if k >= 0.0:
		var g := Proj.nat(CaveShape.CORE.x, 6.0, CaveShape.CORE.y).round() + Vector2(-20, -12)
		var gauge := Rect2(g, Vector2(40, 4))
		_front.draw_rect(gauge.grow(1.0), Color("#6b4fa8"))
		_front.draw_rect(gauge, Color("#1a1426"))
		_front.draw_rect(Rect2(gauge.position, Vector2(roundf(gauge.size.x * k), gauge.size.y)), Color("#b48cff"))
		PixelText.draw(_front, gauge.position + Vector2(gauge.size.x * 0.5, -3), "ANCRE  %d %%" % roundi(k * 100.0), Color("#e6d8ff"), 1)
	# Dans la capsule : PV de l'Exilé au-dessus (la capsule le régénère, Capsule.HEAL_RATE).
	var eng := Capsule.engineer() if GameState.in_capsule else null
	if eng != null:
		var bar := Rect2((top + Vector2(-11, -29)).round(), Vector2(22, 4))
		_front.draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
		_front.draw_rect(bar, Color("#2a1512"))
		_front.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(eng.hp / eng.max_hp, 0.0, 1.0)), bar.size.y)), UnitView.HP_ALLY)
	if not Opening.cinematic():
		var anchor_label := ""
		if Capsule.can_wake_anchor():
			anchor_label = "E : Réactiver l’Ancre"
		elif Capsule.can_pray_anchor():
			anchor_label = "E : Cesser de prier" if Capsule.praying(GameState.incarnated) else "E : Prier"
		_prompt(Proj.nat(CaveShape.CORE.x, 6.0, CaveShape.CORE.y).round() + Vector2(0, 4), anchor_label)


func _overlays(S: Dictionary) -> void:
	var t: float = S.t
	# Poussière (éteinte) : un grain se détache d'une borne.
	if S.mode == 0:
		var dust := [[46, 47], [74, 47]]
		for i in 2:
			var k := fmod(t + i * 2.1, 4.2) / 1.1
			if k < 1.0:
				_R(dust[i][0], roundi(dust[i][1] + k * k * (62 - dust[i][1])), 1, 1, Color("#a3a9b3"), 0.85)
	# Crépitement en attente au pied, jusqu'à l'arrivée du trait.
	if S.mode == 0 or (S.mode == 1 and S.bt < 0.8):
		var k := fmod(t, 2.7)
		if k < 0.22:
			var sd := floorf(t / 2.7) * 7.0 + floorf(k * 24.0)
			for j in 3:
				_R(57 + roundi(_hash(sd + j) * 6.0), 61 - roundi(_hash(sd + j + 9) * 3.0), 1, 1, CY[3], 0.75)
	if S.mode == 1:
		var bt: float = S.bt
		if bt >= 0.8 and bt < 1.15:
			var k := (bt - 0.8) / 0.35
			var r := 1.0 + k * 8.0
			for j in 8:
				var g := j * PI / 4.0 + 0.3
				_R(60 + roundi(cos(g) * r), 61 + roundi(sin(g) * r * 0.5), 1, 1, CY[4], 1.0 - k)
			var kd := _ph(bt, 0.85, 1.45)
			if kd > 0.0 and kd < 1.0:
				for x in [46, 74]:
					_R(x, roundi(47 + kd * kd * 15.0), 1, 1, Color("#a3a9b3"), 0.9)
		if S.settle >= 0.0:
			for j in 4:
				var side := 1 if j % 2 else -1
				var k := _ph(S.settle, j * 0.14, 1.3 + j * 0.14)
				if k > 0.0 and k < 1.0:
					var r := 1.0 + k * 3.0
					_EL(60 + side * roundi(17.0 + k * 6.0 + j), roundi(60.0 - k * 8.0 - j), r, r * 0.8, Color("#d6e2ea"), 0.5 * (1.0 - k))
	# Lucioles qui s'échappent du haut de la colonne.
	if S.lit >= 1.0:
		for i in 4:
			var k := fmod(t * 0.35 + i * 0.25, 1.0)
			_R(59 + (3 if i % 2 else -2) + roundi(sin(t * 2.0 + i * 1.7) * 2.0), roundi(2.0 - k * 16.0), 1, 1, CY[3] if i % 2 else CY[4], 1.0 - k)


## Borne basse à pointe de quartz ; elles s'allument une à une pendant la montée.
func _pylon(x: int, y: int, i: int, S: Dictionary) -> void:
	var h := 6
	_R(x - 2, y - h, 5, h + 1, K)
	_R(x - 1, y - h + 1, 3, h - 1, IRON[2])
	_R(x - 1, y - h + 1, 1, h - 1, IRON[3])
	_R(x - 2, y - h - 2, 5, 3, K)
	_R(x - 1, y - h - 1, 3, 1, BRZ[3])
	var on: bool = S.rise > i * 0.22 + 0.05 or S.lit >= 1.0
	if S.has("pyl"):
		on = S.pyl[i]
	if on:
		_R(x - 2, y - h - 6, 5, 5, CY[2], 0.3)
	_R(x - 1, y - h - 5, 3, 3, K)
	_R(x, y - h - 5, 1, 3, CY[4] if on else Color("#4a515d"))
	_R(x - 1, y - h - 4, 1, 1, CY[3] if on else Color("#3a414c"))
	_R(x + 1, y - h - 4, 1, 1, CY[2] if on else Color("#2b313a"))


## Voyant sur la margelle : rouge qui bat (éteinte), rouge/ambre (allumage), ambre (allumée), cyan (occupée).
func _lamp(x: int, y: int, S: Dictionary) -> void:
	var col := Color("#4a1c19")
	var glow := 0.0
	if S.lamp == "off":
		var k := fmod(S.t, 2.6)
		if k < 0.14 or (k > 0.3 and k < 0.44):
			col = Color("#d0483c")
			glow = 0.3
	elif S.lamp == "dim":
		col = CY[0]
	elif S.lamp == "boot":
		col = Color("#d0483c") if int(floorf(S.t * 12.0)) % 3 else Color("#ffcf6a")
		glow = 0.25
	else:
		col = Color("#9fe6ff") if S.occ else Color("#ffcf6a")
		glow = 0.28
	if glow > 0.0:
		_R(x - 1, y - 1, 4, 4, col, glow)
	_R(x, y, 2, 2, col)


## Trait d'énergie au sol, de l'Ancre à la capsule.
func _draw_link() -> void:
	var s := GameState.opening_stage
	var k := 0.0
	var alpha := 1.0
	if s == "link":
		k = clampf(Opening.elapsed() / Opening.LINK_LEN, 0.0, 1.0)
	elif s == "awake":
		# Arrivé : quelques secondes allumé, puis il s'éteint.
		k = 1.0
		alpha = 1.0 - clampf((Opening.elapsed() - Opening.LINK_HOLD) / Opening.LINK_FADE, 0.0, 1.0)
	if k <= 0.0 or alpha <= 0.0:
		return
	var a := Proj.nat(CaveShape.CORE.x, 0.0, CaveShape.CORE.y - 1.5)  # arrière du puits
	var b := Proj.nat(Capsule.POS.x, 0.0, Capsule.POS.y + 1.0)
	var head := a.lerp(b, k)
	var t := GameState.sim_time
	var seg := 24
	var n := maxi(1, ceili(seg * k))
	var prev := a
	for i in range(1, n + 1):
		var f := minf(float(i) / seg, k)
		var p := a.lerp(b, f)
		# Petite ondulation qui frémit, nulle aux deux bouts.
		p.x += sin(f * 19.0 + floorf(t * 12.0) * 1.7) * 1.2 * sin(f * PI)
		draw_line(prev.round(), p.round(), Color(LINE, 0.35 * alpha), 3.0)
		draw_line(prev.round(), p.round(), Color(LINE_CORE, 0.9 * alpha), 1.0)
		prev = p
	if k < 1.0:
		# Tête du trait : éclat et étincelles.
		draw_circle(head.round(), 3.0, Color(LINE, 0.5))
		draw_circle(head.round(), 1.5, LINE_CORE)
		for j in 4:
			var ang := t * 9.0 + j * TAU / 4.0
			draw_rect(Rect2((head + Vector2(cos(ang), sin(ang) * 0.5) * 4.0).round(), Vector2.ONE), LINE_CORE)
	else:
		# Conduit établi : impulsions qui montent vers la capsule.
		for j in 2:
			var f := fmod(t * 0.6 + j * 0.5, 1.0)
			draw_circle(a.lerp(b, f).round(), 1.5, Color(LINE_CORE, 0.8 * alpha))


## Invite « E : … » : petite bannière 16 bits (même cadre que les dialogues) et texte bitmap, en pixels natifs.
func _prompt(top: Vector2, label: String) -> void:
	if label != "":
		var tw := PixelText.width(label, 1)
		var box := Rect2((top + Vector2(-tw * 0.5 - 6, -25)).round(), Vector2(tw + 12, 15))
		SnesBanner.paint(_front, box, SnesBanner.DIALOGUE, true)
		PixelText.draw(_front, box.position + Vector2(box.size.x * 0.5, 11), label, SnesBanner.INK, 1)


# ---------- primitives pixel (repère de la planche : pied en (60, 62)) ----------

func _R(x: float, y: float, w: float, h: float, col: Color, a := 1.0) -> void:
	if w <= 0.0 or h <= 0.0 or a <= 0.0:
		return
	_ci.draw_rect(Rect2(_base + Vector2(roundf(x) - 60.0, roundf(y) - 62.0), Vector2(roundf(w), roundf(h))), Color(col, col.a * minf(a, 1.0)))


func _EL(cx: float, cy: float, rx: float, ry: float, col: Color, a := 1.0) -> void:
	var n := floori(ry)
	for y in range(-n, n + 1):
		var hw := roundf(rx * sqrt(maxf(0.0, 1.0 - pow(y / (ry + 0.5), 2.0))))
		_R(cx - hw, cy + y, 2.0 * hw + 1.0, 1.0, col, a)


## Contour d'ellipse ; half = 1 : seulement la moitié avant (bas).
func _RING(cx: float, cy: float, rx: float, ry: float, col: Color, a := 1.0, half := 0) -> void:
	var n := ceili(rx * 8.0) + 8
	var seen := {}
	for i in n:
		var g := float(i) / n * TAU
		var s := sin(g)
		if half == 1 and s <= 0.0:
			continue
		var p := Vector2(roundf(cx + cos(g) * rx), roundf(cy + s * ry))
		if seen.has(p):
			continue
		seen[p] = true
		_R(p.x, p.y, 1, 1, col, a)


static func _ph(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func _hash(n: float) -> float:
	var v := sin(n * 127.1 + 311.7) * 43758.5453
	return v - floorf(v)
