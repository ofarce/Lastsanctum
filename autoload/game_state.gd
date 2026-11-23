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
## Séquence d'ouverture (sim/opening.gd) : étape (vide = pas de séquence) et son début.
var opening_stage := ""
var opening_at: float = 0.0
var door_closed := false
var shield_up := false
var shield_at: float = INF
var shield_line_said := false
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
## Caches de la jungle à fouiller (sim/loot.gd, place_caches) : {x, z, kind, loot}.
var caches: Array[Dictionary] = []

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
## Onglet ouvert du menu Construire (HudModel.BUILD_FAMILIES).
var hud_build_family: String = "temples"
var hud_building: Building = null
## Coffre désigné au clic droit (halo de sélection) : {"kind": "vault"} pour le coffre antique,
## {"building": Building, "kind": "in" | "out"} pour un coffre de production ; vide sinon.
var hud_chest: Dictionary = {}
## Ennemi sélectionné (écart voulu D14), ou null.
var hud_enemy: Enemy = null
## Bosquet pétrifié sélectionné (origine Vector2i de ses 2 × 2 cases), ou null.
var hud_grove: Variant = null

## Numéro de la vague en cours (wave), 0 avant le premier assaut.
var wave: int = 0
## Repaires de la faune hostile (sim/wildlife.gd) : {kind, x, z, beast, empty_since}.
var wildlife_lairs: Array[Dictionary] = []
## Errants des galeries (sim/roamers.gd) : {state, seed, dens} ; vide = à tirer.
var roamers: Dictionary = {}
## Portails fixes des salles allumés (sim/portal_net.gd, biomes en salles) : id de salle du plan → vrai.
var room_portals: Dictionary = {}
## Vague dont le rappel d'assaut gratuit a déjà servi (PortalNet.assault_recall) ; 0 = aucune.
var assault_recall_wave: int = 0
## Flot nocturne (sim/night.gd) : instant du prochain squelette (0 = à tirer), nuit déjà annoncée (numéro du jour).
var night_next: float = 0.0
## Prochain reflux d'un Pylône de Merenor canalisé (sim/portal_net.gd) ; 0 = à tirer.
var reflux_next: float = 0.0
var night_day: int = 0
## Décor et salles à thème du Temple (sim/sanctum.gd) : {state, seed, layout, lit, done, next} ; vide = à tirer.
var sanctum: Dictionary = {}
## Gorge-Cuivre, boss du biome 2 (sim/gorge.gd) : {state, seed, e, mode, phase, marks…} ; vide = à créer.
var gorge: Dictionary = {}
## Météo de la jungle (core/weather.gd) : {kind, from, since} ; vide = temps clair.
var weather: Dictionary = {}
## Assauts programmés (spawnQueue : {"at": instant}) et ennemis vivants (étape 8).
var spawn_queue: Array = []
## Escouades de la vague en cours : total et déjà sorties (compteur du HUD).
var wave_squads := 0
var squads_out := 0
var enemies: Array = []
## Corps purement visuels : ne bloquent ni les assauts ni le ciblage.
var enemy_corpses: Array[Enemy] = []
## Premier boss, la Martyre de Byrsa (sim/martyre.gd) : "" pas encore venue, "waiting" bouclier levé,
## "duel" Ingénieur sous le bouclier, "defeated" tombée. Centre du bouclier, apparition, chute, impact attendu.
var martyre: Enemy = null
var martyre_state := ""
## Martyre levée dans son arène du quartier B (Temple en salles) : hors vague, les assauts continuent ; sa mort
## ouvre la porte mb2 de la route du boss.
var martyre_arena := false
## L'Archiprêtre aux racines, mini-boss 1 du Temple (sim/archipretre.gd) ; vide = à poser.
var archipretre: Dictionary = {}
var martyre_center := Vector2.ZERO
var martyre_at: float = INF
var martyre_down_at: float = INF
var martyre_hit_at: float = INF
## Coup de bâton attendu ("melee" ou "fissure") et point visé ; incantation des sceaux en cours ; geste en
## cours (elle ne bouge pas) ; effets au sol (sim/martyre.gd).
var martyre_hit_kind := "melee"
var martyre_aim := Vector2.ZERO
var martyre_cast_at: float = INF
var martyre_busy_until: float = -INF
var martyre_fx: Array[Dictionary] = []
## Salves (planches/martyre-bullet-hell.html) : balles en vol, gestes à venir, phase (0, 1, 2), prochain
## motif (instant, combinaison imposée sinon rotation de la phase, rang dans chaque rotation), rayon courant
## du bouclier et début de son resserrement, fin de l'invulnérabilité de l'Ingénieur après un coup.
## Balles des ennemis à distance tirées sur l'Exilé incarné (sim/enemy_shots.gd).
var enemy_shots: Array[Dictionary] = []
## Souffles armés des squelettes explosifs tombés (sim/skeletons.gd) : {x, z, at, dmg}.
var skeleton_blasts: Array[Dictionary] = []
var martyre_bullets: Array[Dictionary] = []
var martyre_events: Array[Dictionary] = []
var martyre_phase := 0
var martyre_next_at: float = INF
var martyre_next: Array = []
var martyre_rot: Array = [0, 0, 0]
var martyre_radius := 48.0
var martyre_shrink_at: float = INF
var martyre_iframe_until: float = -INF
## Boss de la frontière, l'Œil de la Matrice (sim/oeil.gd) : "" salle pas encore découverte, "waiting" éveillé,
## "duel" Ingénieur dans la salle, "defeated" tombé (porte de chair ouverte). Balles en vol, couloirs du Regard
## (fx), et le reste de son état dans oeil_run (phase, prochain motif, ouverture de l'œil, regard…).
var oeil: Enemy = null
var oeil_state := ""
var oeil_bullets: Array[Dictionary] = []
var oeil_fx: Array[Dictionary] = []
var oeil_run: Dictionary = {}
## Bâtiments du sanctuaire (buildings) et unités tombées que le Puits des Âmes peut rappeler (FALLEN).
var buildings: Array[Building] = []
var fallen: Array[Unit] = []
## Effets visuels (effects : {type, x, z, age, duration, …}) et murs de feu du lance-flammes (fireWalls).
var effects: Array[Dictionary] = []
## Chiffres de dégâts flottants ({target, x, z, amount, age, duration}), hors de `effects` (parité JS).
var damage_numbers: Array[Dictionary] = []
## Objets déjà récoltés au moins une fois dans la partie (« Nouvelle ressource : … ! »).
var collected_items: Dictionary = {}
## Âges des métaux ouverts (sim/ages.gd) : âge → true.
var ages_open: Dictionary = {}
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
## Exilé incarné (galerie des Exilés) : la caméra le suit, ZQSD/flèches le pilotent, clic droit tire.
var incarnated: Unit = null
## L'Ingénieur est entré dans la capsule (au centre de la paroi nord, Capsule) : caché, désincarné.
var in_capsule := false
## Capsule alimentée par l'Ancre (trait d'énergie arrivé) : allumée et utilisable.
var capsule_on := false
## Équipement de départ remis (Arbalestrie, Combinaison, Sceau de minage, plan « Analyse ») : depuis le 2026-11-22, par
## le Coffre Antique à sa première ouverture (Simulation.open_chest), et non plus par la capsule. Nom gardé pour les sauvegardes.
var capsule_gift := false
## Sceau de minage remis par le Coffre Antique : l'Ingénieur peut creuser la roche.
var mining_seal := false
## Plans de fabrication appris (« analyse » : mod Analyse à l'Établi d'exo, data/recipes.gd PLANS).
var plans: Array[String] = []
## Mods déjà fabriqués (2026-11-22) : un mod ne se fabrique qu’une fois.
var mods_crafted: Array[String] = []
## Dernier coup reçu par l'Exilé incarné (Combat.damage) : il compte comme « en combat » COMBAT_CALM secondes.
var incarnated_hurt_at := -INF
## Retour de l'Ingénieur tombé : instant où il réapparaît dans la capsule (INF s'il est en vie).
var engineer_respawn_at: float = INF
## Munition choisie pour l'Arbalestrie (data/ammo.gd), gardée d'une incarnation à l'autre.
var ammo := "spirit"
## Munition d'avant le dernier changement et instant du changement (Barillet double, Culasse froide : sim/mods.gd) ;
## Barillet double : vrai si le prochain tir part de la seconde chambre.
var ammo_prev := "spirit"
## Mods déjà annoncés par le grand écrin (ui/hud/mod_reveal.gd) : clé = objet ; un mod ne s'annonce qu'une fois.
var mods_seen: Dictionary = {}
var ammo_changed_at := -INF
var barrel_flip := false
## Écho du pylône : assaut et nuit de meutes déjà annoncés (sim/mods.gd).
var echo_wave := -1.0
var echo_raid_day := -1


