# Technical Preferences

<!-- Populated for Omega Outpost (值守) — Godot 4.6 Jam Project -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: GL Compatibility (forward+ for low-poly is overkill; compat gives best perf for SubViewport×4)
- **Physics**: Jolt Physics (3D, via built-in plugin)

## Input & Platform

- **Target Platforms**: PC (Windows)
- **Input Methods**: Keyboard + Mouse
- **Primary Input**: Mouse (click UI elements on control panel) + Keyboard (camera switching)
- **Gamepad Support**: None (jam scope — single platform, single input method)
- **Touch Support**: None
- **Platform Notes**: Jam build targets Windows x64 only. No console/mobile considerations.

## Naming Conventions

- **Classes**: PascalCase (`AnomalyZone`, `EnemyAI`, `SecurityCamera`)
- **Variables**: snake_case (`anomaly_radius`, `door_breach_time`)
- **Signals/Events**: past_tense_snake_case (`door_opened`, `entity_consumed`, `day_started`)
- **Files**: snake_case for scripts (`anomaly_zone.gd`), kebab-case for scenes (`facility.tscn`, `monitoring-room.tscn`)
- **Scenes/Prefabs**: kebab-case (`enemy-soldier.tscn`, `blast-door.tscn`)
- **Constants**: ALL_CAPS_SNAKE (`DOOR_COOLDOWN`, `ANOMALY_EXPANSION_RATE`)

## Performance Budgets

- **Target Framerate**: 60 FPS (main camera); 15 FPS (surveillance cameras, via SubViewport)
- **Frame Budget**: 16.67ms — main camera rendering must stay under this with 4 SubViewports active
- **Draw Calls**: ≤ 100 (low-poly + SubViewports share the same scene)
- **Memory Ceiling**: 512 MB (jam build, no streaming)
- **SubViewport Resolution**: 320×240 per camera feed (reduces GPU load significantly)

## Testing

- **Framework**: GDScript built-in asserts + manual playtesting via godot_mcp runtime tools
- **Minimum Coverage**: Core systems only (anomaly expansion formula, combat calculation, event triggers)
- **Required Tests**: Anomaly expansion math, combat power calculation, NPC pathfinding with anomaly avoidance
- **Test Approach**: Jam project — verification-driven via playtesting and screenshots, not automated suite

## Forbidden Patterns

- No hardcoded gameplay values in scripts — all values in `assets/data/game_config.json`
- No `@onready` references to nodes outside the current scene (use dependency injection or exports)
- No `print()` in shipped build — use `MCPRuntime.push_runtime_log()` for debug logging
- No singletons/autoloads except MCPRuntime (provided by plugin)

## Allowed Libraries / Addons

- **godot_mcp** (already integrated) — runtime testing tools
- **Jolt Physics** (built-in Godot 4.6) — 3D physics
- No additional addons planned for jam scope

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — decisions documented in design/gdd/omega-outpost.md]

## Engine Specialists

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist
- **Shader Specialist**: godot-shader-specialist
- **UI Specialist**: godot-gdscript-specialist (pixel-art UI uses Control nodes, not engine-specific UI framework)
- **Additional Specialists**: None needed for jam scope
- **Routing Notes**: This is a jam project — all code is GDScript. No C# or GDExtension.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd) | godot-gdscript-specialist |
| Shader / material (.gdshader, .tres) | godot-shader-specialist |
| UI / screen files (.tscn with Control nodes) | godot-gdscript-specialist |
| Scene / prefab / level files (.tscn) | godot-specialist |
| Native extension / plugin files | Not applicable (jam scope) |
| General architecture review | godot-specialist |
