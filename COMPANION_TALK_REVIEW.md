# 可蒂同行主动对话

2026-10-08 制作人批准继续实现 T 同伴交谈，完成后同步现有 Git 仓库，并评估设置页改键。基线提交 `293ae22`；沿用 `codex/chapter2-mainline-slice` 审阅分支，不自动扩展地图或下一章。

## 玩家操作

- 骑乘且已经结伴的清醒可蒂：按 T。右下角可蒂头像旁显示按键，本次游戏首次可用时显示三秒「按 T 与可蒂交谈」；下蛇/昏迷/死亡/菜单/过场/对白期间隐藏。
- Enter 主动选取身边最近的地面 NPC、可互动剧情物件或吐出的人物；可蒂不抢占 Enter。既有靠近接触互动与第一章其他乘客的 Enter 入口保留。
- 菜单只有「聊聊现在的事」「问问她的情况」「让可蒂下蛇」「继续赶路」。话题对白可以返回菜单或退出，没有营救奖励、重复生成或重新结伴副作用。下蛇后 T 无效，地面互动可让她再上蛇。
- 打开同伴对白暂停世界；退出恢复原有状态。附近 12 格内有活跃敌人、清醒敌对 NPC 或敌弹，或剧情战斗仍有敌人、自身碰撞危险/受伤保护时间未结束时，T 暂不可用，头像旁显示「先脱离战斗」。
- 当前事情按地图使用通用、森林或洞窟台词；身体话题和开场保留曾受欺负的结果。仅已结伴可蒂跨图纳入这套伤害记忆，不追溯第一章互动的声望/恐惧。

## 修复与编辑

- 修复对白退场时旧按钮仍能接受 Enter/点击并重新打开对白的问题：退场禁用按钮、释放焦点，选择入口校验面板状态与输入锁。
- 修复已结伴可蒂离开第二章地图后受到攻击却不保留受伤对白后果的问题。
- 键位：`project.godot` 的 `companion_talk`，HUD 和设置文字读取 InputMap。
- 头像、短提示和常驻提示：`game/ui/game_hud.tscn` 的 `SafeArea/Companion`、`CompanionHint`。
- 所有对白正文：`game/story/chapter_two.dialogue` 的 `keti_companion*`、`keti_now*` 和 `keti_health*`；路由沿用现有 chapter_two_flow。
- 设置页新增同伴键位行；修改绑定的实现方案另见 `KEYBINDING_EVALUATION.md`，本轮只评估。

## 验证

- `tests/keti_companion_tests.gd`：96 项，真实 T/Enter/方向键、菜单话题与返回、地面人物/物件优先级、退场立即按 Enter、运动暂停、敌人/敌弹/剧情战斗拒绝、昏迷/未结伴/下蛇无效、提示计时、上下蛇、跨图读档、受伤记忆与恢复。
- 森林默认有敌人；安全闲聊测试使敌人暂时失活，独立的战斗限制测试使用活跃原生 EnemyActor 与 EnemyProjectile。输入注入使用 Input.parse_input_event 并刷新缓冲，等待物理与渲染帧。
- 原生 OpenGL 实际渲染检查三图：`review/companion_talk_hint.png`、`review/companion_talk_menu.png`、`review/companion_talk_controls.png`。第四项在对白滚动区内，通过方向键与 Enter 可选择。
- 最终全量脚本：100 个，`valid=true`；HUD 与设置场景静态校验 `valid=true`，第二章预览 60 帧 preflight `started=true/status=ready/diagnostics=[]`。
- 最终 `chapter_two_dialogue_tests.gd` 275 项、`chapter_two_tests.gd` 209 项四条真实键盘主线、`run_tests.gd` 第一章/N1–N7/UI/HUD、`cg_tests.gd` 均通过，`exit_status=0/diagnostics=[]`。
- 验证曾发现退场按钮重入；修复初版使用全局输入锁会让既有流程误判面板仍在等待，已改为只禁用退场按钮并校验面板状态。修正后重新运行上述门禁通过；此前超时运行不作为通过证据。
- 命令为 `gda --user-data-root .godot/<独立运行目录> script run res://tests/<测试名>.gd --timeout 240 --json`，主线用 300 秒。系统根证书读取提示来自 Windows 环境，不是脚本错误；原生渲染截图已实际检查。

本轮完成后停在试玩审阅。Git 同步状态与提交位置以实际日志和远端为准。
