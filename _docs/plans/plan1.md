# Plan 1: Phased Implementation of Spec 1

| Field | Value |
|---|---|
| Implements | `_docs/specs/spec1.md` rev 3.4 |
| Status | DRAFT, not started |
| Tracking | `_docs/PROGRESS.md` (update after every completed task, per CLAUDE.md) |
| Engine / libs | Godot 4.7.x, Jolt, gdUnit4 v6.2.3, Voxel Tools 1.7 GDExtension |

---

## 0. How to use this plan

### 0.1 Rules
- Task IDs are `P<phase>.<n>`; test files carry the suite case IDs from spec 8 (A1..A22, B1..B17, C1..C17) where they apply.
- A task is complete only when its code, scene/resource work and listed tests exist and the headless run exits 0 (CLAUDE.md). Then tick it here and in `_docs/PROGRESS.md`, and commit.
- A phase is complete only when every task is ticked and the **phase gate** (0.3) passes.
- No implementation starts in a phase until the previous phase's gate passes, except Phase 0 tasks marked parallel.
- Test-first for pure logic (CLAUDE.md "Write GdUnit4 test suites ... before feature sign-off"): write the unit suite for a model before or alongside the model, never after the phase gate.

### 0.2 Layout (CLAUDE.md modular structure)
```
res://scripts/autoload/      EventBus, Database, Settings, InputService, PauseManager, GameClock, SaveService, SceneRouter
res://scripts/core/          shared value types (Result, InputFrame), base classes (State, StateMachine)
res://scripts/<domain>/      player, input, terrain, farm, tools, interaction, stamina, sleep, inventory, build,
                             economy, jobs, housing, outfit, mail, npc, pet, museum, decor, save
                             models/   pure RefCounted logic (unit-tested)
                             services/ GameSession-owned Nodes
res://scenes/                main.tscn, player/, pet/, npc/, zones/, props/, build_pieces/, dev/
res://resources/             items/, recipes/, materials/, pieces/, outfits/, pets/, npcs/, mail/, museum/, config/, glyphs/
res://ui/                    hud/, prompts/, menus/<menu_id>.tscn + .gd, theme/
res://test/unit/<domain>/    pure logic suites
res://test/integration/      scene and signal suites; scenes/ holds fixtures
res://test/fixtures/         JSON saves, test-only resources
res://test/helpers/          SignalRecorder, await_physics_frames, FakeVoxelWorld, FakePathProvider, GameSession.new_for_tests
res://addons/                gdUnit4/, zylann.voxel/
res://spikes/                Phase 0 spikes, excluded from export
```

### 0.3 Phase gate (applies to every phase)
- [ ] All unit and integration suites listed in the phase exist under `res://test/unit/` and `res://test/integration/`.
- [ ] Headless run exits 0 with zero failures and zero errors (command from P0.3), including all suites from earlier phases (no regressions).
- [ ] Pause-safety lint suite passes (P1.24).
- [ ] `Database` integrity suite passes for every resource type introduced so far.
- [ ] Manual gamepad pass on the phase's checklist with an Xbox-layout pad and a DualShock 4 or DualSense, plus keyboard/mouse.
- [ ] Phases 2, 2B, 3, 5, 6: performance check on both min-spec machines (spec 0.7: i7-3770 / 16 GB DDR3-1333 / GTX 1070, and base M1 / 16 GB) against D25 (30 fps at 1080p medium) and the voxel budget; and on both recommended-spec machines (spec 0.7.1: Ryzen 5 3600 / 16 GB / RTX 2070, and M2 / 16 GB) against 60 fps at 1080p medium; numbers logged in `_docs/PROGRESS.md`.
- [ ] `_docs/PROGRESS.md` updated: tasks ticked, test run logged with commit SHA, open issues recorded.
- [ ] Commit with a meaningful message.

### 0.4 Deviations from the requested phase list (please review)
1. **Added Phase 0 (bootstrap and voxel spike).** Spec 0.6 items 1, 3, 18, 19, 21, 22 make the test command, gdUnit4-on-4.7, and the Voxel Tools GDExtension unverified. The spike outcome can force the module edition (custom engine build), which changes the editor, CI and export setup for every later phase. Discovering that in Phase 2 would mean redoing Phase 1 setup.
2. **Jump and double jump are in Phase 1**, not only Walk/Run/Duck. Spec D2 makes them core locomotion; auto-jump and the 1 m voxel grid depend on them.
3. **Infrastructure is pulled earlier than the phase it is named in**, because earlier phases need it:
   - `PauseManager` and `EventBus` in Phase 1 (Phase 2 sleep transition pauses the tree). Phase 4 still owns the full menu pause flow and its suites.
   - `InventoryModel` (add/remove/overflow) in Phase 2 (dig drops). Phase 4 owns transactions and economy.
   - `MailService` core (schedule, deliver, claim) in Phase 2 (care package). Phase 5 owns the mail UI and all other mail kinds.
   - `MenuStack` core in Phase 3 (build catalog pauses). Phase 4 owns global keys, focus rules and auto-pause triggers.
4. **Serialization is built per phase, not only in Phase 6.** Every model gets `to_dict()`/`from_dict()` with a round-trip unit test in the phase that creates it. Phase 6 builds `SaveService` (files, atomic writes, slots, migrations, voxel DB) on top. Leaving all serialization to the end would force retrofitting every model.
5. **Spec features not named in your list are assigned here:** PromptOverlay and Deep Mine (Phase 2); block placement, furniture Sit/Toggle/Bed and Set Home (Phase 3); settings, rebinding UI, accessibility, TTS, Go Home button (Phase 4); Talk state, emote and instrument wheel (Phase 5); stamps and decor undo (Phase 6, with painting).
6. **Spec suites are split across phases where they depend on later systems:** Suite A cases A8 to A10 (hammer/screwdriver on loose pieces) run in Phase 3; Suite B case B13 (contract deadline) in Phase 4 and B12 (autosave content) in Phase 6.
7. **"Pickaxe vs axe/picker via interaction volumes":** per spec rev 3, axe and fruit picker are selected by target volumes (`ToolTargetZone`), while pickaxe and shovel are selected by aiming at voxels (dig-anywhere terrain has no per-block volumes). Phase 2 tests both paths.
8. **Added Phase 2B (Farming)** for D9, between Phases 2 and 3, so your phase numbers stay unchanged. It needs Phase 2 terrain, tools, stamina and day rollover; seeds in shops come in Phase 4 and crop donations in Phase 6.

### 0.5 Decision gates
All decisions D1 to D26 are resolved (spec 0.4). No phase is blocked on a decision.

---

## Phase 0: Bootstrap, Test Harness and Voxel Spike

**Goal:** a Godot 4.7 project where the headless gdUnit4 command is proven, CI runs it, and the voxel technology is a go or a documented fallback.
**Depends on:** nothing.

