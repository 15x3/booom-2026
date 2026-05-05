# Level 3 — Elite (1984)

> *"Wireframe space. Every line counts."*

## 1. Overview

Elite 关卡模拟 1984 年 David Braben & Ian Bell 的 **Elite**。线框 3D 渲染、隐藏线消除、高对比度矢量美学。20 FPS。操控生硬受限，呈现早期 3D 飞行的笨拙感。

**时代标识**：进入关卡时显示 "1984 — Elite"

## 2. Player Fantasy

（待设计）

## 3. Detailed Rules

（待设计——用户将提供具体操控方案）

### 已确定
- 线框 3D 渲染，隐藏线消除
- 20 FPS 帧率
- 生硬的操作手感（只能使用现有控件）
- 目标：到达黑洞

### 待定
- 操控方式（如何映射到现有控件？）
- 3D 空间的自由度（6 DOF？还是限制在平面？）
- 攻击机制（是否保留？）
- 障碍类型

## 4. Formulas

（待设计）

## 5. Edge Cases

（待设计）

## 6. Dependencies

- `assets/shaders/wireframe.gdshader` — 线框渲染
- `assets/data/game_config.json` — 关卡配置

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `target_fps` | 20 | 目标帧率 |
| `input_lag_frames` | 3 | 输入延迟帧数（模拟生硬感） |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行
- [ ] 线框 3D 正确渲染
- [ ] 20 FPS 帧率锁定
- [ ] 到达黑洞触发关卡完成
