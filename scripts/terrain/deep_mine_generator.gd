## Deep Mine (spec 9.2, D16): solid rock with 3-high main tunnels on a grid, 2-high crawlspaces
## (Duck) leading to treasure pockets. Seed = hash(save seed, day), so the mine changes daily.
class_name DeepMineGenerator
extends VoxelGeneratorScript

const TUNNEL_SPACING := 12

var ids: Dictionary
var bedrock_y := -40
var top_y := 8
var seed_value := 1


func _init(material_ids: Dictionary = {}, bedrock_level: int = -40, top: int = 8, s: int = 1) -> void:
	ids = material_ids
	bedrock_y = bedrock_level
	top_y = top
	seed_value = s


static func day_seed(save_seed: int, day: int) -> int:
	return hash([save_seed, "deep_mine", day])


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(out: VoxelBuffer, origin: Vector3i, _lod: int) -> void:
	var size := out.get_size()
	for x in size.x:
		for z in size.z:
			for y in size.y:
				var v := voxel_at(origin.x + x, origin.y + y, origin.z + z)
				if v != 0:
					out.set_voxel(v, x, y, z, VoxelBuffer.CHANNEL_TYPE)


func voxel_at(x: int, y: int, z: int) -> int:
	if y < bedrock_y or y > top_y:
		return 0
	if y == bedrock_y:
		return ids.get("mat_bedrock", 0)
	var floor_y := bedrock_y + 4
	var mx := posmod(x, TUNNEL_SPACING)
	var mz := posmod(z, TUNNEL_SPACING)
	# Main tunnels: 3 high, 3 wide, along both axes.
	if y >= floor_y and y < floor_y + 3 and (mx < 3 or mz < 3):
		return 0
	# Crawlspaces: 2 high, 1 wide, diagonal offsets between tunnels.
	var cell := Vector2i(floori(float(x) / TUNNEL_SPACING), floori(float(z) / TUNNEL_SPACING))
	var r := absi(hash([seed_value, cell.x, cell.y]))
	if y >= floor_y and y < floor_y + 2 and mz == 6 and mx >= 3 and mx <= 6 + r % 4:
		return 0
	if y == floor_y and mz == 6 and mx == 7 + r % 4 and r % 3 == 0:
		return ids.get("mat_chest_block", 0)
	var h := absi(hash([seed_value, x, y, z]))
	if h % 149 == 0:
		return ids.get("mat_geode_rock", 0)
	if h % 41 == 0:
		return ids.get("mat_iron_ore", 0)
	if h % 29 == 0:
		return ids.get("mat_copper_ore", 0)
	if h % 67 == 0:
		return ids.get("mat_quartz_ore", 0)
	return ids.get("mat_stone_hard", 0) if y < floor_y - 6 else ids.get("mat_stone", 0)
