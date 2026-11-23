extends Node
## Headless test runner. Usage:  godot --headless --path . res://tests/test_runner.tscn [-- name1 name2]
## Runs tests/t_*.gd (each extends TestCase, methods named test_*). Exit code 1 on any failure.

func _ready() -> void:
	var filter: PackedStringArray = OS.get_cmdline_user_args()
	var dir := DirAccess.open("res://tests")
	var files := dir.get_files()
	files.sort()
	var total_checks := 0
	var total_fail := 0
	var report: Array = []
	var t_all := Time.get_ticks_msec()
	for f in files:
		if not (f.begins_with("t_") and f.ends_with(".gd")):
			continue
		var name := f.get_basename().substr(2)
		if filter.size() > 0 and name not in filter:
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("FAIL  %s : could not load script" % name)
			total_fail += 1
			report.append({"suite": name, "status": "load_error", "checks": 0, "failures": ["could not load"]})
			continue
		var inst: TestCase = script.new()
		var t0 := Time.get_ticks_msec()
		for m in inst.get_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_"):
				inst.current = mname
				inst.call(mname)
		var ms := Time.get_ticks_msec() - t0
		total_checks += inst.checks
		total_fail += inst.failures.size()
		var st := "PASS" if inst.failures.is_empty() else "FAIL"
		print("%s  %-22s %4d checks  %6d ms" % [st, name, inst.checks, ms])
		for fl in inst.failures:
			print("      - " + fl)
		report.append({"suite": name, "status": st, "checks": inst.checks, "failures": inst.failures, "ms": ms})
	print("---- %d checks, %d failures, %d ms ----" % [total_checks, total_fail, Time.get_ticks_msec() - t_all])
	var out := FileAccess.open("res://tests/last_report.json", FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify({"checks": total_checks, "failures": total_fail, "suites": report, "godot": Engine.get_version_info()["string"]}, "  "))
	get_tree().quit(1 if total_fail > 0 else 0)
