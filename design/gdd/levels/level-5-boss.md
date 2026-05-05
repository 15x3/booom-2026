# Level 5 — Boss: 千年虫 / Y2K Bug (1999)

> *"The bug that threatens all eras."*

## 1. Overview

Boss 关卡以 1999 年 **Homeworld** 美学为基础（引擎拖尾、手绘背景、定向环境光）。Boss 是"千年虫"——一个跨越所有时代的元游戏 Bug。主操控为 Star Fox 风格（Level 4），但 Boss 会触发干扰，迫使玩家应对来自每个历史时代的不规则玩法。

**时代标识**：进入关卡时显示 "1999 — Homeworld"

## 2. Player Fantasy

- 面对一个把游戏历史当武器的 Boss
- 最精美的画面被 Bug 破坏时的紧张感
- 在不同操控模式间切换的适应力挑战
- 最终胜利后加速白屏的释放感

## 3. Detailed Rules

### 3.1 主操控

- **默认**：Star Fox 风格街机操控（Level 4）
- Boss 在 Homeworld 美学下战斗
- 引擎拖尾效果、手绘风格天空盒、定向环境光

### 3.2 干扰系统

Boss 随机触发三种干扰：

**干扰 1：线框降级**
- 画面退化到 Level 3 的线框 3D 美学
- 帧率从 30 降到 ~15
- 持续时间：5~8 秒
- 玩家需要在线框模式下继续战斗

**干扰 2：命令劫持**
- 画面变为 Level 2 的橙色等离子终端
- 控制失效，屏幕显示命令提示
- 玩家必须在限时内输入正确指令解除劫持（如 `OVERRIDE`、`REBOOT`）
- 失败 = 额外伤害
- 持续时间：直到玩家成功输入解除命令

**干扰 3：Spacewar 闪回**
- 当 HP < 30% 时可能触发
- 画面变为 Level 1 的 2D 磷光绿 Spacewar
- 弹出一个 Spacewar 迷你游戏（击落 3 个敌人）
- 通过 = 恢复 25% HP，回到 Boss 战
- 失败 = HP 直接清零，关卡失败

### 3.3 Boss 行为

- Boss 有多阶段（至少 2 阶段）
- 每阶段触发不同干扰组合
- Boss 被击败后：加速 → 白屏 → 制作名单

### 3.4 结局

- Boss 被击败后，飞船开始加速
- 画面逐渐白屏（类似超光速效果）
- 白屏后显示制作名单 + 游戏历史时间线：

```
1962 — Spacewar!
1974 — Spasim
1984 — Elite
1993 — Star Fox
1999 — Homeworld
2026 — Event Horizon
```

## 4. Formulas

（待详细设计——Boss HP、伤害、干扰触发阈值等）

## 5. Edge Cases

| 场景 | 处理 |
|------|------|
| 干扰中 HP 归零 | 关卡失败 |
| Spacewar 迷你游戏失败 | HP 清零，直接失败 |
| 干扰叠加 | 按优先级处理：Spacewar > 命令劫持 > 线框降级 |
| Boss 最后阶段 | 干扰频率加倍 |

## 6. Dependencies

- 依赖 Level 1~4 的所有视觉/操控系统
- `assets/data/game_config.json` — 关卡配置
- Boss 模型和动画

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `boss_hp` | 500 | Boss 总 HP |
| `boss_phases` | 2 | Boss 阶段数 |
| `interference_interval_min` | 8.0 | 干扰最小间隔（秒） |
| `interference_interval_max` | 15.0 | 干扰最大间隔（秒） |
| `spacewar_trigger_hp` | 0.3 | Spacewar 闪回触发 HP 阈值 |
| `spacewar_hp_recovery` | 0.25 | Spacewar 成功恢复的 HP 比例 |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行
- [ ] Boss 战主操控为 Star Fox 风格
- [ ] 三种干扰均可触发且功能正确
- [ ] Spacewar 迷你游戏可完成
- [ ] Boss 击败后触发白屏+制作名单
- [ ] 制作名单包含时间线
- [ ] 所有关卡配置值在 game_config.json 中
