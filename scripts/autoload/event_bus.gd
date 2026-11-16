## Global signal bus (spec 1.2, 1.5). Signal declarations only: no state, no logic.
## Events are past tense. Later phases add their signals here.
extends Node

# Input (spec 2.5)
signal input_device_changed(kind: int, glyph_set: int)
signal joypad_lost(device: int)
signal joypad_restored(device: int)

# Pause (spec 5.2)
signal game_paused
signal game_resumed
signal pause_changed(paused: bool, reasons: Array)

# Player (spec 4.1)
signal player_state_changed(from: StringName, to: StringName)

# Settings
signal settings_changed(section: StringName, key: StringName, value: Variant)

# Inventory, wallet, unlocks (spec 1.8)
signal item_added(item_id: StringName, qty: int)
signal inventory_changed
signal hotbar_selected(index: int)
signal coins_changed(old_value: int, new_value: int)
signal unlock_granted(kind: StringName, id: StringName)

# Tools (spec 2.6)
signal tool_equipped(tool_type: StringName, item_id: StringName, source: StringName)
signal tool_unequipped(source: StringName)
signal tool_auto_selected(tool_type: StringName, target_kind: StringName, reason: StringName)
signal prompt_changed(target_key: String, state: StringName, tool_type: StringName)

# Terrain and world (spec 1.8, 6.4)
signal voxel_damaged(cell: Vector3i, hits_left: int)
signal voxel_dug(cell: Vector3i, material_id: StringName)
signal tree_harvested(key: String, qty: int)
signal tree_chopped(key: String)
signal chest_spawned(key: String, cell: Vector3i)
signal chest_opened(key: String, reward: Dictionary)
signal geode_found(cell: Vector3i)

# Stamina and sleep (spec 6.1, 6.2, 6.3)
signal stamina_changed(old_value: int, new_value: int, reason: StringName)
signal stamina_low(level_pct: int)
signal stamina_depleted
signal sleep_transition_started(reason: StringName)
signal player_woke(reason: StringName, day: int)
signal player_sent_home
signal player_returned_to_safe_ground
signal stuck_hint
signal day_started(day: int)
signal clock_late_night

# Mail (spec 3.3)
signal mail_delivered(ids: Array)
signal mail_claimed(id: String)

# Farming (spec 1.8, 10)
signal soil_tilled(cell: Vector3i)
signal crop_planted(cell: Vector3i, crop_id: StringName)
signal crop_watered(cell: Vector3i)
signal crop_grew(cell: Vector3i, stage: int)
signal crop_harvested(cell: Vector3i, crop_id: StringName, qty: int)
signal can_refilled(water: int)
signal sprinkler_placed(cell: Vector3i)
signal farm_changed(zone_id: StringName)

# Build and housing (spec 1.8)
signal piece_placed(uid: String, piece_id: StringName, cell: Vector3i)
signal piece_fastened(uid: String)
signal fasten_progressed(uid: String, done: int, total: int)
signal piece_removed(uid: String, piece_id: StringName)
signal block_placed(cell: Vector3i, material_id: StringName)
signal block_removed(cell: Vector3i, material_id: StringName)
signal voxel_placed(cell: Vector3i, material_id: StringName)
signal furniture_toggled(uid: String, state: int)
signal build_mode_changed(active: bool)
signal ghost_changed(state: StringName, reason: StringName)
signal build_changed(zone_id: StringName)
signal pet_nudge_requested(cells: Array)
signal deed_granted(plot_id: StringName)
signal home_changed(zone_id: StringName, bed_key: StringName)

# Menus (spec 5.3)
signal menu_opened(menu_id: StringName)
signal menu_closed(menu_id: StringName)

# Zones (spec 1.2 SceneRouter)
signal zone_unloading(zone_id: StringName)
signal zone_loaded(zone_id: StringName)
