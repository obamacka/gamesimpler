## Painting rules (spec 7.2). Pure. Only owned, placed pieces with paint regions; dyes must be
## unlocked; dyes are never consumed (D12).
class_name PaintModel
extends RefCounted

const NOT_OWNED := &"not_owned"
const NO_REGION := &"no_region"
const LOCKED := &"dye_locked"
const SAME := &"same_dye"


static func check(def: BuildPieceDef, inst: Dictionary, region_id: StringName, dye_id: StringName, owned: bool, unlocked: bool) -> StringName:
	if not owned:
		return NOT_OWNED
	if def.region_param(region_id) == &"":
		return NO_REGION
	if not unlocked or not Database.dyes.has(dye_id):
		return LOCKED
	if StringName(inst.get("paint", {}).get(String(region_id), "")) == dye_id:
		return SAME
	return &""


## Region ids of a piece in cycle order.
static func regions(def: BuildPieceDef) -> Array:
	return def.paint_regions.map(func(r): return r["region_id"])


## Dye colour of a region; unpainted is white with alpha 0, so textured models keep their
## texture (spec 11.3) while placeholder boxes multiply by white.
const UNPAINTED := Color(1, 1, 1, 0)


static func color_of(inst: Dictionary, region_id: StringName) -> Color:
	var dye: DyeDef = Database.dyes.get(StringName(inst.get("paint", {}).get(String(region_id), "")))
	return dye.color if dye else UNPAINTED
