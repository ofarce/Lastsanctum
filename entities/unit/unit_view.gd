class_name UnitView
extends Node2D
## Rendu d'une unité alliée ou d'un ennemi (drawUnitSprite et drawCharacter, Index.html, 73b410f) :
## ombre et sélection (ellipses), sprite (repos, marche à la distance parcourue, agenouillement, coups
## d'épée et salves d'arbalète), orientation vers l'ennemi visé ou dans le sens de la marche, barre de vie,
## badge de niveau.
## Origine du nœud : point au sol continu ; le sprite est aligné sur la grille native par le shader.

const Ammo := preload("res://data/ammo.gd")
const SPR_FRAMES := 24
## Repos : 12 i/s (grille commune 12 / 24 i/s), soit 2 s pour 24 images.
const IDLE_FPS := 12.0
## Z()/PX = 8/0,86 : unité de monde en pixels natifs pour les ellipses (circle3).
const ZN := 8.0 / 0.86
const SHADOW := Color("#0b1615a0")
## Sélection alliée en cyan (couleur des Exilés) : l'or est réservé aux forces de Laetan.
const SEL_FILL := Color("#5ce8ff40")
const SEL_LINE := Color("#8ff2ff")
const FOE_FILL := Color("#db505055")
const FOE_LINE := Color("#ff7a6a")
const HP_BG := Color("#191b1d")
const HP_ALLY := Color("#85d6b1")
const HP_GUARD := Color("#9db88f")
const HP_ENEMY := Color("#db7772")
const Gear := preload("res://data/gear_items.gd")
## Halo de sélection alliée : lueur cyan douce au sol, anneau vif par-dessus.
const HALO := Color("#3fe6ff")

## Unité amie sous le pointeur (InputController) : seule elle montre sa barre de vie.
static var hovered: Unit

var unit: Unit
var simulation: Simulation
var world: World
var _meta: Dictionary
var _idle: Array[AtlasTexture] = []
var _walk: Array[AtlasTexture] = []
var _enemy_attack: Array[AtlasTexture] = []
var _enemy_death: Array[AtlasTexture] = []
## Animations propres à la Martyre de Byrsa : incantation et réaction aux coups (vides pour les autres).
var _enemy_cast: Array[AtlasTexture] = []
var _enemy_hit: Array[AtlasTexture] = []
var _corpse_shadow_ready := false
static var _enemy_sheets: Dictionary = {}
var _kneel: Array[AtlasTexture] = []
var _kneel_fps := 12.0
## Ingénieur sans armure (surcharge de l'Ancre), tenue « Le Tyrien » (TyrienArt) : repos, marche, agenouillement à
## bout de souffle, incantation, méditation ; "meta" = cadences des animations.
static var _bare: Dictionary
## Corps de l'Ingénieur par tenue : false = Templier (combinaison), true = avant la combinaison (TyrienArt.ragged).
static var _bare_sets: Dictionary
## Calques des pièces d'équipement portées, enfants de _body (même image, même orientation).
var _gear: Array[Sprite2D] = []
## Casque de combat de l'Ingénieur à l'Arbalestrie (planches/ingenieur-canon-planche.html) : se ferme au premier
## tir (HELM_RATE par seconde, 4 étapes), se relève HELM_HOLD s après le dernier tir.
const HELM_HOLD := 1.0
const HELM_RATE := 3.0
var _helm: Sprite2D
var _helm_p := 0.0
var _helm_t := -INF
var enemy := false
## Animations d'attaque (ATK.sword[0..4], ATK.xbow) : 12 images, ancre propre.
static var _atk: Dictionary
var _sword: Array = []
var _xbow: Array[AtlasTexture] = []
var _body := Sprite2D.new()
var _mining_seal: Node2D
## Iris de la Matrice porté (entities/unit/iris_fx.gd) : orbe-satellite et ping de sonar.
var _iris: Node2D
## Voile de la Martyre porté (entities/unit/veil_fx.gd) : liseré, pendentif, coup absorbé.
var _veil: Node2D
## Les douze mods du 2026-11-21 (entities/unit/mods_worn_fx.gd) : derrière et devant le corps.
var _mods_back: Node2D
var _mods_front: Node2D
var _under := _UnitDecal.new()
## Méditation de l'Ingénieur (Meditation) : halo et lueurs derrière le sprite, puis devant.
var _med_back := _MedFx.new()
var _med_front := _MedFx.new()
var _med_on := false
var _over := _UnitBar.new()
## Soin reçu (« + » verts) et rappel par le Puits des Âmes (bulle qui devient l'unité), alliés seulement.
var _heal: HealFx
var _revive: ReviveFx
# État d'animation (u._lx, u._lz, u._wp, u._still, u._face).
var _lx := NAN
var _lz := NAN
## Phase de marche, demi-tour (UnitFeel) ; _dt = durée de la dernière image.
var _feel := UnitFeel.new()
var _dt := 0.0
var _warped := false
## Ingénieur sans armure : vue de face (« d ») ou de dos (« u ») quand il marche surtout vers le bas ou le
## haut de l'écran, gardée au repos ; vide = profil.
var _vdir := ""
var _face := 1
var _under_key: Variant = null
var _over_key := Vector4(-1, -1, -1, -1)

