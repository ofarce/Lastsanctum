extends RefCounted
## Accès aux valeurs de référence produites par le baker (res://assets/baked/fixtures/).

const DIR := "res://assets/baked/fixtures/"


static func load_json(name: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + name + ".json"))
	return data if data is Dictionary else {}
