class_name MapImportLoader
extends RefCounted
## Extension point for custom map geometry (not implemented, no UI).
##
## A map set is a directory with `provinces.json` (id, names, adm0, terrain, coastal, centroid, neighbours) and
## `geometry` (polygons per province id), registered in `Defs.MAP_DIRS` and selected with `Defs.use_map_set(id)`.
## Scenarios and saves record the set in `map_set`, and the editor writes `ScenarioModel.export()["map_set"]`
## from `Defs.map_set`. A future importer (GeoJSON / Natural Earth / user shapefile-converted data) subclasses
## this class, overrides `load_table` and `load_polygons`, and returns data in the documented shapes. Callers
## must check `validate_table` before registering a set. The base class always reports "not supported".

## Short id and display names of the importer, e.g. {"id": "geojson", "name": {"en": "...", "tr": "..."}}.
func describe() -> Dictionary:
	return {"id": "none", "name": {"en": "No importer", "tr": "İçe aktarıcı yok"}}

## Returns {"ok": bool, "provinces": Array[Dictionary], "reason": String}; each province needs
## id, name {en, tr}, adm0, terrain, coastal, neighbors (ids).
func load_table(_path: String) -> Dictionary:
	return {"ok": false, "provinces": [], "reason": "IMPORT_NOT_SUPPORTED"}

## Returns {"ok": bool, "polygons": {province_id: Array[PackedVector2Array]}, "reason": String}.
func load_polygons(_path: String) -> Dictionary:
	return {"ok": false, "polygons": {}, "reason": "IMPORT_NOT_SUPPORTED"}

## Structural check of a province table; returns a list of error strings (empty = acceptable).
static func validate_table(provinces: Array) -> Array:
	var errs: Array = []
	var ids := {}
	for p in provinces:
		var pid := str(p.get("id", ""))
		if pid == "" or ids.has(pid):
			errs.append("bad or duplicate id: " + pid)
		ids[pid] = true
		for k in ["name", "adm0", "terrain", "neighbors"]:
			if not p.has(k):
				errs.append("%s: missing %s" % [pid, k])
	for p in provinces:
		for nb in p.get("neighbors", []):
			if not ids.has(nb):
				errs.append("%s: unknown neighbour %s" % [p.get("id", ""), nb])
	return errs
