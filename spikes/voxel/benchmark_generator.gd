# Spike-only terrain generator: rolling hills of grass/dirt over stone with ore specks.
# Runs on Voxel Tools worker threads: no scene tree access here.
extends VoxelGeneratorScript

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const ORE := 4

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 1234
	_noise.frequency = 0.02


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var size := out_buffer.get_size()
	for x in size.x:
		for z in size.z:
			var wx := origin.x + x
			var wz := origin.z + z
			var h := int(16.0 + _noise.get_noise_2d(wx, wz) * 8.0)
			for y in size.y:
				var wy := origin.y + y
				var v := AIR
				if wy < h - 3:
					v = ORE if ((wx * 73856093) ^ (wy * 19349663) ^ (wz * 83492791)) % 37 == 0 else STONE
				elif wy < h - 1:
					v = DIRT
				elif wy < h:
					v = GRASS
				if v != AIR:
					out_buffer.set_voxel(v, x, y, z, VoxelBuffer.CHANNEL_TYPE)
