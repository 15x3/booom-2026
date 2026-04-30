# BOOOM2026 — Event Horizon (事件视界)

Godot 4.6 jam game. Cockpit-based space survival with physical panel controls and mini-map driving.

## Project Facts

- **Engine**: Godot 4.6, GL Compatibility renderer, Jolt Physics
- **Language**: GDScript only
- **Main Scene**: `scenes/cockpit.tscn` (single scene, everything runs from here)
- **Game Config**: `assets/data/game_config.json` — **all gameplay values live here**
- **Node Data**: `assets/data/nodes.json` — navigation graph with per-node map_data
- **MCP Plugin**: `addons/godot_mcp/` provides runtime testing tools (screenshots, input, live inspection)

## Directory Layout

```
scripts/              All game code (NOT src/ — src/ is unused template leftover)
  controls/           Physical panel controls (base, knob, button, switch, lever, side_panel)
scenes/               .tscn files
  controls/           Control prefabs (button, knob, lever, switch)
  panels/             SubViewport panels (comm, mini-map, system, gravity-map)
assets/
  data/               game_config.json, nodes.json
  shaders/            CRT, lens_distortion, BlackHole, accretion_disk
design/gdd/           Game design doc (event-horizon.md)
production/           Sprint state, session checkpoints
docs/                 Architecture, collaboration principle
src/                  UNUSED (template leftover, has only .gitkeep)
```

## Key Architecture

**`scripts/cockpit.gd` is the orchestrator** (~1100 lines). It wires everything:
SubViewports, camera feeds, console panel, ship physics, maintenance, resources,
narrative, and navigation.

Critical patterns an agent would miss:
- `ship_physics` and `maintenance_manager` are loaded at runtime via `load()` +
  `set_script()` onto new `Node` instances — they are NOT scene tree nodes in
  cockpit.tscn. See `_setup_ship_physics()` and `_setup_maintenance()`.
- The console panel (`scenes/console-panel.tscn`) is instantiated at runtime in
  `_setup_console_panel()`. Controls discovered via `get_all_controls()`.
- Controls use `get_meta("type")` for identification (values: `"knob"`, `"lever"`,
  `"switch"`, `"button"`, `"side_panel"`), not class checks.
- Controls emit signals (`interacted`, `value_changed`, `toggled`, `stop_changed`)
  that cockpit.gd binds with the control name.
- SubViewport camera feeds run at 15 FPS (timer-driven `UPDATE_ONCE`);
  main monitor runs `UPDATE_ALWAYS`. SubViewports render into MeshInstance3D screen
  slots via material texture assignment with CRT/lens distortion shaders.

## Data Flow

```
game_config.json → cockpit._load_config() → config dict
config dict passed to: ship_physics.load_config(), mini_map.load_config(),
  ship_resources.load_config(), maintenance_manager.load_config(), etc.
```

All game systems receive their config as a `Dictionary` parameter. They do not load
config themselves — cockpit.gd is the single loader. **Never hardcode gameplay numbers.**

## Conventions

- **Scripts**: snake_case (`ship_physics.gd`)
- **Scenes**: kebab-case (`console-panel.tscn`)
- **Signals**: past_tense_snake_case (`destination_reached`, `breaker_tripped`)
- **Constants**: ALL_CAPS_SNAKE
- **No `print()`** — use `push_warning()`/`push_error()` or `MCPRuntime.push_runtime_log()`
- **No autoloads** except MCPRuntime/MCPScreenshot/MCPInputService/MCPGameInspector (MCP plugin)

## Runtime Testing (MCP)

Runtime tools only work when the game is playing:
```
godot_run_scene(wait_for_runtime=true)
  → godot_take_screenshot / godot_send_input / godot_query_runtime_node
godot_stop_scene()
```

## Development Guide

Full phased task list in `DEV-GUIDE.md` (Chinese). Key phases:
1. Physical controls (knob/button/switch/lever/side_panel)
2. Mini-map driving (ship_physics + mini_map + gravity)
3. Operation flow (console operations replace keyboard shortcuts)
4. Maintenance (breaker trips, O2 supply, engine cooling)
5. Special nodes (storm, slingshot)
6. Audio, title screen, build

## Session Recovery

`production/session-state/active.md` is the checkpoint. Read it first after compaction or crash.

## Instructions Loaded by OpenCode

From `opencode.json` — all loaded automatically:
- `.claude/docs/coding-standards.md` — doc comments, testing gates, CI rules
- `.claude/docs/context-management.md` — session recovery, file-backed state strategy
- `.claude/docs/coordination-rules.md` — agent delegation tiers, model assignments
- `.claude/docs/technical-preferences.md` — engine config, naming, performance budgets
- `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` — ask-before-propose protocol, approval gates
