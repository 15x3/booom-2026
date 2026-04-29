# 事件视界 — 程序开发任务清单

**项目：** 事件视界 (Event Horizon) — "视界限" Jam
**周期：** 3 周 / 每天 2 小时 / 共约 42 小时
**引擎：** Godot 4.6 / GDScript / GL Compatibility / Jolt Physics
**设计文档：** `design/gdd/event-horizon.md`
**核心方向：** 驾驶舱物理操作 + 小地图实时驾驶 + 资源管理生存

---

## 技术架构总览

```
cockpit.tscn                            ← 唯一主场景
├── CockpitInterior/
│   ├── Body (CSGBox3D)
│   ├── ConsolePanel/                   ← 控制台（程序化3D）
│   │   ├── IgnitionBtn [button_control]  ← 点火按钮
│   │   ├── NavKnob [knob_control]        ← 导航旋钮 (NAV/LOCK/SLING)
│   │   ├── FuelValve [knob_control]      ← 燃料阀门 (OFF/LOW/MID/HIGH)
│   │   ├── ThrustLever [lever_control]   ← 推力推杆 (弹弓用)
│   │   ├── LeftPanel [side_panel]        ← 左侧面板
│   │   │   ├── ScanFreqKnob [knob_control]
│   │   │   ├── ScanSwitch [switch_control]
│   │   │   ├── Breaker1-4 [switch_control]
│   │   ├── RightPanel [side_panel]       ← 右侧面板
│   │   │   ├── O2Valve [switch_control]
│   │   │   ├── CoolingKnob [knob_control]
│   ├── MainScreenSlot                  ← 主监视器（小地图）
│   ├── LeftScreenSlot                  ← 前方摄像头
│   ├── RightScreenSlot                 ← 后方摄像头
│   ├── SystemPanelSlot                 ← 系统面板
│   └── CommScreenSlot                  ← 通讯面板
│
├── SpaceEnvironment/
│   ├── BlackHolePlaceholder + AccretionDisk
│   ├── StarfieldPlaceholder
│   └── WorldEnvironment
│
├── PlayerCamera [camera_controller]
│   └── Flashlight (SpotLight3D)        ← 手电筒
│
├── NavigationSystem [navigation_system]
├── ShipResources [ship_resources]      ← 扩展：温度+O2补给+断路器
├── NarrativeManager [narrative_manager]
├── OperationManager [operation_manager]  ← 新增：操作流程管理
├── MaintenanceManager [maintenance_manager] ← 新增：日常维持
│
├── ForwardViewport (320×240 @ 15fps)
├── RearViewport (320×240 @ 15fps)
├── MainMonitorViewport (640×480)       ← 小地图驾驶场
│   └── MiniMapPanel [mini_map]         ← 新增（替换 gravity_map）
├── CommViewport (640×100)
├── SystemPanelViewport (480×160)
│
└── HUD (CanvasLayer)
	├── Crosshair [crosshair]
	├── TransitionPlayer [transition_player]
	└── SlingshotHUD [slingshot_hud]    ← 新增：弹弓进度条
```

---

## 复用说明

### 完全复用（不改）

| 文件 | 说明 |
|------|------|
| `scripts/transition_player.gd` | 过渡动画库 |
| `scripts/comm_panel.gd` | 通讯面板 |
| `scripts/narrative_manager.gd` | 叙事管理 |
| `scripts/crosshair.gd` | 准星 |
| `assets/shaders/CRT.gdshader` | CRT 效果 |
| `assets/shaders/lens_distortion.gdshader` | 透镜扭曲 |
| `assets/shaders/BlackHole.gdshader` | 黑洞可视化 |
| `assets/shaders/accretion_disk.gdshader` | 吸积盘 |
| `scripts/gravity_map.gd` | 保留旧文件做参考，不再使用 |

### 保留并扩展

| 文件 | 改动 |
|------|------|
| `scripts/navigation_system.gd` | 适配小地图到达判定 |
| `scripts/ship_resources.gd` | 新增引擎温度+O2补给+断路器查询 |
| `scripts/system_panel.gd` | 新增温度/断路器/冷却状态 UI |
| `scripts/camera_controller.gd` | 手电筒+射线交互扩展到控件 |

