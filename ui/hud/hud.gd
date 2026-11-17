class_name Hud
extends CanvasLayer
## HUD de commandement (Index.html, hud.js, hud.css, dialogue.js, 73b410f), à la résolution écran :
##  - bandeau du haut : vague, Forge, Vie, Discipline, Savoir, Exilés, Menace ;
##  - bandeau de commandement : minicarte, portrait et identité, détails (ou Ancre), panneau d'ordres ;
##  - notice, bouton Rejouer, bannière de fin, bulle de dialogue.
## La logique (actions, textes) est dans HudModel ; ce nœud ne fait que l'afficher.
## Mise en page : règles de hud.css pour une fenêtre d'au moins 1150 px de large (dimensions relevées
## dans le prototype à 1440×900) ; les variantes pour petits écrans ne sont pas portées (ECARTS.md).

const TOP_INSET := Vector2(16, 14)
const BAR_MARGIN := 12.0
const GRID_FR := [16.0, 29.0, 31.0, 30.0]
const GRID_MIN := [145.0, 270.0, 290.0, 310.0]
const RES_ICON_COLORS := {"forge": Color("#d5c7a9"), "vie": Color("#ad855d"), "discipline": Color("#85d7f0"), "savoir": Color("#d5c7a9"), "menace": Color("#df936f")}
const RES_ICONS := {"forge": "iron", "vie": "heart", "discipline": "shield", "savoir": "book", "menace": "menace"}
const RES_NAMES := {"forge": "Forge", "vie": "Vie", "discipline": "Discipline", "savoir": "Savoir", "menace": "Menace"}
const PORTRAITS := "res://assets/baked/hud/portraits/%s.png"
## Portraits hors baker : Ingénieur sans armure (planches/ingenieur-sans-armure-export.html).
const PORTRAITS_EXTRA := {"engineer-bare": TyrienArt.PORTRAIT}

var sim: Simulation
var world: World

var _root := Control.new()
# Bandeau du haut.
var _wave_card := _Panel.new()
var _wave_icon := TextureRect.new()
var _wave_label := HudStyle.label(20, HudStyle.IVORY)
var _res_panel := _Panel.new()
## Panneau d'objectif sous la carte de vague (Rapport de l'Ingénieur).
var objective := ObjectivePanel.new()
## Quêtes de l'Ingénieur, affichées par le panneau d'objectif.
var quests := Quests.new()
var _res_items := {}
var _resource_boost := Button.new()
var _fast_construction := Button.new()
# Notice, Rejouer, bannière, dialogue.
var _notice := _Panel.new()
var _notice_label := HudStyle.label(14, Color("#e8d2a7"))
var _notice_end := 0.0
var _restart := _RestartButton.new()
## Munitions de la réserve globale (haut à droite) : flèches × quantité, carburant × ∞ (pas encore géré).
var _ammo_panel := _Panel.new()
var _ammo_arrow := _ItemGlyph.new()
var _ammo_arrow_l := HudStyle.label(20, HudStyle.IVORY)
var _ammo_fuel := TextureRect.new()
var _ammo_fuel_l := HudStyle.label(20, HudStyle.IVORY)
var _banner := _Panel.new()
var _banner_title := HudStyle.label(25, HudStyle.IVORY)
var _banner_small := HudStyle.label(15, Color("#b8c9bb"))
var dialogue := DialogueBubble.new()
# Bandeau de commandement.
var _bar := _Panel.new()
var _modules: Array[_Panel] = []
var _diamonds := _Diamonds.new()
var minimap := Minimap.new()
var _north := HudStyle.label(13, Color("#f5d99b"))
var _portrait := _PortraitButton.new()
var _kind := HudStyle.label(9, HudStyle.MUTED, HudStyle.spaced(2))
var _chosen := HudStyle.label(22, HudStyle.IVORY)
var _heart := TextureRect.new()
var _health := _HealthTrack.new()
var _status := HudStyle.label(10, HudStyle.MUTED)
var _unit_details := Control.new()
var _stats: Array[Dictionary] = []
var _stat_row := _StatRow.new()
var _lore := HudStyle.label(12, Color("#ddcfaf"), HudStyle.italic())
var _anchor_details := Control.new()
var _anchor_eyebrow := HudStyle.label(10, HudStyle.MUTED, HudStyle.spaced(2))
var _assault_box := _AssaultBox.new()
var _assault_icon := TextureRect.new()
var _assault_label := HudStyle.label(13, Color("#e9c784"))
var _assault_time := HudStyle.label(19, Color("#e9c784"))
var _anchor_lore := HudStyle.label(12, Color("#ddcfaf"), HudStyle.italic())
var _actions_box := Control.new()
## Menu « Construire » : rangée de grands carrés au-dessus du bandeau, bulle « nom · coût » au survol.
var _build_row := Control.new()
var _build_buttons: Array[BuildButton] = []
var _build_bubble := _Bubble.new()
var _buttons: Array[ActionButton] = []
var _sig := ""
var _portrait_key := ""
var _last_map := -INF
## updateHUD : au plus toutes les 0,1 s de simulation (HUD.lastUpdate), sauf quand la sélection, le
## menu ou le mode changent (le prototype force alors la mise à jour : updateHUD(true)).
var _last_update := -INF
var _ctx := ""
var _view := {}


func _ready() -> void:
	layer = 5
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_build_bar()
	_build_overlays()
	var inventory := preload("res://ui/inventory/engineer_inventory.gd").new()
	_root.add_child(inventory)
	get_viewport().size_changed.connect(_layout)
	Events.notice.connect(say)
	Events.game_reset.connect(_on_reset)
	Events.game_over.connect(show_banner)
	_layout()


