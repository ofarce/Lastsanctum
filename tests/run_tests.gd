extends SceneTree
## Lanceur de tests headless :
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --only=full_game   # fichiers contenant « full_game »
##   … -- --jobs=4      # nombre de processus (défaut : un par fil du processeur) ; --jobs=1 : tout dans ce processus
##   … -- --verbose     # recopie aussi la sortie brute des processus (erreurs de script, traces)
## Découvre res://tests/test_*.gd, exécute chaque méthode test_*(), affiche PASS/FAIL et quitte avec le
## code 1 si au moins un test échoue (ou si aucun test n'est trouvé).
##
## Les fichiers sont répartis entre plusieurs processus Godot (un lot par processus, équilibré d'après les
## durées du dernier passage, gardées dans tests/.durations.json). Chaque processus joue ses fichiers à la
## suite et rend un résultat par test ; celui-ci les rassemble et les affiche dans l'ordre des fichiers.

const TESTS_DIR := "res://tests/"
const DURATIONS := "res://tests/.durations.json"
## Marque des lignes de résultat qu'un processus de lot écrit pour le lanceur.
const MARK := "@@TEST@@ "
## Durée supposée d'un test jamais chronométré (ms).
const UNKNOWN_MS := 3000.0

var _lock := Mutex.new()
## Résultats reçus : {file, name, ms, failures}.
var _results: Array[Dictionary] = []
var _verbose := false


func _initialize() -> void:
	# Les tests démarrent après la première image : l'arbre de scène est alors actif et les nœuds
	# ajoutés par les tests reçoivent _ready immédiatement.
	process_frame.connect(_main, CONNECT_ONE_SHOT)


func _arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return fallback


func _main() -> void:
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	var batch := _arg("batch")
	if batch:
		await _run_files(batch.split(",", false), true)
		quit(0)
		return
	var t0 := Time.get_ticks_msec()
	var files := _test_files()
	var jobs := mini(int(_arg("jobs", str(OS.get_processor_count()))), files.size())
	if jobs <= 1:
		await _run_files(files, false)
	else:
		await _run_parallel(files, jobs)
	_report(files, Time.get_ticks_msec() - t0)


# ---------------------------------------------------------------- Exécution dans ce processus

func _run_files(files: PackedStringArray, as_batch: bool) -> void:
	# Les tests du jeu complet partent de l'ancien enchaînement ; test_opening.gd rallume la séquence.
	load("res://sim/simulation.gd").play_opening = false
	# Un lot dont le lanceur a disparu (Ctrl+C) s'arrête au test suivant au lieu de tourner dans le vide.
	var parent := int(_arg("parent", "0"))
	for file in files:
		var script := load(TESTS_DIR + file) as GDScript
		# Un fichier qui ne compile pas compte comme un échec (sinon ses tests disparaîtraient en silence).
		if script == null or not script.can_instantiate():
			_emit({"file": file, "name": "", "ms": 0, "failures": ["chargement impossible"]}, as_batch)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			if parent > 0 and DirAccess.dir_exists_absolute("/proc/self") and not DirAccess.dir_exists_absolute("/proc/%d" % parent):
				return
			var instance: RefCounted = script.new()
			var t0 := Time.get_ticks_msec()
			instance.call(name)
			var ms := Time.get_ticks_msec() - t0
			# Une image entre deux tests : les messages différés (redessins, libérations) sont traités.
			await process_frame
			_emit({"file": file, "name": name, "ms": ms, "failures": Array(instance.get("failures"))}, as_batch)
		if as_batch:
			print(MARK + JSON.stringify({"file": file, "done": true}))


func _emit(r: Dictionary, as_batch: bool) -> void:
	if as_batch:
		print(MARK + JSON.stringify(r))
	else:
		_results.append(r)
		_print_result(r)


func _print_result(r: Dictionary) -> void:
	var failures: Array = r["failures"]
	var label: String = r["file"] + ("::" + r["name"] if r["name"] else "")
	print("%s %s (%d ms)" % ["PASS" if failures.is_empty() else "FAIL", label, int(r["ms"])])
	for failure: String in failures:
		print("     - " + failure)


# ---------------------------------------------------------------- Exécution répartie