### 大改

| 文件 | 改动 |
|------|------|
| `scripts/cockpit.gd` | 移除键盘S/T/W，接入 OperationManager + MaintenanceManager |
| `scenes/cockpit.tscn` | 新增 ConsolePanel + 侧面板 + 手电筒 + MiniMap |

### 新建

| 文件 | 说明 |
|------|------|
| `scripts/controls/base_control.gd` | 控件基类 |
| `scripts/controls/knob_control.gd` | 旋钮（拖拽旋转+吸附） |
| `scripts/controls/button_control.gd` | 按钮（点击动画） |
| `scripts/controls/switch_control.gd` | 开关（拨动切换） |
| `scripts/controls/lever_control.gd` | 拉杆（拖拽上下） |
| `scripts/controls/side_panel.gd` | 侧面板（开合动画） |
| `scripts/mini_map.gd` | 小地图驾驶系统 |
| `scripts/ship_physics.gd` | 飞船2D物理（潜艇式） |
| `scripts/operation_manager.gd` | 操作流程管理 |
| `scripts/maintenance_manager.gd` | 日常维持管理 |
| `scripts/slingshot_hud.gd` | 弹弓进度条 HUD |
| `scenes/console-panel.tscn` | 控制台场景 |

---

## 系统开发清单

### Phase 1: 控件基础 (预估 6-8h)

**目标：** 所有物理控件可用，可鼠标交互，有动画反馈

- [ ] P1.1 `scripts/controls/base_control.gd` — 基类：碰撞体 + 高亮 + 动画 + 脚本接口
- [ ] P1.2 `scripts/controls/knob_control.gd` — 旋钮：拖拽旋转 + 档位吸附 + value_changed 信号
- [ ] P1.3 `scripts/controls/button_control.gd` — 按钮：点击 + 按下/弹起 Tween
- [ ] P1.4 `scripts/controls/switch_control.gd` — 开关：点击切换 + 拨动动画 + toggled 信号
- [ ] P1.5 `scripts/controls/lever_control.gd` — 拉杆：上下拖拽 + 连续值 + 动画
- [ ] P1.6 `scripts/controls/side_panel.gd` — 侧面板：开合旋转动画 + 碰撞体 + 脚本接口
- [ ] P1.7 `scenes/console-panel.tscn` — 程序化搭建所有 3D 控件 + 侧面板（左/右各一个）
- [ ] P1.8 `camera_controller.gd` 射线交互扩展 — 控件碰撞体 + 手电筒 SpotLight3D

**验收：** 驾驶舱内可见所有控件，鼠标可交互（旋钮拖拽旋转、按钮点击、开关切换、拉杆拖拽、面板开合），有动画反馈。

---

### Phase 2: 小地图驾驶 (预估 8-10h)

**目标：** 主监视器上可驾驶飞船在小地图中移动

- [ ] P2.1 `scripts/ship_physics.gd` — 潜艇式2D物理（转向+油门+惯性+引力拉力+阻力）
- [ ] P2.2 `scripts/mini_map.gd` — 小地图渲染：引力场渐变背景 + 碎片标记 + 目的地标记 + 飞船图标 + 信号强度条
- [ ] P2.3 地图数据驱动 — `nodes.json` 每节点新增 `map_data` 段（尺寸/起始位置/碎片/目的地/引力参数/扫描频率）
- [ ] P2.4 飞船驾驶操控 — NavKnob→转向，FuelValve→油门，实时映射
- [ ] P2.5 碰撞检测 — 飞船与碎片碰撞 + hull 伤害
- [ ] P2.6 引力场效果 — 减速 + 方向拉力（越靠近"黑洞边"越强）
- [ ] P2.7 到达目的地判定 — 飞入目的地半径 → 触发节点切换
- [ ] P2.8 地图数据刷新机制 — 扫描后更新碎片位置 + 显示隐藏目的地 + 数据过期漂移

**验收：** 主监视器显示小地图，飞船可通过物理控件驾驶。有引力场颜色渐变、碎片碰撞伤害、目的地飞入触发。地图数据不自动更新，扫描后刷新。

---

### Phase 3: 操作流程 (预估 6-8h)

**目标：** 完整的操作流程管理，替换键盘输入