## Nervosité des ennemis (couche procédurale, en pixels natifs entiers, par-dessus les planches) :
## éclair blanc et recul quand ils encaissent, fente vers la cible à l'attaque, tremblement étourdi,
## projection en arrière à la mort ; l'attaque rend la main au repos dès la fin de son geste.
## Éclair : durée (s), intervalle minimal entre deux éclairs (dégâts continus), intensité de modulation.
const HURT_FLASH := 0.11
const HURT_GAP := 0.16
const HURT_GLOW := 2.4
## Recul : durée (s), amplitude (px) d'un gros coup ; seuil (part des PV) en dessous duquel rien ne recule.
## Les alliés reculent moins (HURT_RECOIL_ALLY) : leur ligne ne doit pas paraître céder à chaque coup.
const HURT_RECOIL_T := 0.16
const HURT_RECOIL := 3.0
const HURT_RECOIL_ALLY := 2.0
const HURT_RECOIL_MIN := 0.03
## Fente d'attaque : montée, retour (s, à la cadence de la vague) et amplitude (px) par type.
const LUNGE_IN := 0.06
const LUNGE_OUT := 0.26
## Les chiens de la Bête (beast) n'en ont pas : leur planche porte déjà le bond de 12 px.
## La Brute et le Strazhar non plus : leurs planches (tools/unites-maj/export_g1.py) portent l'élan du coup.
const LUNGE := {"creep": 3, "scout": 3, "shield": 2, "soldier": 2,
		"croc": 5, "feline": 6, "archer": -1, "spitter": -1}
## Mort : projection en arrière (px) sur DEATH_KICK_T s.
const DEATH_KICK := 4.0
const DEATH_KICK_T := 0.22
## Attaque : au moins ATTACK_MIN_S s, puis retour au repos une fois la dernière image distincte passée.
const ATTACK_MIN_S := 0.25
## Coups annoncés (Enemy.windup) : instant du choc dans l'atlas d'attaque (s). L'animation démarre assez loin
## dans l'armement pour que ce choc tombe à la fin du délai ; l'arme luit pendant l'armement (TELL_GLOW).
const ATTACK_IMPACT := {"brute": 0.4, "strazhar": 0.25}
const TELL_GLOW := 0.3
static var _attack_active: Dictionary = {}
var _last_hp := NAN
var _hurt_t := -INF
var _hurt_k := 0.0
var _recoil_k := 0.0
var _recoil_dir := -1
## Réaction dessinée au coup (atlas "hit") : début, et durée minimale entre deux réactions (s). La Martyre garde
## sa propre cadence (Enemy.hurt_at, sim/martyre.gd).
const HIT_GAP := 0.6
var _hit_t := -INF


func setup(u: Unit, meta: Dictionary, sim: Simulation, w: World = null) -> void:
	unit = u
	simulation = sim
	world = w
	_meta = meta
	enemy = u.is_enemy()
	var base := (EnemyArt.ROOT + "%s_" if enemy else "res://assets/baked/units/%s_") % u.role
	if not enemy and (u.role == "paladin" or u.role == "shooter"):
		if _atk.is_empty():
			_atk = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["attacks"]
		if u.role == "paladin":
			for i in 5:
				_sword.append(_frames("res://assets/baked/attacks/sword_%d.png" % i, _atk["sword"]["sheet"]))
		else:
			_xbow = _frames("res://assets/baked/attacks/xbow.png", _atk["xbow"]["sheet"])
	if not enemy and u.role == "engineer" and _bare.is_empty():
		TyrienArt.load_all()
		for exil: bool in [false, true]:
			var pack := {"meta": TyrienArt.meta["anims"]}
			for anim: String in ["idle", "walk", "kneel", "pray", "settle", "lotus", "idle_d", "walk_d", "idle_u", "walk_u", "hit", "c_idle", "c_walk", "c_idle_d", "c_walk_d", "c_idle_u", "c_walk_u", "helm"]:
				if TyrienArt.meta["anims"].has(anim):
					pack[anim] = TyrienArt.anim_of(anim, exil)
			_bare_sets[exil] = pack
		_bare = _bare_sets[TyrienArt.ragged()]
	if enemy:
		if not _enemy_sheets.has(u.role):
			var sheets := {}
			for action: String in ["idle", "walk", "attack", "death", "cast", "hit"]:
				if meta.has(action):
					sheets[action] = _frames(base + action + ".png", meta[action])
			_enemy_sheets[u.role] = sheets
		_idle = _enemy_sheets[u.role]["idle"]
		_walk = _enemy_sheets[u.role]["walk"]
		_enemy_attack = _enemy_sheets[u.role]["attack"]
		_enemy_death = _enemy_sheets[u.role]["death"]
		_enemy_cast = _enemy_sheets[u.role].get("cast", [] as Array[AtlasTexture])
		_enemy_hit = _enemy_sheets[u.role].get("hit", [] as Array[AtlasTexture])
		if not _attack_active.has(u.role):
			_attack_active[u.role] = _active_length(_enemy_attack, float(meta["attack"]["fps"]))
	else:
		_idle = _frames(base + "idle.png", meta["idle"])
		_walk = _frames(base + "walk.png", meta["walk"])
	if meta.has("kneel"):
		_kneel = _frames(base + "kneel.png", meta["kneel"])
		_kneel_fps = float(meta["kneel"].get("fps", 12.0))
	use_parent_material = true
	_under.view = self
	add_child(_under)
	if not enemy and u.role == "engineer":
		_med_back.view = self
		_med_back.use_parent_material = true
		add_child(_med_back)
		_mining_seal = preload("res://entities/unit/mining_seal_fx.gd").new()
		_mining_seal.view = self
		_mining_seal.use_parent_material = true
		add_child(_mining_seal)
		_iris = preload("res://entities/unit/iris_fx.gd").new()
		_iris.view = self
		_iris.use_parent_material = true
		add_child(_iris)
		_mods_back = preload("res://entities/unit/mods_worn_fx.gd").new()
		_mods_back.view = self
		_mods_back.use_parent_material = true
		add_child(_mods_back)
	_body.centered = false
	_body.use_parent_material = true
	add_child(_body)
	if not enemy and u.role == "engineer":
		_med_front.view = self
		_med_front.front = true
		_med_front.use_parent_material = true
		add_child(_med_front)
		_veil = preload("res://entities/unit/veil_fx.gd").new()
		_veil.view = self
		_veil.use_parent_material = true
		add_child(_veil)
		_mods_front = preload("res://entities/unit/mods_worn_fx.gd").new()
		_mods_front.view = self
		_mods_front.front = true
		_mods_front.use_parent_material = true
		add_child(_mods_front)
	if not enemy:
		_revive = ReviveFx.new()
		_revive.view = self
		_revive.use_parent_material = true
		add_child(_revive)
		_heal = HealFx.new()
		_heal.view = self
		_heal.use_parent_material = true
		add_child(_heal)
	_over.view = self
	add_child(_over)
	_update()


