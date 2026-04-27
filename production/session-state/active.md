# Session State — Active

**Last Updated:** 2026-04-27

## Current Task

**S1: 驾驶舱场景 + 监视器渲染** — 进行中，卡在 ViewportTexture 映射问题

## Progress

### S1 阻塞问题：ViewportTexture 不渲染到 3D 屏幕面板

**症状：** 场景运行无错，但 MeshInstance3D（PlaneMesh）屏幕面板显示为纯白，没有 SubViewport 的摄像头画面。

**已尝试：**
1. `ViewportTexture.new()` + `vp.get_path()` → 白屏
2. `ViewportTexture.new()` + `get_path_to(vp)` → 白屏（路径正确：`ForwardViewport`）
3. `await get_tree().process_frame` 延迟一帧设置 → 白屏
4. `mat.cull_mode = CULL_DISABLED` → 白屏
5. `mat.transparency = TRANSPARENCY_ALPHA` → 白屏（已移除）
6. `render_target_update_mode = UPDATE_ALWAYS` → 白屏

**日志确认：**
- 脚本加载配置正常
- SubViewport world_3d 共享设置正常
- ViewportTexture viewport_path 设置正确（`ForwardViewport`、`RearViewport`、`MainMonitorViewport`）
- 无运行时错误

**下一步排查方向：**
1. **检查 PlaneMesh 朝向** — PlaneMesh 可能背面朝向玩家。虽然设置了 CULL_DISABLED，但 UV 映射可能需要翻转
2. **检查 SubViewport 内 Camera3D 是否真的渲染了 3D 内容** — world_3d 共享后，SubViewport 内的 Camera3D 看到的可能只是空场景（因为 3D 节点在主场景树中，不在 SubViewport 内）
3. **关键怀疑：world_3d 共享可能不够** — 可能需要将 SpaceEnvironment 的实例也放进 SubViewport 的场景树中，或者使用不同的方法
4. **替代方案：不用 world_3d 共享，改用 SubViewportContainer** — 在 HUD 层（CanvasLayer）放置 SubViewportContainer 显示摄像头画面，然后将 SubViewportContainer 的渲染结果映射到 3D 屏幕

### S1 已完成的部分
- [x] 目录结构（assets/data/, scripts/, scenes/）
- [x] game_config.json（全部参数）
- [x] scripts/cockpit.gd（主控脚本，含配置加载、监视器切换、CRT 参数应用）
- [x] scenes/cockpit.tscn（完整场景树）
  - SpaceEnvironment（黑洞占位 + 星点）
  - CockpitInterior（CSGBox 外壳 + 3 个 PlaneMesh 屏幕面板 + 系统面板）
  - PlayerCamera（第一人称固定）
  - ForwardViewport / RearViewport（SubViewport 320×240）
  - MainMonitorViewport（SubViewport 640×480）
  - HUD CanvasLayer + MonitorSwitchLabel
- [x] 输入映射（monitor_gravity/forward/scan → 键 1/2/3）
- [x] 主场景设置为 cockpit.tscn
- [ ] **ViewportTexture 映射到 3D 屏幕面板** ← 阻塞中
- [ ] CRT Shader 应用到 SubViewport
- [ ] 最终验收截图

## Key Files Modified This Session

| File | Purpose |
|------|---------|
| `assets/data/game_config.json` | 全局游戏参数（资源/操作/伤害/弹弓/监视器/CRT） |
| `scripts/cockpit.gd` | 驾驶舱主控脚本 |
| `scenes/cockpit.tscn` | 驾驶舱主场景 |
| `project.godot` | 主场景 + 输入映射（自动更新） |

## Technical Decisions

- **方案 C：** SubViewport 内嵌 Camera3D + CRT ColorRect，3D 屏幕面板用 ViewportTexture 引用 SubViewport 输出
- **渲染层分离：** Layer 1 = SpaceEnvironment，Layer 2 = CockpitInterior
- **CRT Shader：** 使用现有 `assets/shaders/CRT.gdshader`（canvas_item 类型），通过 ColorRect 叠加在 SubViewport 内

## Open Questions

1. ViewportTexture 为什么不渲染？可能是 Godot 4.6 中 world_3d 共享的行为与预期不同
2. 是否需要改用 SubViewportContainer + 2D overlay 方案？
3. PlaneMesh 的 UV 方向是否正确？