func setup(s: Simulation, w: World) -> void:
	sim = s
	world = w
	minimap.world = w
	dialogue.camera = w.camera
	s.engineer_greeted.connect(dialogue.greet_engineer)
	s.engineer_spoke.connect(func(u: Unit, text: String) -> void:
		dialogue.show_dialogue({"speaker": u, "name": "Ingénieur Exilé", "role": "engineer", "compact": true, "lines": [text]}))
	s.turrets_activated.connect(_on_turrets_activated)
	# Caméra revenue sur l'Ingénieur : surcharge de l'Ancre (sim/overload.gd), puis le dialogue.
	w.anchor_spark.engineer_reached.connect(_on_engineer_reached)
	s.overload_finished.connect(_show_equipment_dialogue)


func _on_turrets_activated() -> void:
	for u in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden:
			dialogue.close()
			world.anchor_spark.return_to_engineer(u)
			return


func _on_engineer_reached(u: Unit) -> void:
	if not Overload.start(u):
		_show_equipment_dialogue(u)


func _show_equipment_dialogue(u: Unit) -> void:
	dialogue.show_dialogue({"speaker": u, "any_button": true, "lines": [
		"Je suis en vie... Mais mon équipement n'a pas résisté. Et sans lui, impossible de combattre le Credo.",
		"Peut-être que la Salamandre peut m'aider. Je devrais pouvoir ériger des temples grâce à mon Enonciation."
	]})


# ---------------------------------------------------------------- Construction

func _build_top() -> void:
	# #hud-top : pointer-events: none, les clics traversent le bandeau du haut.
	_wave_card.kind = "metal"
	_wave_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wave_card)
	_wave_icon.texture = HudStyle.icon("skull", 26)
	_wave_icon.modulate = Color("#e69354")
	_wave_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_card.add_child(_wave_icon)
	_wave_card.add_child(_wave_label)
	_root.add_child(objective)
	objective.resized.connect(_layout_debug)
	_res_panel.kind = "metal"
	_res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_res_panel)
	for k in _res_keys():
		var icon := TextureRect.new()
		icon.texture = HudStyle.icon("people" if k == "population" else RES_ICONS[k], 26)
		icon.modulate = Color("#d5c7a9") if k == "population" else RES_ICON_COLORS[k]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := HudStyle.label(16, HudStyle.IVORY)
		name_l.text = "Exilés" if k == "population" else RES_NAMES[k]
		var value_l := HudStyle.label(20, HudStyle.IVORY)
		for n: Control in [icon, name_l, value_l]:
			_res_panel.add_child(n)
		_res_items[k] = {"icon": icon, "name": name_l, "value": value_l}
	_resource_boost.name = "ResourceBoost"
	_resource_boost.text = "+1000"
	_resource_boost.tooltip_text = "Ajouter 1 000 de chaque ressource"
	_resource_boost.focus_mode = Control.FOCUS_NONE
	_resource_boost.mouse_filter = Control.MOUSE_FILTER_STOP
	_resource_boost.add_theme_font_override("font", HudStyle.font())
	_resource_boost.add_theme_font_size_override("font_size", 16)
	_resource_boost.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#302a1c") if state != "normal" else Color("#171c17")
		style.border_color = HudStyle.GOLD_LIGHT if state != "normal" else HudStyle.GOLD
		style.set_border_width_all(1)
		_resource_boost.add_theme_stylebox_override(state, style)
	_resource_boost.pressed.connect(_add_resources)
	_root.add_child(_resource_boost)
	_fast_construction.name = "FastConstruction"
	_fast_construction.toggle_mode = true
	_fast_construction.text = "Construction rapide : OFF"
	_fast_construction.tooltip_text = "Double la vitesse de tous les chantiers et de la réactivation de l’Ancre"
	_fast_construction.focus_mode = Control.FOCUS_NONE
	_fast_construction.mouse_filter = Control.MOUSE_FILTER_STOP
	_fast_construction.add_theme_font_override("font", HudStyle.font())
	_fast_construction.add_theme_font_size_override("font_size", 14)
	_fast_construction.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		_fast_construction.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	_fast_construction.toggled.connect(func(active: bool) -> void:
		GameState.fast_construction = active
		_fast_construction.text = "Construction rapide : ON" if active else "Construction rapide : OFF")
	_root.add_child(_fast_construction)
	_ammo_panel.name = "AmmoPanel"
	_ammo_panel.kind = "metal"
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ammo_panel)
	_ammo_arrow.item = "arrows"
	_ammo_arrow.tooltip_text = "Flèches (réserve globale) : une par tir d’archer"
	_ammo_arrow.mouse_filter = Control.MOUSE_FILTER_PASS
	_ammo_fuel.texture = HudStyle.icon("flame", 26)
	_ammo_fuel.modulate = Color("#e69354")
	_ammo_fuel.tooltip_text = "Carburant (réserve globale) : illimité pour le moment"
	_ammo_fuel.mouse_filter = Control.MOUSE_FILTER_PASS
	_ammo_fuel_l.text = "× ∞"
	for n: Control in [_ammo_arrow, _ammo_arrow_l, _ammo_fuel, _ammo_fuel_l]:
		_ammo_panel.add_child(n)


func _add_resources() -> void:
	for resource: String in Catalog.RES_ORDER:
		GameState.res[resource] += 1000.0
	refresh()


static func _res_keys() -> Array[String]:
	var keys: Array[String] = Catalog.RES_ORDER.duplicate()
	keys.append("population")
	keys.append("menace")
	return keys


