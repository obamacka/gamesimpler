# Progress

| Field | Value |
|---|---|
| Spec | `_docs/specs/spec1.md` rev 3.4 |
| Plan | `_docs/plans/plan1.md` |
| Active phase | Phase 1 (automated tasks done; manual checklist pending) and Phase 0 (hardware checks pending) |
| Last updated | 2026-11-16 |

## How to update
1. After finishing a task, tick it in `plan1.md` and in the phase table below, with the date and commit SHA.
2. A task may be ticked only after the headless test run exits 0 (CLAUDE.md). Log every gating run in the Test run log.
3. A phase is complete only when its gate (`plan1.md` 0.3) passes; set its status to `Done` with the gate commit.
4. Record blockers and deviations as they happen, not at phase end.

Status values: `Not started`, `In progress`, `Blocked`, `Done`.

## Environment
| Item | Status |
|---|---|
| Godot 4.7.x binary | 4.7.2.stable.official.ed1daf0bf (Linux, release SHA512 verified); used in the cloud session and CI |
| gdUnit4 v6.2.3 | Installed in `addons/gdUnit4` (tag v6.2.3, commit f2e4f86) |
| Voxel Tools 1.7 GDExtension | Fetched by `ci/fetch_voxel.sh` (tag v1.7x, SHA256 pinned); binaries gitignored |
| Headless test command | CLAUDE.md (owner, 2026-11-16): `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`. Updated 2026-11-16 to include `--remote-debug tcp://127.0.0.1:0` (verified in P0.3) |
| CI | GitHub Actions `tests` workflow; runs 1 (0abde5d) and 2 (24a5cfd, with voxel suite) passed |
| Min-spec hardware (Windows/Linux) | Intel Core i7-3770, 16 GB DDR3-1333, Nvidia GTX 1070 (spec 0.7) |
| Min-spec hardware (macOS) | Base Apple M1, 16 GB RAM (D24) |
| Performance target | 30 fps at 1920x1080 medium on min spec; 60 fps on recommended spec (D25) |
| Recommended spec (D26) | Windows/Linux: Ryzen 5 3600, 16 GB, RTX 2070. macOS: M2, 16 GB |

## Phase overview
| Phase | Title | Status | Gate commit |
|---|---|---|---|
| 0 | Bootstrap, Test Harness and Voxel Spike | In progress | |
| 1 | Core Engine, Gamepad Input, Camera, Tall Character FSM | In progress: all automated tasks done, manual checklist pending | |
| 2 | Mining, Foraging, Stamina Loop, Auto-Tool | Not started | |
| 2B | Farming | Not started | |
| 3 | Magnetic Grid Building, Screw/Hammer Mini-Games | Not started | |
| 4 | Economy, Jobs, Wardrobe UI, Game Pause | Not started | |
| 5 | NPCs, Mail, Pet Companion | Not started | |
| 6 | Museum, Collection Book, Dye Painting, Save/Load | Not started | |

## Task tracker

### Phase 0
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P0.1 Project skeleton | Done | 2026-11-16 | df1a866 | Jolt, Forward+, layers, gdUnit4 plugin enabled |
| P0.2 Install gdUnit4 v6.2.3 | Done | 2026-11-16 | df1a866 | addon's own tests excluded |
| P0.3 Prove headless command | Done | 2026-11-16 | df1a866 | exit codes: pass 0, fail 100, no flag 103, parse error 105 with `--remote-debug`; CLAUDE.md command hangs at `debug>` on parse errors |
| P0.4 Update CLAUDE.md test command | Done (owner) | 2026-11-16 | 3682356 | follow-up done 2026-11-16: `--remote-debug` flag added to CLAUDE.md |
| P0.5 Test helpers | Done | 2026-11-16 | df1a866 | SignalRecorder, PhysicsWait, TestSession |
| P0.6 CI | Done | 2026-11-16 | 0abde5d | run 1 green; voxel fetch added in 24a5cfd |
| P0.7 Min-spec hardware | Done (owner) | 2026-11-16 | | Windows/Linux and macOS (M1 16 GB) defined |
| P0.8 Voxel spike (a to k) | In progress | 2026-11-16 | 24a5cfd | a, c, e, f, g, h, i pass headless; b, d (frame budget), j, k need the four target machines |
| P0.9 Export smoke | Blocked | | | needs export templates and the target machines |
| P0.10 Go / no-go record | In progress | 2026-11-16 | 24a5cfd | provisional GO for GDExtension; final after hardware rows |

