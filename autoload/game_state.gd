extends Node
## État global de la partie (autoload « GameState »).
## Contient uniquement des données ; la logique vit dans res://sim/.
## Chaque champ ajouté doit être remis à sa valeur initiale dans reset().

## Temps de simulation écoulé en secondes (currentTime dans Index.html:65).
var sim_time: float = 0.0
## Accélération des chantiers activée par le bouton du HUD.
var fast_construction := false

## Partie terminée (victoire ou défaite) : la simulation est figée.
var ended: bool = false

## L'Ancre a été réactivée par l'Ingénieur (ORB.active, buildings.js). Éteinte au départ.
var orb_active: bool = false
## Progression de la réactivation, en secondes (ORB.progress, sur ORB.time = 8 s).
var orb_progress: float = 0.0
## Instant de la réactivation (ORB.finishedAt), INF avant.
var orb_finished_at: float = INF
## Étincelle de l'Ancre partie, balistes pas encore armées (elles s'arment à son arrivée, 4,75 s après).
var spark_pending: bool = false
## Surcharge de l'Ancre (sim/overload.gd) : début (INF avant), impact de la nova sur l'Ingénieur,
## Ingénieur pris dedans, étape (0 aucune, 1 en cours, 2 armure perdue, 3 dialogue lancé).
var overload_at: float = INF
var overload_hit: float = INF
var overload_unit: Unit = null
var overload_stage: int = 0
## Instant de (re)lancement de la séquence du portail des Exilés (PORTAL.start).
var portal_start: float = 0.0
## Portails divins actifs (DEITY_PORTALS[].active) : id du dieu -> vrai pendant une invocation.
var deity_active: Dictionary = {}
## Unité qui réactive l'Ancre (ORB.owner), ou null.
var orb_owner: Unit = null
## Intégrité de l'Ancre en % (coreHP).
var core_hp: float = 1.0
## Prochain assaut (nextWave), 0 si aucun n'est programmé.
var next_wave: float = 0.0

## Ressources (RES, buildings.js) : Forge, Vie, Discipline, Savoir.
var res: Dictionary = {"forge": 0.0, "vie": 0.0, "discipline": 0.0, "savoir": 0.0}

## Ressource cumulative : soldats ennemis tués et nouveaux adeptes recrutés.
var menace: int = 0
## Recherches achevées et en cours (id -> {building, progress}).
var research_done: Dictionary = {}
var research_jobs: Dictionary = {}
## Coffre antique : le système qui le débloque positionne ce drapeau.
var base_inventory_unlocked := false
## L'Ingénieur a déjà remarqué le glyphe de la paroi est (réplique dite une seule fois par partie).
var vault_hint_said := false
## Instant où l'Ingénieur a ouvert le coffre antique (animation du couvercle), INF avant.
var chest_opened_at: float = INF
## Une pile {item, quantity} par case, limitée à 9 999 objets.
var base_inventory: Array[Dictionary] = []
## Défenses de l'Atelier posées (sim/placeables.gd) : {item, cell: Vector2i, x, z, tick}.
var placed: Array[Dictionary] = []
## Objet à poser en mode « place » (HUD.mode), choisi dans le menu Poser de l'Ingénieur.
var hud_place_item: String = ""
## Objets persistants au sol : {item: identifiant, position: Vector2(x, z)}.
var ground_items: Array[Dictionary] = []

## Unités alliées et sélection (units, selected).
var units: Array[Unit] = []
var selected: Array[Unit] = []
var next_uid: int = 0
## HUD.anchor (l'Ancre est sélectionnée) et HUD.mode (null, "move", "build").
var anchor_selected: bool = false
var hud_mode: String = ""
## HUD.menu ("" ou "build"), HUD.buildType (bâtiment à placer) et HUD.building (bâtiment sélectionné).
var hud_menu: String = ""
var hud_build_type: String = ""
var hud_building: Building = null
## Ennemi sélectionné (écart voulu D14), ou null.
var hud_enemy: Enemy = null

## Numéro de la vague en cours (wave), 0 avant le premier assaut.
var wave: int = 0
## Assauts programmés (spawnQueue : {"at": instant}) et ennemis vivants (étape 8).
var spawn_queue: Array = []
var enemies: Array = []
## Corps purement visuels : ne bloquent ni les assauts ni le ciblage.
var enemy_corpses: Array[Enemy] = []
## Premier boss, la Martyre de Byrsa (sim/martyre.gd) : "" pas encore venue, "waiting" bouclier levé,
## "duel" Ingénieur sous le bouclier, "defeated" tombée. Centre du bouclier, apparition, chute, impact attendu.
var martyre: Enemy = null
var martyre_state := ""
var martyre_center := Vector2.ZERO
var martyre_at: float = INF
var martyre_down_at: float = INF
var martyre_hit_at: float = INF
## Bâtiments du sanctuaire (buildings) et unités tombées que le Puits des Âmes peut rappeler (FALLEN).
var buildings: Array[Building] = []
var fallen: Array[Unit] = []
## Effets visuels (effects : {type, x, z, age, duration, …}) et murs de feu du lance-flammes (fireWalls).
var effects: Array[Dictionary] = []
## Chiffres de dégâts flottants ({target, x, z, amount, age, duration}), hors de `effects` (parité JS).
var damage_numbers: Array[Dictionary] = []
## Objets déjà récoltés au moins une fois dans la partie (« Nouvelle ressource : … ! »).
var collected_items: Dictionary = {}
var fire_walls: Array[Dictionary] = []
## Balistes de l'entrée (turrets : {id, x, z, complete, cycle_age, firing, target, aim, …}) et carreaux en vol.
var turrets: Array[Dictionary] = []
var turret_bolts: Array[Dictionary] = []
## Popups de prière (prayPopups : {x, z, amount, res, at}).
var pray_popups: Array[Dictionary] = []
## Fin d'activité de chaque portail divin (DEITY_PORTALS[].activeUntil), par dieu.
var deity_until: Dictionary = {}
## Point du sol sous le pointeur (templePointer), pour l'aperçu de construction ; null hors du monde.
var build_pointer: Variant = null


func reset() -> void:
	sim_time = 0.0
	fast_construction = false
	ended = false
	orb_active = false
	orb_progress = 0.0
	orb_finished_at = INF
	spark_pending = false
	overload_at = INF
	overload_hit = INF
	overload_unit = null
	overload_stage = 0
	portal_start = 0.0
	deity_active = {}
	orb_owner = null
	core_hp = 1.0
	next_wave = 0.0
	res = {"forge": 0.0, "vie": 0.0, "discipline": 0.0, "savoir": 0.0}
	menace = 0
	research_done.clear()
	research_jobs.clear()
	base_inventory_unlocked = false
	chest_opened_at = INF
	vault_hint_said = false
	base_inventory.clear()
	ground_items.clear()
	placed.clear()
	units.clear()
	selected.clear()
	next_uid = 0
	anchor_selected = false
	hud_mode = ""
	hud_menu = ""
	hud_build_type = ""
	hud_place_item = ""
	hud_building = null
	hud_enemy = null
	wave = 0
	spawn_queue = []
	enemies = []
	martyre = null
	martyre_state = ""
	martyre_center = Vector2.ZERO
	martyre_at = INF
	martyre_down_at = INF
	martyre_hit_at = INF
	enemy_corpses.clear()
	buildings.clear()
	fallen.clear()
	pray_popups.clear()
	effects.clear()
	collected_items.clear()
	damage_numbers.clear()
	fire_walls.clear()
	turrets.clear()
	turret_bolts.clear()
	deity_until = {}
	build_pointer = null
	Events.game_reset.emit()