func _build_bar() -> void:
	_bar.kind = "bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bar)
	for i in 4:
		var m := _Panel.new()
		m.kind = "module"
		m.diamond = i < 3
		m.mouse_filter = Control.MOUSE_FILTER_STOP
		m.clip_contents = true
		_bar.add_child(m)
		_modules.append(m)
	# Losanges de liaison, au-dessus des modules (.hud-module:after, z-index 1).
	_bar.add_child(_diamonds)
	# Minicarte.
	_modules[0].add_child(minimap)
	_north.text = "N"
	_north.add_theme_color_override("font_shadow_color", Color("#000000"))
	_north.add_theme_constant_override("shadow_offset_y", 1)
	_modules[0].add_child(_north)
	# Portrait et identité.
	_portrait.pressed.connect(_center_on_selection)
	_modules[1].add_child(_portrait)
	for n: Control in [_kind, _chosen, _status]:
		_modules[1].add_child(n)
	_chosen.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_heart.texture = HudStyle.icon("heart", 19, 0.0, true)
	_heart.modulate = Color("#e1e4b3")
	_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modules[1].add_child(_heart)
	_modules[1].add_child(_health)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_constant_override("line_spacing", -3)
	# Détails de l'unité.
	_modules[2].add_child(_unit_details)
	_unit_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_details.add_child(_stat_row)
	for s: Array in [["sword", "Dégâts"], ["range", "Portée"], ["shield", "Armure"], ["boot", "Déplacement"]]:
		var icon := TextureRect.new()
		icon.texture = HudStyle.icon(s[0], 24)
		icon.modulate = Color("#dfc390")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := HudStyle.label(12, Color("#c8bca2"))
		name_l.text = s[1]
		var value_l := HudStyle.label(20, HudStyle.IVORY)
		for n: Control in [icon, name_l, value_l]:
			_unit_details.add_child(n)
		_stats.append({"icon": icon, "name": name_l, "value": value_l})
	_lore.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore.max_lines_visible = 2
	_lore.add_theme_constant_override("line_spacing", -1)
	_unit_details.add_child(_lore)
	# Détails de l'Ancre.
	_modules[2].add_child(_anchor_details)
	_anchor_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_eyebrow.text = "DÉFENSE DU SANCTUAIRE"
	_anchor_details.add_child(_anchor_eyebrow)
	_anchor_details.add_child(_assault_box)
	_assault_icon.texture = HudStyle.icon("skull", 23)
	_assault_icon.modulate = Color("#e89448")
	_assault_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_assault_label.text = "Prochain assaut"
	for n: Control in [_assault_icon, _assault_label, _assault_time]:
		_assault_box.add_child(n)
	_anchor_lore.text = "Tant qu’elle demeure, le serment tient."
	_anchor_lore.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_anchor_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor_details.add_child(_anchor_lore)
	# Panneau d'ordres.
	_actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modules[3].add_child(_actions_box)
	_build_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_build_row)
	_build_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bubble.visible = false
	_root.add_child(_build_bubble)


func _build_overlays() -> void:
	_notice.kind = "notice"
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.modulate.a = 0.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_child(_notice_label)
	_root.add_child(_notice)
	_restart.pressed.connect(func() -> void: if sim: sim.new_game())
	_restart.tooltip_text = "Rejouer la partie"
	_root.add_child(_restart)
	_banner.kind = "banner"
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_small)
	_root.add_child(_banner)
	_root.add_child(dialogue)


# ---------------------------------------------------------------- Mise en page

func _screen() -> Vector2:
	return _root.get_viewport_rect().size


## --hud-height : clamp(96px, 13,333vh, 125,333px).
func hud_height() -> float:
	return clampf(_screen().y * 0.133333, 96.0, 125.333)


## Colonnes de la grille du bandeau : minmax(min, fr), avec une distribution CSS des fractions.
static func grid_columns(inner: float) -> Array[float]:
	var fixed := [false, false, false, false]
	var cols: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for _pass in 4:
		var free := inner
		var frs := 0.0
		for i in 4:
			if fixed[i]:
				free -= GRID_MIN[i]
			else:
				frs += GRID_FR[i]
		var changed := false
		for i in 4:
			if fixed[i]:
				cols[i] = GRID_MIN[i]
			else:
				cols[i] = free / frs * GRID_FR[i]
				if cols[i] < GRID_MIN[i]:
					fixed[i] = true
					changed = true
		if not changed:
			break
	return cols


func _layout() -> void:
	var s := _screen()
	_layout_top(s)
	# #command-bar : left/right/bottom 12, hauteur --hud-height, bordure 1, marge intérieure 3, écart 3.
	var h := hud_height()
	_bar.position = Vector2(BAR_MARGIN, s.y - BAR_MARGIN - h)
	_bar.size = Vector2(s.x - 2.0 * BAR_MARGIN, h)
	minimap.command_bar_height = h
	var cols := grid_columns(_bar.size.x - 2.0 - 6.0 - 9.0)
	var x := 4.0
	for i in 4:
		_modules[i].position = Vector2(x, 4.0)
		_modules[i].size = Vector2(cols[i], h - 8.0)
		x += cols[i] + 3.0
	_diamonds.modules = _modules
	_diamonds.size = _bar.size
	_diamonds.queue_redraw()
	_layout_map(_modules[0].size)
	_layout_selection(_modules[1].size)
	_layout_details(_modules[2].size)
	_layout_actions(_modules[3].size)
	_layout_build_row()
	objective.position = Vector2(TOP_INSET.x, TOP_INSET.y + 56.0 + 10.0)
	_layout_debug()
	_fast_construction.size = Vector2(230, 38)
	_layout_ammo(s)
	_restart.position = Vector2(s.x - 16.0 - _restart.size.x, _ammo_panel.position.y + _ammo_panel.size.y + 10.0)
	_layout_notice()
	_layout_banner()


## Boutons de debug : sous le panneau d'objectif, dont la hauteur suit le nombre d'objectifs affichés.
func _layout_debug() -> void:
	var dbg_y := objective.position.y + maxf(ObjectivePanel.HEIGHT, objective.size.y) + 10.0
	_resource_boost.position = Vector2(16, dbg_y)
	_resource_boost.size = Vector2(100, 38)
	_fast_construction.position = Vector2(16, dbg_y + 44.0)


