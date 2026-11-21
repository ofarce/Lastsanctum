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
## Icônes de ressource à la couleur du culte qui la produit (Aether, Medeina, Indra, Sigil) ; Exilés en cyan, Menace en rouge.
const RES_ICON_COLORS := {"forge": Color("#8f8cf0"), "vie": Color("#6fcf78"), "discipline": Color("#f29a45"), "savoir": Color("#c3c6cf"), "menace": Color("#e2604e"), "population": Color("#5ce8ff")}
const RES_MIN_GAP := 22.0
const RES_ICONS := {"forge": "iron", "vie": "heart", "discipline": "shield", "savoir": "book", "menace": "menace"}
const RES_NAMES := {"forge": "Forge", "vie": "Vie", "discipline": "Discipline", "savoir": "Savoir", "menace": "Menace"}
const PORTRAITS := "res://assets/baked/hud/portraits/%s.png"
## Portraits hors baker : Ingénieur sans armure (planches/ingenieur-sans-armure-export.html).
const PORTRAITS_EXTRA := {"engineer-bare": TyrienArt.PORTRAIT, "engineer-exil": TyrienArt.EXIL_PORTRAIT}

var sim: Simulation
var world: World

var _root := Control.new()
# Bandeau du haut.
var _wave_card := _Panel.new()
var _wave_icon := TextureRect.new()
var _wave_label := HudStyle.label(20, HudStyle.IVORY)
## Jour et heure (core/day_night.gd), sous le bandeau des ressources.
var _sky_card := _Panel.new()
var _sky_icon := TextureRect.new()
var _sky_label := HudStyle.label(18, HudStyle.IVORY)
var _sky_key := ""
## Vrai quand la carte du jour est posée en bas à droite (au-dessus du menu de l'Ingénieur incarné).
var _sky_low := false
var _res_panel := _Panel.new()
var _res_shown := false
## Panneau d'objectif sous la carte de vague (Rapport de l'Ingénieur).
var objective := ObjectivePanel.new()
## Quêtes de l'Ingénieur, affichées par le panneau d'objectif.
var quests := Quests.new()
var _res_items := {}
var _res_level := 0
var _res_raw := {}
var _resource_boost := Button.new()
var _crafted_item_boost := Button.new()
var _fast_construction := Button.new()
var _martyre_spawn := Button.new()
var _oeil_go := Button.new()
var _minimap_unlock := Button.new()
var _wave_trigger := Button.new()
var _archer_spawn := Button.new()
var _mods_give := Button.new()
## Seul bouton de debug visible au départ : il déplie les autres, qu'un clic ailleurs replie.
var _debug_toggle := Button.new()
var _debug_open := false
# Notice, Rejouer, bannière, dialogue.
var _notice := _Panel.new()
var _notice_label := SnesBanner.label()
var _notice_end := 0.0
## Alerte de vague : texte rouge en bas à gauche, juste au-dessus de la minicarte (Events.wave_alert).
var _wave_alert := HudStyle.label(20, Color("#ff4a3d"))
var _wave_alert_end := 0.0
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
var item_banner := ItemBanner.new()
# Bandeau de commandement.
var _bar := _Panel.new()
var _modules: Array[_Panel] = []
var _diamonds := _Diamonds.new()
var minimap := Minimap.new()
var _north := HudStyle.label(13, Color("#f5d99b"))
## Zoom de la caméra : « + » et « − » au-dessus de la minicarte, calés sur son bord droit.
var _zoom: Control = preload("res://ui/hud/zoom_buttons.gd").new()
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
## Incarné (Ingénieur) : menu « Construire » / « Poser » en bas à droite, hors bandeau de commandement.
var _inc_actions := Control.new()
var _inc_buttons: Array[ActionButton] = []
var _inc_sig := ""
const INC_BTN := Vector2(86.0, 46.0)
var _sig := ""
var _portrait_key := ""
var _last_map := -INF
## updateHUD : au plus toutes les 0,1 s de simulation (HUD.lastUpdate), sauf quand la sélection, le
## menu ou le mode changent (le prototype force alors la mise à jour : updateHUD(true)).
var _last_update := -INF
var _ctx := ""
var _view := {}
## Galerie des Exilés (au-dessus de la minicarte) et boutons Incarner / Désincarner.
var exile_gallery := ExileGallery.new()
## Vie du boss en haut de l'écran (Martyre de Byrsa).
var boss_bar := BossBar.new()
## Minicarte plein écran (TAB ou M, après la recherche « Minicarte »).
var minimap_overlay := MinimapOverlay.new()
## Codex d'aide (F1 ou bouton « ? » à droite de la carte de vague) : met le jeu en pause.
var help_panel := HelpPanel.new()
var _help_button := HelpButton.new()
## Recherches achevées : icônes en haut à gauche, sous la carte de vague ; effet au survol.
var research_shelf := ResearchShelf.new()
## Objets ramassés, en haut à gauche sous les recherches achevées.
var loot_feed := preload("res://ui/hud/loot_feed.gd").new()
## Fiche de la recherche survolée, à la place des statistiques quand un bâtiment a des recherches (piste A).
var research_card := ResearchCard.new()
var grimoire := ResearchGrimoire.new()
var sfx_player: Node = preload("res://ui/audio/sfx_player.gd").new()
var music_player: Node = preload("res://ui/audio/music_player.gd").new()


func _ready() -> void:
	layer = 5
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_root.add_child(research_shelf)
	_root.add_child(loot_feed)
	_build_bar()
	minimap_overlay.minimap = minimap
	_root.add_child(minimap_overlay)
	_build_overlays()
	_root.add_child(boss_bar)
	_root.add_child(exile_gallery)
	_root.add_child(_zoom)
	var inventory := preload("res://ui/inventory/engineer_inventory.gd").new()
	_root.add_child(inventory)
	_root.add_child(grimoire)
	research_shelf.open_grimoire.connect(func() -> void:
		grimoire.toggle()
		refresh(true))
	_root.add_child(help_panel)
	_help_button.pressed.connect(help_panel.toggle)
	_root.add_child(_help_button)
	add_child(sfx_player)
	add_child(music_player)
	get_viewport().size_changed.connect(_layout)
	Events.notice.connect(say)
	Events.wave_alert.connect(show_wave_alert)
	Events.game_reset.connect(_on_reset)
	Events.game_over.connect(show_banner)
	Events.items_received.connect(item_banner.show_items)
	Events.loot_picked.connect(loot_feed.add)
	_layout()


