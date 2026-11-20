class_name Sfx
extends RefCounted
## Raccourcis d'émission des bruitages (lus par ui/audio/sfx_player.gd).


## Son d'interface ou de cinématique, au volume du catalogue.
static func play(sound: String) -> void:
	Events.sound.emit(sound)


## Son situé au point (x, z) du monde, coupé hors écran ; `delay` en secondes.
static func at(sound: String, x: float, z: float, delay := 0.0) -> void:
	Events.sound_at.emit(sound, x, z, delay)
