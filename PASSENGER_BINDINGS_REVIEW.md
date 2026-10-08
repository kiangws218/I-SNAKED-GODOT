# 乘客交谈与键盘改键验收

2026-10-08，制作人明确要求 T 适用于蛇背上的所有人物，没有对白时显示“...”，并批准设置页改键。基线 `c982db1`，继续使用 `codex/chapter2-mainline-slice` 审阅分支；本轮不扩展剧情、地图或战斗数值。

## 试玩

- `game/chapter2_preview.tscn` 按 F6。救出并结伴的可蒂仍有原来的四项闲聊菜单。任何其他实际乘客也可按 T；昏迷人物或没有适用骑乘对白的人物显示 ASCII `...`，Enter 或“继续赶路”关闭后保持骑乘。
- T 验证存档的 rider 身份与真实 NPC 子节点一致，不会隔空联系下蛇、胃袋中或另一张地图上的人物。既有战斗、菜单、对白、过场和地图切换限制保留。
- 森林营地结算后的阿见复用原有休息对白，仅有继续探索出口。乘客入口不会转回地面营救、缴费、唤醒或奖励流程。
- 标题菜单或暂停菜单 → 设置 → 更改键位。点击主键/备用键，再按新键；Esc 取消捕获，Backspace 删除备用键。主键不能为空，Esc 固定返回，支持单项恢复和全部恢复。
- 12 项玩法动作可配置，每项最多两个键。动作间重键、同动作重复、组合键和 F1–F12 会被拒绝并说明原因。当前只提供键盘改键。
- 菜单和对白仍使用固定 Enter/方向键/数字 1–9，保留原生空格确认。修改地面互动或移动键不会影响对白确认和导航；死亡界面和 Boss 重试保留固定 UI 操作。
- 配置保存到 `user://controls.cfg`，立即应用，启动时读取；与 `user://settings.cfg` 音量和剧情存档分离。没有配置时使用项目原始默认键，损坏值回退默认，保存失败保留当前绑定。
- `game/boss/boss_arena.tscn` 可独立 F6，直接加载同一配置。Boss HUD、乘客 HUD，以及教学的吐出/节点提示使用当前键位。

## 原生编辑入口

设置页为 `game/ui/settings_panel.tscn` 中的 ScrollContainer、12 个 `key_binding_row.tscn` 实例和恢复按钮；行、文字、间距、滚动区域均可在 Godot 场景树编辑。键位默认值仍由 `project.godot` 的 InputMap 持有。InputBindingsStore 只负责验证、持久化和应用，不持有剧情状态；乘客兜底正文仍在 `game/story/chapter_two.dialogue`。

## 验证

使用 Godot 4.7.2、GDA 0.17.0；所有 script run 使用隔离 user-data-root，避免修改制作人的设置和剧情存档。

- 全量 106 个脚本编译通过。
- `tests/passenger_talk_tests.gd`：51 项通过，实际 T/Enter 验证巴克、米罗、商人、昏迷乘客、唯一座位/错误身份、存读档恢复、下蛇、暂停和战斗拦截，以及阿见原有安全对白及无重复奖励；省略号退出恢复原剧情节点和事实。
- `tests/keti_companion_tests.gd`：98 项通过，保留可蒂闲聊返回/退出、地面互动优先、跨图存读档、主动上下蛇、昏迷省略号、吞吐恢复与战斗限制。
- `tests/input_bindings_store_tests.gd`：配置持久化、冲突、恢复、坏配置、失败回滚与音量隔离通过。
- `tests/input_rebinding_tests.gd`：49 项真实键盘检查通过，包括设置按钮、主/备用捕获、冲突提示、Esc 取消、备用删除、原始默认恢复、配置重新加载、教学提示、新旧键生效/失效、独立 Boss 操作和剧情乘客操作。暂停游戏中的捕获还验证 F5 不穿透存档，取消/返回不误恢复世界。
- `tests/chapter_two_tests.gd`：209 项主线键盘实操通过；`tests/chapter_two_dialogue_tests.gd`：275 项重复对白/结果回归通过。
- `tests/boss_arena_tests.gd`：46 项原生 Boss 回归通过；`tests/run_tests.gd`：原第一章 N1–N7、UI/HUD 回归通过；`tests/cg_tests.gd` 通过。
- HUD、设置页和动作行静态校验通过；第二章启动 preflight 为 `ready`/`started=true`。preflight 提前退出仍有既有资源释放提示，完整测试主动释放后无脚本诊断。运行器另有本机 Windows 根证书读取提示；原生截图环境有 shader cache 目录提示。
- 五张 Godot 原生截图已逐张检查：`review/input_settings.png`、`review/input_settings_actions.png`、`review/input_settings_capture.png`、`review/passenger_talk_hint.png`、`review/passenger_talk_silent.png`。改键面板、滚动列表底部、取消/删除提示、捕获中的按钮状态，以及巴克乘客头像/姓名/主键提示和省略号退出均可见。

当前阶段出口为代码、原生 UI、实际输入与回归完成，并同步现有审阅分支，然后停止等待制作人试玩。