static func _frames(path: String, m: Dictionary) -> Array[AtlasTexture]:
	var tex: Texture2D = load(path)
	var out: Array[AtlasTexture] = []
	for i in int(m["count"]):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2((i % int(m["cols"])) * int(m["frame_w"]), (i / int(m["cols"])) * int(m["frame_h"]), int(m["frame_w"]), int(m["frame_h"]))
		out.append(a)
	return out


## Durée utile d'une attaque (s) : jusqu'à la dernière image qui diffère de l'image finale, plus une image
## de pose ; les planches tiennent ensuite la garde immobile jusqu'à 1 s, que le repos remplace.
static func _active_length(frames: Array[AtlasTexture], fps: float) -> float:
	var n := frames.size()
	if n < 2:
		return n / fps
	var img := frames[0].atlas.get_image()
	if img == null:
		return n / fps
	if img.is_compressed():
		img.decompress()
	# L'import bave les couleurs dans les pixels transparents (fix_alpha_border), différemment selon la
	# rangée de l'atlas : prémultiplié, seul ce qui se voit est comparé.
	img.convert(Image.FORMAT_RGBA8)
	img.premultiply_alpha()
	var last := img.get_region(Rect2i(frames[n - 1].region)).get_data()
	var used := 1
	for i in range(n - 2, -1, -1):
		if img.get_region(Rect2i(frames[i].region)).get_data() != last:
			used = i + 2
			break
	return maxf(ATTACK_MIN_S, mini(n, used) / fps)


## Coups encaissés, déduits de la baisse des PV (toutes sources) : intensité selon la part des PV perdus.
func _track_hurt(u: Unit, t: float) -> void:
	if is_nan(_last_hp):
		_last_hp = u.hp
	var drop := _last_hp - u.hp
	_last_hp = u.hp
	if drop <= 0.0:
		return
	var share := drop / maxf(1.0, u.max_hp)
	var k := clampf(0.45 + share * 6.0, 0.45, 1.0)
	if t - _hurt_t < HURT_GAP and k <= _hurt_flash(t):
		return
	_hurt_t = t
	_hurt_k = k
	var big := share >= HURT_RECOIL_MIN or u.hp <= 0.0
	_recoil_k = clampf(share * 10.0, 0.5, 1.0) if big and u.role != Martyre.KIND else 0.0
	_recoil_dir = -(u.face if u.face != 0 else 1)
	if big and t - _hit_t >= HIT_GAP:
		_hit_t = t


func _hurt_flash(t: float) -> float:
	var a := t - _hurt_t
	return _hurt_k * (1.0 - a / HURT_FLASH) if a >= 0.0 and a < HURT_FLASH else 0.0


func _recoil_px(t: float) -> float:
	var a := (t - _hurt_t) / HURT_RECOIL_T
	if a < 0.0 or a >= 1.0 or _recoil_k <= 0.0:
		return 0.0
	# Choc immédiat puis retour amorti.
	return _recoil_dir * roundf((HURT_RECOIL if enemy else HURT_RECOIL_ALLY) * _recoil_k * pow(1.0 - a, 2.0))


## Fente : élan rapide vers la cible, puis retour en douceur (age à la cadence de la vague).
static func _lunge_px(role: String, age: float) -> float:
	var amp := float(LUNGE.get(role, 0))
	if amp == 0.0 or age < 0.0 or age >= LUNGE_IN + LUNGE_OUT:
		return 0.0
	var p := 1.0 - pow(1.0 - age / LUNGE_IN, 2.0) if age < LUNGE_IN else 1.0 - pow((age - LUNGE_IN) / LUNGE_OUT, 2.0)
	return roundf(amp * p)


func _flash_color(base: Color, f: float) -> Color:
	var g := 1.0 + HURT_GLOW * f
	return Color(base.r * g, base.g * g, base.b * g, base.a)


func _process(delta: float) -> void:
	_dt = delta
	_update()