### Phase 1
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P1.1 to P1.4 Resources and project settings | Done | 2026-11-16 | 62d93a5 | input map generated from InputBindings (61 actions); config and glyph set resources |
| P1.5 to P1.17 Scripts | Done | 2026-11-16 | 62d93a5 | autoloads, input models, player FSM, controller, camera |
| P1.18 to P1.21 Scenes and UI | Done | 2026-11-16 | 62d93a5 | VoxelViewer deferred to Phase 2 |
| P1.22 to P1.27 Unit suites | Done | 2026-11-16 | 62d93a5 | input map, device, rebind, resume guard, lint, transition table, jump, ledge, settings, state machine |
| P1.28 to P1.30 Integration suites | Done | 2026-11-16 | 62d93a5 | pause manager, player locomotion (13 cases), input service, glyph icon |
| Manual checklist | Not started | | | needs Xbox pad, DualShock/DualSense, KB/M on Windows/Linux (macOS optional); includes physics interpolation check at 30 fps |

### Phase 2
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P2.1 to P2.4 Resources | Not started | | | |
| P2.5 to P2.21 Scripts | Not started | | | P2.18 adds a temporary mailbox `claim_all`, removed in P5.13 |
| P2.22 Scenes | Not started | | | |
| P2.23 to P2.28 Unit suites | Not started | | | |
| P2.29 to P2.33 Integration suites | Not started | | | Suite A: A1 to A7, A11 to A22. Suite B: B1 to B11, B14 to B17 |
| Manual checklist | Not started | | | |

### Phase 2B
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P2B.1 to P2B.2 Resources and zone | Not started | | | |
| P2B.3 to P2B.11 Scripts | Not started | | | |
| P2B.12 to P2B.14 Unit suites | Not started | | | |
| P2B.15 to P2B.16 Integration suites | Not started | | | Suite F: F1 to F16 |
| Manual checklist and performance check | Not started | | | |

### Phase 3
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P3.1 to P3.2 Resources | Not started | | | |
| P3.3 to P3.13 Scripts | Not started | | | |
| P3.14 to P3.16 Unit suites | Not started | | | |
| P3.17 to P3.21 Integration suites | Not started | | | Suite A: A8 to A10 |
| Manual checklist | Not started | | | |

### Phase 4
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P4.1 Resources | Not started | | | |
| P4.2 to P4.13 Scripts | Not started | | | |
| P4.14 to P4.16 Unit suites | Not started | | | |
| P4.17 to P4.23 Integration suites | Not started | | | Suite B: B13 |
| Manual checklist | Not started | | | |

### Phase 5
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P5.1 Resources | Not started | | | |
| P5.2 to P5.13 Scripts | Not started | | | |
| P5.14 to P5.17 Unit suites | Not started | | | |
| P5.18 to P5.22 Integration suites | Not started | | | |
| Manual checklist | Not started | | | |

### Phase 6
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P6.1 Resources | Not started | | | |
| P6.2 to P6.10 Scripts | Not started | | | |
| P6.11 to P6.13 Unit suites | Not started | | | |
| P6.14 to P6.18 Integration suites | Not started | | | Suite B: B12. Suite C: C1 to C17 |
| Manual checklist and release candidate | Not started | | | |

## Test run log
| Date | Commit | Phase | Command | Exit code | Failures | Notes |
|---|---|---|---|---|---|---|
| 2026-11-16 | df1a866 | 0 | CLAUDE.md command | 0 | 0 | P0.3 passing run, 4 cases |
| 2026-11-16 | df1a866 | 0 | CLAUDE.md command + temp failing suite | 100 | 1 | P0.3 fail path (temp suite removed) |
| 2026-11-16 | df1a866 | 0 | CLAUDE.md command + temp parse-error suite | 124 (timeout) | n/a | hangs at `debug>` |
| 2026-11-16 | df1a866 | 0 | `--remote-debug tcp://127.0.0.1:0` variant + parse error | 105 | n/a | exits cleanly |
| 2026-11-16 | df1a866 | 0 | `ci/run_tests.sh` | 0 | 0 | 11 cases |
| 2026-11-16 | 0abde5d | 0 | CI run 1 | 0 | 0 | GitHub Actions |
| 2026-11-16 | 24a5cfd | 0 | CI run 2 | 0 | 0 | GitHub Actions, 17 cases incl. voxel smoke |
| 2026-11-16 | 1756fff | 0 | updated CLAUDE.md command | 0 | 0 | 17 cases |
| 2026-11-16 | cf7ecc6 | 0 | `ci/run_tests.sh` | 0 | 0 | 17 cases; plus `ci/run_benchmark.sh --headless-smoke` OK |
| 2026-11-16 | 62d93a5 | 1 | `ci/run_tests.sh` | 0 | 0 | 117 cases (Phase 0 + Phase 1) |
| 2026-11-16 | 24a5cfd | 0 | `ci/run_tests.sh` | 0 | 0 | 17 cases incl. voxel smoke |