func _layout_top(s: Vector2) -> void:
	var tw := HudStyle.text_width(_wave_label.text if _wave_label.text else "Vague —", 20)
	_wave_card.position = TOP_INSET
	_wave_card.size = Vector2(1.0 + 22.0 + 26.0 + 12.0 + tw + 22.0 + 1.0, 56.0)
	_wave_icon.position = Vector2(23.0, 15.0)
	_wave_icon.size = Vector2(26, 26)
	_wave_label.position = Vector2(23.0 + 26.0 + 12.0, 13.0)
	_wave_label.size = Vector2(tw + 4.0, 30.0)
	# #resources : centré dans l'espace laissé à droite de la carte de vague (margin: 0 auto).
	var keys := _res_keys()
	var widths: Array[float] = []
	var total := 2.0 * 23.0
	for i in keys.size():
		var it: Dictionary = _res_items[keys[i]]
		var w := 26.0 + 10.0 + HudStyle.text_width(it["name"].text + " ", 16) + 8.0 + HudStyle.text_width(it["value"].text, 20)
		widths.append(w)
		total += w + (25.0 + 24.0 if i < keys.size() - 1 else 0.0)
	var left := TOP_INSET.x + _wave_card.size.x + 26.0
	var right := s.x - TOP_INSET.x
	# Réduit les espaces entre ressources si le bandeau dépasse la place disponible.
	var gap := clampf(49.0 + (right - left - total) / (keys.size() - 1), 0.0, 49.0)
	total += (gap - 49.0) * (keys.size() - 1)
	_res_panel.size = Vector2(total, 52.0)
	_res_panel.position = Vector2(left + maxf(0.0, (right - left - total) / 2.0), TOP_INSET.y)
	var x := 23.0
	var seps: Array[float] = []
	for i in keys.size():
		var it: Dictionary = _res_items[keys[i]]
		it["icon"].position = Vector2(x, 13.0)
		it["icon"].size = Vector2(26, 26)
		var nw := HudStyle.text_width(it["name"].text + " ", 16)
		it["name"].position = Vector2(x + 36.0, 14.0)
		it["name"].size = Vector2(nw, 26.0)
		it["value"].position = Vector2(x + 36.0 + nw + 8.0, 12.0)
		it["value"].size = Vector2(HudStyle.text_width(it["value"].text, 20) + 2.0, 28.0)
		x += widths[i]
		if i < keys.size() - 1:
			seps.append(x + gap / 2.0)
			x += gap
	_res_panel.separators = seps
	var fit := minf(1.0, (right - left) / total)
	_res_panel.scale = Vector2.ONE * fit
	_res_panel.position.x = left + maxf(0.0, (right - left - total * fit) / 2.0)


## Bandeau des munitions : aligné à droite, sous le bandeau des ressources.
func _layout_ammo(s: Vector2) -> void:
	var aw := HudStyle.text_width(_ammo_arrow_l.text, 20) + 4.0
	var fw := HudStyle.text_width(_ammo_fuel_l.text, 20) + 4.0
	var x := 18.0
	_ammo_arrow.position = Vector2(x, 9.0)
	_ammo_arrow.size = Vector2(30, 30)
	_ammo_arrow_l.position = Vector2(x + 36.0, 9.0)
	_ammo_arrow_l.size = Vector2(aw, 28.0)
	x += 36.0 + aw + 24.0
	_ammo_fuel.position = Vector2(x, 11.0)
	_ammo_fuel.size = Vector2(26, 26)
	_ammo_fuel_l.position = Vector2(x + 34.0, 9.0)
	_ammo_fuel_l.size = Vector2(fw, 28.0)
	_ammo_panel.size = Vector2(x + 34.0 + fw + 18.0, 48.0)
	var bottom := TOP_INSET.y + 52.0 * _res_panel.scale.y + 8.0
	_ammo_panel.position = Vector2(s.x - TOP_INSET.x - _ammo_panel.size.x, bottom)


func _layout_map(m: Vector2) -> void:
	minimap.position = Vector2(8, 8)
	minimap.size = m - Vector2(16, 16)
	_north.position = Vector2(m.x - 15.0 - HudStyle.text_width("N", 13), 9.0)
	_north.size = Vector2(12, 16)


func _layout_selection(m: Vector2) -> void:
	var p := minf(94.0, m.y - 18.0)
	_portrait.position = Vector2(9, 9)
	_portrait.size = Vector2(p, p)
	var x0 := 9.0 + p + 10.0
	var w := m.x - x0 - 9.0
	_chosen.add_theme_font_size_override("font_size", roundi(clampf(_screen().x * 0.015, 16.0, 22.0)))
	var status_h := 11.0 * clampi(_lines(_status.text, 10, w), 1, 2)
	var total := 10.8 + 4.0 + 23.8 + 8.0 + 21.0 + 5.0 + status_h
	var y := 9.0 + (m.y - 18.0 - total) / 2.0
	_kind.position = Vector2(x0, y - 1.0)
	_kind.size = Vector2(w, 12.8)
	_chosen.position = Vector2(x0, y + 14.8 - 2.0)
	_chosen.size = Vector2(w, 27.8)
	# Surtitre 10,8 ; titre (marges 4 et 8) 23,8 ; barre de vie 21 ; statut (marge 5).
	_heart.position = Vector2(x0, y + 46.6 + 1.0)
	_heart.size = Vector2(19, 19)
	_health.position = Vector2(x0 + 28.0, y + 46.6)
	_health.size = Vector2(w - 28.0, 21.0)
	_status.position = Vector2(x0, y + 72.6 - 2.0)
	_status.size = Vector2(w, status_h + 4.0)


