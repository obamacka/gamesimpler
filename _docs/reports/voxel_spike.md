# Voxel Spike Report (plan P0.8, P0.9, P0.10)

| Field | Value |
|---|---|
| Status | Partial: headless checks done (2026-11-16); hardware checks pending on the four target machines |
| Godot | 4.7.2.stable.official.ed1daf0bf (`Godot_v4.7.2-stable_linux.x86_64.zip`, SHA512 matches the release `SHA512-SUMS.txt`) |
| Voxel Tools | GDExtension 1.7, release tag `v1.7x`, `GodotVoxelExtension.zip` SHA256 `600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8` |
| `voxel.gdextension` | `compatibility_minimum = "4.4.1"`; ships Windows x86_64, Linux x86_64/arm64, macOS universal, iOS, Android |
| Test machine (headless) | Cloud container, Intel Xeon @ 2.30 GHz, 4 vCPU, headless display server (no GPU rendering) |
| Suites | `res://test/integration/test_voxel_smoke.gd` (6 cases); benchmark `res://spikes/voxel/voxel_benchmark.tscn` |

## Results so far

| Check | Result | Evidence |
|---|---|---|
| a. Extension loads in editor import and headless runs | **Pass** | `--import` clean; `test_extension_classes_are_registered` |
| b. VoxelTerrain + VoxelMesherBlocky + VoxelBlockyLibrary render | **Pending (needs a GPU machine)**. Meshing itself works headless (`is_area_meshed` true) | `test_character_on_voxel_collision_and_dig_latency`; data block size not yet read back (default `mesh_block_size` 16 per docs) |
| c. Dig, place, raycast through `get_voxel_tool()` | **Pass** | `test_dig_place_and_raycast` (`set_voxel`, `get_voxel`, `raycast` with `position`/`previous_position`) |
| d. Edit-to-collision latency and frame budget | **Partial pass on container**: 2 physics frames, 27 ms (suite) and max 34.5 ms over 3 samples (benchmark). Budget is 100 ms. Frame budget on min spec **pending** | suite and benchmark output |
| e. `VoxelStreamSQLite` save via `save_modified_blocks()` tracker, reload | **Pass**: tracker completed in about 7 ms for a small edit set | `test_sqlite_save_reload_and_copy_while_attached` |
| f. Copy the SQLite file while the stream is attached, reload the copy | **Pass**: no `-journal`/`-wal`/`-shm` side files were present after the tracker completed; the copy reloaded with all edits | same test. This resolves spec 0.6 item 22 for the default configuration; keep the test as a regression guard |
| g. `VoxelAStarGrid3D` path for a 1x2 agent | **Pass**: path of 10 steps routed through a 1-voxel gap in a 3-high wall | `test_astar_path_on_blocky_terrain` (synchronous `find_path`; `find_path_async` still to exercise in Phase 5) |
| h. Jolt `CharacterBody3D` works headless, including on voxel collision | **Pass**: lands on a static box and on voxel terrain at the expected height | `test_jolt_character_lands_on_static_floor_headless`, `test_character_on_voxel_collision_and_dig_latency` |
| i. `@voxel_real` suite passes headless | **Pass** (6/6) | CI command, exit 0 |
| j. No illegal-instruction crash on the i7-3770 (no AVX2) | **Pending (min-spec machine)** | |
| k. 30 fps on min spec, 60 fps on recommended spec at 1080p medium, view distance 96 | **Pending (four machines)**. Container CPU-only reference: 145 fps average, p99 7.4 ms, max 19.3 ms, 0 frames over 33.3 ms | benchmark, 10 s headless |
| P0.9 export smoke on Windows, Linux, macOS (M1) | **Pending** | export templates and machines needed |

## Notable findings
1. Voxel meshing, collision generation and SQLite streaming all work under the headless display server. Standard integration suites can use real terrain where useful, not only `FakeVoxelWorld`; the fake stays for speed and determinism.
2. The CLAUDE.md test command hangs at `debug>` on a GDScript parse error (exit code 124 from a 90 s timeout). Adding `--remote-debug tcp://127.0.0.1:0` makes it exit 105. `ci/run_tests.sh` uses the safe variant; CLAUDE.md was updated on 2026-11-16.
3. The GDExtension binaries are 134 MB for all platforms, 65 MB for the desktop set. They are not committed; `ci/fetch_voxel.sh` downloads and verifies them (SHA256 pinned). Owner decision 2026-11-16: keep the fetch script (no Git LFS).

## How to run the hardware checks (b, d, j, k, P0.9)
On each machine, from the repository root, with the window able to show 1920x1080:

| Machine | Command |
|---|---|
| i7-3770 / GTX 1070 (Windows) | `powershell -ExecutionPolicy Bypass -File ci\run_benchmark.ps1 -Tier min -Machine "i7-3770 / GTX 1070"` |
| i7-3770 / GTX 1070 (Linux) | `ci/run_benchmark.sh --tier min --machine "i7-3770 / GTX 1070"` |
| Ryzen 5 3600 / RTX 2070 | same script, `--tier rec` / `-Tier rec`, `--machine "Ryzen 5 3600 / RTX 2070"` |
| M1 16 GB | `ci/run_benchmark.sh --tier min --machine "M1 16 GB"` |
| M2 16 GB | `ci/run_benchmark.sh --tier rec --machine "M2 16 GB"` |

The scripts download and verify Godot 4.7.2 (SHA512) and Voxel Tools 1.7 (SHA256) into `.bench/` and `addons/zylann.voxel/bin/`, import the project, run the 60 s benchmark, and print a ready-to-paste row for the table below. The full JSON is also saved to `user://voxel_benchmark_<time>.json`.

Pass criteria (computed by the benchmark): `--tier min`: average fps >= 30, at most 1% of frames over 33.3 ms, edit-to-collision <= 100 ms. `--tier rec`: average fps >= 60, at most 1% of frames over 16.7 ms, edit-to-collision <= 100 ms. On macOS the rendering driver must be `metal`.

Script status: `ci/run_benchmark.sh` was run end to end in the cloud container with `--headless-smoke` (Linux path). The macOS path and `ci/run_benchmark.ps1` have not been executed (no Mac or PowerShell available in the cloud session); report any error output.

| Machine (CPU, GPU) | avg fps | p99 ms | max ms | frames > 33.3 ms | edit-to-collision max ms | driver | Result |
|---|---|---|---|---|---|---|---|
| (paste rows here) | | | | | | | |

Note: the benchmark uses a medium-quality default environment (procedural sky, one shadowed sun). A formal "medium preset" does not exist yet; it is defined in Phase 4 settings, and the benchmark should be re-run then.

## Go / no-go (P0.10)
**Provisional GO for the GDExtension edition**, based on every headless check passing. Final decision after the hardware rows above are filled. Fallbacks remain as documented in spec 9.5 (`VoxelBoxMover`) and 0.6 item 18 (module edition).