func setup(s: Simulation, w: World) -> void:
	sim = s
	world = w
	sfx_player.camera = w.camera
	minimap.world = w
	_zoom.world = w
	minimap_overlay.world = w
	help_panel.sim = s
	grimoire.sim = s
	help_panel.world = w
	exile_gallery.world = w
	dialogue.camera = w.camera
	# Plus de réplique d'accueil (« Ah. elle est là. Au travail. » retirée à la demande).
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


var _pending_equipment: Unit = null


func _show_equipment_dialogue(u: Unit) -> void:
	# Pendant la cinématique du bouclier (HUD masqué) : le dialogue attend la fin des barres.
	if Opening.cinematic():
		_pending_equipment = u
		return
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
	_sky_card.kind = "metal"
	_sky_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sky_card)
	for c: Control in [_sky_icon, _sky_label]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky_card.add_child(c)
	_sky_icon.modulate = Color("#f1c86a")
	_root.add_child(objective)
	objective.resized.connect(_layout_debug)
	_res_panel.kind = "metal"
	_res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_res_panel)
	for k in _res_keys():
		var icon := TextureRect.new()
		icon.texture = HudStyle.icon("people" if k == "population" else RES_ICONS[k], 26)
		icon.modulate = RES_ICON_COLORS[k]
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
	_crafted_item_boost.name = "CraftedItemBoost"
	_crafted_item_boost.text = "+100 objets craftables"
	_crafted_item_boost.tooltip_text = "Ajouter 100 de chaque objet de l’Atelier, de la Scierie, de l’Archerie, de la Fonderie et de l’Armurerie au stock de base, et rendre ce stock accessible"
	_crafted_item_boost.focus_mode = Control.FOCUS_NONE
	_crafted_item_boost.mouse_filter = Control.MOUSE_FILTER_STOP
	_crafted_item_boost.add_theme_font_override("font", HudStyle.font())
	_crafted_item_boost.add_theme_font_size_override("font_size", 14)
	_crafted_item_boost.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		_crafted_item_boost.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	_crafted_item_boost.pressed.connect(_add_crafted_items)
	_root.add_child(_crafted_item_boost)
	_martyre_spawn.name = "MartyreSpawn"
	_martyre_spawn.text = "Faire venir la Martyre"
	_martyre_spawn.tooltip_text = "Fait apparaître tout de suite la Martyre de Byrsa et son bouclier sur la route du sud"
	_martyre_spawn.focus_mode = Control.FOCUS_NONE
	_martyre_spawn.mouse_filter = Control.MOUSE_FILTER_STOP
	_martyre_spawn.add_theme_font_override("font", HudStyle.font())
	_martyre_spawn.add_theme_font_size_override("font_size", 14)
	_martyre_spawn.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		_martyre_spawn.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	_martyre_spawn.pressed.connect(_spawn_martyre)
	_root.add_child(_martyre_spawn)
	_oeil_go.name = "OeilGo"
	_oeil_go.text = "Aller à l’Œil de la Matrice"
	_oeil_go.tooltip_text = "Découvre la salle de la frontière, tout en haut du Temple, et y conduit l’Ingénieur"
	_oeil_go.focus_mode = Control.FOCUS_NONE
	_oeil_go.mouse_filter = Control.MOUSE_FILTER_STOP
	_oeil_go.add_theme_font_override("font", HudStyle.font())
	_oeil_go.add_theme_font_size_override("font_size", 14)
	_oeil_go.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		_oeil_go.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	_oeil_go.pressed.connect(_go_oeil)
	_root.add_child(_oeil_go)
	_minimap_unlock.name = "MinimapUnlock"
	_minimap_unlock.text = "Recherche Minicarte"
	_minimap_unlock.tooltip_text = "Achève la recherche « Minicarte » : TAB ou M affiche la minicarte en plein écran"
	_minimap_unlock.focus_mode = Control.FOCUS_NONE
	_minimap_unlock.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_unlock.add_theme_font_override("font", HudStyle.font())
	_minimap_unlock.add_theme_font_size_override("font_size", 14)
	_minimap_unlock.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		_minimap_unlock.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	_minimap_unlock.pressed.connect(func() -> void:
		GameState.research_done["minimap"] = true
		say("Minicarte : TAB ou M pour l’afficher en plein écran.")
		refresh(true))
	_root.add_child(_minimap_unlock)
	_debug_button(_wave_trigger, "WaveTrigger", "Déclencher une vague",
		"Lance tout de suite l’assaut suivant par le sud, sans attendre le matin", _trigger_wave)
	_debug_button(_archer_spawn, "ArcherSpawn", "Faire venir un archer",
		"Fait apparaître gratuitement un archer allié à côté de l’Ancre, sans Caserne", _spawn_archer)
	_debug_button(_mods_give, "ModsGive", "Donner les 15 mods",
		"Met un exemplaire de chaque mod dans le paquetage de l’Ingénieur, le reste dans le réseau des coffres", _give_mods)
	_debug_button(_debug_toggle, "DebugToggle", "DEBUG", "Affiche les boutons de debug", func() -> void:
		_set_debug_open(not _debug_open))
	_set_debug_open(false)
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


## Debug : la Martyre de Byrsa apparaît tout de suite (sinon à Martyre.MENACE de menace), même après sa chute.
func _spawn_martyre() -> void:
	if Martyre.active():
		sim.say("La Martyre de Byrsa est déjà sur le terrain.", 2.0)
		return
	Martyre.spawn(sim)
	refresh()


## Bouton de debug au style des autres (bordure de « +100 ressources »).
func _debug_button(b: Button, node_name: String, label: String, tip: String, action: Callable) -> void:
	b.name = node_name
	b.text = label
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_override("font", HudStyle.font())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", HudStyle.IVORY)
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, _resource_boost.get_theme_stylebox(state))
	b.pressed.connect(action)
	_root.add_child(b)


func _debug_buttons() -> Array[Button]:
	return [_resource_boost, _fast_construction, _crafted_item_boost, _martyre_spawn, _oeil_go,
		_minimap_unlock, _wave_trigger, _archer_spawn, _mods_give]


func _set_debug_open(open: bool) -> void:
	_debug_open = open
	for b: Button in _debug_buttons():
		b.visible = open


