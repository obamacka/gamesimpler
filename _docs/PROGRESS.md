# Progress

| Field | Value |
|---|---|
| Spec | `_docs/specs/spec1.md` rev 3.12 |
| Plan | `_docs/plans/plan1.md` |
| Active phase | Phase A (art pass) automated work done (PA1 to PA4); owner review items open All six phases have their automated work done (Phases 3 to 6 started on owner request before earlier gates passed); manual checklists for Phases 1 to 6, Phase 0 hardware checks and the release-candidate checklist pending |
| Last updated | 2026-11-20 |

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
| 2 | Mining, Foraging, Stamina Loop, Auto-Tool | In progress: all automated tasks done, manual checklist and min-spec performance check pending | |
| 2B | Farming | In progress: all automated tasks done, manual checklist pending | |
| 3 | Magnetic Grid Building, Screw/Hammer Mini-Games | In progress: automated tasks done except P3.8 icons; manual checklist pending | |
| 4 | Economy, Jobs, Wardrobe UI, Game Pause | In progress: automated tasks done; manual checklist pending | |
| 5 | NPCs, Mail, Pet Companion | In progress: automated tasks done; manual checklist pending | |
| 6 | Museum, Collection Book, Dye Painting, Save/Load | In progress: automated tasks done (plus navmesh); manual and release-candidate checklists pending | |

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
| P2.1 to P2.4 Resources | Done | 2026-11-16 | 205f54a | content authored as JSON in resources/data, built into typed Resources by Database |
| P2.5 to P2.21 Scripts | Done | 2026-11-16 | 5e4c70e | P2.18 temporary mailbox `claim_all` (removed in P5.13); ProtectionVolume editor gizmo deferred; WalletModel pulled in for chest coins |
| P2.22 Scenes | Done | 2026-11-16 | 5e4c70e | wilderness, orchard, deep mine (generated), starter cabin (static); main scene playable |
| P2.23 to P2.28 Unit suites | Done | 2026-11-16 | 5e4c70e | terrain, tools, stamina, discovery, rollover, mail, inventory, resolver, mine, database, rng, round trip, prompt model |
| P2.29 to P2.33 Integration suites | Done | 2026-11-16 | 5e4c70e | Suite A 19/19 (A1-A7, A11-A22), Suite B 15/15 (B1-B11, B14-B17), dig and forage 10, safe ground 4, real-terrain smoke 9 |
| Manual checklist | Not started | | | dig, forage, chop, exhaustion loop with pad and KB/M; performance on the min-spec machines |

### Phase 2B
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P2B.1 to P2B.2 Resources and zone | Done | 2026-11-16 | 93b088c | 6 crops, seeds, produce, hoe, can, `item_sprinkler`, `mat_farmland` (voxel 13), welcome letter, `plot_starter_garden`; Home Meadow generated zone with flattened garden, protected cabin exterior, well; cabin door now leads to the meadow |
| P2B.3 to P2B.11 Scripts | Done | 2026-11-16 | 93b088c | FarmModel, FarmService, FarmView/CropView/SoilOverlay, HotbarModel, farm rules in the selector, FarmActionTarget in Interact, occupancy and P3 protection, sprinkler command, new-game kit, `farm` save section |
| P2B.12 to P2B.14 Unit suites | Done | 2026-11-16 | 93b088c | farm model 13, farm tool rules 10, rollover step order, farm round trip 2, database integrity +2 |
| P2B.15 to P2B.16 Integration suites | Done | 2026-11-16 | 93b088c | Suite F 16/16 (F15 asserts PRODUCE only; `entry_discovered` waits for Phase 6 CollectionService); Suite A 19/19 unchanged; Home Meadow real-terrain smoke |
| Manual checklist | Not started | | | plant, water, harvest with pad only; hoe vs shovel prompts; picture guide in the welcome letter (letter art not made yet) |

