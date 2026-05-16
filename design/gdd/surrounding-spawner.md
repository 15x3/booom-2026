# Surrounding Spawner — 环绕式生成空间

**Game**: Event Horizon (BOOOM2026)
**Level**: Level 4 — Star Fox (轨道射击)
**Status**: Approved — Ready for Implementation
**Created**: 2026-05-08

---

## Overview

将 Level 4 的敌人波次系统从"正面飞入 + 场景 Marker 节点"重构为"全方位环绕式生成 + 数据驱动配置"。敌人可从前/左/右/上/下五个方向进入战场，每个方向有独特的入场动画，波次结构完全由 JSON 配置驱动。

---

## Player Fantasy

"敌机从四面八方切入战场" — 玩家不再是面对一串正面飞来的靶子，而是需要时刻警惕侧翼包抄、头顶俯冲、脚下跃起的全维度威胁。配合 Star Fox 经典的 V 字编队和散兵线，营造太空大战的紧张感。

---

## Detailed Rules

### 1. 五区生成空间 (SpawnArea)

SpawnArea 是 PathFollow3D 的子节点，跟随玩家移动。由 5 个 Area3D 组成，每个携带一个 BoxShape3D 定义采样体积：

| Region | Position (local to PathFollow3D) | BoxShape Size | 说明 |
|---|---|---|---|
| FrontSpawn | (0, 0, -250) | 200×150×5 | 正前方竖直面 |
| LeftSpawn | (-125, 0, -125), Y=90° | 200×150×5 | 左侧竖直面 |
| RightSpawn | (125, 0, -125), Y=90° | 200×150×5 | 右侧竖直面 |
| TopSpawn | (0, 125, -125) | 200×5×150 | 顶部水平面 |
| DownSpawn | (0, -125, -125) | 200×5×150 | 底部水平面 |

尺寸依据：Camera FOV=70°, far=250。在 z=-125 处水平可见约 182 单位，取 200 留边距；垂直可见约 130，取 150 留边距。

### 2. Region Resolver

代码中的字符串到 Area3D 节点映射：

```gdscript
var spawn_regions: Dictionary = {}

func _setup_scene() -> void:
    var spawn_area = $TrackPath/PathFollow3D/SpawnArea
    spawn_regions = {
        "FrontSpawn": spawn_area.get_node("FrontSpawn"),
        "LeftSpawn": spawn_area.get_node("LeftSpawn"),
        "RightSpawn": spawn_area.get_node("RightSpawn"),
        "TopSpawn": spawn_area.get_node("TopSpawn"),
        "DownSpawn": spawn_area.get_node("DownSpawn"),
    }
```

注意：GDScript 不支持 `@onready` 字典字面量引用 `$` 路径，必须在 `_ready()` / `_setup_scene()` 中赋值。

### 3. 位置采样函数

#### `get_random_local_in_box(region_name: String) -> Vector3`

在 BoxShape 的局部空间内随机采样。返回值是相对于 Area3D 节点的局部坐标。

```gdscript
func get_random_local_in_box(region_name: String) -> Vector3:
    var area: Area3D = spawn_regions.get(region_name)
    if area == null:
        return Vector3.ZERO
    var shape: BoxShape3D = area.get_node("CollisionShape3D").shape
    var half := shape.size * 0.5
    return Vector3(
        randf_range(-half.x, half.x),
        randf_range(-half.y, half.y),
        randf_range(-half.z, half.z)
    )
```

#### `get_spawn_position(region_name: String, entry_z: float) -> Vector3`

完整的位置生成流程：

1. 调用 `get_random_local_in_box()` 获取局部采样点
2. 通过 `area.transform` 转为 PathFollow3D 局部坐标
3. **Z 轴覆盖**：在 PathFollow3D 局部空间中替换 Z 为 `entry_z`
4. 通过 `path_follow.global_transform` 转为世界坐标

```gdscript
func get_spawn_position(region_name: String, entry_z: float) -> Vector3:
    var area: Area3D = spawn_regions.get(region_name)
    var local_in_area := get_random_local_in_box(region_name)
    var local_in_path := area.transform * local_in_area
    local_in_path.z = entry_z
    return path_follow.global_transform * local_in_path
```

**Z 轴扰动**（补丁 #2）：同一编队的敌人 entry_z 加 `randf_range(-2.0, 2.0)` 随机偏移，避免所有敌人在同一 Z 平面上显得像纸片。

