## Builds the VoxelBlockyLibrary from Database materials (spec 3.4, 11.10): model index =
## voxel_id, index 0 is air. Materials with tiles get a 3 x 1 atlas (top, side, bottom) built
## at load with nearest filtering; others keep their flat colour.
class_name VoxelLibraryBuilder
extends RefCounted

const TILE_DIR := "res://assets/third_party/kenney/voxel_pack/"
const ATLAS := Vector2i(3, 1)
const TOP := Vector2i(0, 0)
const SIDE := Vector2i(1, 0)
const BOTTOM := Vector2i(2, 0)

static var _atlases := {}   # material id -> ImageTexture


static func build() -> VoxelBlockyLibrary:
	var lib := VoxelBlockyLibrary.new()
	lib.add_model(VoxelBlockyModelEmpty.new())
	var max_id := 0
	for m in Database.materials.values():
		max_id = maxi(max_id, m.voxel_id)
	for id in range(1, max_id + 1):
		var cube := VoxelBlockyModelCube.new()
		var mat := StandardMaterial3D.new()
		var def := Database.material_by_voxel(id)
		var tex := atlas_for(def) if def else null
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = def.tint
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			cube.atlas_size_in_tiles = ATLAS
			for side in [VoxelBlockyModel.SIDE_NEGATIVE_X, VoxelBlockyModel.SIDE_POSITIVE_X, VoxelBlockyModel.SIDE_NEGATIVE_Z, VoxelBlockyModel.SIDE_POSITIVE_Z]:
				cube.set_tile(side, SIDE)
			cube.set_tile(VoxelBlockyModel.SIDE_POSITIVE_Y, TOP)
			cube.set_tile(VoxelBlockyModel.SIDE_NEGATIVE_Y, BOTTOM)
		else:
			mat.albedo_color = def.color if def else Color.MAGENTA
		cube.set_material_override(0, mat)
		lib.add_model(cube)
	lib.bake()
	return lib


## Top, side and bottom tiles side by side; cached per material. Null without tiles.
static func atlas_for(def: VoxelMaterialDef) -> ImageTexture:
	if def.tiles.is_empty():
		return null
	if _atlases.has(def.id):
		return _atlases[def.id]
	var imgs: Array[Image] = []
	for face in ["top", "side", "bottom"]:
		var t := load(TILE_DIR + def.tile(face)) as Texture2D
		if t == null:
			return null
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
	var w := imgs[0].get_width()
	var h := imgs[0].get_height()
	var atlas := Image.create(w * ATLAS.x, h, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		if imgs[i].get_size() != Vector2i(w, h):
			imgs[i].resize(w, h, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	atlas.generate_mipmaps()
	_atlases[def.id] = ImageTexture.create_from_image(atlas)
	return _atlases[def.id]
