class_name EnemyArt
extends RefCounted
## Atlas issus de la fiche validée ; les références du baker restent intactes.
const ROOT := "res://assets/imported/enemies/"
const DEATH_DURATION := 1.8
const CORPSE_LIFETIME := 10.0
const MAX_CORPSES := 80
static var _meta: Dictionary = {}


static func all() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))["enemies"]
	return _meta