### P0 tasks
- [x] **P0.1 Project skeleton.** Create `project.godot` for Godot 4.7.x: `physics/3d/physics_engine="Jolt Physics"`, `rendering/renderer/rendering_method="forward_plus"`, physics ticks 60, named 3D physics layers 1 to 9 (spec 1.7), window defaults. Create the folder layout in 0.2. Update `.gitignore` for `.godot/`, `user://` exports, spike outputs.
- [x] **P0.2 Install gdUnit4 v6.2.3** into `res://addons/gdUnit4/` from the `v6.2.3` release; enable the plugin; record the source URL and license in `res://addons/README.md`.
- [x] **P0.3 Prove the headless command.** Run the CLAUDE.md command and the spec 0.6 item 1 variant with `--remote-debug tcp://127.0.0.1:0` against: a passing suite, a failing suite, and a suite with a GDScript parse error. Record exit codes and whether any run hangs at a `debug>` prompt. Also record the exit code without `--ignoreHeadlessMode`. Write the verified command into `_docs/PROGRESS.md`.
- [x] **P0.4 Update CLAUDE.md test command.** Done by the owner on 2026-11-16 (commit `3682356`). Follow-up after P0.3: if the parse-error run hangs, propose adding `--remote-debug tcp://127.0.0.1:0` (owner approval required).
- [x] **P0.5 Test helpers.** `res://test/helpers/signal_recorder.gd` (records name, args, physics frame), `res://test/helpers/physics_wait.gd` (`await_physics_frames(n)`), `res://test/helpers/test_session.gd` (factory placeholder, filled per phase). Unit suite `res://test/unit/helpers/test_signal_recorder.gd`.
- [x] **P0.6 CI.** GitHub Actions workflow running the headless command on Linux with a pinned Godot 4.7.x binary; upload gdUnit4 reports. Optional Windows and macOS jobs for exports in P0.9.
- [x] **P0.7 Min-spec hardware.** Defined by the owner on 2026-11-16: Intel Core i7-3770, 16 GB DDR3-1333, Nvidia GTX 1070 (Windows/Linux); base Apple M1, 16 GB (macOS, D24). Target 30 fps at 1080p medium (D25).
- [ ] **P0.8 Voxel spike** (in `res://spikes/voxel/`, not shipped). Install Voxel Tools 1.7 GDExtension into `res://addons/zylann.voxel/`. Run all measurements on both min-spec machines (spec 0.7). Verify and record numbers in `_docs/reports/voxel_spike.md`:
  - [x] a. Extension loads in the editor and in a headless run.
  - [ ] b. `VoxelTerrain` + `VoxelMesherBlocky` + `VoxelBlockyLibrary` with 4 materials renders; data block size confirmed.
  - [x] c. Dig and place through `get_voxel_tool()` (`set_voxel`, `get_voxel`, `raycast`).
  - [ ] d. Collision rebuild latency after single-voxel edits against the budget (<= 100 ms edit-to-collision, no frame > 33.3 ms during continuous digging) on min-spec hardware, with a Jolt `CharacterBody3D` standing and walking over edits.
  - [x] e. `VoxelStreamSQLite` save via `save_modified_blocks()` and `VoxelSaveCompletionTracker.is_complete()`, then reload.
  - [x] f. Copy the SQLite file after the tracker completes while the stream is attached; reload the copy in a fresh terrain and diff voxels (spec 0.6 item 22).
  - [x] g. `VoxelAStarGrid3D.find_path_async` for a pet-sized agent across dug terrain.
  - [x] h. Jolt `CharacterBody3D` physics works in a headless run (needed by Phase 1 integration suites).
  - [x] i. `@voxel_real` smoke suite `res://test/integration/test_voxel_smoke.gd` passes headless (or the report states why it needs a windowed job).
  - [ ] j. No illegal-instruction crash on the i7-3770 (no AVX2), in the editor or the exported build.
  - [ ] k. Frame rate at 1920x1080 medium with the target view distance while walking and digging: >= 30 fps on both min-spec machines and >= 60 fps on both recommended-spec machines (D25, D26); on the M1 confirm the Metal driver is active; voxel worker thread count chosen so at least 2 hardware threads stay free for main and physics.
- [ ] **P0.9 Export smoke.** Export the spike for Windows x86_64, Linux x86_64, macOS (universal) with stock templates; each launches and digs. The macOS build is run on the base M1.
- [ ] **P0.10 Go / no-go record.** In `_docs/reports/voxel_spike.md`: GDExtension go, or fallback to module edition (custom editor, templates, CI change), and/or `VoxelBoxMover` for player collision (spec 9.5), and/or per-save `database_path` (spec 9.6). Update spec 0.6 and 9 if anything changed.

### P0 tests
- `res://test/unit/test_smoke.gd` (one passing assertion; a temporary failing twin proves non-zero exit, then removed).
- `res://test/unit/helpers/test_signal_recorder.gd`.
- `res://test/integration/test_voxel_smoke.gd` (`@voxel_real`).

### P0 exit criteria
- Verified command recorded; CI green; voxel go/no-go documented; owner has seen the spike report.

---

## Phase 1: Core Engine, Cross-Platform Gamepad Input, Camera and Tall Character FSM

**Goal:** a 2.1 m character that walks, runs, ducks, jumps and double jumps in a graybox room with gamepad or keyboard, with device-aware glyphs and a working pause primitive.
**Depends on:** Phase 0 gate.
**Spec:** 1.2, 1.4, 1.7, 2.1 to 2.5, 4.1, 4.2 (locomotion rows), 4.2.1, 5.2, 5.5.

### P1 resources and project settings
- [ ] **P1.1 Input map** in `project.godot`: every action in spec 2.2, 2.3 (`build_tool_next/prev`, `rotate_cw/ccw`, `undo`, `build_catalog`, `note_1..8`), 2.4 (`ui_*` explicit events, custom `ui_tab_*`, `ui_page_*`, `ui_secondary`, `ui_tertiary`, `ui_wheel_select`), with joypad and KB/M events and deadzones exactly as specified.
- [ ] **P1.2 `res://resources/config/input_contexts.tres`**: action -> context map (`GAMEPLAY`, `AIRBORNE`, `BUILD`, `INSTRUMENT`, `UI`) used by conflict validation.
- [ ] **P1.3 `res://resources/config/player_config.tres`** (`PlayerConfig`: capsules, speeds, reach) and **`jump_config.tres`** (`JumpConfig`: gravity 24, 7.9 / 7.6 m/s, coyote 0.12, buffer 0.15, air control 0.8, max fall 20).
- [ ] **P1.4 Glyph sets** `res://resources/glyphs/{xbox,playstation,nintendo,kbm}.tres` (`GlyphSetDef`: texture per action button, native color per button per spec 2.8). Placeholder art is fine.

### P1 scripts
- [ ] **P1.5 Core types** `res://scripts/core/result.gd`, `input_frame.gd` (all spec 2.1 fields), `state.gd`, `state_machine.gd`.
- [ ] **P1.6 `EventBus`** autoload with Phase 1 signals: `input_device_changed`, `player_state_changed`, `game_paused`, `game_resumed`, `pause_changed`. Registered first (spec 1.2 order).
- [ ] **P1.7 `Settings`** autoload: ConfigFile load/save of `[input]` and `[accessibility]` keys used in Phase 1 (`run_mode`, `duck_mode`, `jump_auto`, `sensitivity`, `invert_y`, `glyph_override`), defaults per spec 5.10; `to_dict()/from_dict()`.
- [ ] **P1.8 Input models** (`res://scripts/input/models/`): `InputDeviceModel` (event classification thresholds, vendor id -> glyph set, override), `RebindModel` (plain-dict <-> InputEvent for joy button, joy axis with sign, physical key, mouse button; locked actions; context-disjoint conflict check).
- [ ] **P1.9 `InputService`** autoload (ALWAYS): routes events to `InputDeviceModel`, emits `input_device_changed`, handles `Input.joy_connection_changed` (emits `EventBus.joypad_lost/joypad_restored` for Phase 4), applies rebinds from Settings, mouse capture policy.
- [ ] **P1.10 `PauseManager`** autoload (ALWAYS): `request_pause`, `release_pause`, `has_reason`, `is_paused`, `reset_for_tests`; sole writer of `get_tree().paused`; edge-only signals.
- [ ] **P1.11 `InputReader`** (`res://scripts/player/input_reader.gd`): builds `InputFrame` per physics tick, toggle/hold logic for run and duck, `inject(frame)` seam, resume guard (`ResumeGuardModel`, pure) honoring `resume_frame` and release-required set.
- [ ] **P1.12 `JumpModel`** (pure): apex and velocity math, coyote timer, buffer timer, air-jump counter, ceiling hit.
- [ ] **P1.13 `PlayerContext`** and **`PlayerTransitionTable`** (pure): all locomotion and airborne rows of spec 4.2; action rows stubbed behind context flags so later phases only add rows.
- [ ] **P1.14 Player states** `idle.gd`, `walk.gd`, `run.gd`, `duck.gd`, `jump.gd`, `fall.gd` (thin: call table, drive motor, play anims).
- [ ] **P1.15 `PlayerMotor`**: `CharacterBody3D` movement with air control, max fall speed, collider swap for duck, `HeadClearance` and `StepProbe` queries producing `head_clear`, `headroom_ok`, `ledge_ahead`.
- [ ] **P1.16 `LedgeModel`** (pure): auto-jump decision from probe results (step solid, above free, 3 free above step top; disabled while ducking or within 0.5 s of a manual jump).
- [ ] **P1.17 `CameraRig`**: right-stick and mouse look via actions/mouse delta only, sensitivity, invert-Y, SpringArm length standing 4.0 / ducking 2.5, `camera_reset`.