### 4. 阵型系统 (Formation)

编队偏移量在区域的**局部空间**内定义，`area.global_transform` 自动处理旋转，无需关心区域朝向。

#### 支持的阵型

| Formation | 说明 | 偏移量生成逻辑 |
|---|---|---|
| `scatter` | 随机散布 | 每个敌人独立调用 `get_random_local_in_box()` |
| `v_shape` | V 字编队（经典 Star Fox） | 领队 (0,0,0)，左翼 (-spacing, spacing, spacing)，右翼 (spacing, spacing, spacing)，以此类推 |
| `line` | 横排 | `(i - (count-1)/2) * spacing, 0, 0` |
| `stagger` | 交错排列 | 奇偶行错开半个 spacing |

#### `_spawn_formation(entry: Dictionary)` 伪代码

```
base_local = get_random_local_in_box(entry.region)
offsets = _get_formation_offsets(entry.formation, entry.count, entry.spacing)

for i in range(entry.count):
    offset = offsets[i] if i < offsets.size() else Vector3.ZERO
    final_local = base_local + offset
    entry_z_jittered = entry.entry_z + randf_range(-2.0, 2.0)  // Z 轴扰动
    world_pos = get_spawn_position_from_local(entry.region, final_local, entry_z_jittered)
    _spawn_typed_enemy(entry.type, world_pos, entry.region, entry.entry_z)
```

### 5. 数据驱动波次配置

#### JSON 结构

```json
"starfox": {
    "waves": [
        {
            "trigger_progress": 0.08,
            "label": "编队突袭",
            "enemies": [
                {
                    "type": "enemy_small",
                    "region": "FrontSpawn",
                    "count": 5,
                    "delay": 0.0,
                    "formation": "v_shape",
                    "spacing": 2.5,
                    "entry_z": -200.0
                }
            ]
        },
        {
            "trigger_progress": 0.16,
            "label": "侧翼包抄",
            "enemies": [
                {
                    "type": "enemy_small",
                    "region": "LeftSpawn",
                    "count": 3,
                    "delay": 0.0,
                    "formation": "line",
                    "spacing": 2.0,
                    "entry_z": -30.0
                },
                {
                    "type": "enemy_small",
                    "region": "RightSpawn",
                    "count": 3,
                    "delay": 0.5,
                    "formation": "line",
                    "spacing": 2.0,
                    "entry_z": -30.0
                }
            ]
        },
        {
            "trigger_progress": 0.32,
            "label": "全方位夹击",
            "enemies": [
                { "type": "enemy_small", "region": "FrontSpawn", "count": 4, "delay": 0.0, "formation": "scatter", "spacing": 3.0, "entry_z": -180.0 },
                { "type": "enemy_small", "region": "TopSpawn", "count": 2, "delay": 1.0, "formation": "line", "spacing": 3.0, "entry_z": -25.0 },
                { "type": "enemy_small", "region": "DownSpawn", "count": 2, "delay": 1.0, "formation": "line", "spacing": 3.0, "entry_z": -25.0 },
                { "type": "enemy_medium", "region": "LeftSpawn", "count": 1, "delay": 2.0, "formation": "scatter", "spacing": 2.0, "entry_z": -30.0 }
            ]
        }
    ],
    "wave_triggers_legacy": { ... }
}
```

#### 字段说明

| 字段 | 类型 | 必须 | 默认值 | 说明 |
|---|---|---|---|---|
| trigger_progress | float | 是 | — | PathFollow3D.progress_ratio 触发阈值 |
| label | string | 否 | "" | 调试用标签 |
| enemies | array | 是 | — | 敌人生成列表 |
| enemies[].type | string | 是 | — | "enemy_small" / "enemy_medium" / "enemy_boss" |
| enemies[].region | string | 是 | — | "FrontSpawn" / "LeftSpawn" / "RightSpawn" / "TopSpawn" / "DownSpawn" |
| enemies[].count | int | 是 | 1 | 生成数量 |
| enemies[].delay | float | 否 | 0.0 | 波次内的延迟（秒） |
| enemies[].formation | string | 否 | "scatter" | "scatter" / "v_shape" / "line" / "stagger" |
| enemies[].spacing | float | 否 | 2.0 | 编队间距 |
| enemies[].entry_z | float | 否 | -30.0 | PathFollow3D 局部 Z 坐标（FrontSpawn 默认 -200） |

### 6. Spawn Queue（生成队列）