- [ ] P3.1 `scripts/operation_manager.gd` — 核心框架：步骤验证 + 错误后果 + 操作状态
- [ ] P3.2 扫描/地图刷新流程 — 打开左面板 → 调频 → 扫描开关 → 刷新地图
- [ ] P3.3 残骸扫描 — 节点2特殊频率 + 叙事文本
- [ ] P3.4 `cockpit.gd` 改造 — 移除键盘 S/T/W 操作，接入 OperationManager
- [ ] P3.5 节点0教学 — 自由探索式 comm_panel 文字引导
- [ ] P3.6 `game_config.json` 更新 — 新增驾驶物理/控件/扫描/弹弓配置段
- [ ] P3.7 `nodes.json` 更新 — 每节点完整 map_data 数据

**验收：** 键盘不再控制扫描/推进。所有操作通过物理控件完成。教学引导玩家找到并操作各控件。扫描流程正确刷新地图数据。

---

### Phase 4: 日常维持 (预估 4-6h)

**目标：** 驾驶期间持续有系统故障需要处理

- [ ] P4.1 `scripts/maintenance_manager.gd` — 断路器跳闸 + O2补给 + 引擎冷却逻辑
- [ ] P4.2 断路器系统 — 随机跳闸 → 对应 SubViewport 冻结 → 面板复位恢复
- [ ] P4.3 O2 补给 — 氧气低时触发 → 右面板操作 → 恢复 10-15%
- [ ] P4.4 引擎冷却 + 温度 — HIGH档积累 → 过热惩罚 → 冷却旋钮降温
- [ ] P4.5 `ship_resources.gd` 扩展 — 新增 engine_temp + o2_supply + breaker 状态方法
- [ ] P4.6 `system_panel.gd` UI 扩展 — 温度条 + 断路器指示灯(×4) + O2待命灯 + 冷却指示

**验收：** 驾驶过程中断路器随机跳闸，对应屏幕冻结。可打开面板复位。O2低时触发补给。引擎温度随操作变化，可冷却。系统面板显示所有新状态。

---

### Phase 5: 特殊节点 (预估 4-6h)

**目标：** 风暴和弹弓节点完整改造

- [ ] P5.1 风暴节点改造 — 环境光关闭 + 手电筒 + 断路器全跳 + 音效碎片提示 + Space减速
- [ ] P5.2 弹弓5步流程 — HIGH阀 → SLING旋钮 → 推力推杆 → 点火 → 时机点火
- [ ] P5.3 `scripts/slingshot_hud.gd` — 弹弓进度条 HUD（_draw 实时绘制）
- [ ] P5.4 弹弓综合判定 — 推力值 + 时机 → ESCAPE / DRIFT / CONSUMED
- [ ] P5.5 结局画面适配 — 三种结局文本 + 过渡动画

**验收：** 风暴期间环境光关闭，只有手电筒可见。弹弓5步操作完整可用，进度条显示，综合判定三种结局。

---

### Phase 6: 收尾 (预估 4-6h)

**目标：** 音效、标题画面、构建

- [ ] P6.1 基础音效集成
  - 控件操作音（按钮点击、旋钮旋转、开关拨动）
  - 引擎声（随油门变化）
  - 碎片碰撞声
  - 断路器跳闸电弧声
  - 风暴碎片接近音效
  - O2/温度报警蜂鸣声
- [ ] P6.2 标题画面 + 操作说明
- [ ] P6.3 全流程测试 + 数值调优
- [ ] P6.4 构建为 Windows 可执行文件

**验收：** 游戏有音效、有标题画面、可完整从头玩到尾、可构建。

---

## 时间估算

| Phase | 预估时间 | 天数 (2h/天) |
|-------|---------|-------------|
| Phase 1: 控件基础 | 6-8h | 3-4 天 |
| Phase 2: 小地图驾驶 | 8-10h | 4-5 天 |
| Phase 3: 操作流程 | 6-8h | 3-4 天 |
| Phase 4: 日常维持 | 4-6h | 2-3 天 |
| Phase 5: 特殊节点 | 4-6h | 2-3 天 |
| Phase 6: 收尾 | 4-6h | 2-3 天 |
| **总计** | **32-44h** | **16-22 天** |