func _update() -> void:
	var u := unit
	visible = not u.hidden and (u.alive() or (enemy and u.dead)) and not Overload.hidden_in_blast(u)
	if enemy and world and not world.fog.visible_at(u.pos()):
		visible = false
	# Invulnérable après un coup de la Martyre : l'Ingénieur clignote.
	if not enemy and (Martyre.blinking(u) or OeilMatrice.blinking(u)):
		visible = false
	position = Proj.nat(u.x, 0.0, u.z)
	# Voyage par un portail (PortalNet, Orbe suspendu) : la bulle referme le voyageur, qui pâlit, rapetisse puis
	# disparaît dans l'orbe ; à l'arrivée, l'inverse.
	if not enemy:
		var wv := PortalNet.warp_view(u)
		if not wv.is_empty():
			var k := float(wv["k"])
			scale = Vector2.ONE * (1.0 if k < 0.35 else maxf(0.08, 1.0 - (k - 0.35) / 0.25 * 0.92))
			modulate = Color.WHITE.lerp(Color(0.78, 0.86, 1.0), clampf(k / 0.35, 0.0, 1.0))
			if k >= 0.6:
				visible = false
			_warped = true
		elif _warped:
			scale = Vector2.ONE
			modulate = Color.WHITE
			_warped = false
	# Gardiens des Pylônes de Merenor : l'alpha est deux fois plus grand ; une bête qui renaît sort du slime
	# en silhouette noire puis reprend ses couleurs.
	if enemy and not u.dead:
		var ge := u as Enemy
		scale = Vector2.ONE * (Pylons.ALPHA if ge.alpha else 1.0)
		var rk := clampf((GameState.sim_time - ge.risen_at) / 1.4, 0.0, 1.0)
		modulate = Color(lerpf(0.06, 1.0, rk), lerpf(0.05, 1.0, rk), lerpf(0.08, 1.0, rk), 1.0)
	_track_hurt(u, GameState.sim_time)
	if enemy and u.dead:
		var age := maxf(0.0, GameState.sim_time - (u as Enemy).died_at)
		_body.texture = _enemy_death[mini(_enemy_death.size() - 1, floori(age * (u as Enemy).pace * float(_meta["death"]["fps"])))]
		_body.offset = Vector2(-float(_meta["ax"]), -float(_meta["ay"]))
		# Projection en arrière au coup fatal (sens opposé au regard), amortie, puis le corps reste là.
		var kick := -float(u.face if u.face != 0 else 1) * roundf(DEATH_KICK * (1.0 - pow(1.0 - clampf(age / DEATH_KICK_T, 0.0, 1.0), 3.0)))
		_body.position = Vector2(kick, 0.0)
		_body.scale = Vector2(-1 if u.face < 0 else 1, 1)
		var progress := clampf(age / EnemyArt.DEATH_DURATION, 0.0, 1.0)
		_under.position = Vector2(8.0 * progress + kick, -3.0 * progress)
		_under.scale = Vector2(1.0 + progress, 1.0)
		if not _corpse_shadow_ready:
			_corpse_shadow_ready = true
			_under.queue_redraw()
		_over.visible = false
		modulate = Color(1, 1, 1, clampf(Loot.corpse_life(u as Enemy) - age, 0.0, 1.0))
		_body.modulate = _flash_color(Color.WHITE, _hurt_flash(GameState.sim_time))
		return
	if is_nan(_lx):
		_lx = u.x
		_lz = u.z
	var dist := Vector2(u.x - _lx, u.z - _lz).length()
	var moved := dist > 0.001
	# Départ sur un appui, pas terminé à l'arrêt (UnitFeel.step).
	# Ingénieur : foulée de son propre atlas (5 unités par cycle, soit 3 cycles par seconde à sa vitesse de 15,2).
	var stride := float(TyrienArt.meta["stride"]) if u.unarmored and not _bare_sets.is_empty() else float(_meta["stride"])
	_feel.step(dist, stride, _dt)
	var _wp := _feel.wp
	var walking := _feel.walking
	# Orientation : alliés vers l'ennemi le plus proche (20 pour le Tireur, 10 sinon), sinon sens de la marche.
	var foe: Variant = null if enemy else Combat.target_closest(u, GameState.enemies, 20.0 if u.role == "shooter" else 10.0, world)
	var dxs: float = foe.x - u.x if foe else u.x - _lx
	# u._face est partagé avec les frappes (swordStrike, volley) : une orientation imposée tient tant
	# qu'aucun ennemi n'est visé et que l'unité ne bouge pas.
	if absf(dxs) > 0.001:
		u.face = -1 if dxs < 0.0 else 1
	_face = u.face if u.face != 0 else 1
	if not _bare_sets.is_empty():
		_bare = _bare_sets[TyrienArt.ragged()]
	var bare := u.unarmored and not _bare.is_empty()
	if bare and _bare.has("walk_d"):
		var ddx := u.x - _lx
		var ddz := u.z - _lz
		if foe:
			_vdir = ""
		elif moved:
			if absf(ddz) > absf(ddx) * 1.2:
				_vdir = "d" if ddz > 0.0 else "u"
			elif absf(ddx) > absf(ddz):
				_vdir = ""
	else:
		_vdir = ""
	_lx = u.x
	_lz = u.z
	# Ennemi masqué (brouillard, caché) : seul l'état d'animation suit son cours (marche, regard, demi-tour,
	# coups encaissés, ci-dessus) ; l'image du sprite est choisie à la première image où il redevient visible.
	if enemy and not visible:
		_feel.turn(_face, Time.get_ticks_msec() / 1000.0)
		return
	var cannon := bare and String(Gear.weapon(u).get("piece", "")) == "cannon" and _bare.has("c_walk")
	var walk_frames: Array[AtlasTexture] = (_bare[("c_walk_" if cannon and _bare.has("c_walk_d") else "walk_") + _vdir] if _vdir != "" else (_bare["c_walk"] if cannon else _bare["walk"])) if bare else _walk
	var wn := walk_frames.size()
	var wi := floori(_wp * wn) % wn
	var bob_i := floori(_wp * 6.0) if enemy else wi
	var bob := 1 if not _meta.get("self_bob", false) and walking and (bob_i == 1 or bob_i == 4) else 0
	var kick := 1 if not enemy and u.attack > (0.7 if u.role == "paladin" else 0.62) else 0
	var t := GameState.sim_time
	var frame: AtlasTexture
	var key: int = (u as Enemy).anim_key() if enemy else u.id
	if walking:
		frame = walk_frames[wi]
	elif enemy and _meta["idle"].get("loop", false):
		# Boucle de repos à sa propre cadence (Martyre de Byrsa : 74 images à 24 i/s).
		frame = _idle[floori(t * (u as Enemy).pace * float(_meta["idle"]["fps"])) % _idle.size()]
	else:
		var idle_frames: Array = (_bare[("c_idle_" if cannon and _bare.has("c_idle_d") else "idle_") + _vdir] if _vdir != "" else (_bare["c_idle"] if cannon else _bare["idle"])) if bare else _idle
		var it := t * ((u as Enemy).pace if enemy else 1.0)
		frame = idle_frames[(floori(it * IDLE_FPS) + (key & 7) * 3) % idle_frames.size()]
	var ax := float(_meta["ax"])
	var ay := float(_meta["ay"])
	# Marche ennemie dans un cadre propre (Strazhar à quatre pattes) : ancre de la marche.
	if enemy and walking and _meta["walk"].has("ax"):
		ax = float(_meta["walk"]["ax"])
		ay = float(_meta["walk"]["ay"])
	# attackFrame : coup d'épée (0,8 s) ou salve d'arbalète (0,7 s), sur 12 images.
	var atk: Array = []
	var atk_meta: Dictionary = {}
	var e := -1.0
	if not _sword.is_empty() and u.sw >= 0:
		e = (t - u.sw_t0) / float(_atk["sword"]["swing_s"])
		atk = _sword[u.sw]
		atk_meta = _atk["sword"]
	elif not _xbow.is_empty():
		e = (t - u.sh_t0) / float(_atk["xbow"]["volley_s"])
		atk = _xbow
		atk_meta = _atk["xbow"]
	if e >= 0.0 and e < 1.0:
		frame = atk[mini(atk.size() - 1, floori(e * atk.size()))]
		ax = atk_meta["ax"]
		ay = atk_meta["ay"]
		kick = 0
	var lunge := 0.0
	var tell := 0.0
	if enemy:
		var age := (t - (u as Enemy).attack_started) * (u as Enemy).pace
		# Coup annoncé : l'atlas est avancé pour que son choc coïncide avec la fin de l'armement.
		var windup := (u as Enemy).windup
		var lead := maxf(0.0, float(ATTACK_IMPACT.get(u.role, 0.0)) - windup) if windup > 0.0 else 0.0
		# Durée propre de l'animation si elle est plus courte que la recharge (Martyre de Byrsa).
		var span := float(_meta["attack"].get("duration", minf(Catalog.ENEMY[u.role]["cd"], _attack_active.get(u.role, INF))))
		var playing := age >= 0.0 and age + lead < span
		lunge = _lunge_px(u.role, age - windup)
		if windup > 0.0 and age >= 0.0 and age < windup:
			tell = TELL_GLOW * sin(PI * age / windup)
		if playing:
			frame = _enemy_attack[mini(_enemy_attack.size() - 1, floori((age + lead) * float(_meta["attack"]["fps"])))]
			ax = float(_meta["ax"])
			ay = float(_meta["ay"])
			bob = 0
		# Incantation (la plus récente des deux l'emporte), puis réaction aux coups si rien d'autre ne joue.
		if not _enemy_cast.is_empty():
			var ca := (t - (u as Enemy).cast_started) * (u as Enemy).pace
			if ca >= 0.0 and ca < float(_meta["cast"]["duration"]) and (u as Enemy).cast_started >= (u as Enemy).attack_started:
				frame = _enemy_cast[mini(_enemy_cast.size() - 1, floori(ca * float(_meta["cast"]["fps"])))]
				playing = true
		if not _enemy_hit.is_empty() and not playing:
			var ha := (t - ((u as Enemy).hurt_at if u.role == Martyre.KIND else _hit_t)) * (u as Enemy).pace
			if ha >= 0.0 and ha < float(_meta["hit"]["duration"]):
				frame = _enemy_hit[mini(_enemy_hit.size() - 1, floori(ha * float(_meta["hit"]["fps"])))]
	if not _kneel.is_empty() and simulation and simulation.kneeling(u):
		if bare:
			var pr: Array = _bare["pray"]
			frame = pr[floori(t * float(_bare["meta"]["pray"]["fps"])) % pr.size()]
		else:
			frame = _kneel[floori(t * _kneel_fps) % _kneel.size()]
	# Surcharge de l'Ancre : retombe à genoux, puis souffle court jusqu'au prochain ordre.
	var drop := 0.0
	var winded := bare and Overload.winded(u)
	if winded:
		var age := t - u.winded_at
		var kn: Array = _bare["kneel"]
		# Souffle court en boucle : les 24 premières images (les 12 suivantes le relèvent).
		frame = kn[floori(age * float(_bare["meta"]["kneel"]["fps"])) % mini(24, kn.size())]
		drop = -10.0 * (1.0 - pow(clampf(age / Overload.FALL, 0.0, 1.0), 3.0))
		kick = 0
		bob = 0
		_face = 1 if CaveShape.CORE.x >= u.x else -1
	# Arrivée par le portail (sim/opening.gd) : à genoux, souffle court, puis se relève.
	if bare and u.role == "engineer" and GameState.opening_stage == "arrival":
		var at := Opening.elapsed() - Opening.ARR_EJECT
		if at >= 0.0 and Opening.elapsed() < Opening.ARR_STAND:
			var kn: Array = _bare["kneel"]
			var fps := float(_bare["meta"]["kneel"]["fps"])
			if Opening.elapsed() < Opening.ARR_RISE:
				frame = kn[floori(at * fps) % 24]
			else:
				frame = kn[mini(kn.size() - 1, 24 + floori((Opening.elapsed() - Opening.ARR_RISE) * 12.0))]
			drop = -10.0 * (1.0 - pow(clampf(at / 0.25, 0.0, 1.0), 3.0))
			kick = 0
			bob = 0
			winded = true
	# Coup encaissé (assez fort pour un recul) : buste rejeté en arrière, six images ; cède à tout ce qui suit.
	if bare and not walking and not winded and _bare.has("hit"):
		var ha := (t - _hit_t) * float(_bare["meta"]["hit"]["fps"])
		var hf: Array = _bare["hit"]
		if ha >= 0.0 and ha < hf.size():
			frame = hf[floori(ha)]
			kick = 0
	# Creusement : l'Ingénieur vise et tire ses pitons d'ancrage (EngineerAim).
	if u.role == "engineer" and not walking and world and not winded:
		var aim: Variant = EngineerAim.pose(u, world.terrain_state)
		if aim != null:
			frame = aim["frame"]
			ax = aim["ax"]
			ay = aim["ay"]
			kick = 0
			_face = aim["face"]
	# Méditation en lévitation : assise en tailleur, puis lotus flottant tourné vers le temple.
	var med := Meditation.state(u) if u.role == "engineer" and not enemy else {}
	if not med.is_empty():
		var age: float = med["age"]
		var tb: Building = med["temple"]
		_face = 1 if (tb.x if tb else CaveShape.CORE.x) >= u.x else -1
		kick = 0
		bob = 0
		if bare:
			if age < Meditation.SETTLE:
				var se: Array = _bare["settle"]
				frame = se[mini(se.size() - 1, floori(age * float(_bare["meta"]["settle"]["fps"])))]
			else:
				var lo: Array = _bare["lotus"]
				frame = lo[floori((age - Meditation.SETTLE) * float(_bare["meta"]["lotus"]["fps"])) % lo.size()]
		elif not _kneel.is_empty():
			frame = _kneel[floori(t * _kneel_fps) % _kneel.size()]
		ax = float(_meta["ax"])
		ay = float(_meta["ay"])
		drop = -roundf(Meditation.lift(age))
	if not med.is_empty() or _med_on:
		_med_on = not med.is_empty()
		_med_back.queue_redraw()
		_med_front.queue_redraw()
	# Ingénieur armé au Creuset : taille à une main (slash1), à deux mains (slash2) ou tir du canon (shoot),
	# planches/armes-attaques.html ; démarre à sw_t0 (épées) ou sh_t0 (canon).
	if bare and not winded and med.is_empty():
		var anim := String(Gear.weapon(u).get("anim", ""))
		# Tir surtout vers le sud ou le nord : pose de face ou de dos (sinon profil), au gantelet comme à l'Arbalestrie.
		var vertical := anim == "shoot" and absf(u.aim_dir.y) > absf(u.aim_dir.x) * 1.2
		var down := u.aim_dir.y > 0.0
		if anim == "shoot" and cannon and TyrienArt.meta["anims"].has("c_shoot"):
			anim = "c_shoot"
			if vertical and TyrienArt.meta["anims"].has("c_shoot_d"):
				anim = "c_shoot_d" if down else "c_shoot_u"
		elif vertical:
			var vert := "shoot_d" if down else "shoot_u"
			if TyrienArt.meta["anims"].has(vert):
				anim = vert
		if anim != "" and TyrienArt.meta["anims"].has(anim):
			var fps := TyrienArt.fps(anim)
			var frames := TyrienArt.anim(anim)
			# Tirs (shoot, shoot_d/u, c_shoot, c_shoot_d/u de l'Arbalestrie) : depuis sh_t0 ; tailles : depuis sw_t0.
			var age := t - (u.sh_t0 if anim.begins_with("shoot") or anim.begins_with("c_shoot") else u.sw_t0)
			if age >= 0.0 and age < frames.size() / fps:
				frame = frames[mini(frames.size() - 1, floori(age * fps))]
				kick = 0
				bob = 0
				_face = u.face
	# Tyrien : planches au gabarit propre (cadre plus large pour l'équipement).
	var tyrien := bare and TyrienArt.is_tyrien(frame)
	if tyrien:
		ax = float(TyrienArt.meta["ax"])
		ay = float(TyrienArt.meta["ay"])
	_body.texture = frame
	_body.offset = Vector2(-ax - kick, -ay)
	_sync_gear(frame if tyrien else null)
	_sync_helm(frame, cannon, t)
	_sync_tip(frame, cannon)
	var jolt := 0.0
	if enemy:
		# Fente vers la cible, recoil d'un coup reçu, tremblement d'étourdissement (1 px, 15 Hz).
		jolt = lunge * _face + _recoil_px(t)
		if (u as Enemy).stun > 0.0:
			jolt += 1.0 if floori(t * 30.0) % 2 == 0 else -1.0
	else:
		jolt = _recoil_px(t) + _shot_kick(t)
	# Éclair du coup encaissé, sur le sprite seul : la barre de vie ne clignote pas.
	_body.modulate = _flash_color(Color.WHITE, maxf(_hurt_flash(t), tell))
	# Demi-tour en trois images (largeurs intermédiaires, un pixel d'affaissement), horloge réelle.
	var now := Time.get_ticks_msec() / 1000.0
	var kx := _feel.turn(_face, now)
	_body.position = Vector2(jolt, -bob + roundf(drop) + (1.0 if _feel.turning(now) else 0.0))
	_body.scale = Vector2(kx, 1)
	if _mining_seal:
		_mining_seal.tick(_face, _body.position, ReviveFx.body_shown(u))
	if _iris:
		_iris.tick(_face, _body.position, ReviveFx.body_shown(u))
	if _veil:
		_veil.tick(_body, _vdir, ReviveFx.body_shown(u))
	if _mods_back:
		_mods_back.tick(_face, _body.position, _vdir, ReviveFx.body_shown(u))
		_mods_front.tick(_face, _body.position, _vdir, ReviveFx.body_shown(u))
	if _revive:
		# Rappel : sprite, ombre et barre de vie masqués tant que la bulle n'a pas pris la forme de l'unité.
		var shown := ReviveFx.body_shown(u)
		_body.visible = shown
		_under.visible = shown
		_over.visible = shown
		_revive.tick()
		_heal.tick()
	# Barre de vie des ennemis : seulement avec le mod Analyse porté (planches/intro-capsule-planche.html).
	if enemy:
		_over.visible = Mods.analysis()
	# Ombre, sélection, barre de vie et badge : redessinés seulement quand leur état change.
	var under_key := selected()
	if under_key != _under_key:
		_under_key = under_key
		_under.queue_redraw()
	var over_key := Vector4(u.hp, u.max_hp, Catalog.lvl(u) * 100 + u.squad + (100000 if preload("res://sim/placeables.gd").posted(u) else 0) + (1000000 if hovered == u else 0), world.camera.px if world else 1)
	if over_key != _over_key:
		_over_key = over_key
		_over.queue_redraw()