### P1 scenes and UI
- [ ] **P1.18 `res://scenes/player/player.tscn`**: node tree per spec 1.4 (VoxelViewer added but inert until Phase 2), placeholder 2.1 m humanoid with skeleton and the five outfit slots.
- [ ] **P1.19 `res://scenes/dev/locomotion_room.tscn`**: graybox with flat floor, 1-, 2- and 3-unit steps, a ledge for coyote tests, 2-unit tunnel (duck), low ceiling over a duck spot, ramps.
- [ ] **P1.20 `res://scenes/main.tscn`** minimal: World, Player, UI layer with a debug overlay showing state, device and glyph set.
- [ ] **P1.21 Glyph widget** `res://ui/prompts/glyph_icon.tscn` that swaps texture/color on `input_device_changed`.

### P1 tests
Unit (`res://test/unit/`):
- [ ] **P1.22** `input/test_input_action_map.gd`: table-driven from spec 2.2 to 2.4. Every action exists; each gameplay action has its specified joypad event and KB/M event; trigger axis thresholds 0.5; stick deadzones; `ui_*` events explicit; `jump`, `pause_menu`, `ui_accept`, `ui_cancel` have gamepad events; no physical input bound twice within one context (uses `input_contexts.tres`).
- [ ] **P1.23** `input/test_input_device_model.gd` (mouse motion > 4 px switches, joypad axis > 0.5 switches, smaller does not; `0x054C`/`0x045E`/`0x057E`/unknown mapping; override wins), `input/test_rebind_model.gd` (round-trip each event type incl. axis sign; locked actions refuse unbind; conflict detection same context vs disjoint contexts), `input/test_resume_guard.gd` (pressed flags dropped through `resume_frame`; held-at-resume requires release; axes pass; jump suppressed after menu close).
- [ ] **P1.24** `core/test_pause_safety_lint.gd`: scans `res://scripts` and `res://ui` for `create_timer(` without `false` as second argument and for `get_tree().create_tween(`; fails with file and line.
- [ ] **P1.25** `player/test_player_transition_table.gd`: Idle/Walk/Run thresholds; duck toggle and hold modes; Duck exit gated by `head_clear`; Run impossible while ducking; jump requires `headroom_ok`; Duck -> Jump stands first; coyote jump within 0.12 s and not after; buffer 0.15 s; exactly one air jump; `air_jumps_left` reset only on landing; walking off a ledge keeps the double jump; ceiling hit -> Fall with `vy = 0`; auto-jump only when `jump_auto` and `ledge_ahead` for 0.3 s; no action states entered while airborne (rows stubbed).
- [ ] **P1.26** `player/test_jump_model.gd` (apex 1.30 m and double-jump total >= 2.0 m + capsule margin for configured values; fall speed capped), `player/test_ledge_model.gd`.
- [ ] **P1.27** `settings/test_settings_model.gd` (defaults, round-trip, unknown keys ignored).

Integration (`res://test/integration/`):
- [ ] **P1.28** `test_pause_manager.gd`: ref-counted reasons; `game_paused` once on first reason, `game_resumed` once on last release; duplicate request idempotent; release of unknown reason no-op; `reset_for_tests` clears; `monitor_signals(EventBus, false)`.
- [ ] **P1.29** `test_player_locomotion.gd` (fixture `locomotion_room.tscn`, `InputReader.inject`, `await_physics_frames`): walk and run displacement; duck swaps colliders and fits the 2-unit tunnel; cannot stand under the low ceiling and stands after leaving it; jump lands on the 1-unit step, double jump on the 2-unit step, cannot reach the 3-unit step; coyote jump off the ledge; auto-jump on and off; landing from > 4 m produces no damage state and recovers within 0.2 s.
- [ ] **P1.30** `test_input_service.gd`: calling `InputService` handlers directly with constructed InputEvent objects emits `input_device_changed` with the right glyph set; rebind applied from Settings updates `InputMap`.

### P1 manual checklist
- [ ] Xbox pad and DualShock/DualSense on Windows and Linux (macOS if available): every gameplay action in spec 2.2 fires; glyphs switch on device change; hotplug does not crash.
- [ ] KB/M: same actions; mouse captured in gameplay.
- [ ] At a forced 30 fps cap, compare camera and character smoothness with physics interpolation on and off (spec 0.6 item 30); record the choice in PROGRESS.

---

## Phase 2: Mining, Foraging and Stamina Loop with Auto-Tool Context Switching

**Goal:** dig-anywhere voxel terrain with protection, drops, geodes and chests; apple foraging and timber; auto-tool switching; stamina, exhaustion and the cozy sleep-to-home loop with a care package in the mailbox.
**Depends on:** Phase 1 gate; P0.10 voxel decision.
**Spec:** 1.3, 1.6, 2.6, 2.8 (prompts), 3.1, 3.3, 3.4 (materials, trees, discovery, zones), 4.3, 4.5 (context Interact, Sleep), 6.1 to 6.4, 9.

### P2 resources
- [ ] **P2.1 Voxel materials** `res://resources/materials/mat_*.tres` (`VoxelMaterialDef`): dirt, grass, sand, clay, stone, hard stone, copper ore, iron ore, quartz ore, geode rock, chest block, bedrock; `res://resources/materials/blocky_library.tres` (`VoxelBlockyLibrary`) with matching models and collision AABBs.
- [ ] **P2.2 Items** for Phase 2: BLOCK items for placeable materials, ores, minerals, geode, apple, wood, snack (`&"snack"` tag), tools (shovel, pickaxe tiers 1 to 3, axe, fruit picker, hammer, screwdriver) with `ToolData`.
- [ ] **P2.3 Loot, discovery, treasure, trees:** `LootTableDef`s per material, `DiscoveryTableDef` (geode and chest chances and pity), `TreasureTableDef` (Phase 2 pools: coins, sticker and dye ids registered but unlock effects inert until Phase 6), `FruitTreeDef` apple, `TimberTreeDef`.
- [ ] **P2.4 Zones:** `TerrainZoneDef` for Wilderness, Orchard (OVERWORLD), Deep Mine (PER_DAY seed, no persistence), Starter Cabin (STATIC); `StaminaConfig.tres`; care-letter `MailTemplateDef`s in pools `pool_care_exhausted`, `pool_care_exhausted_repeat`, `pool_care_late_night`.

