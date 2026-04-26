# OpenCode Game Studio

This project has been migrated from Claude Code Game Studios to OpenCode.

**Primary instructions file**: `AGENTS.md` — OpenCode reads this file first.

## Configuration

- **OpenCode config**: `opencode.json`
- **Agents**: `.opencode/agents/` (49 specialized agents)
- **Commands**: `.opencode/commands/` (33 slash commands)
- **Skills**: `.claude/skills/` (72 skills, loaded by OpenCode via skill tool)

## Legacy Claude Code Structure

The `.claude/` directory is preserved for OpenCode compatibility — OpenCode discovers skills from `.claude/skills/` natively. The `.claude/docs/` and `.claude/rules/` directories contain standards and path-scoped rules referenced by `opencode.json`'s `instructions` field.

## Quick Start

Run `/start` for guided onboarding, or see `AGENTS.md` for the full project guide.