func reset() -> void:
	incarnated = null
	in_capsule = false
	capsule_on = false
	capsule_gift = false
	mining_seal = false
	plans.clear()
	mods_crafted.clear()
	incarnated_hurt_at = -INF
	engineer_respawn_at = INF
	ammo = "spirit"
	ammo_prev = "spirit"
	mods_seen = {}
	ammo_changed_at = -INF
	barrel_flip = false
	echo_wave = -1.0
	echo_raid_day = -1
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
	opening_stage = ""
	opening_at = 0.0
	door_closed = false
	shield_up = false
	shield_at = INF
	shield_line_said = false
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
	base_inventory.clear()
	ground_items.clear()
	caches.clear()
	placed.clear()
	units.clear()
	selected.clear()
	next_uid = 0
	anchor_selected = false
	hud_mode = ""
	hud_menu = ""
	hud_build_type = ""
	hud_build_family = "temples"
	hud_place_item = ""
	hud_building = null
	hud_chest = {}
	hud_enemy = null
	hud_grove = null
	wave = 0
	wildlife_lairs.clear()
	roamers = {}
	room_portals = {}
	assault_recall_wave = 0
	night_next = 0.0
	reflux_next = 0.0
	night_day = 0
	sanctum = {}
	gorge = {}
	weather = {}
	Weather.river = null
	Weather.road = null
	spawn_queue = []
	wave_squads = 0
	squads_out = 0
	enemies = []
	martyre = null
	martyre_state = ""
	martyre_arena = false
	archipretre = {}
	martyre_center = Vector2.ZERO
	martyre_at = INF
	martyre_down_at = INF
	martyre_hit_at = INF
	martyre_hit_kind = "melee"
	martyre_aim = Vector2.ZERO
	martyre_cast_at = INF
	martyre_busy_until = -INF
	martyre_fx.clear()
	martyre_bullets.clear()
	enemy_shots.clear()
	skeleton_blasts.clear()
	martyre_events.clear()
	martyre_phase = 0
	martyre_next_at = INF
	martyre_next = []
	martyre_rot = [0, 0, 0]
	martyre_radius = 48.0
	martyre_shrink_at = INF
	martyre_iframe_until = -INF
	oeil = null
	oeil_state = ""
	oeil_bullets.clear()
	oeil_fx.clear()
	oeil_run = {}
	enemy_corpses.clear()
	buildings.clear()
	fallen.clear()
	pray_popups.clear()
	effects.clear()
	collected_items.clear()
	ages_open.clear()
	damage_numbers.clear()
	fire_walls.clear()
	turrets.clear()
	turret_bolts.clear()
	deity_until = {}
	build_pointer = null
	Events.game_reset.emit()
