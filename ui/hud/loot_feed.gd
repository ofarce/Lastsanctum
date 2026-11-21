extends Control
## Objets ramassés par l'Exilé (Events.loot_picked), en haut à gauche : une ligne par objet, « icône Nom ×N »,
## cadre Sarcelle resserré (SnesBanner.INFO), nom à la couleur de rareté quand l'objet n'est pas normal.
## Chaque ligne reste 5 s puis s'efface ; ramasser de nouveau le même objet ajoute à sa quantité et relance
## ses 5 s. Les lignes s'empilent vers le bas, la plus ancienne en haut. Les mods n'y passent pas (sim/loot.gd).

const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const Recipes := preload("res://data/recipes.gd")

const SHOW := 5.0
const FADE := 0.4
const ROW_H := 34.0
const GAP := 4.0
const ICON := 26.0
const FONT_SIZE := 15
const MAX_ROWS := 8

## [{item, count, until}] ; `until` en secondes réelles (le jeu peut être en pause).
var rows: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func add(item: String, count: int) -> void:
	for r: Dictionary in rows:
		if r["item"] == item:
			r["count"] += count
			r["until"] = _now() + SHOW
			queue_redraw()
			return
	rows.append({"item": item, "count": count, "until": _now() + SHOW})
	while rows.size() > MAX_ROWS:
		rows.pop_front()
	queue_redraw()


static func line(item: String, count: int) -> String:
	return "%s ×%d" % [Recipes.name_of(item), count]


func _process(_d: float) -> void:
	if rows.is_empty():
		return
	var now := _now()
	rows = rows.filter(func(r: Dictionary) -> bool: return r["until"] > now)
	queue_redraw()


func _draw() -> void:
	var f := HudStyle.font()
	var now := _now()
	var y := 0.0
	for r: Dictionary in rows:
		var a := clampf((float(r["until"]) - now) / FADE, 0.0, 1.0)
		var text := line(r["item"], r["count"])
		var w := 8.0 + ICON + 8.0 + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 12.0
		var box := Rect2(0.0, y, w, ROW_H)
		# Fondu final : chaque teinte du cadre perd son opacité ; l'icône disparaît à mi-fondu.
		var tone: Array[Color] = []
		for c: Color in SnesBanner.INFO:
			tone.append(Color(c, c.a * a))
		SnesBanner.paint(self, box, tone, true)
		var icon_c := Vector2(8.0 + ICON / 2.0, y + ROW_H / 2.0)
		if a > 0.5:
			ItemIcon.draw_item(self, r["item"], icon_c, ICON / 32.0)
		var rarity := Loot.rarity_of(r["item"])
		var col: Color = HudStyle.IVORY if rarity == "normal" else Loot.rarity_color(r["item"])
		var base := Vector2(8.0 + ICON + 8.0, y + ROW_H / 2.0 + f.get_ascent(FONT_SIZE) / 2.0 - 2.0)
		draw_string(f, base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, 0.7 * a))
		draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(col, a))
		y += ROW_H + GAP