**不使用协程**，用 timer 递减在 `_physics_process` 中 tick，避免生命周期问题。

```gdscript
var _spawn_queue: Array = []

func _check_waves() -> void:
    var ratio := path_follow.progress_ratio
    for i in range(_waves_config.size()):
        if _wave_spawned.has(i):
            continue
        var wave: Dictionary = _waves_config[i]
        if ratio >= float(wave.get("trigger_progress", 1.0)):
            _wave_spawned[i] = true
            _enqueue_wave(wave)

func _enqueue_wave(wave: Dictionary) -> void:
    var enemies: Array = wave.get("enemies", [])
    for entry in enemies:
        _spawn_queue.append({
            "time_remaining": float(entry.get("delay", 0.0)),
            "type": entry.get("type", "enemy_small"),
            "region": entry.get("region", "FrontSpawn"),
            "count": int(entry.get("count", 1)),
            "formation": entry.get("formation", "scatter"),
            "spacing": float(entry.get("spacing", 2.0)),
            "entry_z": float(entry.get("entry_z", -30.0)),
        })

func _process_spawn_queue(delta: float) -> void:
    var remaining: Array = []
    for entry in _spawn_queue:
        entry["time_remaining"] = entry["time_remaining"] - delta
        if entry["time_remaining"] <= 0.0:
            _spawn_formation(entry)
        else:
            remaining.append(entry)
    _spawn_queue = remaining
```

**清理机制**（补丁 #3）：玩家死亡或场景重置时调用 `_spawn_queue.clear()`，防止残留敌人在重开时突然刷出。

```gdscript
func take_damage(amount: float) -> void:
    # ... 现有逻辑 ...
    if hp <= 0.0:
        _spawn_queue.clear()  # 波次清理

func _process_dying(delta: float) -> void:
    # ... 现有逻辑 ...
```

### 7. 入场行为分支 (ENTRY Phase)

`level4_enemy_base.gd` 的 `setup()` 新增参数：

```gdscript
func setup(ship_anchor, path_follow, cfg, track_speed, combat_bounds,
           spawn_face: String = "FrontSpawn", entry_z: float = -30.0) -> void:
    _spawn_face = spawn_face
    _entry_z = entry_z
    # ... 现有逻辑 ...
```

#### `_process_entry()` 分支

| 分支 | 初始 rotation | 运动逻辑 | 摆正时机 |
|---|---|---|---|
| FrontSpawn | (0, 0, 0) | 高速 lerp _relative_z 到 harass_z | abs(_relative_z - target_z) < 1.0 |
| LeftSpawn | (0, +45°, +0.3) | 横移(+X方向)，lerp Z | abs(x) < combat_bounds.x × 1.2（提前 20%） |
| RightSpawn | (0, -45°, -0.3) | 横移(-X方向)，lerp Z | abs(x) < combat_bounds.x × 1.2 |
| TopSpawn | (-25°, 0, 0) | 斜向下飞，lerp Z | y > -combat_bounds.y × 1.2 |
| DownSpawn | (+15°, 0, 0) | 向上弹起，lerp Z | y < combat_bounds.y × 1.2 |

**摆正动画**（补丁 #1）：摆正时机提前到进入边界前的 80% 位置。不等到完全进入才摆正，而是在进入过程中就开始平滑 Tween 旋转（~0.3s），营造"切入航道"的自然感，避免"撞"进视野的突兀感。

**Fallback**: 未识别的 spawn_face 值默认走 FrontSpawn 逻辑。

---

## Formulas

### 可视距离计算

Camera FOV = 70°, position (0, 2, 5), rotation (-8.6°, 0, 0), far = 250

在距离 D 处的水平可视宽度：
```
visible_width(D) = 2 × D × tan(FOV / 2) = 2 × D × tan(35°) ≈ 1.4 × D
```

| 距离 | 水平可视宽度 | 垂直可视高度 |
|---|---|---|
| D = 125 (侧面/上下面) | ~175 | ~130 |
| D = 250 (正面) | ~350 | ~260 |

### 入场时间估算

FrontSpawn (entry_z = -200, harass_z ≈ -15):
- 距离 ≈ 185 单位
- entry_speed = 60 → ~3 秒
- 旧 ease_weight = 4.0 → ~1.5-2 秒（指数衰减）

FlankSpawn (entry_z = -30, 进入 combat_bounds):
- 侧向距离 ≈ 125 - 6 = 119 单位
- entry_speed = 60 → ~2 秒

