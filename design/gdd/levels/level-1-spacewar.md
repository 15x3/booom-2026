# Level 1 — Spacewar! (1962)

> *"The origin. Phosphor green on black."*

## 1. Overview

Spacewar 关卡模拟 1962 年 MIT 的世界首款电子游戏 **Spacewar!**。2D 矢量图形、示波器美学、磷光余晖效果。玩家通过驾驶舱物理控件（方向盘、推力拉杆）在 2D 小地图上导航飞船至黑洞目标。这是最基础的操控方式——直观的物理反馈。

**时代标识**：进入关卡时显示 "1962 — Spacewar!" + 示波器开机动画

## 2. Player Fantasy

- 感觉自己在操作最早的电子游戏——纯粹的矢量线条世界
- 物理控件带来直觉操控感：转动方向盘=转向，拉杆=加速
- 磷光绿色线条在黑色背景上的余晖效果，模拟示波器/早期 CRT
- 最纯粹的空间导航体验，没有多余信息干扰

## 3. Detailed Rules

### 3.1 操控方式

通过驾驶舱物理控件操作（继承现有系统）：

| 控件 | 功能 | 说明 |
|------|------|------|
| 方向盘 (NavKnob) | 转向 | 连续控制，drag_value 映射到 -180°~180° |
| 推力拉杆 (ThrustLever) | 推力 | drag_value 映射到推力大小 |
| 点火按钮 (IgnitionBtn) | 启动引擎 | 按下后飞船开始响应推力 |

### 3.2 导航

- 飞船在小地图（2D 俯视）上移动
- 黑洞显示为引力井符号，带有吸积盘效果（矢量线条）
- 当前位置到黑洞的方向指示器（矢量箭头）
- 距离黑洞越近，引力越强，需要反向推力抵抗

### 3.3 视觉风格

- **颜色**：磷光绿 (#00FF41) 为主色，深黑 (#0a0a0a) 背景
- **线条**：矢量线条渲染，带有 phosphor afterglow（余晖拖尾）
- **CRT 效果**：轻微弯曲、扫描线、磷光闪烁
- **无文字**：纯图形，所有信息通过线条粗细/亮度/闪烁传达

### 3.4 HP 系统

- 碰撞障碍物（小行星矢量轮廓）扣除 HP
- HP 条以矢量线条长度表示（位于屏幕边缘）
- HP 归零 = 关卡失败

## 4. Formulas

### 转向

```
steering_angle = drag_value * 360 - 180  (deg)
heading += steering_angle * steer_speed * delta
```

### 推力

```
thrust = drag_value * thrust_max
velocity += heading_direction * thrust * delta
velocity *= (1 - drag * delta)  # 空间阻力
```

### 引力

```
dist_to_bh = distance(ship, blackhole)
gravity_force = gravity_strength / (dist_to_bh * dist_to_bh)
gravity_dir = (blackhole - ship).normalized()
velocity += gravity_dir * gravity_force * delta
```

### 碰撞

```
collision_damage = impact_speed * damage_multiplier
hp -= collision_damage
```

## 5. Edge Cases

| 场景 | 处理 |
|------|------|
| 引力过强被吸入黑洞 | HP 快速减少，最终触发失败 |
| 推力拉杆在 0 时点火 | 引擎启动但无推力，无位移 |
| 飞出地图边界 | 环绕（从另一侧出现） |
| HP 归零 | 关卡失败，从开头重试 |

## 6. Dependencies

- **共享资源**：
  - `assets/shaders/phosphor_green.gdshader` — 磷光绿后处理
  - `assets/shaders/crt.gdshader` — CRT 效果
  - `assets/data/game_config.json` — 关卡配置
- **现有系统**：
  - `scripts/console_panel.gd` — 物理控件
  - `scripts/mini_map.gd` — 小地图（适配为 2D 矢量风格）
  - `scripts/ship_physics.gd` — 飞船物理
  - `scripts/camera_controller.gd` — 射线交互
- **音效**：引擎嗡鸣、碰撞低频噪音、引力警告音

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `thrust_max` | 200.0 | 最大推力 |
| `steer_speed` | 2.0 | 转向速度 |
| `drag` | 0.02 | 空间阻力系数 |
| `gravity_strength` | 50000.0 | 引力强度 |
| `blackhole_arrival_dist` | 50.0 | 到达阈值 |
| `hp_max` | 100.0 | 最大HP |
| `damage_multiplier` | 0.5 | 碰撞伤害系数 |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行（F6 运行 level-1-spacewar.tscn）
- [ ] 方向盘控制飞船转向
- [ ] 推力拉杆控制飞船速度
- [ ] 磷光绿矢量美学正确渲染
- [ ] CRT 后处理效果可见
- [ ] 飞船到达黑洞触发关卡完成
- [ ] HP 归零触发关卡失败
- [ ] 所有关卡配置值在 game_config.json 中