### Phase 3
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P3.1 to P3.2 Resources | Done | 2026-11-16 | 405aae6 | 15 pieces in `resources/data/pieces.json` with placeholder box geometry (no per-piece .tscn); `plot_test` in Home Meadow granted by `BuildService.grant_debug_kit()` (debug builds, main.gd) |
| P3.3 to P3.13 Scripts | Done except P3.8 | 2026-11-16 | 405aae6 | P3.8 ghost lacks icons, reason pictograms, stripes and pulse (text label stands in); STORAGE (chest) opens in Phase 4 |
| P3.14 to P3.16 Unit suites | Done | 2026-11-16 | 405aae6 | placement 8, snap 8, fasten 7, sub-FSM 4, blocks 6, build round trip 1, script compile check 1 |
| P3.17 to P3.21 Integration suites | Done | 2026-11-16 | 405aae6 | Suite A 22/22 (A8-A10 added), build placement 5, fasten 3, menu stack 6, furniture 6 |
| Manual checklist | Not started | | | 3x3 room with door, roof and furniture by pad; magnetic feel on High; three ghost palettes readable; sockets auto-advance |

### Phase 4
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P4.1 Resources | Done | 2026-11-16 | 8566596 | `economy.json` (3 shops, starting coins 150), `recipes.json` (10), `jobs.json` (2 jobs, 4 contracts, 1 blueprint), `outfits.json` (6 outfits, 7 dyes, 5 default dyes), `plot_meadow_east` (500 coins); outfits use placeholder boxes |
| P4.2 to P4.13 Scripts | Done | 2026-11-16 | 8566596 | Coordinator with snapshot rollback and `fail_at` seam; EconomyService restock in rollover `restock` step (with job expiry); Craft state; JobService (blueprint auto-complete, craft progress, mail, B13); deeds via PlotSign; OutfitService and customizer with SubViewport turntable; 12 menus; MenuStack globals, focus recovery and debug focus check; focus-loss and pad-loss pause with DeviceBanner; Accessibility runtime (text scale, palette, reduce motion, prompt labels, TTS, master volume, fullscreen, vsync) |
| P4.14 to P4.16 Unit suites | Done | 2026-11-16 | 8566596 | wallet 2, coordinator 7, accretion 2, pricing 3, craft 2, jobs 3, outfit 3, inventory transactions 4, phase 4 round trip 2, accessibility 5, scene/script load checks 2 |
| P4.17 to P4.23 Integration suites | Done | 2026-11-16 | 8566596 | menu pause flow 8, auto-pause 2, shop and craft 5, job contracts 3, B13, wardrobe 3, settings rebind 4 |
| Manual checklist | Not started | | | every menu by pad only with no dead-end focus; unplug/replug the pad mid-game |

### Phase 5
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P5.1 Resources | Done | 2026-11-16 | 56d4cef | `npcs.json` (5 NPCs, friendship rules and letters), `pets.json` (dog, cat, 3 accessories, names, care config), `emotes.json` (8 emotes, 3 instruments), pet food, pet bed and feed bowl pieces, adoption / job offer / catalog / friendship mail |
| P5.2 to P5.13 Scripts | Done | 2026-11-16 | 56d4cef | NPC service and bodies with schedules, Talk with a 0.3 s camera two-shot, DialogueModel and dialogue / gift menus; mail complete (all attachment types, expiry to Lost and Found, cap and prune, catalog orders) and mail menu; PetBrainModel, PetService, Pet body with Skeleton3D and BoneAttachment3D slots, path providers (VoxelAStarGrid3D, navmesh, straight), adoption on day 2, pet_call, bowl self-feed, wheel with Emote and PlayInstrument; `claim_all` removed |
| P5.14 to P5.17 Unit suites | Done | 2026-11-16 | 56d4cef | pet brain 10, feeding 6, accessories 3, mailbox full 7, npc 3, dialogue 2, resolver npc/pet 3, wheel 2, phase 5 round trip 1 |
| P5.18 to P5.22 Integration suites | Done | 2026-11-16 | 56d4cef | pet follow 6, pet care 5, mail arrival 5, npc talk 2, emote and instrument 4 |
| Manual checklist | Not started | | | pet through tunnels, dug terrain and town; TTS letter; claim package; adopt, name and dress the pet by pad |

