## Display case (spec 3.7): a locked silhouette until its rule is met; then each donated
## entry of this case appears at its slot marker. Slots are one per collectible of the case.
class_name DisplayCase
extends WorldObject

@export var case_id: StringName

var slots: Array[Marker3D] = []
var entries: Array = []   # item ids in slot order
var shell: Node3D


func _ready() -> void:
	entries = Database.collectibles().filter(func(it): return it.collection.case_id == case_id).map(func(it): return it.id)
	var width := maxf(1.2, entries.size() * 0.6)
	add_static_box(self, Vector3(width, 1.0, 0.8), Vector3(width * 0.5 - 0.3, 0.5, 0))
	for i in entries.size():
		var m := Marker3D.new()
		m.name = "slot_%d" % i
		m.position = Vector3(i * 0.6, 1.1, 0)
		add_child(m)
		slots.append(m)
	EventBus.item_donated.connect(_on_change)
	EventBus.display_case_unlocked.connect(_on_change)
	refresh()


func _exit_tree() -> void:
	for sig in [EventBus.item_donated, EventBus.display_case_unlocked]:
		if sig.is_connected(_on_change):
			sig.disconnect(_on_change)


func _on_change(_a = null, _b = null) -> void:
	refresh()


func unlocked() -> bool:
	var s := session()
	return s != null and String(case_id) in s.museum.model.cases_unlocked


func refresh() -> void:
	var s := session()
	if shell:
		shell.queue_free()
	var width := maxf(1.2, entries.size() * 0.6)
	# spec 12.8: a cabinet, darkened while the case is locked
	shell = add_art(self, ArtPaths.PROPS + "Cabinet.gltf", AABB(Vector3(-0.3, 0, -0.4), Vector3(width, 1.0, 0.8)))
	if shell:
		if not unlocked():
			var dark := StandardMaterial3D.new()
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dark.albedo_color = Color(0.05, 0.05, 0.08, 0.7)
			for mi in ModelFit.mesh_instances(shell):
				mi.material_overlay = dark
	else:
		shell = box_mesh(Vector3(width, 1.0, 0.8), Color(0.55, 0.45, 0.35) if unlocked() else Color(0.15, 0.15, 0.18), Vector3(width * 0.5 - 0.3, 0.5, 0))
		add_child(shell)
	for i in slots.size():
		for c in slots[i].get_children():
			slots[i].remove_child(c)   # free the "Display" name before the new one is added
			c.queue_free()
		if unlocked() and s and s.museum.model.is_donated(entries[i]):
			var m := ItemVisual.make(entries[i], 0.3, MenuBase.item_color(entries[i]))
			m.position.y -= 0.15   # slot markers sit at the visual's centre
			m.name = "Display"
			slots[i].add_child(m)


## Entries shown right now (spec 8.5 C9).
func display_count() -> int:
	var n := 0
	for sl in slots:
		for c in sl.get_children():
			if c.name == "Display" and not c.is_queued_for_deletion():
				n += 1
	return n