## Debug : l'assaut suivant part aussitôt ; le calendrier normal des vagues reste inchangé.
func _trigger_wave() -> void:
	if not GameState.spawn_queue.is_empty():
		sim.say("Une vague est encore en train d’arriver.", 2.0)
		return
	sim.combat.start_wave()
	refresh()


## Debug : un archer allié sort à côté de l'Ancre, gratuit et sans Caserne ni recherche requise
## (même force qu'un archer de Caserne, sans hausse de menace) ; il tire sans flèches.
func _spawn_archer() -> void:
	var p := sim.state().push_out_of_rock(CaveShape.CORE + Vector2(2.5, 2.5))
	var u := sim.spawn(Catalog.ADEPT["archer"]["name"], p.x, p.y, "archer")
	var size := float(Catalog.TRAIN_SIZE.get("caserne", 1))
	u.power = size
	u.free_ammo = true
	u.hp = Catalog.ADEPT["archer"]["hp"] * size
	u.max_hp = u.hp
	u.tx = u.x
	u.tz = u.z
	sim.clamp_world(u)
	Sfx.at("adepte_arrive", u.x, u.z)
	refresh(true)


## Debug : la salle de l'Œil est découverte et l'Ingénieur posé à son bord sud, caméra sur la salle.
func _go_oeil() -> void:
	var st := world.terrain_state
	if not st.frontier:
		sim.say("Pas de frontière sur cette carte.", 2.0)
		return
	var c := TerrainState.eye_room_center()
	world.terrain_ops.reveal_gallery(c.x, c.y)
	if world.terrain_ops.painter:
		world.terrain_ops.painter.terrain.flush()
	var at := c + Vector2(0.0, TerrainState.EYE_ROOM_RZ - 4.0)
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive():
			u.x = at.x
			u.z = at.y
			u.tx = at.x
			u.tz = at.y
			u.force_move = false
	world.camera.set_view(c + Vector2(0.0, 4.0), 3)
	refresh()


func _add_crafted_items() -> void:
	var stock := GameState.base_inventory.duplicate(true)
	var items := {}
	for station: String in ["workshop", "scierie", "archerie", "forge", "creuset"]:
		for item: String in Simulation.Recipes.RECIPES[station]:
			items[item] = true
	for item: String in items:
		for i in 100:
			if not Simulation.ItemStorage.store(stock, Simulation.ItemStorage.BASE_CAPACITY, item):
				sim.say("Stock de base plein : libérez des emplacements pour ajouter les objets.", 3.0)
				return
	GameState.base_inventory.assign(stock)
	GameState.base_inventory_unlocked = true
	sim.say("100 de chaque objet craftable ajoutés au stock de base.", 3.0)
	refresh()


## Valeur affichée d'une ressource au palier de place courant (`_res_level`) : le débit nul saute dès le palier 1.
func _res_text(k: String) -> String:
	if not _res_raw.has(k):
		return _res_items[k]["value"].text
	var raw: Array = _res_raw[k]
	if _res_level >= 1 and raw[1] == "0":
		return raw[0]
	return raw[0] + " (+ %s/s)" % raw[1]


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
	for s: Array in [["sword", "Dégâts"], ["range", "Portée"], ["shield", "Armure"], ["boot", "Vitesse"]]:
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
	_modules[2].add_child(research_card)
	research_card.visible = false
	# Panneau d'ordres.
	_actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modules[3].add_child(_actions_box)
	_build_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_build_row)
	_inc_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inc_actions.visible = false
	_root.add_child(_inc_actions)
	_build_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bubble.visible = false
	_root.add_child(_build_bubble)


func _build_overlays() -> void:
	_notice.kind = "notice"
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.modulate.a = 0.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_notice.add_child(_notice_label)
	_root.add_child(_notice)
	_wave_alert.modulate.a = 0.0
	_wave_alert.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_wave_alert.add_theme_color_override("font_outline_color", Color("#1a0503"))
	_wave_alert.add_theme_constant_override("outline_size", 6)
	_wave_alert.add_theme_color_override("font_shadow_color", Color("#000000"))
	_wave_alert.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_wave_alert)
	_restart.pressed.connect(func() -> void: if sim: sim.new_game())
	_restart.tooltip_text = "Rejouer la partie"
	# Bouton « Rejouer » retiré (2026-11-19) : Maj+R relance toujours la partie.
	_restart.visible = false
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
	_root.add_child(item_banner)


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
	# Écran plus étroit que la somme des minimums : toutes les colonnes rétrécissent du même facteur,
	# au lieu de pousser le dernier module hors de l'écran.
	var sum := 0.0
	for c in cols:
		sum += c
	if sum > inner:
		for i in 4:
			cols[i] *= inner / sum
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
	exile_gallery.hud_bottom = _bar.position.y
	_zoom.position = Vector2(_bar.position.x + 4.0 + cols[0] - _zoom.size.x, _bar.position.y - 6.0 - _zoom.size.y)
	_layout_map(_modules[0].size)
	_layout_selection(_modules[1].size)
	_layout_details(_modules[2].size)
	_layout_actions(_modules[3].size)
	_layout_build_row()
	research_shelf.position = Vector2(TOP_INSET.x, TOP_INSET.y + 56.0 + 10.0)
	objective.position = Vector2(TOP_INSET.x, research_shelf.position.y + (ResearchShelf.CELL + 10.0 if research_shelf.visible else 0.0))
	loot_feed.position = objective.position
	_layout_debug()
	_fast_construction.size = Vector2(230, 38)
	_layout_ammo(s)
	_restart.position = Vector2(s.x - 16.0 - _restart.size.x, _ammo_panel.position.y + _ammo_panel.size.y + 10.0)
	_layout_notice()
	_layout_wave_alert()
	_layout_banner()