---

## Edge Cases

1. **轨道弯曲时的侧翼生成**：当轨道有弯道（如 x=+40 处），PathFollow3D 的 forward 方向会偏转。由于 SpawnArea 是 PathFollow3D 子节点，它会自动跟随旋转，侧翼面的朝向始终垂直于当前前进方向。**无需特殊处理**。

2. **同一波次内多区域同时生成**：delay 参数控制时序。同一波次的 LeftSpawn (delay=0) 和 RightSpawn (delay=0.5) 会有 0.5 秒的视觉间隔。

3. **编队超出 BoxShape 边界**：V 字编队的偏移量可能超出 BoxShape 尺寸。`_spawn_formation` 中对最终位置做 clamp 到 shape.size/2。

4. **玩家死亡时队列未清空**：`take_damage()` 中 hp<=0 时调用 `_spawn_queue.clear()`，`_process_dying` 不再 tick 队列。

5. **场景卸载时的 await 残留**：不使用 await，纯 timer 驱动，不存在此问题。

---

## Dependencies

- `level_4_starfox.gd` — 波次系统、Region Resolver、Spawn Queue
- `level4_enemy_base.gd` — ENTRY 行为分支
- `game_config.json` — waves 配置数据
- `level-4-starfox.tscn` — SpawnArea BoxShape 节点

---

## Tuning Knobs

| 参数 | 位置 | 默认值 | 说明 |
|---|---|---|---|
| BoxShape sizes | .tscn | 200×150×5 等 | 生成区域体积 |
| entry_z per wave | game_config.json | -30.0 (侧面) / -200.0 (正面) | 敌人出现深度 |
| entry_z jitter | 代码 | ±2.0 | 同编队 Z 轴扰动 |
| formation spacing | game_config.json | 2.0 | 编队间距 |
| flank straighten threshold | 代码 | combat_bounds × 1.2 | 侧翼摆正提前量 |
| straighten tween duration | 代码 | 0.3s | 摆正动画时长 |

---

## Acceptance Criteria

1. [ ] 5 个 SpawnArea BoxShape 尺寸正确，TopSpawn 不再异常偏小
2. [ ] `get_spawn_position()` 从任意区域采样，坐标正确（可视化验证）
3. [ ] 波次完全由 JSON 配置驱动，不再依赖 SpawnMarkers 节点
4. [ ] Spawn Queue 在 `_physics_process` 中 tick，无 await
5. [ ] 玩家死亡时 `_spawn_queue.clear()` 正确执行
6. [ ] FrontSpawn 敌人保持原有 ENTRY 行为（回归测试）
7. [ ] Left/RightSpawn 敌人侧向滑入，提前 20% 开始摆正旋转
8. [ ] TopSpawn 敌人俯冲入场，带 pitch 偏移
9. [ ] DownSpawn 敌人上跃入场
10. [ ] V 字编队在任意面正确显示（自动跟随区域朝向）
11. [ ] 同编队敌人有 ±2.0 Z 轴扰动，不显得扁平
12. [ ] SpawnMarkers 节点已删除，`wave_triggers_legacy` 已清理

---

## Implementation Phases

### Phase 1: 场景修正 + 基础设施（无行为变化）
- 修正 5 个 BoxShape3D 尺寸
- `level_4_starfox.gd` 新增 spawn_regions、spawn_queue、位置采样函数、阵型函数
- JSON 配置新增 waves 数组（保留 wave_triggers 作为 fallback）

### Phase 2: Wave 系统切换（所有敌人都用旧 Front 行为）
- 替换 `_check_waves()` + `_spawn_wave()` 为新的队列驱动版本
- `_spawn_typed_enemy()` 新增 spawn_face 参数（暂不传递给 enemy）
- 验证：所有波次正确触发，敌人在正确位置生成

### Phase 3: ENTRY 行为分支（逐一实现）
- `enemy_base.gd` setup() 新增 spawn_face、entry_z 参数
- 实现 `_process_entry_front()`（复用现有逻辑）
- 实现 `_process_entry_flank()`（侧翼滑入 + 提前摆正）
- 实现 `_process_entry_dive()`（俯冲）
- 实现 `_process_entry_rise()`（上跃）
- 摆正动画：Tween 0.3s

### Phase 4: 清理
- 删除 SpawnMarkers 节点及所有子节点
- 删除旧 wave_triggers JSON 字段
- 删除 `_get_path_aligned_position()` 函数