### Phase 6
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| P6.1 Resources | Done | 2026-11-16 | 803e74c | collection entries on 13 items (3 new minerals), `museum.json` (3 cases, 4 trophies, geodes), `stickers.json` (7), 2 dyes, 3 blueprint recipes, paint regions on 12 pieces, `piece.gdshader` with 3 instance uniforms, museum zone; treasure pools now reference real ids (they named missing ones before) |
| P6.2 to P6.10 Scripts | Done | 2026-11-16 | 803e74c | Collection and Museum services (guards, batch, rewards once, load reconcile, geodes with undiscovered bias), DisplayCase and TrophyPedestal, donation / collection book / chest reveal / dye palette / sticker sheet / save-load menus, Paint and Stamp tools with eyedropper and undo (20, cleared on zone change), SaveCodec (schema v2, migration from v1, int casting, sanitization, structural failure), SaveService (3 manual + autosave, atomic JSON and voxel-dir rotation, crash seam, consistent-pair load), per-zone SQLite working copies flushed before unload |
| P6.11 to P6.13 Unit suites | Done | 2026-11-16 | 803e74c | museum 7, collection and geode 2, paint 1, stamp 4, undo 2, codec 6, migrations 2, atomic write 2, voxel epoch 3 |
| P6.14 to P6.18 Integration suites | Done | 2026-11-16 | 803e74c | Suite C 15 tests covering C1 to C17, save round trip 3, save failures 3 (B12), paint and stamp 3, real-terrain dig/place/save/reload in `test_voxel_smoke.gd` |
| P6.19 Navigation meshes (owner request) | Done | 2026-11-16 | 803e74c | navigation suite 5 plus the real Home Meadow town bake |
| Manual checklist and release candidate | Not started | | | donate and read the book by pad; paint and stamp a house, save, quit, reload, kill during save; exports for Windows, Linux, macOS not attempted from the cloud session |