## Boutons de debug : sous le panneau d'objectif, dont la hauteur suit le nombre d'objectifs affichés.
func _layout_debug() -> void:
	var dbg_y := objective.position.y + maxf(ObjectivePanel.HEIGHT, objective.size.y) + 10.0
	_debug_toggle.position = Vector2(16, dbg_y)
	_debug_toggle.size = Vector2(100, 38)
	dbg_y += 44.0
	_resource_boost.position = Vector2(16, dbg_y)
	_resource_boost.size = Vector2(100, 38)
	_fast_construction.position = Vector2(16, dbg_y + 44.0)
	_crafted_item_boost.position = Vector2(16, dbg_y + 88.0)
	_crafted_item_boost.size = Vector2(230, 38)
	_martyre_spawn.position = Vector2(16, dbg_y + 132.0)
	_martyre_spawn.size = Vector2(230, 38)
	_oeil_go.position = Vector2(16, dbg_y + 176.0)
	_oeil_go.size = Vector2(230, 38)
	_minimap_unlock.position = Vector2(16, dbg_y + 220.0)
	_minimap_unlock.size = Vector2(230, 38)
	_wave_trigger.position = Vector2(16, dbg_y + 264.0)
	_wave_trigger.size = Vector2(230, 38)
	_archer_spawn.position = Vector2(16, dbg_y + 308.0)
	_archer_spawn.size = Vector2(230, 38)
	# À droite du dernier bouton : en 720 de haut, une rangée de plus passerait sous le portrait.
	_mods_give.position = Vector2(254, dbg_y + 308.0)
	_mods_give.size = Vector2(230, 38)


## Debug : un exemplaire de chaque mod (data/gear_items.gd, champ « module ») au paquetage de l'Ingénieur, puis au
## réseau des coffres quand il est plein.
func _give_mods() -> void:
	var Gear := preload("res://data/gear_items.gd")
	var Store := preload("res://sim/item_storage.gd")
	var eng: Unit = null
	for u: Unit in GameState.units:
		if u.role == "engineer":
			eng = u
	var packed := 0
	var stored := 0
	for item: String in Gear.ITEMS:
		if not Gear.ITEMS[item].has("module"):
			continue
		if eng != null and Store.store(eng.inventory, eng.inventory_capacity, item):
			packed += 1
		elif Store.store(GameState.base_inventory, Store.BASE_CAPACITY, item):
			stored += 1
	say("Mods donnés · %d au paquetage, %d au réseau des coffres." % [packed, stored])
	refresh(true)


func _layout_top(s: Vector2) -> void:
	var tw := HudStyle.text_width(_wave_label.text if _wave_label.text else "Vague —", 20)
	_wave_card.position = TOP_INSET
	_wave_card.size = Vector2(1.0 + 22.0 + 26.0 + 12.0 + tw + 22.0 + 1.0, 56.0)
	_wave_icon.position = Vector2(23.0, 15.0)
	_wave_icon.size = Vector2(26, 26)
	_wave_label.position = Vector2(23.0 + 26.0 + 12.0, 13.0)
	_wave_label.size = Vector2(tw + 4.0, 30.0)
	var keys := _res_keys()
	var sw := HudStyle.text_width(_sky_label.text, 18)
	_sky_card.size = Vector2(18.0 + 20.0 + 8.0 + sw + 18.0, 40.0)
	_sky_icon.position = Vector2(18.0, 10.0)
	_sky_icon.size = Vector2(20, 20)
	_sky_label.position = Vector2(46.0, 7.0)
	_sky_label.size = Vector2(sw + 4.0, 26.0)
	# Bouton d'aide : collé à la carte de vague ; les ressources se centrent dans la place qui reste.
	_help_button.position = TOP_INSET + Vector2(_wave_card.size.x + 8.0 if _wave_card.visible else 0.0, 0.0)
	var left := _help_button.position.x + HelpButton.SIZE.x + 18.0
	var right := s.x - TOP_INSET.x
	# Paliers de place : 0 complet, 1 sans les débits nuls, 2 sans les noms. On garde le premier qui tient avec
	# un écart d'au moins RES_MIN_GAP ; au-delà, le bandeau entier est réduit (fit).
	var widths: Array[float] = []
	var total := 0.0
	var gap := 49.0
	for level in 3:
		_res_level = level
		widths.clear()
		total = 2.0 * 23.0
		for k in keys:
			var it: Dictionary = _res_items[k]
			it["value"].text = _res_text(k)
			it["name"].visible = level < 2
			var nw := HudStyle.text_width(it["name"].text + " ", 16) + 8.0 if level < 2 else 0.0
			widths.append(26.0 + 10.0 + nw + HudStyle.text_width(it["value"].text, 20))
			total += widths[-1]
		gap = minf(49.0, (right - left - total) / (keys.size() - 1))
		if gap >= RES_MIN_GAP:
			break
	gap = maxf(gap, RES_MIN_GAP)
	total += gap * (keys.size() - 1)
	_res_panel.size = Vector2(total, 52.0)
	_res_panel.position = Vector2(left + maxf(0.0, (right - left - total) / 2.0), TOP_INSET.y)
	# Heure et météo : sous le bandeau des ressources, centrées.
	_sky_card.position = Vector2(roundf(_res_panel.position.x + (_res_panel.size.x - _sky_card.size.x) / 2.0), TOP_INSET.y + _res_panel.size.y + 8.0)
	_place_sky_card()
	var x := 23.0
	var seps: Array[float] = []
	for i in keys.size():
		var it: Dictionary = _res_items[keys[i]]
		it["icon"].position = Vector2(x, 13.0)
		it["icon"].size = Vector2(26, 26)
		var nw := HudStyle.text_width(it["name"].text + " ", 16) + 8.0 if _res_level < 2 else 0.0
		it["name"].position = Vector2(x + 36.0, 14.0)
		it["name"].size = Vector2(nw, 26.0)
		it["value"].position = Vector2(x + 36.0 + nw, 12.0)
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
## Carburant sur la première ligne, flèches en dessous.
func _layout_ammo(s: Vector2) -> void:
	var aw := HudStyle.text_width(_ammo_arrow_l.text, 20) + 4.0
	var fw := HudStyle.text_width(_ammo_fuel_l.text, 20) + 4.0
	var x := 18.0
	_ammo_fuel.position = Vector2(x + 2.0, 11.0)
	_ammo_fuel.size = Vector2(26, 26)
	_ammo_fuel_l.position = Vector2(x + 36.0, 9.0)
	_ammo_fuel_l.size = Vector2(fw, 28.0)
	var w := 36.0 + fw
	var h := 48.0
	if _ammo_arrow.visible:
		_ammo_arrow.position = Vector2(x, 9.0 + 38.0)
		_ammo_arrow.size = Vector2(30, 30)
		_ammo_arrow_l.position = Vector2(x + 36.0, 9.0 + 38.0)
		_ammo_arrow_l.size = Vector2(aw, 28.0)
		w = maxf(w, 36.0 + aw)
		h += 38.0
	_ammo_panel.size = Vector2(x + w + 18.0, h)
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
	# Panneau bas (petit écran) : la consigne passe à une ligne, puis le surtitre saute, plutôt que de sortir du cadre.
	var avail := m.y - 18.0
	var status_lines := clampi(_lines(_status.text, 10, w), 1, 2)
	if 10.8 + 4.0 + 23.8 + 8.0 + 21.0 + 5.0 + 11.0 * status_lines > avail:
		status_lines = 1
	var status_h := 11.0 * status_lines
	_status.max_lines_visible = status_lines
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var total := 10.8 + 4.0 + 23.8 + 8.0 + 21.0 + 5.0 + status_h
	_kind.visible = total <= avail
	var y := 9.0 + (m.y - 18.0 - total) / 2.0
	if not _kind.visible:
		total -= 14.8
		y = 9.0 + (m.y - 18.0 - total) / 2.0 - 14.8
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
	# La légende se réduit à une ligne, puis disparaît, quand le module est trop bas pour elle.
	var lore_lines := clampi(_lines(_lore.text, 12, w, HudStyle.italic()), 1, 2)
	while lore_lines > 0 and 50.0 + 8.0 + 16.8 * lore_lines > m.y - 22.0:
		lore_lines -= 1
	_lore.visible = lore_lines > 0
	_lore.max_lines_visible = maxi(lore_lines, 1)
	_lore.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var lore_h := 16.8 * lore_lines
	var total := 50.0 + (8.0 + lore_h if lore_lines > 0 else 0.0)
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
	# Module trop étroit : les noms sautent (icône et valeur seules) pour que la dernière statistique tienne.
	var compact := sum > w
	var value_px := 20
	if compact:
		# Corps de la valeur réduit tant que les quatre blocs ne tiennent pas (jusqu'à 14 px).
		while true:
			sum = 0.0
			for i in n:
				widths[i] = 24.0 + 4.0 + HudStyle.text_width(_stats[i]["value"].text, value_px) + (6.0 if i < n - 1 else 0.0)
				sum += widths[i]
			if sum <= w or value_px <= 14:
				break
			value_px -= 1
	for st: Dictionary in _stats:
		st["value"].add_theme_font_size_override("font_size", value_px)
	var gap := maxf(0.0, (w - sum) / float(n - 1))
	var x := 0.0
	var seps: Array[float] = []
	for i in n:
		var st: Dictionary = _stats[i]
		st["icon"].position = Vector2(x, 8.0 if compact else 0.0)
		st["icon"].size = Vector2(24, 24)
		st["name"].visible = not compact
		st["name"].position = Vector2(x + 32.0, -2.0)
		st["name"].size = Vector2(widths[i], 18.0)
		st["value"].position = Vector2(x + (28.0 if compact else 32.0), 6.0 if compact else 14.0)
		st["value"].size = Vector2(widths[i], 28.0)
		if i < n - 1 and not compact:
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
	research_card.position = Vector2(12.0, 9.0)
	research_card.size = Vector2(m.x - 24.0, m.y - 18.0)


