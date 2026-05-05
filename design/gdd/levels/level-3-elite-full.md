# Level 3 — Elite (1984) 完整设计文档

> *"Wireframe space. Every line counts."*

## 1. Overview

Elite 关卡模拟 1984 年 David Braben & Ian Bell 的 **Elite**。线框3D渲染、隐藏线消除、高对比度矢量美学。20 FPS。玩家通过贸易/战斗/探索积攒足够过路费，最终在出口完成 Coriolis 空间站旋转对接。

**时代标识**: 进入关卡时显示 "1984 — Elite"

## 2. Player Fantasy

玩家体验到从纯文字终端（Level 2 SPASIM）到早期3D矢量图形的进化震撼。线框世界中飞行、贸易、战斗，最终面对经典的空间站对接挑战。操作从纯命令行升级为直接键盘操控飞船，但仍保留那个年代的笨拙感。

## 3. Detailed Rules

### 3.1 屏幕布局

| 座舱屏幕 | 用途 | SubViewport 尺寸 |
|----------|------|-------------------|
| MainScreenSlot (1.6×1.0) | 3D线框世界视口 | 640×480, 20FPS |
| CommScreenSlot (1.6×0.35) | 通讯对话框 | 480×100 |
| LeftScreenSlot (0.7×1.0) | 圆形雷达扫描仪 | 320×400 |

### 3.2 操控方案

| 按键 | 功能 |
|------|------|
| A / D | Roll（左右翻滚） |
| W / S | Pitch（上下俯仰） |
| I / K | Thrust 增/减档 |
| Space | 开火（激光） |
| H | 超空间跳跃（方案A） |
| Tab | 切换目标锁定 |
| E | 停靠空间站（靠近时） |

### 3.3 飞行物理

- 6DOF 简化版：Roll + Pitch + Thrust
- 无独立 Yaw（靠 Roll+Pitch 组合转弯，同原版 Elite）
- 有惯性：松开 Thrust 后飞船保持速度，缓慢减速
- Thrust 档位：0=停止, 1=慢速, 2=巡航, 3=快速
- Roll/Pitch 为持续按键式，松开即停转

### 3.4 贸易系统（轻量）

**4种商品**:

| 商品 | 买入价范围 | 卖出价范围 | 单位利润 |
|------|-----------|-----------|---------|
| Food | 5-10 | 8-15 | 低 |
| Textiles | 12-20 | 18-30 | 中低 |
| Machinery | 30-50 | 45-70 | 中 |
| Luxuries | 60-80 | 90-130 | 高 |

- 货舱上限：20 单位
- 每个空间站有固定买卖价（不同站差价不同）
- 靠近空间站按 E 键进入交易界面（CommScreen显示）

### 3.5 战斗系统

- 激光：前向射击，按住 Space 持续开火，有冷却间隔
- 敌人AI：海盗飞船检测到玩家后追踪+射击
- 护盾 + HP 双层：护盾缓慢自动回复，HP 不回
- 击杀赏金：100-200 credits
- 能量系统：开火消耗能量，能量缓慢回复

### 3.6 两个版本

**方案A (多星系跳跃)**:
- 3个星系，每个有1个空间站+巡逻敌人
- H键超空间跳跃到下一星系（有遭遇概率）
- 站间差价更大

**方案B (单开放区域)**:
- 1个大区域，4个空间站+小行星带+敌人巡逻区
- 纯飞行到达目的地
- 站间差价较小
- 探索要素更多（散落的货柜等）

**共用代码**: 90%相同，只有旅行方式和空间布局不同

### 3.7 终局对接

- Coriolis 空间站（线框立方体）持续旋转
- 入口开口约60度弧段
- 对接条件：对准旋转开口 + 速度低于阈值 + 距离足够近
- 碰到非开口面 = 损伤
- 旋转速度约10秒一圈（适度挑战）
- 需要积攒够过路费才能触发对接

### 3.8 CommScreen 对话框内容

- 空间站通讯（欢迎/拒绝/交易）
- 遭遇战警告
- 交易结果
- 赏金通知
- 关键事件滚动显示
- 按上下键翻看历史

## 4. Formulas

### 飞行

```
velocity = velocity + (forward_dir * thrust_speed[thrust_level] - velocity * drag) * delta
position = position + velocity * delta

roll_rate = roll_input * max_roll_speed * delta
pitch_rate = pitch_input * max_pitch_speed * delta

rotation = current_rotation * Quaternion(roll, pitch)
forward_dir = rotation * Vector3.FORWARD
```

### 战斗

```
laser_damage = base_damage * (1.0 - distance / max_range)
shield -= damage
if shield < 0:
    hp += shield  // shield is negative
    shield = 0
shield_regen = shield_regen_rate * delta
energy -= fire_energy_cost
energy_regen = energy_regen_rate * delta
```