func _layout_details(m: Vector2) -> void:
	var w := m.x - 30.0
	# Détails de l'unité : rangée de statistiques (50 px), légende sur 2 lignes au plus.
	var lore_h := 16.8 * clampi(_lines(_lore.text, 12, w, HudStyle.italic()), 1, 2)
	var total := 50.0 + 8.0 + lore_h
	_unit_details.position = Vector2(15.0, 11.0 + (m.y - 22.0 - total) / 2.0)
	_unit_details.size = Vector2(w, total)
	_stat_row.position = Vector2.ZERO
	_stat_row.size = Vector2(w, 50.0)
	var widths: Array[float] = []
	var sum := 0.0
	var n := _stats.size()
	for i in n:
		var st: Dictionary = _stats[i]
		var tw := maxf(HudStyle.text_width(st["name"].text, 12), HudStyle.text_width(st["value"].text, 20))
		var iw := 24.0 + 8.0 + tw + (13.0 if i < n - 1 else 0.0)
		widths.append(iw)
		sum += iw
	var gap := maxf(0.0, (w - sum) / float(n - 1))
	var x := 0.0
	var seps: Array[float] = []
	for i in n:
		var st: Dictionary = _stats[i]
		st["icon"].position = Vector2(x, 0.0)
		st["icon"].size = Vector2(24, 24)
		st["name"].position = Vector2(x + 32.0, -2.0)
		st["name"].size = Vector2(widths[i], 18.0)
		st["value"].position = Vector2(x + 32.0, 14.0)
		st["value"].size = Vector2(widths[i], 28.0)
		if i < n - 1:
			seps.append(x + widths[i] - 1.0)
		x += widths[i] + gap
	_stat_row.separators = seps
	_lore.position = Vector2(0.0, 58.0 - 1.0)
	_lore.size = Vector2(w, lore_h + 4.0)
	# Détails de l'Ancre : surtitre, ligne d'assaut, légende.
	var a_lore_h := 16.8 * clampi(_lines(_anchor_lore.text, 12, w, HudStyle.italic()), 1, 2)
	var a_total := 15.0 + 7.0 + 37.0 + 6.0 + a_lore_h
	_anchor_details.position = Vector2(15.0, 11.0 + (m.y - 22.0 - a_total) / 2.0)
	_anchor_details.size = Vector2(w, a_total)
	_anchor_eyebrow.position = Vector2(0, 0)
	_anchor_eyebrow.size = Vector2(w, 15.0)
	_assault_box.position = Vector2(0, 22.0)
	_assault_box.size = Vector2(w, 37.0)
	_assault_icon.position = Vector2(10.0, 7.0)
	_assault_icon.size = Vector2(23, 23)
	var lw := HudStyle.text_width(_assault_label.text, 13)
	_assault_label.position = Vector2(10.0 + 23.0 + 12.0, 9.0)
	_assault_label.size = Vector2(lw + 2.0, 20.0)
	_assault_time.position = Vector2(10.0 + 23.0 + 12.0 + lw + 9.0, 5.0)
	_assault_time.size = Vector2(HudStyle.text_width(_assault_time.text, 19) + 4.0, 27.0)
	_anchor_lore.position = Vector2(0, 65.0 - 1.0)
	_anchor_lore.size = Vector2(w, a_lore_h + 4.0)


func _layout_actions(m: Vector2) -> void:
	# Grille de 6 colonnes sur 2 rangées (style en ligne d'Index.html), écart 3, marge 5 + bordure 1.
	_actions_box.position = Vector2(6, 6)
	_actions_box.size = m - Vector2(12, 12)
	var cw := (_actions_box.size.x - 15.0) / 6.0
	var rh := (_actions_box.size.y - 3.0) / 2.0
	for i in _buttons.size():
		var b := _buttons[i]
		b.position = Vector2((i % 6) * (cw + 3.0), (i / 6) * (rh + 3.0))
		b.size = Vector2(cw, rh)


func _layout_build_row() -> void:
	var gap := 8.0
	var n := _build_buttons.size()
	var w := n * BuildButton.SIZE + maxf(0.0, n - 1) * gap
	_build_row.size = Vector2(w, BuildButton.SIZE)
	_build_row.position = Vector2((_screen().x - w) / 2.0, _bar.position.y - 12.0 - BuildButton.SIZE)
	for i in n:
		_build_buttons[i].position = Vector2(i * (BuildButton.SIZE + gap), 0.0)


## Bulle au-dessus du carré survolé (ou, à défaut, du bâtiment armé) : « Nom · 20 Savoir ».
func _update_bubble() -> void:
	var target: BuildButton = null
	for b in _build_buttons:
		if b.is_hovered():
			target = b
	if target == null:
		for b in _build_buttons:
			if b.action.get("active", false):
				target = b
	for b in _build_buttons:
		b.queue_redraw()
	if target == null:
		_build_bubble.visible = false
		return
	var D: Dictionary = Catalog.BUILDINGS[target.action["build_type"]]
	var why := ""
	if target.action.get("locked", false):
		why = "nécessite un " + Catalog.BUILDINGS[D["requires"]]["name"]
	_build_bubble.set_text(D["name"], Catalog.cost_text(D["cost"]), Catalog.can_pay(D["cost"]), why)
	var c := target.global_position + Vector2(BuildButton.SIZE / 2.0, 0.0)
	var x := clampf(c.x - _build_bubble.size.x / 2.0, 8.0, _screen().x - 8.0 - _build_bubble.size.x)
	_build_bubble.position = Vector2(x, c.y - 10.0 - _build_bubble.size.y)
	_build_bubble.tip_x = c.x - x
	_build_bubble.visible = true
	_build_bubble.queue_redraw()


func _layout_notice() -> void:
	var s := _screen()
	var maxw := s.x - 32.0
	var tw := minf(HudStyle.text_width(_notice_label.text, 14), maxw - 42.0)
	var lines := _lines(_notice_label.text, 14, tw + 1.0)
	_notice.size = Vector2(tw + 42.0, 21.0 * lines + 22.0)
	_notice.position = Vector2((s.x - _notice.size.x) / 2.0, 85.0)
	_notice_label.position = Vector2(21.0, 11.0)
	_notice_label.size = Vector2(tw + 1.0, 21.0 * lines)


