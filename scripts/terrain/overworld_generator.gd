## Overworld terrain (spec 9.2): grass/dirt over stone, hard stone deeper, ore veins, geode
## rock and buried chest pockets, bedrock floor. Runs on Voxel Tools worker threads, so all
## inputs are copied in _init and no scene or autoload is touched here.
class_name OverworldGenerator
extends VoxelGeneratorScript

var ids: Dictionary          # material id String -> voxel id
var bedrock_y := -24
var seed_value := 1234
var _noise := FastNoiseLite.new()
var _flats: Array = []       # [[Rect2i (x, z), height]]: flattened areas such as farm plots


func _init(material_ids: Dictionary = {}, bedrock_level: int = -24, s: int = 1234) -> void:
	ids = material_ids
	bedrock_y = bedrock_level
	seed_value = s
	_noise.seed = s
	_noise.frequency = 0.018


## Flattens `rect` (x/z cells, inclusive of position, exclusive of end) to the natural height
## at its center (spec 10.2: the starter garden is level). Call before the terrain generates.
func add_flat(rect: Rect2i) -> void:
	var c := rect.get_center()
	_flats.append([rect, surface_height(_noise, c.x, c.y)])


static func surface_height(noise: FastNoiseLite, x: int, z: int) -> int:
	return int(round(noise.get_noise_2d(x, z) * 6.0)) + 4


func height_at(x: int, z: int) -> int:
	for f in _flats:
		if (f[0] as Rect2i).has_point(Vector2i(x, z)):
			return f[1]
	return surface_height(_noise, x, z)


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


static func _hash(x: int, y: int, z: int, s: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (s * 2654435761))


func _generate_block(out: VoxelBuffer, origin: Vector3i, _lod: int) -> void:
	var size := out.get_size()
	for x in size.x:
		for z in size.z:
			var wx := origin.x + x
			var wz := origin.z + z
			var h := height_at(wx, wz)
			for y in size.y:
				var wy := origin.y + y
				var v := _voxel(wx, wy, wz, h)
				if v != 0:
					out.set_voxel(v, x, y, z, VoxelBuffer.CHANNEL_TYPE)


func _voxel(x: int, y: int, z: int, h: int) -> int:
	if y < bedrock_y:
		return 0
	if y == bedrock_y:
		return ids.get("mat_bedrock", 0)
	if y > h:
		return 0
	if y == h:
		return ids.get("mat_grass", 0)
	if y >= h - 2:
		return ids.get("mat_dirt", 0)
	var r := _hash(x, y, z, seed_value)
	if r % 2003 == 0:
		return ids.get("mat_chest_block", 0)
	if y < h - 10:
		if r % 211 == 0:
			return ids.get("mat_geode_rock", 0)
		if r % 53 == 0:
			return ids.get("mat_iron_ore", 0)
		if r % 97 == 0:
			return ids.get("mat_quartz_ore", 0)
		return ids.get("mat_stone_hard", 0) if y < h - 16 else ids.get("mat_stone", 0)
	if r % 37 == 0:
		return ids.get("mat_copper_ore", 0)
	return ids.get("mat_stone", 0)