### 贸易

```
profit = sell_price * quantity - buy_price * quantity
cargo_used = sum of all commodity quantities
can_trade = cargo_used + trade_quantity <= max_cargo && credits >= total_cost
```

### 经济平衡（15分钟游戏时长）

```
starting_credits = 100
toll_fee = 1000
avg_trade_profit_per_run = 80-150
bounty_per_kill = 100-200
expected_trades = 4-6
expected_kills = 2-3
```

## 5. Edge Cases

- 玩家HP归零 → Game Over，返回标题
- 货舱已满时尝试购买 → 提示货舱不足
- 余额不足时尝试购买 → 提示资金不足
- 没有商品时尝试出售 → 提示无货物
- 超空间跳跃遭遇敌人（方案A）→ 强制战斗
- 对接时速度过快 → 碰撞损伤
- 对接时角度不对 → 碰撞损伤
- 对接时过路费不够 → 空间站拒绝，CommScreen提示

## 6. Dependencies

- `assets/shaders/wireframe.gdshader` — 线框渲染
- `assets/data/game_config.json` — 关卡配置 (elite 段)
- `scenes/cockpit.tscn` — 座舱场景（MainScreenSlot/CommScreenSlot/LeftScreenSlot）
- `scripts/cockpit.gd` — 座舱编排器（level_mode == "elite" 分支）
- `scripts/title_screen.gd` — 标题画面路由

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `target_fps` | 20 | 目标帧率 |
| `max_roll_speed` | 90.0 | 最大翻滚速度 (度/秒) |
| `max_pitch_speed` | 60.0 | 最大俯仰速度 (度/秒) |
| `thrust_speeds` | [0, 30, 60, 120] | 各档位速度 |
| `drag` | 0.3 | 速度衰减系数 |
| `max_cargo` | 20 | 最大货舱 |
| `starting_credits` | 100 | 起始资金 |
| `toll_fee` | 1000 | 过路费 |
| `laser_damage` | 10.0 | 激光伤害 |
| `laser_range` | 500.0 | 激光射程 |
| `laser_cooldown` | 0.5 | 开火冷却 |
| `shield_max` | 50.0 | 最大护盾 |
| `shield_regen` | 5.0 | 护盾回复/秒 |
| `hp_max` | 100.0 | 最大HP |
| `energy_max` | 100.0 | 最大能量 |
| `energy_regen` | 10.0 | 能量回复/秒 |
| `fire_energy_cost` | 10.0 | 开火能量消耗 |
| `enemy_fire_interval` | 2.0 | 敌人开火间隔 |
| `enemy_damage` | 8.0 | 敌人伤害 |
| `bounty_base` | 100 | 基础赏金 |
| `station_rotation_speed` | 36.0 | 空间站旋转速度 (度/秒, ~10秒/圈) |
| `dock_max_speed` | 15.0 | 对接最大速度 |
| `dock_tolerance_angle` | 30.0 | 对接角度容差 |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行
- [ ] 线框3D正确渲染（飞船、空间站、小行星）
- [ ] 20 FPS 帧率锁定
- [ ] WASD + I/K 操控正常
- [ ] 雷达正确显示周围物体
- [ ] 能停靠空间站进行交易
- [ ] 能与海盗战斗获得赏金
- [ ] 积攒够过路费后可尝试对接
- [ ] Coriolis对接挑战完整可玩
- [ ] 通过座舱三屏正确显示
- [ ] 从标题画面可进入Level 3

## 9. 文件清单

```
新增:
  assets/shaders/wireframe.gdshader
  scripts/levels/level_3_elite.gd
  scripts/panels/level3_comms.gd
  scripts/panels/level3_radar.gd

修改:
  scripts/cockpit.gd
  scripts/title_screen.gd
  assets/data/game_config.json
  scenes/levels/level-3-elite.tscn

本文档:
  design/gdd/levels/level-3-elite-full.md
```

## 10. 实现顺序

| Phase | 内容 | 验证标准 |
|-------|------|----------|
| 1 | wireframe shader + 飞行物理 + 星场 | MainScreen显示线框飞船+星场 |
| 2 | 雷达面板 | LeftScreen显示圆形雷达 |
| 3 | 空间站 + 贸易 + CommScreen | 能停靠/买卖商品 |
| 4 | 战斗 + 敌人AI | 能战斗/获得赏金 |
| 5 | 方案A/B 旅行系统 | 两版本分别可玩 |
| 6 | Coriolis 对接终局 | 对接挑战完整 |
| 7 | Cockpit集成 + 配置 | 从title进入Level 3 |
