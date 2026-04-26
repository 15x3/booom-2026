# OpenCode Game Studio - Agent Guide

This is a Godot 4.6 project using the OpenCode agent system with 49 specialized agents and 72 skills.

## Quick Facts

- **Engine**: Godot 4.6 with GL Compatibility renderer
- **Physics**: Jolt Physics
- **Primary Language**: GDScript (not yet configured - run `/setup-engine` to finalize)
- **MCP Plugin**: `godot_mcp` is enabled, providing runtime tools (screenshots, input simulation, live node inspection)
- **Project State**: Early setup - `src/` is empty, infrastructure is in place

## Critical Protocols

### Collaborative Design (Required)
This project follows **user-driven collaboration**, not autonomous generation:
- Agents must ask clarifying questions before proposing solutions
- Present 2-4 options with pros/cons, let user decide
- Draft proposals, get explicit approval ("May I write this?") before using Write/Edit tools
- See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full pattern

### Verification-Driven Development
- Write tests first when adding gameplay systems
- For UI changes, verify with screenshots (use `godot_take_screenshot`)
- Compare expected output to actual output before marking work complete
- Every implementation should have a way to prove it works

## Godot MCP Tools (Runtime Integration)

The project has the godot_mcp plugin enabled, which provides these runtime tools:
- `godot_run_scene` - Launch a scene and wait for game to start
- `godot_take_screenshot` - Capture viewport as PNG (requires running game)
- `godot_send_input` - Simulate keyboard/mouse/action events during tests
- `godot_query_runtime_node` - Inspect live node properties in running game
- `godot_get_runtime_log` - Fetch recent runtime logs
- `godot_stop_scene` - Stop the running scene

**Important**: Runtime tools only work when game is playing. Use pattern:
```bash
godot_run_scene(scene="res://path/to/scene.tscn", wait_for_runtime=true)
# ... send input, take screenshots, query nodes ...
godot_stop_scene()
```

## Code Conventions

- **Data-driven**: All gameplay values must be external config, never hardcoded
- **Doc comments**: All public APIs require doc comments
- **Dependency injection**: Prefer over singletons for testability
- **Commit references**: Must reference relevant story ID or design document

## Design System Structure

- **GDDs** (`design/gdd/`): Must include 8 required sections (Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria)
- **ADR Registry** (`docs/architecture/`): Architecture Decision Records with stable IDs
- **TR Registry** (`docs/architecture/tr-registry.yaml`): Technical Requirement ID registry - never renumber, never delete IDs
- **Entity Registry** (`design/registry/entities.yaml`): Cross-system entity/item/formula registry

## Directory Layout

- `src/` - Game source code (currently empty)
- `design/` - GDDs, UX specs, entity registry
- `docs/architecture/` - ADRs, TR registry
- `tests/` - Unit/integration tests (not yet set up)
- `production/` - Sprint plans, milestones, session state (`production/session-state/active.md` is checkpoint)
- `prototypes/` - Throwaway prototypes (isolated from `src/`)
- `addons/godot_mcp/` - MCP integration plugin

## Testing Setup

No test framework is configured yet. When adding first tests:
- Run `/test-setup` to scaffold test framework for Godot
- Tests should be in `tests/` (not in `src/`)
- Godot test command: `godot --headless --script tests/gdunit4_runner.gd` (after framework setup)

## Engine Configuration

Technical preferences are **not configured**. Run `/setup-engine` to set:
- Target platforms
- Input methods (keyboard/mouse, gamepad, touch)
- Naming conventions
- Performance budgets
- Engine specialist routing (godot-specialist, godot-gdscript-specialist, etc.)

## Context Management

Session state is maintained in `production/session-state/active.md`. After compaction or crash:
- Read `active.md` first to recover state
- Completed sections of multi-section documents are in files, not conversation history

## Instructions Reference

OpenCode loads these instruction files (from `opencode.json`):
- `AGENTS.md` - This file
- `.claude/docs/coding-standards.md`
- `.claude/docs/context-management.md`
- `.claude/docs/coordination-rules.md`
- `.claude/docs/technical-preferences.md`
- `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`

## Getting Started

- Run `/start` for guided onboarding (detects project state, routes to right workflow)
- Run `/setup-engine godot 4.6` to finalize engine configuration
- Run `/brainstorm [theme]` if exploring game concepts