func _layout_banner() -> void:
	var s := _screen()
	var w := maxf(HudStyle.text_width(_banner_title.text, 25), HudStyle.text_width(_banner_small.text, 15)) + 2.0
	var h := 29.0 + 12.0 + 18.0
	_banner.size = Vector2(w + 88.0 + 2.0, h + 60.0 + 2.0)
	_banner.position = Vector2((s.x - _banner.size.x) / 2.0, s.y * 0.4 - _banner.size.y / 2.0)
	_banner_title.position = Vector2(45.0, 31.0)
	_banner_title.size = Vector2(w, 29.0)
	_banner_small.position = Vector2(45.0, 31.0 + 29.0 + 12.0)
	_banner_small.size = Vector2(w, 18.0)


static func _lines(text: String, size: int, width: float, f: Font = null) -> int:
	if text.is_empty() or width <= 0.0:
		return 1
	var font := f if f else HudStyle.font()
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
	return maxi(1, roundi(h / font.get_height(size)))


# ---------------------------------------------------------------- Mise à jour (updateHUD)

func _process(delta: float) -> void:
	if sim == null:
		return
	dialogue.tick(minf(delta, Simulation.MAX_DT))
	if _notice_end < GameState.sim_time:
		_notice.modulate.a = maxf(0.0, _notice.modulate.a - delta / 0.2)
	else:
		_notice.modulate.a = minf(1.0, _notice.modulate.a + delta / 0.2)
	var ctx := "%s|%s|%s|%s|%s|%s|%s|%s" % [GameState.selected.map(func(u: Unit) -> int: return u.id), GameState.hud_menu,
		GameState.hud_mode, GameState.hud_build_type, GameState.hud_building.id if GameState.hud_building else -1,
		GameState.anchor_selected, GameState.ended, GameState.hud_enemy.get_instance_id() if GameState.hud_enemy else 0]
	var t := GameState.sim_time
	if ctx != _ctx or t < _last_update or t - _last_update >= 0.1:
		_ctx = ctx
		_last_update = t
		refresh()


## updateHUD : textes, ordres, portrait ; minicarte au plus toutes les 0,1 s de simulation.
func refresh(force_map := false) -> void:
	quests.update()
	objective.push(quests.objective())
	var v := HudModel.view(sim)
	var relayout := false
	if v != _view:
		relayout = true
		_apply_view(v)
		_view = v
	var all_actions := HudModel.panel_actions(sim)
	var actions: Array[Dictionary] = all_actions.filter(func(a: Dictionary) -> bool: return not a.has("build_type"))
	var builds: Array[Dictionary] = all_actions.filter(func(a: Dictionary) -> bool: return a.has("build_type"))
	if builds.size() != _build_buttons.size():
		for b in _build_buttons:
			b.queue_free()
		_build_buttons.clear()
		for a in builds:
			var bb := BuildButton.new()
			bb.mouse_entered.connect(_update_bubble)
			bb.mouse_exited.connect(_update_bubble)
			_build_row.add_child(bb)
			_build_buttons.append(bb)
		relayout = true
	for i in builds.size():
		_build_buttons[i].set_action(builds[i])
	_update_bubble()
	var sig := "|".join(actions.map(func(a: Dictionary) -> String: return a["id"]))
	if sig != _sig:
		_sig = sig
		for b in _buttons:
			b.queue_free()
		_buttons.clear()
		for a in actions:
			var b := ActionButton.new()
			_actions_box.add_child(b)
			_buttons.append(b)
		relayout = true
	for i in actions.size():
		_buttons[i].set_action(actions[i])
	if relayout:
		_layout()
	var t := GameState.sim_time
	if force_map or t < _last_map or t - _last_map >= 0.1:
		_last_map = t
		minimap.refresh()


func _apply_view(v: Dictionary) -> void:
	_wave_label.text = "Vague " + v["wave"]
	for k in Catalog.RES_ORDER:
		_res_items[k]["value"].text = v["res"][k] + " (+ %s/s)" % HudModel.num_fr(v["resource_rates"][k])
	_res_items["population"]["value"].text = v["population"]
	var arrows := "× %d" % Catalog.ItemStorage.count_ammo("arrows")
	if _ammo_arrow_l.text != arrows:
		_ammo_arrow_l.text = arrows
		_layout_ammo(_screen())
	_res_items["menace"]["value"].text = v["menace"]
	for part: String in ["icon", "name", "value"]:
		var control: Control = _res_items["menace"][part]
		control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.tooltip_text = v["menace_tooltip"]
	_kind.text = v["kind"]
	_chosen.text = v["chosen"]
	_health.set_target(v["health_pct"])
	_health.text = v["health_text"]
	_health.tooltip_text = v["health_label"]
	_health.queue_redraw()
	_status.text = v["status"]
	_unit_details.visible = not v["anchor_details"]
	_anchor_details.visible = v["anchor_details"]
	_assault_time.text = v["assault"]
	_stats[0]["value"].text = v["damage"]
	_stats[1]["value"].text = v["range"]
	_stats[2]["value"].text = v["armor"]
	_stats[3]["value"].text = v["speed"]
	_health.enemy = v["enemy"]
	_lore.text = v["lore"]
	_portrait.disabled = not v["portrait_enabled"]
	if v["portrait_key"] != _portrait_key:
		_portrait_key = v["portrait_key"]
		if _portrait_key.begins_with("enemy-"):
			_portrait.texture = _enemy_portrait(_portrait_key.substr(6))
		elif PORTRAITS_EXTRA.has(_portrait_key):
			_portrait.texture = load(PORTRAITS_EXTRA[_portrait_key])
		else:
			_portrait.texture = load(PORTRAITS % _portrait_key) if ResourceLoader.exists(PORTRAITS % _portrait_key) else null
		_portrait.queue_redraw()