## Casque de combat : progression vers fermé tant que le dernier tir date de moins de HELM_HOLD s, puis relevé ;
## affiché sur les images de l'Arbalestrie (profil, face, dos), décalé avec la tête.
func _sync_helm(frame: Texture2D, cannon: bool, t: float) -> void:
	# Sans canon et casque déjà relevé (tous les ennemis, la plupart des alliés) : rien à chercher dans les planches.
	if not cannon and _helm_p <= 0.0:
		_helm_t = t
		if _helm:
			_helm.visible = false
		return
	var dt := clampf(t - _helm_t, 0.0, 0.25)
	_helm_t = t
	var target := 1.0 if cannon and t - unit.sh_t0 < HELM_HOLD else 0.0
	_helm_p = move_toward(_helm_p, target, HELM_RATE * dt)
	var step := ceili(_helm_p * 4.0 - 0.001)
	var dy := 0
	var show := false
	var layer := "helm"
	# De face ou de dos (canon sur l'épaule, tir vers le sud / le nord) : calques helm_d / helm_u, hauteur de tête
	# mesurée à l'export (templier.json « head_dy »).
	var heads: Dictionary = TyrienArt.meta.get("head_dy", {})
	for anim: String in heads:
		var i := TyrienArt.anim(anim).find(frame)
		if i >= 0 and TyrienArt.meta["anims"].has("helm_d"):
			show = true
			layer = "helm_d" if anim.ends_with("_d") else "helm_u"
			dy = int(heads[anim][i])
			break
	for anim: String in ([] if show else ["c_idle", "c_walk", "c_shoot"]):
		var i := TyrienArt.anim(anim).find(frame)
		if i >= 0:
			show = true
			# Hauteur de la tête dans chaque image (planches/assets/engineer-maj.js : breath, walkPose, c_shoot).
			if anim == "c_idle":
				dy = 1 if (i % 24) >= 9 and (i % 24) <= 20 else 0
			elif anim == "c_walk":
				dy = 1 if i in [0, 1, 5, 6, 7, 11] else 0
			else:
				dy = 1 if i == 1 or i == 2 else 0
	if step <= 0 or not show:
		if _helm:
			_helm.visible = false
		return
	if _helm == null:
		_helm = Sprite2D.new()
		_helm.centered = false
		_helm.use_parent_material = true
		_body.add_child(_helm)
	_helm.visible = true
	_helm.texture = TyrienArt.anim(layer)[step - 1]
	_helm.offset = _body.offset + Vector2(0, dy)
	_helm.z_index = 1