### P2 scripts
- [ ] **P2.5 `Database`** autoload: indexes all definition types by id; integrity checks for Phase 2 types (spec 3.9 rows for materials, items, loot, discovery, zones, care templates).
- [ ] **P2.6 Terrain abstraction:** `IVoxelWorld` base, `FakeVoxelWorld` (`res://test/helpers/`; dictionary + 3D DDA raycast), `VoxelWorldAdapter` (wraps `VoxelTool` per spec 9.1).
- [ ] **P2.7 Terrain logic:** `TerrainRules` (P1 to P7, pure; occupancy provider interface so Phase 3 can add pieces), `VoxelDigModel` (hits, wrong-tool multiplier, drops), `TerrainService` (`hit_voxel`, `can_dig`, `can_place`, `daily_reset`; events per spec 1.8).
- [ ] **P2.8 World generation:** `VoxelGeneratorScript` subclasses for overworld (fixed seed) and Deep Mine (seed = hash(save_seed, day); 3-voxel tunnels, 2-voxel crawlspaces, pockets) using built-in noise; bedrock floor.
- [ ] **P2.9 Protection volumes:** `ProtectionVolume` node (grid-aligned AABB, reason, `allows_place`) and editor gizmo; runtime support protection registry (trees, interactables, spawns).
- [ ] **P2.10 Inventory core:** `InventoryModel` (slots, stacking, instance-data non-merge, `add`/`remove`/`can_add`, overflow result), `InventoryService`, `Pickup` scene for overflow drops.
- [ ] **P2.11 Tools:** `ToolBeltModel` / `ToolBeltService` (grant, best tier, equip, unequip), `ToolTargetZone` (Area3D on `tool_zones`), `ToolSelectionModel` (spec 2.6 rules 1 to 11, pure, injected clock), `ToolAutoSelector` adapter with `set_aim_for_tests` and `manual_select(tool_type)` (the wheel calls this in Phase 5).
- [ ] **P2.12 Mine state** and Mine sub-FSM (Ready, Windup, Strike, Recover, Retarget) for voxels and timber; single-shot air dig from Jump/Fall.
- [ ] **P2.13 Context interaction framework:** `InteractionSpec`, `InteractionResolver` (scoring, aim override, X/Y specs), `Interact` state (Approach, Perform, OpenMenu, Resolve, Handoff) with kinds FORAGE, PICKUP, CHEST, MINE_ENTRANCE, BED (handoff to Sleep).
- [ ] **P2.14 World objects:** `WorldStateService` (fruit regrow, timber chop and respawn, chests), scenes `apple_tree.tscn`, `timber_tree.tscn`, `fallen_log.tscn`, `treasure_chest.tscn`, `mine_entrance.tscn`.
- [ ] **P2.15 Discovery:** `DiscoveryModel` (geode pity on hard voxels, chest reveal on adjacency, chest pity, unique unlock pools with coin fallback, seeded RNG streams) and `DiscoveryService`; minimal `UnlockModel` (records unlock ids; effects wired in later phases).
- [ ] **P2.16 Stamina:** `StaminaModel` (clamp, edge-triggered depletion, last action lands, thresholds once per day), `StaminaService`, HUD stamina bar with low-stamina pulses.
- [ ] **P2.17 Time and sleep:** `GameClock` autoload (D6), `DayRollover` (ordered pipeline with registration for later steps), `SleepDirector` (ALWAYS; `begin_sleep` for exhausted, bed, late_night; `go_home`), `Sleep` state, `SceneRouter` + `Fader`, starter cabin zone with bed marker and mailbox, `HousingService` minimal (home bed).
- [ ] **P2.18 Mail core:** `MailboxModel` (monotonic ids, schedule, `deliver_due` idempotent, claim all-or-nothing, never-expire kinds), `MailService`, care-letter rules (snack once per day, sender fallback `npc_neighbor` until NpcService exists). Mailbox interactable shows the unread badge; until the Phase 5 mail menu exists, X on the mailbox runs `claim_all` with a toast (temporary, tracked in P5.13).
- [ ] **P2.19 Safety:** `SafeGroundTracker` (3-free-voxel rule), `KillPlane`, `DeepWater`, stuck hint; `SaveService` stub autoload recording autosave requests (real implementation Phase 6).
- [ ] **P2.20 PromptOverlay** (`res://ui/prompts/prompt_overlay.tscn`): tool, X and Y prompts per spec 2.8 table for Phase 2 targets; behind/occlusion hiding; lock badges and reason pictograms; hides on `game_paused`; `reduce_motion` and high-contrast support from Settings.
- [ ] **P2.21 Serialization** `to_dict()/from_dict()` for Inventory, ToolBelt, Stamina, WorldState, Terrain damage, Discovery pity, Unlock, Mailbox, GameClock, exhaustion, Housing home.

### P2 scenes
- [ ] **P2.22** Zone scenes `res://scenes/zones/{wilderness,orchard,deep_mine,starter_cabin}.tscn` with VoxelTerrain (or static meshes), protection volumes, spawn markers, safety volumes; `main.tscn` gains GameSession with Phase 2 services.

### P2 tests
Unit (`res://test/unit/`):
- [ ] **P2.23** `terrain/test_fake_voxel_world.gd` (DDA hits, `prev_cell`, max distance, axis-aligned and diagonal rays), `terrain/test_terrain_rules.gd` (P1 to P7 each with pass and fail, order of evaluation, bedrock), `terrain/test_voxel_dig_model.gd` (hits per material and tool, multiplier, drops, partial damage reset).
- [ ] **P2.24** `tools/test_tool_selection_model.gd`: aim beats zone; priority then distance then stable key; debounce 0.15 s; zone hysteresis +0.5 m; voxel aim hysteresis 0.3 s; action locks per state; airborne not locked; manual override 10 s or until no candidates; missing tool; tier too low; keep last tool by default (D15) and revert after 1.0 s only with `auto_tool_revert`; disabled setting; `toolbelt/test_toolbelt_model.gd`.
- [ ] **P2.25** `stamina/test_stamina_model.gd` (clamp at 0, never negative, `depleted_now` only on the > 0 -> 0 edge, last action lands, threshold events once per day, refill to max incl. bonus).
- [ ] **P2.26** `discovery/test_discovery_model.gd` (geode pity forcing, chest reveal adjacency, chest pity, unique unlock draw, exhausted pool -> coins, determinism for a fixed seed).
- [ ] **P2.27** `sleep/test_day_rollover.gd` (step order 1 to 7 with spies; unregistered steps skipped), `mail/test_mailbox_model.gd` (Phase 2 scope: ids, schedule, deliver idempotence, claim all-or-nothing, care package never expires, snack-once-per-day rule), `inventory/test_inventory_model.gd` (stacking, instance data, overflow), `interaction/test_interaction_resolver.gd` (scoring and aim override for Phase 2 kinds), `player/test_mine_subfsm.gd`.
- [ ] **P2.28** `data/test_database_integrity.gd` (Phase 2 types) and `save/test_phase2_round_trip.gd` (every P2.21 model round-trips; integers stay `TYPE_INT` after a JSON string round-trip).

Integration (`res://test/integration/`):
- [ ] **P2.29** `test_auto_tool_selection.gd`: spec 8.3 cases **A1 to A7 and A11 to A22** (A18 via `manual_select`). Explicitly covers volume detection: entering the AppleTree and TimberTree `ToolTargetZone` volumes equips FRUIT_PICKER and AXE after the physics overlap is reported; aiming at stone vs dirt equips PICKAXE vs SHOVEL.
- [ ] **P2.30** `test_stamina_exhaustion.gd`: spec 8.4 cases **B1 to B11 and B14 to B17**. Covers depletion to zero, `Sleep(exhausted)`, ordered signals, wake at the starter-cabin bed marker with full stamina, exactly one care letter with one snack delivered on the new day, claim, repeat-day letter without snack, no loss, deferral during transition, duplicate sleep ignored, owned home bed, airborne depletion, partial damage reset, Deep Mine wake, Go Home.
- [ ] **P2.31** `test_dig_and_forage.gd`: dig drop goes to inventory; full inventory spawns a pickup; protected voxel refused with no stamina spent; hold-to-dig retargets; chest block reveal spawns a `TreasureChest` and opening grants from the pool; geode drop; apple pick via X and via RT gives the same result; regrow after rollover; timber chop and respawn; apple tree never a chop target.
- [ ] **P2.32** `test_safe_ground.gd`: KillPlane and DeepWater return to the last safe 3-free-voxel position under a transition pause; bedrock cannot be dug; Go Home places the player at the home bed without changing day or stamina.
- [ ] **P2.33** `test_voxel_smoke.gd` (`@voxel_real`) extended: generator produces bedrock and protected cells refuse edits through `TerrainService` with the real adapter.

### P2 manual checklist
- [ ] Dig, place nothing yet, forage and chop with pad and KB/M; prompts show correct glyphs and pictograms; auto-tool feels stable at zone edges.
- [ ] Exhaust in Wilderness and in Deep Mine; wake at home; mailbox badge glows; claim the snack.
- [ ] Performance: continuous digging meets the P0 budget on min-spec hardware.

---

## Phase 2B: Farming (D9)

**Goal:** till, plant, water, grow and harvest crops on owned plots and the starter garden, with sprinklers, auto-tool farm rules and the day-1 seed letter.
**Depends on:** Phase 2 gate.
**Spec:** 10, 2.6 (farm rules), 2.8 (farm prompts), 3.1 (SEED), 3.5 (`farm`), 6.1, 6.2 (rollover step 4), 9.3 P3, 8.5.1 (Suite F).

