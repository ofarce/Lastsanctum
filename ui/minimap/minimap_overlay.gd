class_name MinimapOverlay
## Recherche « Minicarte » : TAB ou M affiche la minicarte en plein écran, opaque à 40 % (transparence
## 60 %), avec la position du joueur en point doré. Elle reprend l'image de la minicarte du HUD, dont la
## fenêtre suit la caméra (donc le joueur incarné). Ne capte pas la souris : le jeu continue dessous.
##
## Carte des portails (PortalNet, planche « Portails de Merenor », choix 1) : E sur le seuil d'un portail
## ouvert l'affiche sans recherche, cadrée sur tout le réseau : liens entre les portails ouverts, pylônes en
## reflux en rouge avec leur minuteur, survol = nom et état, clic = voyage. Elle capte alors la souris ;
## Échap, E, TAB ou M la ferment.
extends Control

var opacity := 0.4
const SCREEN_VEIL := 0.25
const MAP_VEIL := 0.6
## Éclaircissement de la carte : ses teintes (jungle, roche, brouillard) sont trop sombres sur le voile.
const BRIGHTEN := 1.8
const GOLD := Color("#ffd24a")

var minimap: Minimap
var world: World
var sim: Simulation
## Nœud d'où la carte des portails a été ouverte (PortalNet.NO_MAP hors de ce mode) et nœud survolé.
var portal_from := PortalNet.NO_MAP
var _hover := PortalNet.NO_MAP
const NODE_R := 11.0
const LINK := Color("#5fa9b8")
const LINK_HOT := Color("#d6f6fb")
const RED := Color("#e0583a")
const RED_DIM := Color("#6e1a1c")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	Events.portal_map.connect(_on_portal_map)
	Events.game_reset.connect(_on_portal_map.bind(PortalNet.NO_MAP))


static func available() -> bool:
	return GameState.research_done.has("minimap")


func toggle() -> void:
	if portal_from != PortalNet.NO_MAP:
		_on_portal_map(PortalNet.NO_MAP)
		return
	visible = not visible and available()
	queue_redraw()


func portal_mode() -> bool:
	return portal_from != PortalNet.NO_MAP


func _on_portal_map(from_id: int) -> void:
	portal_from = from_id
	PortalNet.map_from = from_id
	_hover = PortalNet.NO_MAP
	if from_id == PortalNet.NO_MAP:
		Minimap.focus = Rect2()
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		Minimap.focus = _network_window()
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
	if minimap != null and world != null:
		minimap.refresh()
	queue_redraw()


## Fenêtre qui contient tout le réseau (pylônes éveillés, Ancre, Exilé), aux proportions de la minicarte,
## bornée à la carte.
func _network_window() -> Rect2:
	var pts: Array[Vector2] = [CaveShape.CORE, _player_pos()]
	if world != null and world.terrain_state != null:
		for p: Dictionary in world.terrain_state.portals:
			if p.get("active", false):
				pts.append(Vector2(p["x"], p["z"]))
	var box := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		box = box.expand(q)
	box = box.grow(40.0)
	var ratio := float(Minimap.W) / Minimap.H
	var s := box.size
	s = Vector2(maxf(s.x, s.y * ratio), maxf(s.y, s.x / ratio))
	s = s.max(Minimap.start_window().size)
	var world_size := Vector2(CaveShape.WORLD_X1 - CaveShape.WORLD_X0, CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0)
	s = s.min(world_size).floor()
	var o := box.get_center() - s / 2.0
	o.x = clampf(o.x, CaveShape.WORLD_X0, CaveShape.WORLD_X1 - s.x)
	o.y = clampf(o.y, CaveShape.WORLD_Z0, CaveShape.WORLD_Z1 - s.y)
	return Rect2(o.floor(), s)


func _process(_delta: float) -> void:
	if visible and not available() and not portal_mode():
		visible = false
	# L'Exilé quitte le seuil, part en voyage ou meurt : la carte des portails se ferme.
	if portal_mode():
		var eng: Unit = GameState.incarnated
		if eng == null or not eng.alive() or PortalNet.warping(eng) or world == null \
				or PortalNet.node_at(world.terrain_state, eng.pos()).is_empty():
			_on_portal_map(PortalNet.NO_MAP)
	if visible:
		# Le conteneur du HUD n'a pas de taille propre : on couvre l'écran.
		position = Vector2.ZERO
		size = get_viewport_rect().size
		queue_redraw()


