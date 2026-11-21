class_name ResearchCard
extends Control
## Fiche de recherche du panneau central (planches/recherches-interface-propositions.html, piste A, 2026-11-21) :
## pour un bâtiment, le panneau des statistiques (vide) montre la recherche survolée, sinon celle qui avance, sinon
## la première. Icône 64 px, nom et touche, effet, coût en pastilles (en rouge : stock / besoin), état en clair.

const Icon := preload("res://ui/inventory/item_icon.gd")
const RES_ICONS := {"forge": "iron", "vie": "heart", "discipline": "shield", "savoir": "book"}
const RES_COLORS := {"forge": Color("#8f8cf0"), "vie": Color("#6fcf78"), "discipline": Color("#f29a45"), "savoir": Color("#c3c6cf")}
const GOLD_HI := Color("#e6c889")
const OK := Color("#a8d890")
const BAD := Color("#f0a090")
const RUN := Color("#d6f6fb")
const ICON := 64.0

var id := ""
var key := ""
## Signature du dernier dessin : la fiche ne se redessine que si quelque chose a changé.
var _sig: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_research(research_id: String, research_key: String) -> void:
	var st := HudModel.research_state(research_id)
	var sig: Array = [research_id, research_key, st, HudModel.research_cost_lines(research_id), size]
	if sig == _sig:
		return
	_sig = sig
	id = research_id
	key = research_key
	queue_redraw()


func _draw() -> void:
	if id == "" or not Catalog.RESEARCH.has(id):
		return
	var R: Dictionary = Catalog.RESEARCH[id]
	var st := HudModel.research_state(id)
	var f := HudStyle.font()
	var h := size.y
	# Icône pleine (comme une fois achevée), cadre de laiton.
	var fr := Rect2(0.0, floorf((h - ICON - 6.0) / 2.0), ICON + 6.0, ICON + 6.0)
	draw_rect(fr, Color("#0c1a1e"))
	HudStyle.ring(self, fr, 1.0, HudStyle.GOLD_LIGHT if st["kind"] == "ready" else HudStyle.GOLD)
	var tint := Color(0.55, 0.55, 0.52) if st["kind"] in ["poor", "locked"] else Color.WHITE
	draw_texture_rect(ActionButton._Glyph._full_tex(id), Rect2(fr.position + Vector2(3, 3), Vector2(ICON, ICON)), false, tint)
	var x := fr.end.x + 12.0
	var w := size.x - x
	# Ligne 1 : touche et nom.
	var y := 2.0
	var nx := x
	if key != "" and st["kind"] in ["ready", "poor"]:
		var kw := HudStyle.text_width(key, 11) + 8.0
		var kr := Rect2(x, y + 3.0, kw, 15.0)
		draw_rect(kr, GOLD_HI if st["kind"] == "ready" else Color("#5a1e22"))
		draw_string(f, Vector2(kr.position.x + 4.0, kr.position.y + 12.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color("#101511") if st["kind"] == "ready" else Color("#ffe0d4"))
		nx += kw + 7.0
	draw_string(f, Vector2(nx, y + 16.0), R["name"], HORIZONTAL_ALIGNMENT_LEFT, size.x - nx, 17, GOLD_HI)
	y += 22.0
	# Ligne 2 : effet, deux lignes au plus.
	var desc := String(R.get("desc", ""))
	var lines := 2 if h >= 92.0 else 1
	if desc != "":
		draw_multiline_string(f, Vector2(x, y + f.get_ascent(12)), desc, HORIZONTAL_ALIGNMENT_LEFT, w, 12, lines, HudStyle.IVORY,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND, TextServer.JUSTIFICATION_NONE)
		var used := mini(lines, ceili(f.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, w, 12).y / f.get_height(12)))
		y += f.get_height(12) * used + 4.0
	# Ligne 3 : coût en pastilles (payé quand la recherche est lancée).
	var cx := x
	var paid: bool = st["kind"] in ["run", "stopped", "queue"]
	for line: Dictionary in HudModel.research_cost_lines(id):
		var short: bool = not paid and line["have"] < line["need"]
		var txt := ("%d/%d" % [line["have"], line["need"]]) if short else str(line["need"])
		if line.has("res"):
			var tex := HudStyle.icon(RES_ICONS[line["res"]], 16)
			draw_texture_rect(tex, Rect2(cx, y, 16, 16), false, RES_COLORS[line["res"]])
		else:
			Icon.draw_item(self, line["item"], Vector2(cx + 8.0, y + 8.0), 0.5)
		cx += 19.0
		draw_string(f, Vector2(cx, y + 13.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BAD if short else HudStyle.IVORY)
		cx += HudStyle.text_width(txt, 13) + 11.0
	if paid:
		draw_string(f, Vector2(cx, y + 13.0), "payé", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudStyle.MUTED)
	y += 20.0
	# Ligne 4 : état, avec la jauge quand la recherche avance.
	var col: Color = {"ready": OK, "run": RUN, "stopped": BAD, "queue": RUN, "poor": BAD, "locked": BAD}.get(st["kind"], HudStyle.MUTED)
	var tx := x
	if st["kind"] in ["run", "stopped"]:
		var bw := minf(160.0, w * 0.4)
		var br := Rect2(x, y + 5.0, bw, 6.0)
		draw_rect(br, Color("#0a1a1f"))
		draw_rect(Rect2(br.position, Vector2(roundf(bw * clampf(st.get("progress", 0.0), 0.0, 1.0)), 6.0)), Color("#5fa9b8") if st["kind"] == "run" else Color("#7a5048"))
		HudStyle.ring(self, br.grow(1.0), 1.0, Color("#1b4652"))
		tx += bw + 10.0
	var state_text: String = st["text"]
	if st["kind"] == "ready" and key != "":
		state_text += " · touche " + key
	draw_string(f, Vector2(tx, y + 13.0), state_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx, 13, col)
