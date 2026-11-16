## Deterministic named random streams (spec 3.5 `rng`). Each draw seeds a fresh generator
## from (seed, stream, counter), so results depend only on the save's seed and counters,
## never on call order across different streams.
class_name RngStreams
extends RefCounted

var seed_value := 918273
var counters: Dictionary = {}   # String stream -> int


func _init(s: int = 918273) -> void:
	seed_value = s


func _gen(stream: String) -> RandomNumberGenerator:
	var n: int = counters.get(stream, 0)
	counters[stream] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, stream, n])
	return rng


func randi_range(stream: String, from: int, to: int) -> int:
	return _gen(stream).randi_range(from, to)


## Percent roll: true with probability pct/100.
func chance(stream: String, pct: float) -> bool:
	return _gen(stream).randf() * 100.0 < pct


## Picks an index from integer weights.
func weighted_index(stream: String, weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return -1
	var r := _gen(stream).randi_range(1, total)
	for i in weights.size():
		r -= int(weights[i])
		if r <= 0:
			return i
	return weights.size() - 1


func to_dict() -> Dictionary:
	return {"seed": seed_value, "counters": counters.duplicate()}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d.get("seed", seed_value))
	counters = {}
	var c: Dictionary = d.get("counters", {})
	for k in c:
		counters[String(k)] = int(c[k])
