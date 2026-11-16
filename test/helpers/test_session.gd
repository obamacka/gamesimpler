## Factory for deterministic test sessions (spec 8.2 item 2).
## Phase 0 placeholder: holds the seed only. Each later phase extends build()
## to construct the GameSession services it introduces, with this seed.
class_name TestSession
extends RefCounted

const DEFAULT_SEED := 918273

var rng_seed: int


func _init(seed_value: int = DEFAULT_SEED) -> void:
	rng_seed = seed_value


static func new_for_tests(seed_value: int = DEFAULT_SEED) -> TestSession:
	return TestSession.new(seed_value)