func _layout_actions(m: Vector2) -> void:
	# Grille de 6 colonnes sur 2 rangées (style en ligne d'Index.html), écart 3, marge 5 + bordure 1.
	_actions_box.position = Vector2(6, 6)
	_actions_box.size = m - Vector2(12, 12)
	var cw := (_actions_box.size.x - 15.0) / 6.0
	# Bâtiment à recherches et au plus 6 boutons : une seule rangée, assez haute pour le nom sous l'objet.
	var one_row := _buttons.size() <= 6 and _buttons.any(func(b: ActionButton) -> bool: return b.action.has("research_icon"))
	var rh := _actions_box.size.y if one_row else (_actions_box.size.y - 3.0) / 2.0
	for i in _buttons.size():
		var b := _buttons[i]
		b.position = Vector2((i % 6) * (cw + 3.0), (i / 6) * (rh + 3.0))
		b.size = Vector2(cw, rh)


## Incarné en Ingénieur, sans bâtiment ni allié ouvert : menu de construction et de pose en bas à droite.
func _incarnated_menu() -> bool:
	var inc := GameState.incarnated
	return inc != null and inc.role == "engineer" and not HudModel.incarnated_panel() and not GameState.ended


func _refresh_incarnated_menu(actions: Array[Dictionary]) -> void:
	var inc_actions: Array[Dictionary] = []
	if _incarnated_menu():
		inc_actions = actions.filter(func(a: Dictionary) -> bool:
			var id: String = a["id"]
			return id in ["menu-build", "menu-place", "back"] or id.begins_with("place-") or id.begins_with("bfam-"))
	var sig := "|".join(inc_actions.map(func(a: Dictionary) -> String: return a["id"]))
	if sig != _inc_sig:
		_inc_sig = sig
		for b in _inc_buttons:
			b.queue_free()
		_inc_buttons.clear()
		for a in inc_actions:
			var b := ActionButton.new()
			b.mouse_entered.connect(_update_bubble)
			b.mouse_exited.connect(_update_bubble)
			_inc_actions.add_child(b)
			_inc_buttons.append(b)
	for i in inc_actions.size():
		_inc_buttons[i].set_action(inc_actions[i])


## Bas à droite, calé sur le bord de l'écran ; les carrés de construction au-dessus, alignés à droite.
func _layout_incarnated_menu() -> void:
	if not _incarnated_menu():
		# Désincarné : la carte du jour remonte sous le bandeau des ressources.
		if _sky_low:
			_sky_low = false
			_layout_top(_screen())
		return
	var gap := 6.0
	var right := _screen().x - Hud.BAR_MARGIN
	var n := _inc_buttons.size()
	_inc_actions.size = Vector2(maxf(0.0, n * (INC_BTN.x + gap) - gap), INC_BTN.y)
	_inc_actions.position = Vector2(right - _inc_actions.size.x, _screen().y - Hud.BAR_MARGIN - INC_BTN.y)
	for i in n:
		_inc_buttons[i].position = Vector2(i * (INC_BTN.x + gap), 0.0)
		_inc_buttons[i].size = INC_BTN
	var m := _build_buttons.size()
	_build_row.size = Vector2(maxf(0.0, m * (BuildButton.SIZE + gap) - gap), BuildButton.SIZE)
	# Centrée sur l'onglet de famille ouvert, gardée dans l'écran ; à droite à défaut d'onglet.
	var x := right - _build_row.size.x
	for i in n:
		if String(_inc_buttons[i].action.get("id", "")).begins_with("bfam-") and _inc_buttons[i].action.get("active", false):
			var cx := _inc_actions.position.x + i * (INC_BTN.x + gap) + INC_BTN.x / 2.0
			x = clampf(cx - _build_row.size.x / 2.0, Hud.BAR_MARGIN, right - _build_row.size.x)
	_build_row.position = Vector2(x, _inc_actions.position.y - gap - BuildButton.SIZE)
	for i in m:
		_build_buttons[i].position = Vector2(i * (BuildButton.SIZE + gap), 0.0)
	_place_sky_card()