## Position du joueur : l'Exilé incarné, sinon le centre de la caméra.
func _player_pos() -> Vector2:
	var u: Variant = GameState.incarnated
	if u != null and is_instance_valid(u):
		return Vector2(u.x, u.z)
	return world.camera.cam if world != null else Vector2.ZERO


## Rectangle d'affichage : fenêtre du monde à ses proportions réelles, centrée, marge de 4 %.
func _map_rect() -> Rect2:
	var avail := size * 0.92
	var ratio := Minimap.win.size.x / Minimap.win.size.y
	var s := Vector2(avail.x, avail.x / ratio)
	if s.y > avail.y:
		s = Vector2(avail.y * ratio, avail.y)
	return Rect2((size - s) / 2.0, s)


func _draw() -> void:
	if minimap == null or minimap._tex == null or size.x < 32.0 or size.y < 32.0:
		return
	var r := _map_rect()
	# Voile sombre : léger sur l'écran, plus dense sous la carte, pour qu'elle se détache du jeu.
	# Carte des portails : plus couvrante, on y choisit une destination plutôt qu'on ne joue dessous.
	var pm := portal_mode()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 if pm else SCREEN_VEIL))
	draw_rect(r, Color(0, 0, 0, 0.85 if pm else MAP_VEIL))
	var fade := Color(BRIGHTEN, BRIGHTEN, BRIGHTEN, 0.8 if pm else opacity)
	draw_texture_rect(minimap._tex, r, false, fade)
	HudStyle.ring(self, r.grow(2.0), 1.0, Color(HudStyle.GOLD, 0.8))
	minimap.draw_pings(self, r, 2.0)
	# Point doré du joueur (halo sombre pour la lisibilité).
	var p := _player_pos()
	var q := r.position + Minimap.map_pt(p.x, p.y) / Vector2(Minimap.W, Minimap.H) * r.size
	if r.grow(-2.0).has_point(q):
		var t := float(Time.get_ticks_msec() % 1200) / 1200.0
		draw_circle(q, 10.0 + 4.0 * t, Color(GOLD, 0.35 * (1.0 - t)))
		draw_circle(q, 7.0, Color(0, 0, 0, 0.7))
		draw_circle(q, 5.0, GOLD)
	_draw_network(r)


# ---------------------------------------------------------------- Carte des portails

func _to_map(r: Rect2, at: Vector2) -> Vector2:
	return r.position + Minimap.map_pt(at.x, at.y) / Vector2(Minimap.W, Minimap.H) * r.size


