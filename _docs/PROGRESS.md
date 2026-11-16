# Progress

| Field | Value |
|---|---|
| Spec | `_docs/specs/spec1.md` rev 3.2 |
| Plan | `_docs/plans/plan1.md` |
| Active phase | Phase 0 (not started) |
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
| Godot 4.7.x binary | Not installed in the cloud session container; local and CI installs pending (P0.1, P0.6) |
| gdUnit4 v6.2.3 | Not installed (P0.2) |
| Voxel Tools 1.7 GDExtension | Not installed (P0.8) |
| Headless test command | CLAUDE.md (owner, 2026-11-16): `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`. Not yet run; P0.3 also tests the `--remote-debug tcp://127.0.0.1:0` variant (parse-error hang risk, spec 0.6 item 1) |
| CI | Not configured (P0.6) |
| Min-spec hardware (Windows/Linux) | Intel Core i7-3770, 16 GB DDR3-1333, Nvidia GTX 1070 (spec 0.7) |
| Min-spec hardware (macOS) | Open (D24) |
| Performance target | 60 fps at 1920x1080 medium on min spec (D25, proposed) |

## Phase overview
| Phase | Title | Status | Gate commit |
|---|---|---|---|
| 0 | Bootstrap, Test Harness and Voxel Spike | Not started | |
| 1 | Core Engine, Gamepad Input, Camera, Tall Character FSM | Not started | |
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
| P0.1 Project skeleton | Not started | | | |
| P0.2 Install gdUnit4 v6.2.3 | Not started | | | |
| P0.3 Prove headless command | Not started | | | |
| P0.4 Update CLAUDE.md test command | Done (owner) | 2026-11-16 | 3682356 | follow-up: `--remote-debug` flag if P0.3 shows a hang |
| P0.5 Test helpers | Not started | | | |
| P0.6 CI | Not started | | | |
| P0.7 Min-spec hardware | Done (owner) | 2026-11-16 | | Windows/Linux defined; macOS open (D24) |
| P0.8 Voxel spike (a to k) | Not started | | | run on the min-spec machine; report: `_docs/reports/voxel_spike.md` |
| P0.9 Export smoke | Not started | | | |
| P0.10 Go / no-go record | Not started | | | |

### Phase 1
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P1.1 to P1.4 Resources and project settings | Not started | | | |
| P1.5 to P1.17 Scripts | Not started | | | |
| P1.18 to P1.21 Scenes and UI | Not started | | | |
| P1.22 to P1.27 Unit suites | Not started | | | |
| P1.28 to P1.30 Integration suites | Not started | | | |
| Manual checklist | Not started | | | |

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
| | | | | | | no runs yet |

## Decisions
| ID | Status | Value |
|---|---|---|
| D1 to D4 | Resolved (spec rev 3) | blocky 1 m voxels, protected zones, Voxel Tools GDExtension; jump + double jump, A jump, X/Y interact; criteria-based dedicated states; timed Craft in world |
| D16 to D19 | Resolved (spec rev 3.1, 2026-11-15) | overworld digs permanent and Deep Mine regenerates daily; dug blocks placeable; auto-jump on by default; Go Home in pause menu |
| D5 to D15 | Resolved (spec rev 3.2, 2026-11-16) | upfront coins; 20-minute days; 3 slots + autosave on sleep; apple trees not choppable; **farming system added**; free starter cabin; **pet on day 2**; dyes are unlocks; Forward+; TTS default off; **keep last tool** |
| D20 to D25 | Open, spec defaults assumed | seasons, weather, farmable area, crop death, macOS min spec, performance target; see `plan1.md` 0.5 |

## Blockers and open issues
| Date | Item | Owner | Status |
|---|---|---|---|
| 2026-11-15 | CLAUDE.md headless command does not match gdUnit4 v6.2.3 (spec 0.6 item 1) | owner | Closed 2026-11-16 (3682356) |
| 2026-11-16 | `-d` without `--remote-debug tcp://127.0.0.1:0` may hang on GDScript parse errors | P0.3 | Open |
| 2026-11-15 | Voxel GDExtension maturity, collision latency, headless behavior, SQLite copy safety unverified (spec 0.6 items 18, 19, 21, 22) | P0.8 | Open |
| 2026-11-15 | Min-spec hardware undefined | owner, P0.7 | Closed 2026-11-16 (Windows/Linux); macOS open as D24 |
| 2026-11-16 | i7-3770 has no AVX2; Voxel Tools GDExtension instruction-set requirement unverified | P0.8 j | Open |