### P2B resources
- [ ] **P2B.1** `CropDef`s (carrot, sunflower, pumpkin, cotton, strawberry, tomato) with stage meshes; SEED items and PRODUCE harvest items; `FarmConfig.tres`; `mat_farmland` material and library model; HOE and WATERING_CAN tool items; `piece_sprinkler` (`BuildPieceDef` with `farm_effect = SPRINKLER`); well scene; `mail_tpl_welcome` with starter seeds.
- [ ] **P2B.2** Home Meadow zone: protected starter cabin exterior, owned `plot_starter_garden` (8x8), well; starter cabin interior stays STATIC.

### P2B scripts
- [ ] **P2B.3 `FarmModel`** (pure): farmable-cell rule (D22), till, plant, water (no-op if already watered today), growth at rollover (watered `day - 1` or sprinkler), stage mapping, harvest with seeded yield and seed return, regrow, no death (D23), can capacity and refill.
- [ ] **P2B.4 `FarmService`**: commands and events per spec 1.8; registers `daily_growth` as `DayRollover` step 4; computes growth for every zone in data.
- [ ] **P2B.5 Farm views:** `CropView` scene per crop cell, `SoilOverlay` MultiMesh for wet cells, rebuilt from data on zone load.
- [ ] **P2B.6 Tool rules:** extend `ToolSelectionModel` with the spec 10.4 table (hotbar SEED selection decides till vs dig); HOE and WATERING_CAN in the starter ToolBelt.
- [ ] **P2B.7 Interactions:** TILL, PLANT, WATER (repeat while RT held), REFILL, HARVEST kinds in the context `Interact` state; PromptOverlay farm rows; HUD watering-can level.
- [ ] **P2B.8 Protection and occupancy:** planted crops add P3 support protection and occupy their cell for blocks and pieces.
- [ ] **P2B.9 Sprinkler effect:** placing `piece_sprinkler` uses a minimal placement command now (full Build mode arrives in Phase 3, which then takes over sprinkler placement).
- [ ] **P2B.10 New-game kit:** welcome letter scheduled for day 1 with seeds; starter tools.
- [ ] **P2B.11 Serialization:** `farm` section (tilled, crops, watering can).

### P2B tests
Unit:
- [ ] **P2B.12** `farm/test_farm_model.gd`: farmable rule (owned plot, starter garden, outside, protected, not top-exposed, < 2 free cells above); till sets farmland; plant needs farmland and a SEED; growth only when watered the previous day or sprinkler-covered; same-day plant and water counts; stage boundaries per `days_per_stage`; unwatered for many days keeps stage and never dies; ripe stays ripe; harvest yield and seed return deterministic for a seed; regrow returns to `regrow_stage`; watering twice spends water once; can empty and refill.
- [ ] **P2B.13** `tools/test_tool_selection_farm.gd`: spec 10.4 table row by row, including SEED vs non-SEED selection on the same soil and the empty-can badge.
- [ ] **P2B.14** `sleep/test_day_rollover.gd` extended: farm growth is step 4, after terrain reset and before mail; `save/test_farm_round_trip.gd`; `data/test_database_integrity.gd` extended for crops and seeds.

Integration:
- [ ] **P2B.15** `test_farming.gd`: spec 8.5.1 Suite F cases **F1 to F16**.
- [ ] **P2B.16** `test_auto_tool_selection.gd`: re-run in full to confirm farm rules did not change cases A1 to A22.

### P2B manual checklist
- [ ] Plant, water and harvest with pad only; prompts make the hoe vs shovel choice obvious; a 6-year-old-readable picture guide in the welcome letter.

---

## Phase 3: Magnetic Grid Building System and Screw/Hammer Mini-Games

**Goal:** place, snap, fasten and remove build pieces and natural blocks on owned plots; furniture you can sit on, toggle and sleep in.
**Depends on:** Phase 2 gate.
**Spec:** 1.6, 2.3 (Build), 2.7, 3.4 (pieces, sockets, furniture), 4.4, 4.5 (Sit, BED, SET_HOME, TOGGLE), 5.3 (core), 7.3, 9.3 P4 to P6.

### P3 resources
- [ ] **P3.1 Build pieces** `res://resources/pieces/piece_*.tres` + scenes in `res://scenes/build_pieces/`: floor, wall, wall with door (3 units high), window wall, stairs, roof, fence (NAILS), shelf (SCREWS), chair, sofa, table, bed, lamp, radio, chest (storage, opens in Phase 4). Each with footprint, grid, fastener, fastener sockets, snap sockets, support flags, interactions.
- [ ] **P3.2 Plot for testing** `PlotDef` `plot_test` with bounds, granted by a debug command until Phase 4 purchase exists.

### P3 scripts
- [ ] **P3.3 `PlacementValidator`** (pure): footprint rotation (0/90/180/270) to world cells; plot bounds; occupancy against voxels (via `IVoxelWorld`), pieces, player and pet capsules; support (`requires_support` satisfied by solid voxel below or a FASTENED `provides_support` piece; LOOSE never supports); reasons per spec 2.7.
- [ ] **P3.4 `SnapAssistModel`** (pure): socket candidates by tag compatibility; radius by `snap_strength` (structure 0.30/0.45/0.60 m, furniture 0.20/0.30/0.35 m); nearest wins with stable tie-break; sticky until 1.5x radius; auto-rotation to align wall ends, floor edges and furniture backs; fallback to plain grid; voxel top faces as `&"ground"`.
- [ ] **P3.5 `FastenModel`** (pure): `fasten_steps = sockets * hits_per_socket`; reticle angle snap per strength (4/6/9 deg); auto-advance to the next nearest socket; press mode for nails, hold 0.8 s for screws; `fasten_mode = HOLD`; partial progress kept on release; no miss state.
- [ ] **P3.6 `BuildService`**: shared occupancy provider registered with `TerrainRules` (P4 support protection becomes live); `try_place`, `fasten_step`, `try_remove` (dependents block removal), `try_place_block` and owned-plot instant block removal; events per spec 1.8.
- [ ] **P3.7 Build state** and Build sub-FSM (Place: Preview, Fasten, Removing; Paint and Stamp present but disabled until Phase 6); D-pad tool cycle, RB/LB rotate, Y catalog, X pick, D-pad up/B exit; jump and single-shot air placement for pillar building.
- [ ] **P3.8 Ghost view** (`res://scenes/build/ghost.tscn`): translucent box and outline, palettes DEFAULT / BLUE_ORANGE / HIGH_CONTRAST, check/X/magnet icons, reason pictograms, stripes pattern; fastener reticle and socket highlight.
- [ ] **P3.9 Loose-piece tool zones**: `ToolTargetZone` on LOOSE pieces (HAMMER for NAILS, SCREWDRIVER for SCREWS), active only in Build Place.
- [ ] **P3.10 `MenuStack` core** (`res://ui/menus/menu_stack.gd`, ALWAYS): `push`, `pop`, `pop_to`, `close_all`, `top`, `is_open`; pause via `PauseManager` reason `&"menu"`; menus instanced `WHEN_PAUSED`; initial focus deferred; focus restore on pop; resume frame to `InputReader`; refuse push during `&"transition"`.
- [ ] **P3.11 `build_catalog` menu** (`res://ui/menus/build_catalog.tscn`): Pieces and Blocks tabs, icon grid, last-used focus.
- [ ] **P3.12 Furniture interactions:** `Sit` state (seat snap, collider off, stamina regen, exit validation), TOGGLE (`toggle_furniture`, state saved), BED (handoff to Sleep(bed) via `confirm` menu), SET_HOME (`HousingService.set_home_bed`); `confirm` menu (safe default No).
- [ ] **P3.13 Serialization:** BuildService pieces (cell, rot, fasten, state) `to_dict()/from_dict()`.

