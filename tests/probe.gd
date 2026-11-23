extends Node
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	print("defs ", Defs.provinces.size(), " units ", Defs.units.size(), " techs ", Defs.techs.size(), " errs ", Defs.load_errors)
	var g := Defs.load_geometry()
	print("geom ok ", g.ok, " polys ", g.polys.size(), " borders ", g.borders.size(), " ms ", Time.get_ticks_msec() - t0)
	get_tree().quit(0)
