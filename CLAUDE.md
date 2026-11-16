# Project Guidelines: 3D Cozy Mining & Crafting Adventure

## Approach
- Read existing files before writing. Don't re-read unless changed.
- Thorough in reasoning, concise in output.
- Skip files over 150KB unless required.
- No sycophantic openers or closing fluff.
- No emojis or em-dashes.
- Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or docs before asserting.
- after completing a task, git commit with a meaningful message

## Engine & Tech Stack
- Engine: Godot Engine 4.7 (GDScript), Jolt 3D physics. Tests: gdUnit4
- Platform Targets: Desktop Cross-Platform (Windows, Linux, macOS)
- Control Scheme: Gamepad primary (XInput/DualShock action mapping), Keyboard/Mouse secondary
- Gameplay code reads abstract input actions only (spec §2.1), never device-specific events.

## Architecture Rules
- Player Controller: Use a Finite State Machine (FSM) for state management (Idle, Walk, Run, Duck, Mine, Build, Craft).
- UI Management: Gamepad focus-driven navigation. Opening menus MUST emit a global pause signal `get_tree().paused = true`.
- Module Isolation: Decouple inventory, job systems, economy, and mail via signal buses (`EventBus.gd`).
- Data Persistence: Use Godot `Resource` scripts or JSON for items, recipes, outfits, and save states.

## Workflow Rules
1. Never write implementation code before generating and verifying `_docs/specs/spec[N].md` and `_docs/plans/plan[N].md`.
2. Update `_docs/PROGRESS.md` after completing each sub-task in an active plan.
3. Maintain modular file structure: `res://scenes/`, `res://scripts/`, `res://resources/`, `res://ui/`.

## Testing & Verification Rules
- Framework: GdUnit4 plugin.
- Test Directory Structure: `res://test/unit/` (data/FSM logic) and `res://test/integration/` (UI/world signals).
- Headless CLI Command: `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`
- Mandatory Validation:
  1. Write GdUnit4 test suites (`TestSuite`) for pure logic components (Inventory, Economy, FSM transitions, Save/Load serialization) before feature sign-off.
  2. Execute the headless test suite CLI command and verify 0 failures (exit code 0) before marking any task complete in `_docs/PROGRESS.md`.