### P3 tests
Unit:
- [ ] **P3.14** `build/test_placement_validator.gd`: rotation matrix (each footprint at 4 rotations maps to expected cells, multi-cell pieces); out-of-plot by one cell refused; overlap with voxel, piece, player capsule, pet capsule refused with the right reason; support satisfied by voxel and by FASTENED piece, not by LOOSE; door piece leaves a 3-cell opening.
- [ ] **P3.15** `build/test_snap_assist_model.gd`: socket matrix: for each strength, points at radius -0.01 snap and +0.01 do not, for structure and furniture; incompatible tags never snap; nearest of two sockets wins; equal distance uses stable tie-break; sticky holds until 1.5x radius and releases after; auto-rotation yields the expected rotation index for walls on each floor edge and furniture against each wall face; no socket -> grid cell with manual rotation; snapped position equals socket position exactly.
- [ ] **P3.16** `build/test_fasten_model.gd` (steps count, angle snap per strength, auto-advance order, hold vs press, partial progress, HOLD mode), `build/test_build_subfsm.gd` (tool cycle, catalog return to same sub-state, exit paths, Removing 0.6 s), `build/test_block_placement.gd` (occupancy, owned-plot instant removal returns item, outside plot requires digging), `terrain/test_terrain_rules_support.gd` (P4 live once a piece exists), `save/test_build_round_trip.gd`.

Integration:
- [ ] **P3.17** `test_build_placement.gd`: fixture plot with `FakeVoxelWorld`; ghost validity changes emit expected states; place consumes the item and emits `piece_placed`; LOOSE piece does not support a piece above; dig under a fastened piece refused (`supports_building`); air pillar placement works.
- [ ] **P3.18** `test_fasten_minigame.gd`: nails via injected `use_pressed` frames, screws via held frames; reticle auto-advances; `piece_fastened` once at completion; piece then provides support; B cancels with progress kept.
- [ ] **P3.19** `test_auto_tool_selection.gd`: add spec cases **A8 to A10**.
- [ ] **P3.20** `test_menu_stack_core.gd`: push pauses once; nested push/pop keeps paused until the last pop; `close_all`; catalog returns to the same Build sub-state; focus restored; push refused during transition.
- [ ] **P3.21** `test_furniture_interaction.gd`: Sit snaps to the marker, regenerates stamina, exits on B/move/jump without a jump; toggle state flips and persists in `to_dict`; bed confirm runs Sleep(bed) with no care letter; Set Home changes the wake location.

### P3 manual checklist
- [ ] Build a 3x3 room with door, roof and furniture using pad only; snapping feels magnetic on High; red/green, blue/orange and high-contrast ghosts readable.
- [ ] Hammer and screw sockets auto-advance; no re-aiming needed.

---

## Phase 4: Economy, Job System (Builder/Tailor), Wardrobe UI and Game Pause

**Goal:** coins, shops, crafting, plot purchase, Builder and Tailor jobs, outfits, and the complete menu and pause experience including settings and accessibility.
**Depends on:** Phase 3 gate.
**Spec:** 1.5, 1.8, 3.1, 3.2, 3.4 (jobs, shops, outfits, plots), 4.2 (Craft), 4.5 (menus), 5 (all), 3.8, 5.10.

### P4 resources
- [ ] **P4.1** `EconomyConfig.tres`, `ShopDef`s (general store with seeds and the sprinkler, builder supply, tailor), cotton -> cotton cloth Tailor recipe, item `base_value`s, `RecipeDef`s (workbench, tailor bench, including pet accessory outputs used in Phase 5), `JobDef`s and `ContractDef`s (Builder blueprints, Tailor orders), `BlueprintDef`s and job-site protection volumes, `PlotDef`s with prices, `OutfitDef`s (placeholder meshes per slot), dye id list (palette content in Phase 6).

### P4 scripts
- [ ] **P4.2 `WalletModel`** (int coins, never negative) and `WalletService`.
- [ ] **P4.3 `TransactionCoordinator`**: `try_buy`, `try_sell`, `try_buy_plot`, `try_craft`; validate, then mutate, then emit; failure injection seam for tests.
- [ ] **P4.4 `EconomyService`**: pricing (buy rounded up, sell rounded down), daily restock registered in `DayRollover`.
- [ ] **P4.5 Crafting:** `CraftModel`, `Craft` state (timed in world, cancel on move/duck, nothing consumed on cancel), crafting menu with missing-input display and handoff.
- [ ] **P4.6 Jobs:** `JobModel` (ranks, XP thresholds), `JobService` (accept, submit, abandon; BUILD_BLUEPRINT completion from `piece_fastened` matching blueprint cells; DELIVER_ITEMS; CRAFT_ITEMS; pay through the coordinator; receipt and provided-materials mail via MailService; deadline extension on exhaustion).
- [ ] **P4.7 Housing:** plot purchase via `PlotSign` and `house_purchase` dialog; deed grants build zone.
- [ ] **P4.8 Outfits:** `OutfitModel` (slots, `hide_body_regions` mask, dye ids), Wardrobe interactable, `outfit_customizer` menu with SubViewport preview (WHEN_PAUSED turntable), dye picker by name + swatch.
- [ ] **P4.9 Menus:** `inventory` (Backpack, Outfit, Jobs, Map placeholder; Pet and Collection tabs stubbed), `shop`, `job_board`, `crafting`, `house_purchase`, `pause_menu` (Resume, Go Home, Save/Load disabled until Phase 6, Settings, Quit), `go_home_confirm`, `mine_entrance_confirm`, `settings` (Controls with `rebind_capture`, Assist, Accessibility, Audio, Video), storage chest container.
- [ ] **P4.10 MenuStack complete:** global keys (`pause_menu`, `ui_cancel`, `open_inventory`) via `_unhandled_input`; mouse mode handling; focus graph validator (debug); focus recovery on `gui_focus_changed(null)`; `ScrollContainer.follow_focus`; mouse hover moves focus.
- [ ] **P4.11 Auto-pause triggers:** focus-out opens `pause_menu`; joypad loss adds `&"device_lost"` and shows `DeviceBanner`; reconnect releases.
- [ ] **P4.12 Accessibility runtime:** text scale, reduce motion, palettes, prompt labels, TTS (`DisplayServer.tts_speak` for prompt verbs when enabled), hold durations.
- [ ] **P4.13 Serialization:** Wallet, Economy stock, Jobs, Housing plots, Outfit equipment, Settings additions.

### P4 tests
Unit:
- [ ] **P4.14** `economy/test_wallet_model.gd` (int only; debit refused below 0; credit/debit events), `economy/test_transaction_coordinator.gd` (each command all-or-nothing with failure injected at every step: no partial inventory or wallet change; buy needs coins and space; sell removes exactly; craft simulates removal before checking output space; plot purchase grants deed only with debit).
- [ ] **P4.15** `economy/test_currency_accretion.gd`: a scripted sequence (sell ore, job pay, chest coins from Phase 2 pool, buy) yields the exact expected wallet total; rounding rules at boundaries; no floats in currency paths.
- [ ] **P4.16** `economy/test_pricing.gd`, `crafting/test_craft_model.gd`, `jobs/test_job_model.gd` (XP thresholds, blueprint completion only when all pieces FASTENED, deadline extension), `outfit/test_outfit_model.gd`, `inventory/test_inventory_transactions.gd` (move, split, merge, container transfer, full container refusals), `save/test_phase4_round_trip.gd`.