## Incarné en Ingénieur (menu en bas à droite) : jour et heure au-dessus des carrés de construction,
## alignés à droite ; sinon, sous le bandeau des ressources (position posée par _layout_top).
func _place_sky_card() -> void:
	if not _incarnated_menu():
		return
	_sky_low = true
	var top := _build_row.position.y if _build_buttons.size() > 0 else _inc_actions.position.y
	_sky_card.position = Vector2(_screen().x - Hud.BAR_MARGIN - _sky_card.size.x, top - 6.0 - _sky_card.size.y)


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
	# Onglet du menu Construire survolé (Ingénieur incarné) : nom de la famille, au-dessus de la rangée des bâtiments.
	for ib in _inc_buttons:
		if ib.visible and ib.is_hovered() and String(ib.action.get("id", "")).begins_with("bfam-"):
			var info: Array = ib.action["bubble"]
			_build_bubble.set_text(info[0], info[1], info[2], info[3], info[4] if info.size() > 4 else "")
			_show_bubble(ib.global_position + Vector2(ib.size.x / 2.0, 0.0))
			for b in _build_buttons:
				b.queue_redraw()
			return
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
		# Boutons de fabrication : nom · coût (stock) · prérequis, au survol seulement.
		for ab in _buttons:
			if research_card.visible and ab.action.has("research_icon"):
				continue
			if ab.visible and ab.is_hovered() and ab.action.has("bubble"):
				var info: Array = ab.action["bubble"]
				_build_bubble.set_text(info[0], info[1], info[2], info[3], info[4] if info.size() > 4 else "")
				# Au-dessus du bandeau (pas sur la rangée du haut), pointe à l'aplomb du bouton.
				_show_bubble(Vector2(ab.global_position.x + ab.size.x / 2.0, _bar.global_position.y))
		return
	var D: Dictionary = Catalog.BUILDINGS[target.action["build_type"]]
	var why := ""
	if target.action.get("locked", false):
		why = HudModel.lock_reason(target.action["build_type"])
	var build_cost := Catalog.building_cost(target.action["build_type"])
	_build_bubble.set_text(D["name"], Catalog.cost_text(build_cost), Catalog.can_pay(build_cost), why, String(D.get("lore", "")))
	_show_bubble(target.global_position + Vector2(BuildButton.SIZE / 2.0, 0.0))


## Fiche de recherche : la recherche survolée, sinon celle qui avance, sinon la première du bâtiment.
func _update_research_card() -> void:
	var pick: ActionButton = null
	var first: ActionButton = null
	var running: ActionButton = null
	for b in _buttons:
		if not b.action.has("research_icon"):
			continue
		if first == null:
			first = b
		if b.is_hovered():
			pick = b
		if running == null and b.action.get("active", false):
			running = b
	var show := first != null and HudModel.selected_building() != null
	research_card.visible = show
	_unit_details.visible = not show and not _view.get("anchor_details", false)
	if not show:
		return
	if pick == null:
		pick = running if running else first
	research_card.show_research(pick.action["research_icon"], pick.action["key"])


## Bulle dont la pointe touche `c` (milieu du bord haut du bouton), gardée dans l'écran.
func _show_bubble(c: Vector2) -> void:
	var x := clampf(c.x - _build_bubble.size.x / 2.0, 8.0, _screen().x - 8.0 - _build_bubble.size.x)
	_build_bubble.position = Vector2(x, c.y - 10.0 - _build_bubble.size.y)
	_build_bubble.tip_x = c.x - x
	_build_bubble.visible = true
	_build_bubble.queue_redraw()


func _layout_notice() -> void:
	var s := _screen()
	# Bannière 16 bits en haut de l'écran (SnesBanner), sous le dialogue s'il y en a un.
	var w := SnesBanner.width(s)
	_notice.size = Vector2(w, SnesBanner.height(_notice_label.text, w))
	_notice.position = Vector2(roundf((s.x - w) / 2.0), _notice_top())
	_notice_label.position = SnesBanner.PAD
	_notice_label.size = _notice.size - 2.0 * SnesBanner.PAD


func _notice_top() -> float:
	if dialogue and dialogue.active() and dialogue.visible:
		return dialogue.position.y + dialogue.size.y + 6.0
	return BossBar.top()


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
	if _pending_equipment != null and not Opening.cinematic():
		var pu := _pending_equipment
		_pending_equipment = null
		_show_equipment_dialogue(pu)
	if sim == null:
		return
	dialogue.tick(minf(delta, Simulation.MAX_DT))
	_help_button.visible = HelpPanel.open or not Opening.cinematic()
	_notice.position.y = _notice_top()
	# Incarnation : mode action pur, sans bandeau de commandement.
	var free := GameState.incarnated == null
	# Incarné : le bandeau ne revient que pour les options d'un bâtiment ouvert au clic droit.
	var full_bar := free or HudModel.incarnated_panel()
	# Recherche « Minicarte » : incarné, seule la minicarte reste affichée (le reste du bandeau est masqué).
	var map_only := not full_bar and GameState.research_done.has("minimap")
	_bar.visible = full_bar or map_only
	_bar.self_modulate.a = 0.0 if map_only else 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE if map_only else Control.MOUSE_FILTER_STOP
	_diamonds.visible = not map_only
	_zoom.visible = _bar.visible
	for i in range(1, _modules.size()):
		_modules[i].visible = not map_only
	_build_row.visible = free or _incarnated_menu()
	_inc_actions.visible = _incarnated_menu()
	# Compteurs de ressources : cachés jusqu'au premier gain de mana (séquence d'ouverture), puis gardés.
	if not _res_shown and (GameState.opening_stage == "" or GameState.res.values().any(func(v: float) -> bool: return v > 0.0)):
		_res_shown = true
	_res_panel.visible = _res_shown
	if _notice_end < GameState.sim_time:
		_notice.modulate.a = maxf(0.0, _notice.modulate.a - delta / 0.2)
	else:
		_notice.modulate.a = minf(1.0, _notice.modulate.a + delta / 0.2)
	if _wave_alert_end < GameState.sim_time:
		_wave_alert.modulate.a = maxf(0.0, _wave_alert.modulate.a - delta / 0.6)
	else:
		_wave_alert.modulate.a = minf(1.0, _wave_alert.modulate.a + delta / 0.2)
	var ctx := "%s|%s|%s|%s|%s|%s|%s|%s" % [GameState.selected.map(func(u: Unit) -> int: return u.id), GameState.hud_menu,
		GameState.hud_mode, GameState.hud_build_type, GameState.hud_building.id if GameState.hud_building else -1,
		GameState.anchor_selected, GameState.ended, GameState.hud_enemy.get_instance_id() if GameState.hud_enemy else 0] + str(GameState.hud_grove)
	var t := GameState.sim_time
	if ctx != _ctx or t < _last_update or t - _last_update >= 0.1:
		_ctx = ctx
		_last_update = t
		refresh()


