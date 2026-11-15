@tool
extends EditorPlugin
## Export (étape 12) : la sonde du MCP Godot (addons/godot_mcp) est un outil de développement. Son dossier est
## exclu par les presets (export_presets.cfg) et son autoload est retiré des réglages du projet exporté
## pendant l'export, puis rétabli : le jeu exporté ne la charge pas et ne signale aucun autoload manquant.

var _plugin: _StripProbe


func _enter_tree() -> void:
	_plugin = _StripProbe.new()
	add_export_plugin(_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_plugin)
	_plugin = null


class _StripProbe extends EditorExportPlugin:
	const KEY := "autoload/MCPRuntimeProbe"
	var _saved: Variant = null

	func _get_name() -> String:
		return "ExilesStripProbe"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if ProjectSettings.has_setting(KEY):
			_saved = ProjectSettings.get_setting(KEY)
			ProjectSettings.set_setting(KEY, null)

	func _export_end() -> void:
		if _saved != null:
			ProjectSettings.set_setting(KEY, _saved)
			_saved = null
