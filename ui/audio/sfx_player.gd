extends Node
## Joue les bruitages : res://assets/audio/sfx/<name>.wav (générés par tools/sons/generer.py,
## choisis sur planches/sons-propositions.html).
##   Events.sfx(name, db)              volume explicite (historique : « victoire »)
##   Events.sound(name)                volume du catalogue
##   Events.sound_at(name, x, z, delay) idem, coupé si (x, z) est hors du champ de la caméra
## Chaque son a un intervalle minimal (MIN_GAP) pour qu'une mêlée ne devienne pas une rafale.

const DIR := "res://assets/audio/sfx/"
const VOICES := 12

## Volume conseillé par son (dB), repris du catalogue de tools/sons/propositions.py.
const VOLUME_DB := {
	"victoire": -8, "ui_clic": -16, "ui_selection": -14, "ui_ordre": -16, "ui_refus": -12, "ui_banniere": -14,
	"ui_texte": -22, "ui_inventaire": -14, "bat_pose": -10, "bat_chantier": -18, "bat_termine": -10, "priere": -24,
	"recherche": -9, "forge": -12, "coffre": -14, "minage": -18, "objet_pose": -12, "chausse_trapes": -14,
	"adepte_arrive": -12, "epee": -14, "moulinet": -11, "arc": -15, "fleche_impact": -18, "flammes": -16,
	"flammes_mort": -9, "charge": -11, "sillon": -12, "soin": -15, "tourelle": -14, "exile_blesse": -18,
	"exile_mort": -10, "niveau": -11, "pilum": -14, "sort_lumiere": -14, "automate": -12, "bouclier_dore": -14,
	"fanatique": -18, "aberration": -14, "ennemi_mort": -18, "strazhar": -8, "martyre": -8, "croc": -13,
	"felin": -14, "portail": -10, "expulsion": -10, "porte_barree": -10, "ancre_trait": -12, "capsule": -11,
	"bouclier_forme": -11, "canon": -10, "onde": -7, "vague": -9, "aube": -14, "crepuscule": -14, "quete": -10,
	"defaite": -6, "arbalestrie": -15,
}

## Intervalle minimal entre deux lectures du même son (secondes réelles). Défaut : DEFAULT_GAP.
## Les sons en boucle (flammes, chantier) sont réémis tant que l'action dure et durent environ leur intervalle.
const DEFAULT_GAP := 0.06
const MIN_GAP := {
	"ui_texte": 0.07, "priere": 1.5, "bat_chantier": 1.0, "minage": 0.8, "epee": 0.09, "arc": 0.1,
	"fleche_impact": 0.08, "flammes": 0.9, "tourelle": 0.12, "exile_blesse": 0.3, "ennemi_mort": 0.12,
	"fanatique": 0.35, "automate": 0.25, "bouclier_dore": 0.4, "pilum": 0.15, "sort_lumiere": 0.15,
	"aberration": 3.0, "croc": 0.5, "felin": 1.5, "soin": 0.4, "canon": 0.25, "coffre": 0.15,
	"chausse_trapes": 0.5, "forge": 0.4, "arbalestrie": 0.2,
}

## Caméra du monde (posée par le HUD) : sert à couper les sons hors écran.
var camera: WorldCamera
var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _last := {}
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	Events.sfx.connect(play)
	Events.sound.connect(func(n: String) -> void: play(n, VOLUME_DB.get(n, -12.0)))
	Events.sound_at.connect(_at)


func _at(sound: String, x: float, z: float, delay: float) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay, false).timeout.connect(_at.bind(sound, x, z, 0.0))
		return
	if not _visible(x, z):
		return
	play(sound, VOLUME_DB.get(sound, -12.0))


## Marge hors écran (pixels) : un coup juste au bord reste audible.
const SCREEN_MARGIN := 48.0


func _visible(x: float, z: float) -> bool:
	if camera == null or not is_instance_valid(camera):
		return true
	var size := camera.screen_size()
	var p := camera.project(x, 0.0, z)
	return Rect2(-Vector2.ONE * SCREEN_MARGIN, size + Vector2.ONE * 2.0 * SCREEN_MARGIN).has_point(p)


func play(sound: String, volume_db := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -INF)) < float(MIN_GAP.get(sound, DEFAULT_GAP)):
		return
	var stream := _stream(sound)
	if stream == null:
		return
	_last[sound] = now
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()


## Une voix libre, sinon la plus ancienne (tourniquet).
func _free_player() -> AudioStreamPlayer:
	for i in VOICES:
		var p := _players[(_next + i) % VOICES]
		if not p.playing:
			_next = (_next + i + 1) % VOICES
			return p
	var q := _players[_next]
	_next = (_next + 1) % VOICES
	return q


func _stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := DIR + sound + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		# Fichier pas encore importé par l'éditeur : lecture directe du WAV.
		stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null:
		push_warning("Son introuvable : %s" % path)
	_cache[sound] = stream
	return stream