Integration:
- [ ] **P4.17** `test_menu_pause_flow.gd`: pushing any menu emits `game_paused` exactly once and sets `get_tree().paused`; nested menus keep paused; popping the last emits `game_resumed` once; `pause_menu` handler opens/close_all; `ui_cancel` pops; HUD frozen while menus process; menu instances are `WHEN_PAUSED`; resume guard prevents the closing A press from jumping; focus restored to the previous control; push refused during transition; Go Home from pause menu works.
- [ ] **P4.18** `test_auto_pause_triggers.gd`: `NOTIFICATION_APPLICATION_FOCUS_OUT` delivered to the handler opens `pause_menu`; joypad loss via the `InputService` handler adds `&"device_lost"`, shows the banner, and reconnect releases it.
- [ ] **P4.19** `test_shop_and_craft.gd`: buy and sell through the shop menu controller methods; insufficient coins or space shows a reason and changes nothing; timed craft completes in world, cancel consumes nothing.
- [ ] **P4.20** `test_job_contracts.gd`: Builder contract: accept, provided materials arrive by mail next day, build and fasten blueprint pieces, `contract_completed`, pay credited, receipt mail, XP; Tailor order: craft and deliver; abandon returns nothing lost.
- [ ] **P4.21** `test_stamina_exhaustion.gd`: add spec case **B13** (deadline extension).
- [ ] **P4.22** `test_wardrobe.gd`: equip changes slot mesh; dye id applied; preview animates while paused; cancel leaves equipment unchanged.
- [ ] **P4.23** `test_settings_rebind.gd`: `rebind_capture` controller methods apply a new event, refuse a same-context conflict, refuse unbinding locked actions, and persist to `settings.cfg` in `user://test_tmp/`.

### P4 manual checklist
- [ ] Every menu fully navigable by pad only, including settings and rebinding; no dead-end focus.
- [ ] Unplug the pad mid-game: pause and banner; replug: continue.

---

## Phase 5: NPC Interactions, Mail System and Pet Companion System

**Goal:** NPCs you talk to and gift, the full mail system with UI, and a pet that follows, eats, wears accessories, reacts to emotes and music.
**Depends on:** Phase 4 gate.
**Spec:** 3.3, 3.4 (NPC, pet, emote, instrument), 3.6, 4.5 (Talk), 4.6, 4.7, 4.8, 7.1, 7.4, 9.4.

### P5 resources
- [ ] **P5.1** `NpcDef`s (curator, Hilde, neighbor, builder foreman, tailor), `DialogueDef` resources, gift preferences, schedules within STATIC zones; full `MailTemplateDef` set (job offers, receipts, catalog orders, pet adoption, rewards, friendship letters); `PetSpeciesDef` dog and cat (scenes with accessory bones), `PetAccessoryDef`s with per-species meshes, pet food items; `EmoteDef`s (8) and `InstrumentDef`s (flute, drum, ukulele with 8 notes).

### P5 scripts
- [ ] **P5.2 NPCs:** `NpcModel` (friendship, met, daily gift, flags), `NpcService`, `npc.tscn` with `NavigationAgent3D` on STATIC navmesh, schedule runner; care-letter sender switches to highest-friendship NPC.
- [ ] **P5.3 `Talk` state** (NPC lock, camera two-shot, dialogue push), `DialogueModel` (Greeting, Choices, Chat, JobTalk, Shop), `dialogue` menu showing the A advance glyph; `gift_picker` menu via Y.
- [ ] **P5.4 Mail complete:** all attachment types (`item`, `coins`, `unlock_*`, `contract`, `pet_adoption`), expiry to Lost and Found, inbox cap and prune, catalog orders (debit now, deliver next day).
- [ ] **P5.5 Mail UI:** `mail` menu (InboxList, Reading with illustration first, Claim, ClaimResult, Archive), unread badge, TTS read-aloud when enabled.
- [ ] **P5.6 Pet core:** `PetBrainModel` (Follow, Idle, Wander, Teleport, React, Eat, GoToBowl, Nap, Call; thresholds from `PetSpeciesDef`), `PetService` (adopt, pat, `try_feed`, happiness drift and floor 40, daily reset in `DayRollover`, daily find at >= 80), `pet.tscn` (layer pet, no player collision).
- [ ] **P5.7 Pet pathing:** `IPetPathProvider` with `VoxelPathProvider` (`VoxelAStarGrid3D` over a 32x16x32 region re-centered every 8 m), `NavmeshPathProvider` (STATIC zones), `FakePathProvider` (tests); teleport fallback; nudge when a placed piece covers the pet.
- [ ] **P5.8 Pet accessories:** `PetAccessoryModel` (slot validation, species mesh availability, swap returns the old item, full-inventory refusal), mounting meshes under species `BoneAttachment3D`s, dye via instance shader parameter, `pet_wardrobe` menu with preview.
- [ ] **P5.9 Adoption flow:** letter with `pet_adoption` scheduled at new-game creation for day 2 (D11), species/variant/name picker menu, `pet_call` (D-pad right).
- [ ] **P5.10 Pet furniture:** PET_BED (Nap target) and FEED_BOWL (1-slot storage, self-feed during rollover) pieces.
- [ ] **P5.11 Expression:** `wheel` menu (angle-to-slot, pages Emotes, Instruments, Tools calling `ToolAutoSelector.manual_select`), `Emote` state with pet and NPC reactions (first wave per NPC per day +1 friendship), `PlayInstrument` state with `note_1..8`.
- [ ] **P5.12 Serialization:** Npc state, Pet state, full Mailbox, unlocked emotes and instruments.
- [ ] **P5.13 Remove the Phase 2 temporary mailbox `claim_all`** in favor of the mail menu.

### P5 tests
Unit:
- [ ] **P5.14** `pet/test_pet_brain_model.gd`: every transition of spec 4.6 at its threshold boundary (idle after 2 s within follow distance, wander after 6 s, follow on player move or > 6 m, teleport at > 20 m or 2 s without path or zone change, react on emote/pat, eat on feed, go-to-bowl when food and not fed, nap near pet bed while player sits or sleeps, call -> teleport if no path in 1 s or > 10 m).
- [ ] **P5.15** `pet/test_pet_feeding.gd`: only PET_FOOD or favorite-tagged FOOD accepted; favorite doubles; first feed of day sets `fed_day`, later feeds half effect; clamp 100; daily drift toward 60; never below 40; nothing removed on refusal.
- [ ] **P5.16** `pet/test_pet_accessory_model.gd`: valid slot per item; species without a mesh refused; swap returns previous item; full inventory refusal leaves both unchanged; dye data preserved.
- [ ] **P5.17** `mail/test_mailbox_model_full.gd` (all attachment types, all-or-nothing with mixed attachments, expiry to Lost and Found, never-expire kinds, prune only archived and claimed, monotonic ids across save round-trip), `npc/test_npc_model.gd` (friendship, gift once per day, preferences), `npc/test_dialogue_model.gd`, `interaction/test_interaction_resolver_npc_pet.gd` (X/Y specs for NPC, curator, pet incl. Feed vs Dress Up rule), `ui/test_wheel_model.gd` (angle to slot, dead zone, release on neutral cancels), `save/test_phase5_round_trip.gd`.

Integration:
- [ ] **P5.18** `test_pet_follow.gd` (with `FakePathProvider`): Follow keeps follow distance; Idle and Wander timings; teleport when > 20 m and on zone change; never blocks the player (move through each other); nudged off a newly placed piece; `pet_call`.
- [ ] **P5.19** `test_pet_care.gd`: X pats (once-per-day bonus), Y feeds when food is owned and not fed today, otherwise opens Dress Up; feeding emits `pet_fed` and changes happiness; bowl self-feed at rollover; equipping an accessory creates the mesh under the correct `BoneAttachment3D` for dog and for cat, removes on unequip, and survives `to_dict/from_dict`.
- [ ] **P5.20** `test_mail_arrival.gd`: scheduled mail appears only after `deliver_due` for its day, in id order; `mail_delivered` emitted once with all ids; catalog order arrives next day; job offer contract attachment works with JobService; adoption letter is not in the inbox on day 1, arrives on day 2, and creates the pet; claim with full inventory changes nothing.
- [ ] **P5.21** `test_npc_talk.gd`: Talk locks the NPC, pushes dialogue (paused), close returns to Idle and resumes the NPC; Y gift once per day changes friendship by preference.
- [ ] **P5.22** `test_emote_instrument.gd`: wheel selection enters Emote, pet reacts within 8 m, NPC reacts within 6 m; instrument mode plays notes for each note action and exits on move.

### P5 manual checklist
- [ ] Pet follows through tunnels, across dug terrain and into town; never gets lost.
- [ ] Read a letter with TTS on; claim a package; adopt, name and dress the pet with pad only.

---

## Phase 6: Museum Collection Book, Dye Painting and Save/Load System

