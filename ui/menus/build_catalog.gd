## Build catalog (spec 5.8, plan P3.11): Pieces and Blocks tabs with icon grids. Focus starts
## on the last used entry. result: {"kind": &"piece" | &"block", "id": StringName} or null.
extends MenuBase

static var last_used: Dictionary = {}

var tabs: TabContainer
var buttons: Dictionary = {}   # "kind:id" -> Button


func build() -> void:
	var p := MenuBase.panel(Vector2(720, 460))
	add_child(p)
	tabs = TabContainer.new()
	p.add_child(tabs)
	var s := GameSession.current
	var pieces_grid := GridContainer.new()
	pieces_grid.name = "Pieces"
	pieces_grid.columns = 4
	tabs.add_child(pieces_grid)
	for def in Database.pieces.values():
		var n := s.inventory.count(def.item_id) if s else 0
		_add(pieces_grid, &"piece", def.id, "%s x%d" % [String(def.id).trim_prefix("piece_"), n], def.color, n > 0)
	var blocks_grid := GridContainer.new()
	blocks_grid.name = "Blocks"
	blocks_grid.columns = 4
	tabs.add_child(blocks_grid)
	for it in Database.items.values():
		if it.category == &"BLOCK":
			var n := s.inventory.count(it.id) if s else 0
			var mat: VoxelMaterialDef = Database.materials.get(it.block_material)
			_add(blocks_grid, &"block", it.block_material, "%s x%d" % [String(it.id).trim_prefix("item_"), n], mat.color if mat else Color.WHITE, n > 0)
	if not last_used.is_empty() and last_used["kind"] == &"block":
		tabs.current_tab = 1


func _add(grid: GridContainer, kind: StringName, id: StringName, text: String, color: Color, enabled: bool) -> void:
	var b := MenuBase.make_button(text, color)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): choose(kind, id))
	grid.add_child(b)
	buttons["%s:%s" % [kind, id]] = b


func choose(kind: StringName, id: StringName) -> void:
	last_used = {"kind": kind, "id": id}
	close({"kind": kind, "id": id})


func initial_focus() -> Control:
	if not last_used.is_empty():
		var b: Button = buttons.get("%s:%s" % [last_used["kind"], last_used["id"]])
		if b:
			return b
	for b in buttons.values():
		if not b.disabled:
			return b
	return buttons.values()[0] if not buttons.is_empty() else null
