class_name ResearchGrimoire
extends Control
## Grimoire des recherches (planches/recherches-interface-propositions.html, piste D, 2026-11-21) : fenêtre plein écran
## qui range toutes les recherches par bâtiment, avec leur état (achevée, en cours, en file, prête, trop chère,
## bâtiment absent). Touche X, ou la plaque au livre en tête de la rangée du haut à gauche ; X, Échap ou clic hors de
## la fenêtre la referment. Un clic sur une recherche prête la lance (ou la met en file) dans le premier bâtiment
## achevé de son type. La fiche du bas montre la recherche survolée.

const KEY := "X"
const NODE_H := 58.0
const GAP := 8.0
const PAD := 18.0
const HEAD_H := 44.0
const COL_HEAD := 24.0
const CARD_H := 96.0
const MAX_W := 1180.0
const SEAL := Color("#3f7a3a")
const COLORS := {"done": Color("#a8d890"), "run": Color("#d6f6fb"), "stopped": Color("#f0a090"), "queue": Color("#d6f6fb"),
	"ready": Color("#e6c889"), "poor": Color("#f0a090"), "locked": Color("#f0a090"), "absent": Color("#8a8a7a")}

var sim: Simulation
var _hover := ""
var _rects := {}
var _card := ResearchCard.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_child(_card)


func toggle() -> void:
	visible = not visible
	_hover = ""
	queue_redraw()


## Types de bâtiment à recherches, dans l'ordre du catalogue.
static func building_types() -> Array[String]:
	var out: Array[String] = []
	for id: String in Catalog.RESEARCH:
		var t: String = Catalog.RESEARCH[id]["building"]
		if not out.has(t):
			out.append(t)
	return out


## Premier bâtiment achevé de ce type (celui où la recherche se lance), sinon null.
static func host(type: String) -> Building:
	for b: Building in GameState.buildings:
		if b.type == type and b.complete:
			return b
	return null


func _state(id: String) -> Dictionary:
	var st := HudModel.research_state(id)
	if st["kind"] in ["ready", "poor", "locked"] and host(Catalog.RESEARCH[id]["building"]) == null:
		return {"kind": "absent", "text": "Construire : " + String(Catalog.BUILDINGS[Catalog.RESEARCH[id]["building"]]["name"])}
	return st


func _window() -> Rect2:
	var s := get_viewport_rect().size
	var types := building_types()
	var rows := 0
	for t in types:
		rows = maxi(rows, Catalog.RESEARCH.keys().filter(func(id: String) -> bool: return Catalog.RESEARCH[id]["building"] == t).size())
	var w := minf(MAX_W, s.x - 48.0)
	var h := HEAD_H + COL_HEAD + rows * (NODE_H + GAP) + 12.0 + CARD_H + 30.0 + PAD
	return Rect2(floorf((s.x - w) / 2.0), floorf(maxf(24.0, (s.y - h) / 2.0 - 40.0)), w, h)