**Goal:** the museum and collection book, painting and stamping, and complete, crash-safe saving of everything, including voxel terrain.
**Depends on:** Phase 5 gate.
**Spec:** 3.5, 3.7, 3.9, 6.5, 7.2, 9.6, 8.5.

### P6 resources
- [ ] **P6.1** `CollectionEntryDef` on all minerals, fabrics and produce (farmed crops and foraged produce); `MuseumDef` (cases, trophies, rewards); `DyeDef` palette with names and patterns; `StickerDef`s; `PaintRegionDef`s on paintable pieces and a piece shader with `instance uniform` per region; `GeodeDef`s; reward mail templates.

### P6 scripts
- [ ] **P6.2 Collection:** `CollectionModel`/`CollectionService` (discover on `item_added`, once per id).
- [ ] **P6.3 Museum:** `MuseumModel`/`MuseumService` (`try_donate` guard order, batch dedupe, instance data ignored, plain-stack preference, case and trophy evaluation, `rewards_granted`, load reconcile), museum STATIC zone with cases, slot markers and pedestals, curator Y Donate, `donation` menu (List, Confirm, Result; Geodes tab with undiscovered bias), `collection_book` menu (silhouette, icon, ribbon, hints), inventory Collection tab.
- [ ] **P6.4 Unlock effects:** dyes into the palette, stickers into the sheet and book, blueprints into recipes; chest reveal card shows unlock pictograms.
- [ ] **P6.5 Painting:** `PaintModel` (owned plot only, region cycling, dye must be unlocked), Build Paint tool, eyedropper, `set_instance_shader_parameter` application, dye palette menu; outfit and pet dyes read the same `DyeDef`s.
- [ ] **P6.6 Stamps:** `StampModel` (cap 8 per piece, local-space transform, 45-degree rotation, S/M/L sizes, nearest removal), `Decal` placement, sticker sheet menu.
- [ ] **P6.7 Decor undo:** ring buffer of 20 operations, cleared on zone change.
- [ ] **P6.8 SaveService (real):** JSON codec (int casting and validation, vectors as arrays, unknown-id drop, content sanitization, structural failure), atomic write (`.tmp`, `.bak`, rename), slot management (3 manual + autosave), migrations framework (`migrate_N_to_N1` registry), `save_load` menu, enable Save/Load in `pause_menu`, autosave after sleep (replaces the Phase 2 stub).
- [ ] **P6.9 Voxel persistence:** working-copy SQLite per slot, `save_modified_blocks()` tracker wait with timeout, epoch files, JSON-before-DB ordering, mismatch fallback to the `.bak` pair, per the P0.10 decision (copy vs fresh `database_path`).
- [ ] **P6.10 `GameSession` snapshot:** one `to_dict()/from_dict()` entry point aggregating every service in a fixed order; `GameSession.new_for_tests(seed)` complete.

### P6 tests
Unit:
- [ ] **P6.11** `museum/test_museum_model.gd`: guard order (not_collectible, already_donated before any inventory change, not_in_inventory); exactly one removed; plain stack preferred; dyed and undyed count as one entry; batch dedupe and per-id results; case unlock once; trophy unlock once; reward granted once via `rewards_granted`; reconcile unlocks newly satisfied trophies once and never re-rewards.
- [ ] **P6.12** `museum/test_collection_model.gd`, `decor/test_paint_model.gd`, `decor/test_stamp_model.gd` (cap 8, transforms, removal), `decor/test_decor_undo.gd`.
- [ ] **P6.13** `save/test_save_codec.gd` (every integer field returns `TYPE_INT`; non-integral rejected; vectors; unknown ids dropped with notice flag; duplicates removed; donated ids added to discovered; structural type error fails the load), `save/test_save_migrations.gd` (ordered application, idempotence, fixture v1 -> current), `save/test_save_atomic_write.gd` (crash simulation between steps leaves a loadable primary or `.bak`), `save/test_voxel_epoch.gd` (fake stream: ordering JSON then DB; mismatch picks the consistent pair; aborted tracker writes nothing).

Integration:
- [ ] **P6.14** `test_museum_collection.gd`: spec 8.5 cases **C1 to C17**, including duplicate donation guards (C2 to C5) and serialization (C10 to C14).
- [ ] **P6.15** `test_save_load_roundtrip.gd`: build a session touching every system (player transform, stamina and bonus, home, outfit with dye, toolbelt, inventory incl. instance data and containers, wallet, unlocks, plots, build pieces with fasten, toggle state, paint and stamps, world trees, timber, chests, terrain damage, discovery pity, museum, collection, pet with accessories, jobs, mail inbox and scheduled, NPCs, shops, clock, exhaustion, RNG counters); save to `user://test_tmp/`; load into a fresh session; deep-equal every section; second save byte-identical to the first (determinism).
- [ ] **P6.16** `test_save_failures.gd`: corrupt primary -> `.bak` loads with a notice; save refused during transition except the SleepDirector autosave; spec 8.4 case **B12** (autosave content after exhaustion wake).
- [ ] **P6.17** `test_paint_stamp.gd`: painting sets the instance shader parameter on the piece; stamp creates a `Decal` child; ninth stamp refused; undo restores; all survive save and load.
- [ ] **P6.18** `test_voxel_smoke.gd` (`@voxel_real`) extended: dig and place in a real terrain, full slot save via SaveService, reload, voxels and inventory consistent.

### P6 manual checklist
- [ ] Donate across categories, unlock a case and a trophy, read the collection book with pad only.
- [ ] Paint and stamp a house; save, quit, reload; kill the process during a save and confirm the game loads a consistent state.

### Release-candidate checklist (end of Phase 6)
- [ ] Exports for Windows x86_64, Linux x86_64, macOS (universal) launch, save and load.
- [ ] Full manual pass of all phase checklists on each OS available.
- [ ] Spec open decisions all resolved or explicitly deferred to spec 2.

---

## Traceability

| Spec section | Phase |
|---|---|
| 0.6 items 1 to 3, 18 to 22 (verification risks) | 0 |
| 1.2 autoloads | 1 (EventBus, Settings, InputService, PauseManager), 2 (Database, GameClock, SceneRouter, SaveService stub), 6 (SaveService) |
| 1.3, 1.4, 1.7 scene tree, player, layers | 0, 1, 2 |
| 1.6, 2.7 build grid and snap | 3 |
| 2.1 to 2.5 input | 1 (map, device, rebind model), 4 (rebinding UI) |
| 2.6 auto-tool | 2 (A1 to A7, A11 to A22), 3 (A8 to A10) |
| 2.8 prompts | 2 (core), 3 to 6 (new targets) |
| 3.1 to 3.4 definitions | per domain phase |
| 3.5, 9.6 save | per-phase round-trips, 6 (SaveService, voxel DB) |
| 4.2, 4.2.1 locomotion and airborne | 1 |
| 4.3 Mine | 2 |
| 4.4 Build | 3 (Place), 6 (Paint, Stamp) |
| 4.5 interaction model | 2 (framework, forage, chest, sleep), 3 (sit, toggle, bed), 4 (menus, craft), 5 (talk, gift, pet) |
| 4.6 pet FSM, 7.1 | 5 |
| 5 UI and pause | 1 (PauseManager, resume guard), 3 (MenuStack core), 4 (complete) |
| 6.1 to 6.3 stamina, sleep, safety | 2 |
| 6.4 discovery | 2 (drops, chests), 6 (unlock effects, geode opening UI) |
| 6.5 museum | 6 |
| 7.2 painting and stamping | 6 |
| 7.3 furniture | 3, 5 (pet bed, bowl) |
| 7.4 wheel | 5 |
| 8.3 Suite A | 2, 3 |
| 8.4 Suite B | 2, 4 (B13), 6 (B12) |
| 8.5 Suite C | 6 |
| 9 voxel terrain | 0 (spike), 2 (gameplay), 5 (pet pathing), 6 (persistence) |
| 10 farming, 8.5.1 Suite F | 2B (system), 4 (seeds in shops, cotton recipe), 6 (crop donations) |
| 0.7 min-spec hardware | 0 (spike), performance checks at the 2, 2B, 3, 5, 6 gates |