## Recul du corps propre à la munition tirée (planches/arbalestrie-tir-planche.html) : Indra recule d'un pixel de
## plus pendant 0,1 s (Gueule de feu).
func _shot_kick(t: float) -> float:
	var a := t - unit.sh_t0
	return -float(_face) if unit.sh_ammo == "indra" and a >= 0.0 and a < 0.1 else 0.0


## Lumière du bout du canon, par image (x, y dans le cadre de 48 px) : repos, marche, tir.
const TIP_WALK_Y: Array[int] = [33, 33, 32, 32, 31, 32, 33, 33, 32, 32, 31, 32]
const TIP_SHOOT: Array[Vector2i] = [Vector2i(40, 27), Vector2i(37, 28), Vector2i(38, 28), Vector2i(38, 27), Vector2i(39, 27), Vector2i(40, 27)]
var _tip: Sprite2D
static var _tip_tex: ImageTexture


## Munition choisie visible sur l'arme : la lumière du bout du canon prend sa couleur (cyan d'origine pour les
## balles spirituelles, rien à recouvrir).
func _sync_tip(frame: Texture2D, cannon: bool) -> void:
	var ammo := Ammo.current() if cannon else "spirit"
	var at := Vector2i.ZERO
	var size := Vector2(2, 1)
	if ammo != "spirit":
		var i := TyrienArt.anim("c_idle").find(frame)
		if i >= 0:
			at = Vector2i(39, 32 if i % 24 < 12 else 33)
		else:
			i = TyrienArt.anim("c_walk").find(frame)
			if i >= 0:
				at = Vector2i(39, TIP_WALK_Y[i % TIP_WALK_Y.size()])
			else:
				i = TyrienArt.anim("c_shoot").find(frame)
				if i >= 0:
					at = TIP_SHOOT[mini(i, TIP_SHOOT.size() - 1)]
					size = Vector2(2, 2)
				else:
					# De face ou de dos (canon sur l'épaule, ou tir vers le sud / le nord) : lumière mesurée à l'export
					# (templier.json « tips »).
					var tips: Dictionary = TyrienArt.meta.get("tips", {})
					for anim: String in tips:
						i = TyrienArt.anim(anim).find(frame)
						if i >= 0:
							var p: Array = tips[anim][i]
							at = Vector2i(int(p[0]), int(p[1]))
							size = Vector2(3 if anim.ends_with("_d") and not anim.begins_with("c_shoot") else 2, 2)
							break
	if at == Vector2i.ZERO:
		if _tip:
			_tip.visible = false
		return
	if _tip == null:
		if _tip_tex == null:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			_tip_tex = ImageTexture.create_from_image(img)
		_tip = Sprite2D.new()
		_tip.centered = false
		_tip.texture = _tip_tex
		_tip.z_index = 1
		_body.add_child(_tip)
	_tip.visible = true
	_tip.modulate = EffectsDrawer.AMMO_PAL[ammo][4]
	_tip.scale = size
	_tip.position = Vector2(at) + _body.offset