func _draw_network(r: Rect2) -> void:
	if world == null or world.terrain_state == null:
		return
	var st := world.terrain_state
	var font := HudStyle.font()
	var t := float(Time.get_ticks_msec()) / 1000.0
	var nodes := PortalNet.nodes(st)
	var open := nodes.filter(func(n: Dictionary) -> bool: return n["open"])
	# Liens entre portails ouverts ; celui du départ vers le nœud survolé, plein et animé.
	for i in open.size():
		for j in range(i + 1, open.size()):
			var a: Dictionary = open[i]
			var b: Dictionary = open[j]
			var hot := portal_mode() and ((int(a["id"]) == portal_from and int(b["id"]) == _hover) or (int(b["id"]) == portal_from and int(a["id"]) == _hover))
			_dashed(_to_map(r, Vector2(a["pos"])), _to_map(r, Vector2(b["pos"])), LINK_HOT if hot else Color(LINK, 0.55), 3.0 if hot else 2.0, t * 20.0 if hot else 0.0)
	# Pylônes sauvages découverts : rouge sourd, hors du réseau.
	for p: Dictionary in st.portals:
		if p.get("active", false) and not PortalNet.linked(p) and world.fog.visible_at(Vector2(p["x"], p["z"])):
			_node_icon(_to_map(r, Vector2(p["x"], p["z"])), "wild", t)
	for n: Dictionary in nodes:
		var q := _to_map(r, n["pos"])
		var kind := "base" if int(n["id"]) == PortalNet.ANCHOR_ID else ("open" if n["open"] else "reflux")
		_node_icon(q, kind, t)
		var label: String = n["name"]
		draw_string(font, q + Vector2(-80, NODE_R + 16), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#c9cdd6"))
		if kind == "reflux":
			var rem := PortalNet.reflux_remaining(n["pylon"])
			var line := "reflux %d:%02d · fermé" % [ceili(rem) / 60, ceili(rem) % 60] if rem >= 0.0 else "reflux · fermé"
			draw_string(font, q + Vector2(-80, NODE_R + 31), line, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#ffb48a"))
		if portal_mode() and int(n["id"]) == portal_from:
			draw_arc(q, NODE_R + 6.0 + 2.0 * sin(t * 4.0), 0.0, TAU, 28, Color(GOLD, 0.8), 2.0)
	if not portal_mode():
		return
	draw_string(font, r.position + Vector2(12, 22), "Carte des portails  ·  clic : voyager  ·  Échap : fermer", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d6f6fb"))
	var h := PortalNet.node(st, _hover)
	if h.is_empty():
		return
	var lines: Array = [[h["name"], Color.WHITE]]
	var hp: Dictionary = h["pylon"]
	if int(h["id"]) == PortalNet.ANCHOR_ID:
		lines.append(["La base · toujours ouvert", Color("#d6f6fb")])
	else:
		lines.append(["%d / 4 esprits en prière" % (hp.get("praying", []) as Array).size(), Color("#d6f6fb")])
	if int(h["id"]) == portal_from:
		lines.append(["Vous êtes ici", Color("#ffd24a")])
	elif h["open"]:
		lines.append(["Clic : y aller", Color("#ffb48a")])
	else:
		lines.append(["Fermé pendant le reflux", Color("#ffb48a")])
	var w := 0.0
	for l: Array in lines:
		w = maxf(w, font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var box := Rect2(_to_map(r, h["pos"]) + Vector2(NODE_R + 14.0, -NODE_R - 8.0), Vector2(w + 24.0, lines.size() * 18.0 + 14.0))
	box.position = box.position.clamp(Vector2(4, 4), size - box.size - Vector2(4, 4))
	SnesBanner.paint(self, box, SnesBanner.INFO)
	for i in lines.size():
		draw_string(font, box.position + Vector2(12, 21 + i * 18), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lines[i][1])


## Icône d'un nœud : Ancre dorée, pylône ouvert aux quatre arcs des cultes, reflux rouge qui clignote,
## pylône sauvage rouge sourd.
func _node_icon(q: Vector2, kind: String, t: float) -> void:
	draw_circle(q, NODE_R + 3.0, Color(0, 0, 0, 0.6))
	if kind == "base":
		draw_circle(q, 8.0 + sin(t * 3.0), GOLD)
		return
	for k in 4:
		var c: Color
		match kind:
			"open":
				c = WorldOverlay.BEAM_CULT[Pylons.CULTS[k]]
			"reflux":
				c = RED if fposmod(t * 1.5, 1.0) < 0.5 else RED_DIM
			_:
				c = Color("#5a2024")
		draw_arc(q, NODE_R, -PI + k * PI / 2.0, -PI / 2.0 + k * PI / 2.0, 8, c, 4.0)
	var core := Color.WHITE if kind == "open" else Color("#2a0c10")
	draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(3, 5), q + Vector2(-3, 5)]), core)


func _dashed(a: Vector2, b: Vector2, c: Color, w: float, shift: float) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var dir := (b - a) / d
	var s := -fposmod(shift, 12.0)
	while s < d:
		var s0 := maxf(0.0, s)
		var s1 := minf(d, s + 6.0)
		if s1 > s0:
			draw_line(a + dir * s0, a + dir * s1, c, w)
		s += 12.0


func _node_under(local: Vector2) -> int:
	if world == null:
		return PortalNet.NO_MAP
	var r := _map_rect()
	for n: Dictionary in PortalNet.nodes(world.terrain_state):
		if _to_map(r, n["pos"]).distance_to(local) <= NODE_R + 8.0:
			return int(n["id"])
	return PortalNet.NO_MAP


func _gui_input(event: InputEvent) -> void:
	if not portal_mode():
		return
	if event is InputEventMouseMotion:
		var h := _node_under(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_on_portal_map(PortalNet.NO_MAP)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var id := _node_under(event.position)
		if id == PortalNet.NO_MAP or id == portal_from or sim == null:
			return
		var eng: Unit = GameState.incarnated
		if PortalNet.travel(sim, eng, id):
			_on_portal_map(PortalNet.NO_MAP)
