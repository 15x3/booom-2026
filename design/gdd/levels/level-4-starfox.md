# Level 4 — Star Fox (1993)

> *"Do a barrel roll!"*

## 1. Overview

Star Fox 关卡模拟 1993 年任天堂的 **Star Fox** (Starwing)。低多边形 3D、30 FPS、街机风格操控。从 Level 3 的线框/生硬操控跃升到流畅的街机飞行体验。

**时代标识**：进入关卡时显示 "1993 — Star Fox"

## 2. Player Fantasy

- 爽快的街机飞行——响应灵敏、操控流畅
- 低多边形但充满色彩和活力的 3D 世界
- 从线框时代到有色彩/有面的飞跃感
- 紧张刺激的空战节奏

## 3. Detailed Rules

（待详细设计）

### 已确定
- 低多边形 3D，彩色表面（不再是线框）
- 30 FPS
- 街机风格操控（响应灵敏）
- 目标：到达黑洞

### 待定
- 是否有 on-rails 段落？
- 敌人类型和行为
- 飞行自由度

## 4. Formulas

（待设计）

## 5. Edge Cases

（待设计）

## 6. Dependencies

- `assets/data/game_config.json` — 关卡配置

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `target_fps` | 30 | 目标帧率 |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行
- [ ] 低多边形 3D 渲染
- [ ] 30 FPS 帧率锁定
- [ ] 街机操控手感
- [ ] 到达黑洞触发关卡完成
