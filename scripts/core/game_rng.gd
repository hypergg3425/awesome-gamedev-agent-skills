class_name GameRng
extends RefCounted
## Deterministic, serialisable RNG (PCG32-like via Godot's RandomNumberGenerator state).

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value

func get_state() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}

func set_state(d: Dictionary) -> void:
	_rng.seed = int(d.get("seed", "1"))
	_rng.state = int(d.get("state", "1"))

func randf() -> float:
	return _rng.randf()

func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

func chance(p: float) -> bool:
	return _rng.randf() < p

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

func gauss(mean: float = 0.0, dev: float = 1.0) -> float:
	return _rng.randfn(mean, dev)