## updateHUD : textes, ordres, portrait ; minicarte au plus toutes les 0,1 s de simulation.
func refresh(force_map := false) -> void:
	quests.update()
	objective.push(quests.objective())
	# Encarts d'objectif masqués (2026-11-19).
	objective.visible = false
	var v := HudModel.view(sim)
	var relayout := false
	if v != _view:
		relayout = true
		_apply_view(v)
		_view = v
	if research_shelf.update_ids():
		relayout = true
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
			b.mouse_entered.connect(_update_research_card)
			b.mouse_exited.connect(_update_research_card)
			_actions_box.add_child(b)
			_buttons.append(b)
		relayout = true
	for i in actions.size():
		_buttons[i].set_action(actions[i])
	_update_research_card()
	_refresh_incarnated_menu(actions)
	if relayout:
		_layout()
	_layout_incarnated_menu()
	var t := GameState.sim_time
	if force_map or t < _last_map or t - _last_map >= 0.1:
		_last_map = t
		minimap.refresh()


func _apply_view(v: Dictionary) -> void:
	var wave_text: String = "Vague " + v["wave"]
	var relayout_wave := _wave_label.text.length() != wave_text.length()
	_wave_label.text = wave_text
	# Pas de compteur de vague tant qu'aucune vague n'a été lancée.
	var show_wave := GameState.wave > 0
	if relayout_wave and show_wave:
		_layout_top(_screen())
	if _wave_card.visible != show_wave:
		_wave_card.visible = show_wave
		_layout_top(_screen())
	var sky: Dictionary = v["sky"]
	var text: String = sky["day"] + " · " + sky["time"] + " · " + sky["weather"]
	if sky["next"] != "":
		text += " › " + sky["next"]
	if _sky_label.text != text or _sky_key != sky["time_icon"]:
		var relayout_sky := _sky_label.text.length() != text.length()
		_sky_label.text = text
		if _sky_key != sky["time_icon"]:
			_sky_key = sky["time_icon"]
			_sky_icon.texture = HudStyle.icon(sky["time_icon"], 22)
		if relayout_sky:
			_layout_top(_screen())
	var res_len := 0
	var res_before := 0
	for k in Catalog.RES_ORDER:
		res_before += _res_items[k]["value"].text.length()
		_res_raw[k] = [v["res"][k], HudModel.num_fr(v["resource_rates"][k])]
		_res_items[k]["value"].text = _res_text(k)
		res_len += _res_items[k]["value"].text.length()
	res_before += _res_items["population"]["value"].text.length() + _res_items["menace"]["value"].text.length()
	res_len += String(v["population"]).length() + String(v["menace"]).length()
	_res_items["population"]["value"].text = v["population"]
	var n_arrows := Catalog.ItemStorage.count_ammo("arrows")
	var arrows := "× %d" % n_arrows
	# Pas de compteur de flèches tant que la réserve n'en a aucune.
	if _ammo_arrow.visible != (n_arrows > 0) or _ammo_arrow_l.text != arrows:
		_ammo_arrow.visible = n_arrows > 0
		_ammo_arrow_l.visible = n_arrows > 0
		_ammo_arrow_l.text = arrows
		_layout_ammo(_screen())
	_res_items["menace"]["value"].text = v["menace"]
	# Une valeur a changé de longueur : le bandeau se remet en page (sinon les blocs se chevauchent).
	if res_len != res_before:
		_layout_top(_screen())
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
		elif _portrait_key == "grove":
			# Bosquet pétrifié : premier état (intact) de bosquet.png, cadré en carré sur le feuillage.
			var at := AtlasTexture.new()
			at.atlas = GroveView.SPRITES
			at.region = Rect2(0, 8, 96, 96)
			_portrait.texture = at
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
	# Carillon seulement quand la bannière s'ouvre (pas à chaque remplacement de texte).
	if _notice.modulate.a < 0.05 and not text.is_empty():
		Sfx.play("ui_banniere")
	_notice_label.text = text
	_notice_end = GameState.sim_time + seconds
	_notice.modulate.a = maxf(_notice.modulate.a, 0.01)
	_layout_notice()


## Alerte de vague, en rouge au-dessus de la minicarte ; s'efface seule au bout de `seconds`.
func show_wave_alert(text: String, seconds := 5.0) -> void:
	_wave_alert.text = text
	_wave_alert_end = GameState.sim_time + seconds
	_wave_alert.modulate.a = maxf(_wave_alert.modulate.a, 0.01)
	_layout_wave_alert()


## Alerte de vague calée sur le bord gauche de la minicarte, juste au-dessus du bandeau de commandement.
func _layout_wave_alert() -> void:
	var x := _bar.position.x + _modules[0].position.x
	var w := maxf(_modules[0].size.x, HudStyle.text_width(_wave_alert.text, 20) + 8.0)
	_wave_alert.position = Vector2(x, _bar.position.y - 8.0 - 30.0)
	_wave_alert.size = Vector2(w, 30.0)


## Masque la notice immédiatement (captures de revue).
func hide_notice() -> void:
	_notice_end = -1.0
	_notice.modulate.a = 0.0


