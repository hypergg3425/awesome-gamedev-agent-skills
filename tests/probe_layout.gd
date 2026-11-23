extends Node
func _ready() -> void:
	var v := Layout.apply(get_window())
	await get_tree().process_frame
	print("win ", get_window().size, " factor ", get_window().content_scale_factor, " vis ", get_viewport().get_visible_rect().size, " ret ", v)
	get_tree().quit()