## Decisions
| ID | Status | Value |
|---|---|---|
| D1 to D4 | Resolved (spec rev 3) | blocky 1 m voxels, protected zones, Voxel Tools GDExtension; jump + double jump, A jump, X/Y interact; criteria-based dedicated states; timed Craft in world |
| D16 to D19 | Resolved (spec rev 3.1, 2026-11-15) | overworld digs permanent and Deep Mine regenerates daily; dug blocks placeable; auto-jump on by default; Go Home in pause menu |
| D5 to D15 | Resolved (spec rev 3.2, 2026-11-16) | upfront coins; 20-minute days; 3 slots + autosave on sleep; apple trees not choppable; **farming system added**; free starter cabin; **pet on day 2**; dyes are unlocks; Forward+; TTS default off; **keep last tool** |
| D20 to D25 | Resolved (spec rev 3.3, 2026-11-16) | no seasons; no weather; farm on owned plots and starter garden; crops never die; macOS min spec base M1 16 GB; 30 fps at 1080p medium on min spec, 60 fps on recommended spec |
| D26 | Resolved (spec rev 3.4, 2026-11-16) | recommended spec: Ryzen 5 3600 / 16 GB / RTX 2070 (Windows/Linux), M2 / 16 GB (macOS) |

## Blockers and open issues
| Date | Item | Owner | Status |
|---|---|---|---|
| 2026-11-16 | Phase 1 manual gamepad checklist (plan Phase 1) | team | Open |
| 2026-11-16 | Phase 1 implementation choices recorded in spec: input map generated from InputBindings; `ui_tertiary` KB moved from Shift+Enter to R; Esc overlap rule; ledge probes are direct physics queries; VoxelViewer added in Phase 2 | owner review | Open |
| 2026-11-15 | CLAUDE.md headless command does not match gdUnit4 v6.2.3 (spec 0.6 item 1) | owner | Closed 2026-11-16 (3682356) |
| 2026-11-16 | Confirmed: the CLAUDE.md command hangs at `debug>` on GDScript parse errors; `--remote-debug tcp://127.0.0.1:0` fixes it (exit 105). `ci/run_tests.sh` uses the fix | owner | Closed 2026-11-16: CLAUDE.md updated (owner approved) |
| 2026-11-15 | Voxel GDExtension maturity, collision latency, headless behavior, SQLite copy safety unverified (spec 0.6 items 18, 19, 21, 22) | P0.8 | Partly closed 2026-11-16: headless, SQLite copy and container latency verified; hardware frame budget pending |
| 2026-11-16 | Voxel binaries (65 MB desktop) kept out of git via fetch script; Git LFS is the alternative | owner | Closed 2026-11-16: keep the fetch script |
| 2026-11-16 | Hardware runs of `spikes/voxel/voxel_benchmark.tscn` on the four target machines (P0.8 b, d, j, k; P0.9). One-command scripts: `ci/run_benchmark.sh` (Linux/macOS), `ci/run_benchmark.ps1` (Windows, untested) | team | Open |
| 2026-11-15 | Min-spec hardware undefined | owner, P0.7 | Closed 2026-11-16 (Windows/Linux and macOS) |
| 2026-11-16 | Recommended spec for the 60 fps target undefined (D26) | owner | Closed 2026-11-16 |
| 2026-11-16 | i7-3770 has no AVX2; Voxel Tools GDExtension instruction-set requirement unverified | P0.8 j | Open |