## Portrait d'un ennemi (D14) : première image de repos, cadrée en carré sur la silhouette (pieds en bas).
func _enemy_portrait(kind: String) -> Texture2D:
	var meta: Dictionary = EnemyArt.all().get(kind, {})
	if meta.is_empty():
		return null
	var n := maxf(22.0, float(meta["h"]) + 6.0)
	var a := AtlasTexture.new()
	a.atlas = load(EnemyArt.ROOT + "%s_idle.png" % kind)
	a.region = Rect2(float(meta["ax"]) - n / 2.0, float(meta["ay"]) + 2.0 - n, n, n)
	return a


## say() : message bref sous le bandeau du haut.
func say(text: String, seconds := 2.0) -> void:
	_notice_label.text = text
	_notice_end = GameState.sim_time + seconds
	_notice.modulate.a = maxf(_notice.modulate.a, 0.01)
	_layout_notice()


## Masque la notice immédiatement (captures de revue).
func hide_notice() -> void:
	_notice_end = -1.0
	_notice.modulate.a = 0.0


## end(won) : bannière de fin de partie (les conditions de fin arrivent avec le combat, étape 8).
func show_banner(won: bool) -> void:
	if won:
		_banner_title.text = "SANCTUM PRÉSERVÉ"
		_banner_small.text = "Les Exilés et les disciples d’Indra ont repoussé l’assaut."
	else:
		var engineer_down := GameState.units.any(func(u: Unit) -> bool: return u.role == "engineer" and not u.alive())
		_banner_title.text = "L’INGÉNIEUR EST TOMBÉ" if engineer_down and GameState.core_hp > 0.0 else "L’ANCRE EST PERDUE"
		_banner_small.text = "Maj + R pour recommencer."
	_banner.visible = true
	_layout_banner()


func _on_reset() -> void:
	_fast_construction.set_pressed_no_signal(GameState.fast_construction)
	_fast_construction.text = "Construction rapide : ON" if GameState.fast_construction else "Construction rapide : OFF"
	dialogue.close()
	quests.reset()
	objective.reset()
	_banner.visible = false
	_last_map = -INF


## Bouton du portrait : centre la caméra sur l'Ancre, le bâtiment ou la première unité sélectionnée.
func _center_on_selection() -> void:
	var p: Variant = null
	if GameState.anchor_selected:
		p = CaveShape.CORE
	else:
		var b := HudModel.selected_building()
		var alive := HudModel.alive_selected()
		var foe := HudModel.selected_enemy()
		if b:
			p = Vector2(b.x, b.z)
		elif not alive.is_empty():
			p = alive[0].pos()
		elif foe:
			p = foe.pos()
	if p != null:
		world.camera.set_view(p, world.camera.px)
		refresh(true)


func _input(event: InputEvent) -> void:
	if dialogue.active() and dialogue.dialogue.get("any_button", false) and event.is_pressed():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if not event.is_echo():
				dialogue.advance()
			get_viewport().set_input_as_handled()
			return
	# Pendant un dialogue, Entrée et Échap lui sont réservées (écoute en phase de capture).
	if dialogue.active() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			dialogue.close()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if not event.echo:
				dialogue.advance()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Éléments dessinés

## Panneau : « metal » (.metal-panel), « module » (.hud-module), « bar » (#command-bar), « notice », « banner ».
class _Panel extends Control:
	var kind := "metal"
	var diamond := false
	var separators: Array[float] = []

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"metal", "module":
				# Ombre portée légère (0 3px 12px #0007), puis le panneau.
				for i in 4:
					draw_rect(Rect2(r.position + Vector2(-i, 3 - i), r.size + Vector2(2 * i, 2 * i)), Color(0, 0, 0, 0.07))
				HudStyle.metal_panel(self, size)
				if kind == "metal":
					for x in separators:
						draw_rect(Rect2(x, 13.0, 1.0, 26.0), Color("#8a6c3b66"))
			"bar":
				draw_rect(r.grow(3.0), Color("#0a0e0bc9"))
				draw_rect(r, Color("#0a0e0b"))
				HudStyle.ring(self, r, 1.0, HudStyle.GOLD)
			"notice":
				draw_rect(r, Color("#10170fea"))
				HudStyle.ring(self, r, 1.0, Color("#94733e"))
			"banner":
				for i in 8:
					draw_rect(r.grow(2.0 + i * 4.0), Color(0, 0, 0, 0.05))
				draw_rect(r, Color("#0e1819f2"))
				HudStyle.ring(self, r, 1.0, HudStyle.GOLD_LIGHT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Losanges entre les modules : 4 px tournés à 45°, à cheval sur le bord droit, à mi-hauteur.
class _Diamonds extends Control:
	var modules: Array[_Panel] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for m in modules:
			if m.diamond:
				HudStyle.diamond(self, m.position + Vector2(m.size.x + 0.5, m.size.y / 2.0 + 4.0))


## Barre de vie (.health-track) : fond sombre, liseré vert, remplissage en dégradé, texte centré.
class _HealthTrack extends Control:
	var pct := 100.0
	var text := ""
	## Ennemi sélectionné (D14) : remplissage et liseré rouges.
	var enemy := false
	var _tween: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	## transition: width .18s (courbe « ease » de CSS, proche d'un sinus en entrée et sortie).
	func set_target(target: float) -> void:
		if _tween:
			_tween.kill()
		if not is_inside_tree() or is_equal_approx(pct, target):
			pct = target
			return
		_tween = create_tween()
		_tween.tween_method(func(v: float) -> void:
			pct = v
			queue_redraw(), pct, target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#181e13"))
		draw_rect(Rect2(1, 1, size.x - 2, 4), Color(0, 0, 0, 0.35))
		var fill := Rect2(1, 1, (size.x - 2) * clampf(pct, 0.0, 100.0) / 100.0, size.y - 2)
		if fill.size.x > 0.0:
			var top := Color("#d0584a") if enemy else Color("#6eab3d")
			var bottom := Color("#7a2620") if enemy else Color("#376d25")
			HudStyle.linear_gradient(self, fill, 180.0, [[0.0, top], [1.0, bottom]])
		HudStyle.ring(self, r, 1.0, Color("#a8443a") if enemy else Color("#6e8d35"))
		var f := HudStyle.font()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var base := Vector2((size.x - w) / 2.0, (size.y + f.get_ascent(15) - f.get_descent(15)) / 2.0)
		draw_string(f, base + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.8))
		draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, HudStyle.IVORY)