## end(won) : bannière de fin de partie (les conditions de fin arrivent avec le combat, étape 8).
func show_banner(won: bool) -> void:
	# Bannière de victoire masquée (tri des répliques du 2026-11-20).
	if won:
		return
	_banner_title.text = "L’ANCRE EST PERDUE"
	_banner_small.text = "Maj + R pour recommencer."
	_banner.visible = true
	_layout_banner()


func _on_reset() -> void:
	_res_shown = false
	_wave_alert_end = -1.0
	_wave_alert.modulate.a = 0.0
	_fast_construction.set_pressed_no_signal(GameState.fast_construction)
	_fast_construction.text = "Construction rapide : ON" if GameState.fast_construction else "Construction rapide : OFF"
	dialogue.close()
	item_banner.close()
	grimoire.visible = false
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
		elif GameState.hud_grove != null:
			p = Vector2(GameState.hud_grove * 4) + Vector2(4, 4)
	if p != null:
		world.camera.set_view(p, world.camera.px)
		refresh(true)


func _input(event: InputEvent) -> void:
	# Menu de debug déplié : un clic hors de ses boutons (et hors de DEBUG, qui bascule seul) le replie ; le clic poursuit sa route.
	if _debug_open and event is InputEventMouseButton and event.pressed:
		var at: Vector2 = event.position
		var on_button := _debug_toggle.get_global_rect().has_point(at)
		for b: Button in _debug_buttons():
			on_button = on_button or b.get_global_rect().has_point(at)
		if not on_button:
			_set_debug_open(false)
	# Bannières « Reçu : … » : n'importe quelle action passe à la suivante (posée par-dessus), puis referme.
	if item_banner.active() and event.is_pressed():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if not event.is_echo():
				item_banner.advance()
			get_viewport().set_input_as_handled()
			return
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
		return
	# Codex d'aide : F1 l'ouvre ; ouvert, il garde le clavier (Échap, flèches) et le jeu ne reçoit rien.
	if help_panel.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# Grimoire des recherches : X l'ouvre et le ferme ; ouvert, Échap le ferme.
	var gkey: Key = (event.key_label if event.key_label != KEY_NONE else event.keycode) if event is InputEventKey else KEY_NONE
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed \
			and (gkey == KEY_X or grimoire.visible and gkey == KEY_ESCAPE) and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if grimoire.visible or research_shelf.ids.has(""):
			grimoire.toggle()
			refresh(true)
			get_viewport().set_input_as_handled()
			return
	# Minicarte plein écran : TAB ou M (recherche « Minicarte » achevée). TAB ne change plus le focus.
	var map_key: Key = (event.key_label if event.key_label != KEY_NONE else event.keycode) if event is InputEventKey else KEY_NONE
	if event is InputEventKey and event.pressed and not event.echo and map_key in [KEY_TAB, KEY_M] \
			and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		if not (get_viewport().gui_get_focus_owner() is LineEdit) and MinimapOverlay.available():
			minimap_overlay.toggle()
			refresh(true)
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
				HudStyle.metal_panel(self, size)
				if kind == "metal":
					for x in separators:
						draw_rect(Rect2(x, 13.0, 1.0, 26.0), Color(SnesBanner.INFO[3], 0.45))
			"bar":
				draw_rect(r.grow(3.0), Color(SnesBanner.INFO[4], 0.6))
				draw_rect(r, SnesBanner.INFO[1].darkened(0.35))
			"notice":
				SnesBanner.paint(self, r)
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
			# Même rampe que les barres au-dessus des unités : turquoise allié, saumon ennemi.
			var top := UnitView.HP_ENEMY if enemy else UnitView.HP_ALLY
			var bottom := UnitView.HP_ENEMY.darkened(0.45) if enemy else UnitView.HP_ALLY.darkened(0.45)
			HudStyle.linear_gradient(self, fill, 180.0, [[0.0, top], [1.0, bottom]])
		HudStyle.ring(self, r, 1.0, UnitView.HP_ENEMY.darkened(0.25) if enemy else UnitView.HP_ALLY.darkened(0.25))
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
			draw_rect(Rect2(x, 0.0, 1.0, 41.0), Color(SnesBanner.INFO[3], 0.35))
		draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Color(SnesBanner.INFO[3], 0.45))

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
		HudStyle.ring(self, r, 1.0, SnesBanner.RIM_LO)
		# Rune « centrer » : pastille sur l'angle du cadre, hors du visage.
		var badge := Rect2(Vector2(-3, -3), Vector2(16, 16))
		draw_rect(badge, SnesBanner.EDGE)
		HudStyle.ring(self, badge, 1.0, SnesBanner.RIM_LO)
		draw_texture_rect(_rune, badge.grow(-2.0), false, SnesBanner.RIM)


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
	## Seconde ligne facultative (effet d'une recherche, d'une unité), plus petite.
	var _desc := ""
	var _desc_h := 0.0
	const DESC_W := 340.0

	func set_text(name: String, cost: String, ok: bool, why: String, desc := "") -> void:
		_parts = [[name, HudStyle.IVORY]]
		if cost:
			_parts += [["  ·  ", HudStyle.MUTED], [cost, Color("#e8c35a") if ok else Color("#d36a52")]]
		if why:
			_parts += [["  ·  ", HudStyle.MUTED], [why, Color("#a8d890") if why == "Déjà achevée" else HudStyle.MUTED]]
		_desc = desc
		var w := 0.0
		for p in _parts:
			w += HudStyle.text_width(p[0], 15)
		_desc_h = 0.0
		if desc:
			# Descriptif sur plusieurs lignes au-delà de DESC_W (lore des bâtiments).
			w = clampf(HudStyle.text_width(desc, 13), w, maxf(w, DESC_W))
			_desc_h = HudStyle.font().get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, w, 13).y
		size = Vector2(w + 28.0, 32.0 + (_desc_h + 6.0 if desc else 0.0))

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
		if _desc:
			draw_multiline_string(f, Vector2(14.0, 26.0 + f.get_ascent(13)), _desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13, -1, HudStyle.MUTED)


## Icône d'objet de l'inventaire (bande items.png), dessinée au centre du contrôle.
class _ItemGlyph extends Control:
	const Icon := preload("res://ui/inventory/item_icon.gd")
	var item := ""

	func _draw() -> void:
		Icon.draw_item(self, item, size * 0.5, size.x / 32.0)