## Empile sur _body les calques des pièces portées par l'Ingénieur (aucun hors tenue tyrienne).
func _sync_gear(frame: Texture2D) -> void:
	var layers: Array[AtlasTexture] = []
	if frame != null and not unit.equipment.is_empty():
		layers = TyrienArt.overlays(frame, Gear.pieces(unit))
	while _gear.size() < layers.size():
		var s := Sprite2D.new()
		s.centered = false
		s.use_parent_material = true
		_body.add_child(s)
		_gear.append(s)
	for i in _gear.size():
		var s := _gear[i]
		s.visible = i < layers.size()
		if s.visible:
			s.texture = layers[i]
			s.offset = _body.offset


func selected() -> bool:
	if enemy:
		return GameState.hud_enemy == unit and unit.alive()
	return GameState.selected.has(unit) and unit.alive()


func radius() -> float:
	if enemy:
		return 0.85 if unit.role == "brute" or unit.role == "strazhar" else 0.6
	return 0.75 if unit.role == "paladin" else 0.54


## hpY : hauteur visible du sprite + 4 px.
func hp_y() -> float:
	return float(_meta["h"]) + 4.0


## Ombre et sélection, sous le sprite (circle3 et ellipse de contour).
class _UnitDecal extends Node2D:
	var view: UnitView

	func _draw() -> void:
		var r := view.radius()
		if view.selected() and not view.enemy:
			halo(self, r)
		_ellipse(r * 1.3 * ZN * 0.9, r * 1.3 * ZN * 0.42, SHADOW)
		if view.selected() and view.enemy:
			_ellipse(r * 2.3 * ZN * 0.9, r * 2.3 * ZN * 0.42, FOE_FILL)
			# ctx.lineWidth = PX pixels d'écran, soit 1 pixel natif.
			draw_polyline(_ellipse_points(r * 1.75 * ZN * 0.9, r * 1.75 * ZN * 0.42, true), FOE_LINE, 1.0, true)
		elif view.selected():
			draw_polyline(_ellipse_points(r * 1.75 * ZN * 0.9, r * 1.75 * ZN * 0.42, true), SEL_LINE, 1.0, true)

	## Halo cyan sous une unité amie sélectionnée : couronnes concentriques de plus en plus claires vers le
	## centre (lueur diffuse), sous l'ombre portée. Rayon r en unités de monde.
	static func halo(ci: CanvasItem, r: float) -> void:
		const RINGS := 7
		for i in RINGS:
			var k := 2.6 - 1.4 * float(i) / (RINGS - 1)
			ci.draw_colored_polygon(_ellipse_points(r * k * ZN * 0.9, r * k * ZN * 0.42, false), Color(HALO, 0.07 + 0.02 * i))

	func _ellipse(rx: float, ry: float, c: Color) -> void:
		draw_colored_polygon(_ellipse_points(rx, ry, false), c)

	static func _ellipse_points(rx: float, ry: float, closed: bool) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 48
		for i in n + (1 if closed else 0):
			var a := TAU * i / n
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts


## Barre de vie au-dessus du sprite (drawCharacter) : 4 px d'écran de haut.
class _UnitBar extends Node2D:
	var view: UnitView
	var _bold: FontVariation

	func _draw() -> void:
		var px := float(view.world.camera.px) if view.world else 1.0
		var w := maxf(12.0 / px, 2.8 * ZN)
		var y := -view.hp_y()
		var u := view.unit
		# Unité amie : barre de vie seulement sous le pointeur (badges toujours affichés).
		if view.enemy or UnitView.hovered == u:
			draw_rect(Rect2(-w / 2.0, y, w, 4.0 / px), HP_BG)
			var fill := HP_ENEMY if view.enemy else (HP_GUARD if u.role == "guard" else HP_ALLY)
			draw_rect(Rect2(-w / 2.0, y, w * maxf(0.0, u.hp / u.max_hp), 4.0 / px), fill)
		if view.enemy:
			return
		# drawLevelBadge : ★niveau au-dessus de la barre (16 px plus haut pour une escouade), gras 10 px d'écran.
		var lvl := Catalog.lvl(u)
		var by := y - (16.0 if u.squad else 5.0) / px
		draw_set_transform(Vector2(0, by), 0.0, Vector2(1.0 / px, 1.0 / px))
		if u.squad:
			_text("I%d" % u.squad, Vector2(0, 10.0), Color("#f5ecca"))
		if lvl >= 2:
			var text := "★%d" % lvl
			_text(text, Vector2(1, 1), Color("#0b0a09cc"))
			_text(text, Vector2.ZERO, Color("#f4ecd6"))
		# Bonus de poste de tir : pastille du créneau de rondins au-dessus de l'unité.
		if preload("res://sim/placeables.gd").posted(u):
			var at := Vector2(0, (-10.0 if lvl >= 2 or u.squad else -2.0) - 9.0)
			draw_circle(at, 9.0, Color("#0b0a09b0"))
			draw_arc(at, 9.0, 0.0, TAU, 20, Color("#f4ecd6"), 1.0, true)
			preload("res://ui/inventory/item_icon.gd").draw_item(self, "firing_post", at, 0.5)
		draw_set_transform(Vector2.ZERO)

	func _text(text: String, at: Vector2, c: Color) -> void:
		if _bold == null:
			_bold = FontVariation.new()
			_bold.base_font = load("res://assets/fonts/DejaVuSans.ttf")
			_bold.variation_embolden = 0.7
		var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_bold, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)


## Calques de la méditation (Meditation.draw_back / draw_front), aux pieds de l'unité.
class _MedFx extends Node2D:
	var view: UnitView
	var front := false

	func _draw() -> void:
		if front:
			Meditation.draw_front(self, view.unit, view._face, view.position)
		else:
			Meditation.draw_back(self, view.unit, view._face)
