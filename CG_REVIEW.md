# CG 试验场审阅

状态：制作人提供的首批舔脚 CG 序列帧已接入，等待实机节奏审阅。

## 本轮范围

- 选择“舔一下丽丝的脚”或“舔她的脚（阿见）”后，右侧对话保持可见且输入锁定，左侧安全区播放舔舐 CG。
- 同一个 `LickCg` 场景组合制作人提供的蛇头、4 帧信子、3 帧人类脚部反应；蛇头按近景透视放大，信子由嘴部向上倾斜约 30° 覆盖脚掌。怪物脚暂时保留代码占位回退，不复制播放逻辑。
- 演出按 `淡入 → 蛇头靠近 → contact → 信子伸出/脚趾蜷缩 → 脚趾张开 → reaction_peak → 收回 → 淡出` 播放。
- `presentation` 数据入口保留 `cg_id`、`variant`、`portrait_expression`，以后可增加非舔舐 CG，而不用把剧情条件写进表现节点。
- 播放支持 await、重播替换、显式取消；死亡、读档、换会话会唤醒旧等待者，旧 Tween 不能推进新剧情。

## 试验场

在 Godot 中打开 `game/art_review/cg_review.tscn` 并运行当前场景（F6）。

- `R`：重播。
- `V`：依次切换丽丝、阿见、怪物脚占位变体，便于对比角色微调。
- `Esc`：取消。

右侧深色区域模拟正式对话框占用，CG 只在左侧安全区内按视口自适应缩放。人类脚、蛇头和信子来自 `assets/cg/lick/`；怪物脚仍是结构占位。

## 在 Godot 编辑器中调整

- 打开 `game/cg/lick_cg.tscn`，在 2D 视图选择 `Stage/Foot`、`Stage/SnakeRig/SnakeHead` 或 `Stage/SnakeRig/Tongue`，可直接拖动，并用 Transform 调整缩放、旋转。`SnakeRig` 是蛇头靠近动画的共同父节点，不要把角色差异写到这里。
- 打开 `game/cg/variants/lisi_foot.tres` 或 `ajian_foot.tres`，在 Inspector 的“角色脚部微调”分组分别调整 `foot_offset`、`foot_scale`、`foot_rotation_degrees`、`foot_tint`。
- `.tscn` 的节点 Transform 是所有角色共享的基础构图；`.tres` 是单个角色叠加的微调。新增角色时复制一个 `.tres` 并在 `CgPlayer` 的稳定 variant 映射中登记即可，无需复制动画代码。

## 接入点

- `game/cg/cg_player.tscn`：通用表现播放器与生命周期边界。
- `game/cg/lick_cg.tscn`：可在 2D 编辑器拖放的脚、蛇头与信子基础构图。
- `game/cg/lick_cg.gd`：舔舐时间线、序列帧切换和自适应舞台。
- `game/cg/lick_cg_variant.gd` 与 `game/cg/variants/*.tres`：各角色脚部颜色、比例、位置和旋转微调。
- `game/story/story_graph.json`：具体选项声明 `presentation`。
- `GameSession.play_cg()`：剧情与表现之间唯一桥接入口。

CG 不拥有剧情 flag、物品或存档状态；剧情 action 仍由 `StoryDirector` 先提交一次，演出只负责呈现。

## 验证

2026-09-14 使用 Godot 4.7.2：

```powershell
godot --headless --path . --script res://tests/cg_tests.gd
godot --headless --path . --script res://tests/run_tests.gd
```

结果：`CG TESTS PASSED`；`UI/HUD TESTS PASSED (INCLUDING N1-N7 REGRESSION)`。本机受限环境仍会报告无法写入 `user://logs` 与根证书读取警告，不影响退出码和测试结论。

## 制作人重点检查

1. 左侧构图是否适合正式 768×480 画面。
2. 蛇头靠近、接触、脚趾反应和收回的节奏是否合适。
3. CG 播放期间保留右侧对白与头像是否符合预期。
4. 人类脚上排三帧的蜷缩/张开顺序是否自然，怪物脚何时补正式变体。
