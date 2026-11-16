## Picks the focused interactable (spec 4.5): an aimed target wins outright, otherwise the
## highest score = facing_dot * 2 - distance / 2 + kind priority, ties by key.
## candidates: [{"key": String, "kind": StringName, "distance": float, "facing_dot": float, "aimed": bool}]
class_name InteractionResolver
extends RefCounted

const KIND_PRIORITY := {&"PICKUP": 3, &"NPC": 2, &"PET": 2, &"CHEST": 2}


static func score(c: Dictionary) -> float:
	return float(c["facing_dot"]) * 2.0 - float(c["distance"]) / 2.0 + float(KIND_PRIORITY.get(c["kind"], 1))


static func best(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	for c in candidates:
		if c.get("aimed", false):
			return c
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var sa := score(a)
		var sb := score(b)
		if not is_equal_approx(sa, sb):
			return sa > sb
		return a["key"] < b["key"])
	return sorted[0]