func _process(_delta: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at: Vector2 = event.position
		var over := ""
		for id: String in _rects:
			if (_rects[id] as Rect2).has_point(at):
				over = id
		_hover = over
	elif event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not _window().has_point(event.position):
			toggle()
			return
		if _hover != "" and sim != null:
			var b := host(Catalog.RESEARCH[_hover]["building"])
			if b != null and Simulation.can_research(b, _hover):
				Sfx.play("ui_clic")
				sim.start_research(b, _hover)


func _draw() -> void:
	var f := HudStyle.font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var win := _window()
	draw_rect(win.grow(3.0), Color("#0a1d24"))
	draw_rect(win, Color("#0d2329f5"))
	HudStyle.ring(self, win, 2.0, Color("#5fa9b8"))
	HudStyle.ring(self, win.grow(-3.0), 1.0, Color("#1b4652"))
	var x0 := win.position.x + PAD
	var y := win.position.y + 14.0
	draw_string(f, Vector2(x0, y + 22.0), "Grimoire des recherches", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HudStyle.GOLD_LIGHT)
	var done := GameState.research_done.size()
	var info := "%d achevée%s sur %d · %s ou Échap pour fermer" % [done, "s" if done > 1 else "", Catalog.RESEARCH.size(), KEY]
	draw_string(f, Vector2(win.end.x - PAD - HudStyle.text_width(info, 13), y + 20.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.MUTED)
	y = win.position.y + HEAD_H
	draw_rect(Rect2(x0, y - 6.0, win.size.x - PAD * 2.0, 1.0), Color("#1b4652"))
	var types := building_types()
	var cw := (win.size.x - PAD * 2.0 - GAP * (types.size() - 1)) / types.size()
	var here := HudModel.selected_building()
	_rects.clear()
	for ci in types.size():
		var t := types[ci]
		var cx := x0 + ci * (cw + GAP)
		var built := host(t) != null
		var title := String(Catalog.BUILDINGS[t]["name"]).to_upper() + ("" if built else " · À CONSTRUIRE")
		var hc := HudStyle.GOLD_LIGHT if here != null and here.type == t else (HudStyle.MUTED if built else Color("#6a6a5c"))
		draw_string(f, Vector2(cx, y + 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, cw, 11, hc)
		var ny := y + COL_HEAD
		for id: String in Catalog.RESEARCH:
			if Catalog.RESEARCH[id]["building"] != t:
				continue
			var r := Rect2(cx, ny, cw, NODE_H)
			_rects[id] = r
			_draw_node(f, id, r)
			ny += NODE_H + GAP
	# Fiche de la recherche survolée, en pied de fenêtre.
	var rows_end := win.end.y - PAD - CARD_H - 30.0
	draw_rect(Rect2(x0, rows_end, win.size.x - PAD * 2.0, 1.0), Color("#1b4652"))
	_card.position = Vector2(x0, rows_end + 10.0)
	_card.size = Vector2(win.size.x - PAD * 2.0, CARD_H - 10.0)
	_card.visible = _hover != ""
	if _hover != "":
		_card.show_research(_hover, "")
	else:
		draw_string(f, Vector2(x0, rows_end + 34.0), "Survolez une recherche pour lire son effet ; cliquez sur une recherche prête pour la lancer. Une seule avance par bâtiment, les autres attendent en file.",
			HORIZONTAL_ALIGNMENT_LEFT, win.size.x - PAD * 2.0, 13, HudStyle.MUTED)
	# Légende.
	var lx := x0
	var ly := win.end.y - PAD - 6.0
	for e: Array in [["done", "Achevée"], ["run", "En cours"], ["queue", "En file"], ["ready", "Prête"], ["poor", "Trop chère"], ["absent", "Bâtiment absent"]]:
		var sw := Rect2(lx, ly - 10.0, 10.0, 10.0)
		HudStyle.ring(self, sw, 1.0, COLORS[e[0]])
		draw_string(f, Vector2(lx + 16.0, ly), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudStyle.MUTED)
		lx += 16.0 + HudStyle.text_width(e[1], 12) + 22.0


func _draw_node(f: Font, id: String, r: Rect2) -> void:
	var st := _state(id)
	var kind: String = st["kind"]
	var hover := id == _hover
	var bg := Color("#10261a") if kind == "done" else Color("#0f2a31")
	draw_rect(r, bg.lightened(0.06) if hover else bg)
	var edge: Color = SEAL if kind == "done" else (COLORS[kind] if kind in ["ready", "run", "queue"] else Color("#1b4652"))
	if hover:
		edge = HudStyle.GOLD_LIGHT
	HudStyle.ring(self, r, 1.0, edge)
	var dim := kind == "absent"
	var tex := ActionButton._Glyph._full_tex(id)
	draw_texture_rect(tex, Rect2(r.position + Vector2(8.0, floorf((r.size.y - 32.0) / 2.0)), Vector2(32, 32)), false,
		Color(1, 1, 1, 0.45) if dim else (Color(0.6, 0.6, 0.58) if kind in ["poor", "locked"] else Color.WHITE))
	var tx := r.position.x + 48.0
	var tw := r.size.x - 54.0
	var name: String = Catalog.RESEARCH[id]["name"]
	var two := HudStyle.text_width(name, 13) > tw
	var ny := r.position.y + (5.0 if two else 12.0)
	draw_multiline_string(f, Vector2(tx, ny + f.get_ascent(13)), name, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, 2,
		Color(HudStyle.IVORY, 0.55) if dim else HudStyle.IVORY)
	var sy := r.end.y - 8.0
	var text: String = st["text"]
	if kind == "run" or kind == "stopped":
		var bw := minf(60.0, tw * 0.35)
		var br := Rect2(tx, sy - 7.0, bw, 5.0)
		draw_rect(br, Color("#0a1a1f"))
		draw_rect(Rect2(br.position, Vector2(roundf(bw * clampf(st.get("progress", 0.0), 0.0, 1.0)), 5.0)), Color("#5fa9b8"))
		tx += bw + 6.0
		tw -= bw + 6.0
		text = text.get_slice(" · ", 1) if kind == "run" else "À l’arrêt"
	elif kind == "queue":
		text = "En file · n° %d" % st["pos"]
	elif kind == "poor" and text.contains(", "):
		text = text.get_slice(", ", 0) + "…"
	elif kind == "ready":
		var b := host(Catalog.RESEARCH[id]["building"])
		text = "Prête · cliquer pour la file" if b != null and not Simulation.research_queue(b).is_empty() else "Prête · cliquer pour lancer"
	draw_string(f, Vector2(tx, sy), text, HORIZONTAL_ALIGNMENT_LEFT, tw, 11, COLORS[kind])