func _run_parallel(files: PackedStringArray, jobs: int) -> void:
	var batches := _split(files, jobs)
	var threads: Array[Thread] = []
	var done: Array[Dictionary] = []
	for batch: PackedStringArray in batches:
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/run_tests.gd",
			"--", "--batch=" + ",".join(batch), "--parent=%d" % OS.get_process_id()])
		var p := OS.execute_with_pipe(OS.get_executable_path(), args)
		if p.is_empty():
			for file in batch:
				_results.append({"file": file, "name": "", "ms": 0, "failures": ["processus de test impossible à lancer"]})
			continue
		var seen := {}
		done.append({"files": batch, "seen": seen})
		for pipe: FileAccess in [p["stdio"], p["stderr"]]:
			var t := Thread.new()
			t.start(_drain.bind(pipe, seen))
			threads.append(t)
	print("%d fichiers de tests sur %d processus…" % [files.size(), batches.size()])
	for t in threads:
		while t.is_alive():
			await process_frame
			OS.delay_msec(20)
		t.wait_to_finish()
	# Un processus mort en route (plantage du moteur) : ses fichiers non terminés sont des échecs.
	for d: Dictionary in done:
		for file: String in d["files"]:
			if not d["seen"].has(file):
				_results.append({"file": file, "name": "", "ms": 0, "failures": ["processus de test interrompu avant la fin du fichier"]})
				_print_result(_results[-1])


## Lit un tuyau d'un processus de lot jusqu'à sa fermeture ; les résultats sont affichés au fil de l'eau.
func _drain(pipe: FileAccess, seen: Dictionary) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line := pipe.get_line()
		if line.begins_with(MARK):
			var r: Dictionary = JSON.parse_string(line.trim_prefix(MARK))
			_lock.lock()
			if r.has("done"):
				seen[r["file"]] = true
			else:
				_results.append(r)
				_print_result(r)
			_lock.unlock()
		elif _verbose and not line.is_empty():
			print(line)


## Lots de fichiers de durées voisines : le plus long d'abord, toujours dans le lot le moins chargé.
func _split(files: PackedStringArray, jobs: int) -> Array:
	var known: Dictionary = {}
	if FileAccess.file_exists(DURATIONS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DURATIONS))
		if data is Dictionary:
			known = data
	var weighted: Array = []
	for file in files:
		var ms: float = known.get(file, -1.0)
		if ms < 0.0:
			ms = UNKNOWN_MS * FileAccess.get_file_as_string(TESTS_DIR + file).count("\nfunc test_")
		weighted.append([ms, file])
	weighted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var batches: Array = []
	var loads: Array[float] = []
	for k in jobs:
		batches.append(PackedStringArray())
		loads.append(0.0)
	for w: Array in weighted:
		var k := loads.find(loads.min())
		batches[k].append(w[1])
		loads[k] += w[0]
	return batches


# ---------------------------------------------------------------- Bilan

func _report(files: PackedStringArray, wall_ms: int) -> void:
	var passed := 0
	var failed: Array[Dictionary] = []
	var per_file := {}
	for r: Dictionary in _results:
		per_file[r["file"]] = float(per_file.get(r["file"], 0.0)) + float(r["ms"])
		if (r["failures"] as Array).is_empty():
			passed += 1
		else:
			failed.append(r)
	# Durées gardées pour équilibrer le prochain passage (les fichiers non joués gardent l'ancienne).
	var known: Dictionary = {}
	if FileAccess.file_exists(DURATIONS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DURATIONS))
		if data is Dictionary:
			known = data
	for file: String in per_file:
		known[file] = roundf(per_file[file])
	for file: String in known.keys():
		if not FileAccess.file_exists(TESTS_DIR + file):
			known.erase(file)
	var out := FileAccess.open(DURATIONS, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(known, "\t"))
		out.close()
	if not failed.is_empty():
		failed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return [a["file"], a["name"]] < [b["file"], b["name"]])
		print("\nÉchecs :")
		for r in failed:
			_print_result(r)
	print("\n%d réussi(s), %d échoué(s) en %.1f s" % [passed, failed.size(), wall_ms / 1000.0])
	quit(1 if not failed.is_empty() or passed == 0 else 0)


func _test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var only := _arg("only")
	for file in DirAccess.get_files_at(TESTS_DIR):
		if only and not file.contains(only):
			continue
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			files.append(file)
	files.sort()
	return files