## Rangée de statistiques : séparateurs verticaux et trait du bas.
class _StatRow extends Control:
	var separators: Array[float] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for x in separators:
			draw_rect(Rect2(x, 0.0, 1.0, 41.0), Color("#755c354d"))
		draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Color("#886a3777"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Ligne « Prochain assaut » : liseré cuivré et lueur intérieure.
class _AssaultBox extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for i in 6:
			HudStyle.ring(self, r.grow(-1.0 - i * 2.0), 2.0, Color(Color("#9a5005"), 0.02))
		HudStyle.ring(self, r, 1.0, Color("#aa7c39"))


## Bouton du portrait : cadre doré, fond radial, portrait agrandi sans lissage, rune en haut à gauche.
class _PortraitButton extends BaseButton:
	var texture: Texture2D
	var _rune := HudStyle.icon("rune", 20)

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tooltip_text = "Centrer sur la sélection"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0b100e"))
		var c := r.get_center()
		for i in range(12, 0, -1):
			var t := float(i) / 12.0
			var pts := PackedVector2Array()
			for k in 32:
				var a := TAU * k / 32.0
				pts.append(c + Vector2(cos(a), sin(a)) * size * 0.5 * sqrt(2.0) * t)
			var clip := Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]))
			for p in clip:
				draw_colored_polygon(p, Color(Color("#3e3b26"), 0.5 * (1.0 - t) * 0.25))
		HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#12140e"))
		if texture:
			draw_texture_rect(texture, r.grow(-1.0), false)
		HudStyle.ring(self, r, 1.0, HudStyle.GOLD)
		# Rune : #f6c76d avec une lueur orangée.
		for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_texture_rect(_rune, Rect2(Vector2(6, 6) + o, Vector2(20, 20)), false, Color(Color("#e5972d"), 0.35))
		draw_texture_rect(_rune, Rect2(Vector2(6, 6), Vector2(20, 20)), false, Color("#f6c76d"))


## Bouton Rejouer (.restart-button) : panneau métallique, icône, libellé, touche ⇧ R ; opacité 0,7
## hors survol.
class _RestartButton extends BaseButton:
	var _icon := HudStyle.icon("restart", 14)

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		var tw := HudStyle.text_width("Rejouer", 12)
		var kw := maxf(21.0, HudStyle.text_width("⇧ R", 10) + 6.0) + 2.0
		size = Vector2(1.0 + 10.0 + 14.0 + 8.0 + tw + 8.0 + kw + 10.0 + 1.0, 34.0)

	func _draw() -> void:
		modulate.a = 1.0 if is_hovered() else 0.7
		HudStyle.metal_panel(self, size)
		var f := HudStyle.font()
		var x := 11.0
		draw_texture_rect(_icon, Rect2(x, 10.0, 14.0, 14.0), false, HudStyle.IVORY)
		x += 14.0 + 8.0
		var base := (size.y + f.get_ascent(12) - f.get_descent(12)) / 2.0
		draw_string(f, Vector2(x, base), "Rejouer", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudStyle.IVORY)
		x += HudStyle.text_width("Rejouer", 12) + 8.0
		var kw := maxf(21.0, HudStyle.text_width("⇧ R", 10) + 6.0) + 2.0
		var kr := Rect2(x, 8.0, kw, 18.0)
		draw_rect(kr, Color("#10140d"))
		HudStyle.ring(self, kr, 1.0, Color("#8c744b"))
		var kb := kr.position.y + (kr.size.y + f.get_ascent(10) - f.get_descent(10)) / 2.0
		draw_string(f, Vector2(kr.position.x, kb), "⇧ R", HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 10, HudStyle.IVORY)


## Bulle dorée du menu « Construire » : nom (ivoire) · coût (or, ou rouge si insuffisant) · prérequis.
class _Bubble extends Control:
	var tip_x := 0.0
	var _parts: Array = []

	func set_text(name: String, cost: String, ok: bool, why: String) -> void:
		_parts = [[name, HudStyle.IVORY], ["  ·  ", HudStyle.MUTED], [cost, Color("#e8c35a") if ok else Color("#d36a52")]]
		if why:
			_parts += [["  ·  ", HudStyle.MUTED], [why, HudStyle.MUTED]]
		var w := 0.0
		for p in _parts:
			w += HudStyle.text_width(p[0], 15)
		size = Vector2(w + 28.0, 32.0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0d0f0bf2"))
		HudStyle.ring(self, r, 1.0, Color("#e8c35a"))
		var t := clampf(tip_x, 10.0, size.x - 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(t - 7, size.y), Vector2(t + 7, size.y), Vector2(t, size.y + 7)]), Color("#e8c35a"))
		draw_colored_polygon(PackedVector2Array([Vector2(t - 5.5, size.y - 1), Vector2(t + 5.5, size.y - 1), Vector2(t, size.y + 4.5)]), Color("#0d0f0b"))
		var f := HudStyle.font()
		var x := 14.0
		for p in _parts:
			draw_string(f, Vector2(x, 21.0), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, p[1])
			x += HudStyle.text_width(p[0], 15)


## Icône d'objet de l'inventaire (bande items.png), dessinée au centre du contrôle.
class _ItemGlyph extends Control:
	const Icon := preload("res://ui/inventory/item_icon.gd")
	var item := ""

	func _draw() -> void:
		Icon.draw_item(self, item, size * 0.5, size.x / 32.0)
