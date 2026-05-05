# Level 2 — Spasim (1974)

> *"The universe at 10 frames per second."*

## 1. Overview

Spasim 关卡模拟 1974 年 PLATO 系统上的世界首款 3D 网络游戏 **SPASIM**。玩家通过命令行终端输入文字指令操控飞船，在橙色等离子屏美学下导航至黑洞目标。操控方式从 Level 1 的物理控件彻底切换为键盘文本输入，呈现早期计算机终端的操作体验。

**时代标识**：进入关卡时显示 "1974 — Spasim" + PLATO 终端启动动画

## 2. Player Fantasy

- 感觉自己坐在 1974 年的 PLATO 终端前，敲击橙色等离子屏幕上的命令
- 每次输入命令后等待星图更新，体验早期计算机的"缓慢但确定"的反馈节奏
- 命令行操控带来的策略性——不能实时微操，必须提前规划航向和速度
- 从 Level 1 的直觉操控"降级"到文字操控，产生"技术退步"的荒诞感

## 3. Detailed Rules

### 3.1 命令输入系统

- 屏幕下方 1/4 区域为命令行区（`>` 提示符 + 闪烁光标）
- 玩家通过键盘输入命令文本，按 Enter 执行
- 支持的命令不区分大小写
- 无效命令显示 `ERROR: UNKNOWN COMMAND`，不消耗游戏时间
- 输入时暂停游戏更新（命令输入期间飞船保持当前状态）

### 3.2 命令列表（6 个）

| 命令 | 参数 | 说明 |
|------|------|------|
| `HEAD <angle>` | 0~360 | 设定航向角（0=北，顺时针） |
| `THRUST <0-3>` | 0~3 | 设定速度档位：0=停止、1=慢速、2=巡航、3=快速 |
| `AIM` | — | 进入瞄准模式（WASD 移动准星，Enter/F 射击，Esc 取消） |
| `FIRE` | — | 发射相位炮（AIM 模式下朝准星方向，否则朝当前航向） |
| `SCAN` | — | 扫描周围空间，同时显示飞船状态和到黑洞的方位/距离 |
| `HELP` | — | 显示命令列表 |

### 3.3 瞄准模式

- 执行 `AIM` 后进入瞄准模式
- 屏幕中央出现准星，用 W/A/S/D 移动准星
- 按 Enter 或 F 退出瞄准模式并射击
- 按 Esc 取消瞄准，回到命令行

### 3.4 导航与到达

- 黑洞在3D场景中显示为黑洞球体+吸积盘
- 玩家需要通过 `SCAN` 定位黑洞方向，用 `HEAD` 设定航向
- 当飞船与黑洞距离 < 到达阈值时，关卡完成

### 3.5 帧率与更新

- 游戏以 10 FPS 更新
- 每帧更新：飞船位置、碰撞检测
- 命令在下一帧生效（模拟早期计算机的延迟感）

## 4. Formulas

### 航向与位移

```
heading_rad = heading_deg * PI / 180

velocity = speed_tier * speed_base * delta
vx = velocity * sin(heading_rad)
vz = -velocity * cos(heading_rad)
```
vz = velocity * cos(heading_rad) * cos(pitch_rad)
vy = velocity * sin(pitch_rad)
```

### 碰撞检测

```
distance_to_target = sqrt((dx*dx) + (dy*dy) + (dz*dz))
collision_threshold = object_radius + ship_radius
hit = distance_to_target < collision_threshold
```

### 相位炮伤害

```
phaser_damage = base_damage / (distance / 1000 + 1)
```

## 5. Edge Cases

| 场景 | 处理 |
|------|------|
| 输入空命令 | 忽略，显示新提示符 |
| HEAD 无参数 | 显示 `ERROR: HEAD <angle>` 提示正确格式 |
| HEAD 超出范围 | 钳制到 0~360 |
| THRUST 超出范围 | 钳制到 0~3 |
| FIRE 时未瞄准 | 朝当前航向发射 |
| HP 归零 | 关卡失败，显示 "SYSTEM FAILURE"，从关卡开头重试 |

## 6. Dependencies

- **共享资源**：
  - `assets/shaders/advance hologram.gdshader` — 全息材质（应用到所有 3D mesh）
  - `assets/shaders/BlackHole.gdshader` — 黑洞效果
  - `assets/shaders/accretion_disk.gdshader` — 吸积盘效果
  - `assets/spasim-main/meshes/*.obj` — Spasim 原始模型
  - `assets/data/game_config.json` — 关卡配置值
- **输入系统**：纯键盘输入（无鼠标、无物理控件交互）
- **场景结构**：独立场景，不依赖 cockpit.tscn
- **音效**：
  - 键盘敲击音（每次按键）
  - 命令执行确认音（低沉蜂鸣）
  - 相位炮发射音

## 7. Tuning Knobs

所有值应在 `game_config.json` 的 `spasim` 节点下配置：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `speed_base` | 50.0 | 每档基础速度（单位/秒） |
| `speed_tiers` | [0, 1, 2, 3] | 速度档位乘数 |
| `hp_max` | 100 | 最大HP |
| `blackhole_arrival_dist` | 200.0 | 到达黑洞的距离阈值 |
| `scan_range` | 5000.0 | 扫描范围 |
| `target_fps` | 10 | 目标帧率 |

## 8. Acceptance Criteria

- [ ] 关卡可独立运行（F6 运行 level-2-spasim.tscn）
- [ ] 输入 `HEAD 180` + Enter 后飞船转向 180°
- [ ] 输入 `THRUST 2` 后飞船开始巡航移动
- [ ] 输入 `SCAN` 后显示飞船状态+周围物体方位/距离
- [ ] `AIM` 进入瞄准模式，WASD 移动准星，Enter/F 射击
- [ ] `FIRE` 发射相位炮，有视觉效果
- [ ] 3D 全息材质（橙色边缘光+扫描线）应用到所有 mesh
- [ ] 帧率锁定在 10 FPS
- [ ] 飞船到达黑洞触发关卡完成
- [ ] HP 归零触发关卡失败
- [ ] `HELP` 显示 6 个命令
- [ ] 所有关卡配置值在 game_config.json 中