### Phase A (art pass)
| Task | Status | Date | Commit | Notes |
|---|---|---|---|---|
| PA1.1 Vendor KayKit packs | Done | 2026-11-19 | 44e8742 | Furniture Bits 53 and Restaurant Bits 144 glTF models, pack textures, LICENSE.txt, SOURCE.md (commit SHAs), CREDITS.md; glTF references checked (own .bin and pack PNG only) |
| PA1.2 ModelFit and model support | Done | 2026-11-19 | 44e8742 | `ModelFit`, `ItemVisual`; `model` on pieces, `world_model` on items, `model` on MenuStation; Database checks paths, quarter-turn yaw, PRIMARY-only paint, item models |
| PA1.3 Textured paint shader | Done | 2026-11-19 | 44e8742 | texture shading kept under dye (`mix(tex, dye * (0.55 + 0.9 luma), painted)`); unpainted = white alpha 0; loose pieces lightened |
| PA1.4 Furniture mapping and new pieces | Done | 2026-11-19 | 44e8742 | 7 existing pieces mapped, seat parts and seats moved to the art (seat = 0.5 model units x scale); 7 new pieces with items and builder-shop stock; radio, pet bed, feed bowl and structure pieces stay placeholders |
| PA1.5 Item and station models | Done | 2026-11-19 | 44e8742 | carrot and tomato props; 3 shop counters, workbench and tailor bench in Home Meadow (colliders resized to the models) |
| PA1.6 Tests | Done | 2026-11-19 | 44e8742 | unit art 9 (fit, turn, orientation with a mutation check, seat heights, glTF refs, validation, item visual), integration art 5; full suite 563 cases exit 0; visual check by Xvfb renders |
| PA2.1 World scale 0.75 | Done | 2026-11-20 | 378b44a | ModelFit.place at 0.75 m per unit; pieces re-footprinted (kitchen modules 2x2), parts and seats (0.375 m) from the scaled models; stations size colliders from models |
| PA2.2 Player 1.7 m | Done | 2026-11-20 | c6d2514 | PlayerConfig drives capsules, probes and camera (1.7 m, duck 0.9 m, eye 1.55 m); locomotion room tunnel is a 1 m crawl space; NPC capsule 1.7 m |
| PA2.3 Vendor Quaternius free packs | Done | 2026-11-20 | c6d2514 | Superhero heads, hair, Peasant and Ranger parts, UAL1 and UAL2; textures 1024 px; 46 MB |
| PA2.4 CharacterRig | Done | 2026-11-20 | c6d2514 | outfit skeleton, head cut by skin weights (custom AABB), hair, base layer, parts per slot, cloth-only dye, HAIR hiding, bone placeholders; player and wardrobe preview |
| PA2.5 Animation | Done | 2026-11-20 | c6d2514 | CharacterAnimModel; merged library (86 clips); player updates the clip every tick |
| PA2.6 NPC appearance | Done | 2026-11-20 | c6d2514 | appearance in npcs.json validated; NPCs face their walking direction |
| PA2.7 Tests | Done | 2026-11-20 | c6d2514 | character anim 5, character rig 8, wardrobe updated; full suite 576 cases exit 0 |
| PA3.1 Vendor animals and crops | Done | 2026-11-20 | 91fe7bf | Quaternius Animal Pack Vol.2 (Dog, Cat FBX) and 25 Nature Crops Pack FBX from OpenGameArt, LICENSE (CC0 per page), SOURCE |
| PA3.2 Pet model | Done | 2026-11-20 | 91fe7bf | species model fitted to the size box, coat by material name (FBX colours are grey), accessories on Bone.001 to Bone.003 at true size, Idle/Walking, faces velocity |
| PA3.3 Crop stage models | Done | 2026-11-20 | 91fe7bf | stages _1 to _3, ripe _4 (the _Crop files are produce), one scale per crop, ripe glow overlay; produce props for strawberry, pumpkin, sunflower; cotton stays a box |
| PA3.4 Tests | Done | 2026-11-20 | d313df0 | data 7 (crops, pets, tools, tiles, validation), visuals 5 (pet colours, accessory size, walk and facing, crop stages and glow, held tool) |
| PA4.1 Vendor Kenney tools and tiles | Done | 2026-11-20 | 91fe7bf | Survival Kit tool glb (5 plus upgraded) from itch, Voxel Pack tiles (13) from OpenGameArt |
| PA4.2 Tools in hand | Done | 2026-11-20 | 91fe7bf | tool world_model (upgraded for tier 2+); hand_r attachment, 0.6 m, oriented on the Idle hand pose |
| PA4.3 Block textures | Done | 2026-11-20 | d313df0 | per-material 3 x 1 atlas; grass top and side fringe recoloured to meadow green; bedrock and farmland tinted |
| PA4.4 Tests | Done | 2026-11-20 | d313df0 | full suite 588 cases exit 0 |

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
| 2026-11-16 | 205f54a | 2 | `ci/run_tests.sh` | 0 | 0 | 199 cases (part 1) |
| 2026-11-16 | 5e4c70e | 2 | `ci/run_tests.sh` | 0 | 0 | 262 cases (Phases 0 to 2) |
| 2026-11-16 | 24a5cfd | 0 | `ci/run_tests.sh` | 0 | 0 | 17 cases incl. voxel smoke |
| 2026-11-16 | 93b088c | 2B | `ci/run_tests.sh` | 0 | 0 | 311 cases (Phases 0 to 2B) |
| 2026-11-16 | 405aae6 | 3 | `ci/run_tests.sh` | 0 | 0 | 369 cases (Phases 0 to 3) |
| 2026-11-16 | 8566596 | 4 | `ci/run_tests.sh` | 0 | 0 | 430 cases (Phases 0 to 4) |
| 2026-11-16 | 56d4cef | 5 | `ci/run_tests.sh` | 0 | 0 | 489 cases (Phases 0 to 5) |
| 2026-11-16 | 803e74c | 6 | `ci/run_tests.sh` | 0 | 0 | 549 cases (Phases 0 to 6) |
| 2026-11-19 | 44e8742 | A | `ci/run_tests.sh` | 0 | 0 | 563 cases (Phases 0 to 6, PA1) |
| 2026-11-20 | c6d2514 | A | `ci/run_tests.sh` | 0 | 0 | 576 cases (PA2) |
| 2026-11-20 | d313df0 | A | `ci/run_tests.sh` | 0 | 0 | 588 cases (PA3, PA4) |
| 2026-11-20 | 1e66c69 | A | release workflow (GitHub Actions run 44786213773) | 0 | 0 | test gate, exports, macOS ad-hoc signing and publish all succeeded |

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
| 2026-11-20 | Release v0.1.0 published as a pre-release (https://github.com/obamacka/gamesimpler/releases/tag/v0.1.0, workflow run 44786213773, commit 1e66c69); exports built in CI; Linux export boots headless (300 frames, no errors) in the cloud session; Windows and macOS exports not launched here (no Windows or macOS machine); macOS is ad-hoc signed, not notarized; Windows is not code-signed; project setting import_etc2_astc enabled for the macOS universal export | owner review | Open |
| 2026-11-20 | PA3/PA4 for owner review: sunflower uses the pack's generic blue flower and strawberry a berry bush; cotton has no model; dog and cat have only Idle and Walking clips (no sit, sleep or eat); watering can, fruit picker and screwdriver have no hand model; tool grip and angle are a fixed pose on the Idle hand; this session moved to a new personal environment "gamesimpler" (exact hosts for itch, its download mirror and opengameart.org) | owner review | Open |
| 2026-11-20 | PA2 for owner review: the free Quaternius tier gives semi-realistic adult faces (Superhero heads) next to toy-like KayKit furniture; only the "Dark" skin tone exists for the Regular body; only Peasant and Ranger outfits; player body type and hair are fixed in PlayerConfig until a character creator exists; straw hat and scarf remain placeholder boxes; the free tier has no wave, pickaxe or sleep clips (substitutes in spec 11.7); kitchen modules at 2 x 2 cells leave 0.5 m gaps in a row; the 1.7 m player stands in 2-voxel tunnels and Duck now means 1-voxel crawl spaces; integration tests take about 1 s each now that every player and NPC builds a rig; headless runs log a dummy-renderer "material is null" error per rig (not seen with a real renderer) | owner review | Open |
| 2026-11-19 | (Resolved 2026-11-20: one world scale 0.75 m per KayKit unit and a 1.7 m player, spec 11.4) PA1 for owner review: KayKit uses a 2-unit tile, so 1-cell fits run 0.44 (stove, fridge) to 0.95 (wide cabinet) while seating is about 0.6 to 0.8; the fridge is barely taller than a chair next to the 2.1 m player capsule. Shop counters face their drawers to the shopkeeper side (yaw 0) | owner review | Closed |
| 2026-11-16 | Phase 1 manual gamepad checklist (plan Phase 1) | team | Open |
| 2026-11-16 | Phase 2 manual checklist and min-spec performance check | team | Open |
| 2026-11-16 | Phase 2 choices for owner review: JSON content authoring (spec 3 conventions updated); care-letter snack rule compares against the collapse day (spec 6.2 corrected, the old rule could never trigger); `player_woke` emitted just before the transition pause is released (spec 6.2 diagram updated to match Suite B); Bed and Mine Entrance act without the confirm dialog until Phase 3 adds menus; SafeGround uses the standing-capsule clearance as the "3 free voxels" check; prompt occlusion implemented in 5ac70f4 | owner review | Open |
| 2026-11-16 | Phase 2B manual checklist (plan P2B) | team | Open |
| 2026-11-16 | Plan 0 rule broken on owner request: Phases 3 to 5 started while the Phase 1, 2 and 2B gates (manual checklists, min-spec performance) are open. Rework risk if those checks find feel or performance problems | owner | Open |
| 2026-11-16 | Bugs found and fixed in Phase 4: `Database.templates_in_pool` sorted StringNames by address, so care-letter pool order (and the seeded pick) could differ between runs (fixed with a text sort, test added); two zone `.tscn` files with 3-component Colors failed to load (new scene-load test). Neither reached a commit | team | Closed |
| 2026-11-16 | Bugs found and fixed in Phase 6: crash (segfault) when anything raycast the previous zone's VoxelTerrain during a zone change, and STATIC zones kept a dangling voxel adapter (reachable since Phase 2 by walking from the overworld into the cabin); the player body left the physics space while frozen; navmesh voxel faces had the wrong winding (masked in fixtures by the floor collider); treasure pools referenced non-existent blueprint, dye and sticker ids | team | Closed |
| 2026-11-16 | Phase 6 choices for owner review: save schema v2 (v1 saves migrate); slot 0 is the autosave; each slot holds a voxel directory with one SQLite per overworld zone; a crash between the JSON and voxel renames loads the older consistent pair; the curator's Y opens donations (gifts to the curator are not possible); museum content is a first pass (3 cases, 4 trophies, 5 minerals); sticker and dye pattern art are placeholders; paint and stamps are refused on job-site pieces | owner review | Open |
| 2026-11-16 | Phase 5 choices for owner review: no navmesh is baked yet, so NPCs steer straight between schedule markers inside protected town volumes and the pet uses a straight line in the cabin (VoxelAStarGrid3D on voxel ground); instrument notes are generated tones (no samples); NPC and pet visuals are placeholder boxes with a real Skeleton3D and BoneAttachment3D slots; friendship: gifts loved 80 / liked 45 / neutral 20 / disliked 0, first talk per day 5, first wave per day 1, letters at 200 and 400; the pet settles at 80% of follow distance; care letters are signed by the best friend; the sweater fits dogs only (exercises the species check) | owner review | Open |
| 2026-11-16 | Bugs found and fixed in Phase 5 work: deferred grab_focus on rebuilt or closed menus (engine errors in every menu test, also in the real game); the pet parked exactly at follow_distance so Idle could never trigger; inbox prune ran before the day's delivery; float drift in pet timers | team | Closed |
| 2026-11-16 | Phase 4 choices for owner review: starting coins 150; contracts that miss their deadline end with no penalty at the next rollover; B13 extends contracts due on the collapse day by one day; buying a tool from a shop grants it to the ToolBelt; music and effects volumes are stored but no audio buses exist yet; NPC shopkeepers arrive in Phase 5 (stations are counters for now); the job site lives in Home Meadow (x 16..22, z 6..12) | owner review | Open |
| 2026-11-16 | Bug found and fixed in 405aae6: `ui/hud/hud.gd` from 93b088c did not parse, so the HUD was missing in the playable build; no test loaded it. New `core/test_scripts_parse.gd` compiles every script | team | Closed |
| 2026-11-16 | Phase 3 choices for owner review: occupancy per cell and layer (floor, body, wall faces) so thin walls, floors and furniture can share cells (spec 1.6 rev 3.6); furniture on whole cells (0.5 m sub-grid deferred); support needs one supported bottom cell, not all; furniture is FASTENED on placement; removal refused while anything rests on the piece; block removal instant for any placeable block in an owned plot; RB rotates clockwise; pieces have no per-piece scenes yet | owner review | Open |
| 2026-11-16 | Phase 2B choices for owner review: seeds aimed at non-farmable grass/dirt show a blocked prompt instead of digging (spec 10.4 row added); wetness stored per soil cell so empty farmland can be watered (save shape in spec 3.5 updated, crop `stage`/`watered_day` no longer saved); harvest is X only per spec 10.4 (RT does nothing on a ripe crop); sprinkler is an item placed with RT while selected on owned plot soil until Phase 3; crop visuals are placeholder boxes; plots are flattened to the natural height at their center, which can leave a ledge at the border; no water voxels yet, so the well is the only refill source | owner review | Open |
| 2026-11-16 | Phase 1 implementation choices recorded in spec: input map generated from InputBindings; `ui_tertiary` KB moved from Shift+Enter to R; Esc overlap rule; ledge probes are direct physics queries; VoxelViewer added in Phase 2 | owner review | Open |
| 2026-11-15 | CLAUDE.md headless command does not match gdUnit4 v6.2.3 (spec 0.6 item 1) | owner | Closed 2026-11-16 (3682356) |
| 2026-11-16 | Confirmed: the CLAUDE.md command hangs at `debug>` on GDScript parse errors; `--remote-debug tcp://127.0.0.1:0` fixes it (exit 105). `ci/run_tests.sh` uses the fix | owner | Closed 2026-11-16: CLAUDE.md updated (owner approved) |
| 2026-11-15 | Voxel GDExtension maturity, collision latency, headless behavior, SQLite copy safety unverified (spec 0.6 items 18, 19, 21, 22) | P0.8 | Partly closed 2026-11-16: headless, SQLite copy and container latency verified; hardware frame budget pending |
| 2026-11-16 | Voxel binaries (65 MB desktop) kept out of git via fetch script; Git LFS is the alternative | owner | Closed 2026-11-16: keep the fetch script |
| 2026-11-16 | Hardware runs of `spikes/voxel/voxel_benchmark.tscn` on the four target machines (P0.8 b, d, j, k; P0.9). One-command scripts: `ci/run_benchmark.sh` (Linux/macOS), `ci/run_benchmark.ps1` (Windows, untested) | team | Open |
| 2026-11-15 | Min-spec hardware undefined | owner, P0.7 | Closed 2026-11-16 (Windows/Linux and macOS) |
| 2026-11-16 | Recommended spec for the 60 fps target undefined (D26) | owner | Closed 2026-11-16 |
| 2026-11-16 | i7-3770 has no AVX2; Voxel Tools GDExtension instruction-set requirement unverified | P0.8 j | Open |
