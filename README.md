# I SNAKED-GODOT

《我蛇了》的独立 Godot 4.7.2 原生剧情项目。

这个仓库以剧情模式为主。旧 `IM-SNAKE` 是只读的玩法事实和内容参考，不是要搬运的代码库。新项目不复制网页引擎、旧 Godot `main.gd`、肉鸽、战役、本地双人、移动端或素材候选库。2026-10-04 制作人另行批准唯一 Boss「磐」的独立原生战斗地图。

## 当前阶段

可蒂结伴骑乘与独立 Boss 切片入口、编辑方式、验证和停止线见 `COMPANION_BOSS_REVIEW.md`。打开 `game/boss/boss_arena.tscn` 按 F6 运行 Boss 地图；打开 `game/chapter2_preview.tscn` 按 F6 试玩营救结伴。

按 T 与蛇背上的任意人物交谈：有适用对白时播放对白，没有时显示“...”，Enter 关闭后继续赶路。可蒂结伴后的闲聊菜单保留；地面互动默认为 Enter。

标题菜单或暂停菜单 → 设置 → 更改键位，可修改 12 项玩法的主键与备用键，支持冲突提示、删除备用键和恢复默认，保存后立即生效并在重启后恢复。Esc 固定返回，菜单/对白继续用 Enter、方向键和数字选项；键位不随存档槽位保存。独立 Boss 场景也加载同一份键位配置。最新验收见 `PASSENGER_BINDINGS_REVIEW.md`。

N7 第一章剧情、状态、存档恢复和自动回归已经完成。正式 UI/HUD 阶段也已实现。丽丝/阿见舔脚选项已接入可等待、可取消、数据驱动的组合动画；制作人提供的人类脚、蛇头与信子序列帧已用于试验场，怪物脚仍保留占位回退。

运行主场景先进入三槽标题菜单；选择新游戏后，可不借助调试键从教学、荒野和可蒂事件玩到第一章森林入口。WASD/方向键转向，J/空格吐出，Q/E 切换胃袋，K 断尾，F 放置节点，回车推进对白，P/Escape 暂停。调试构建仍保留 F1–F4 跨图、F5/F6 存读档与 F9 检查点重试。

## 打开与验证

2026-09-12：本机正式工程已统一为I-SNAKED-GODOT。六名NPC移动动画已验收，制作人批准与可蒂头像、八项试玩优化一起提交推送；反馈清单与验证见`PLAYTEST_FEEDBACK_REVIEW.md`。Godot打开`game/art_review/npc_review.tscn`按F6查看六人，标准重复导入命令见`NPC_ART_PIPELINE.md`，不代表批准整个N8阶段。

用 Godot 4.7.2 打开本目录的 `project.godot`。建议把 Godot 控制台程序加入本机 `PATH`，然后执行：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

办公室电脑已定位到的程序为 `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`；其他电脑使用自己的安装路径。绝对路径不是项目依赖。

若安装了 GDA，可以补充执行：

```powershell
gda --version --json
gda script validate --all --project . --json
gda scene validate game/main.tscn --project . --json
gda scene preflight game/main.tscn --project . --json
```

GDA 是效率工具，不是项目依赖。Godot 4.7.2 已完成首次无界面导入，N0 项目契约测试通过；`gda` 当前未加入 PATH，后续可用时再补充其结构化检查。

CG 试验场可在 Godot 中打开 `game/art_review/cg_review.tscn` 后按 F6 运行；`R` 重播、`V` 切换女性脚/怪物脚、`Esc` 取消。设计边界和验收见 `CG_REVIEW.md`。

## 编辑地图

正式地图不是运行时代码生成。请在 Godot 文件系统面板打开 `game/maps/levels/` 下的地图场景：`Ground`/`Collision` 用 TileMap 面板绘制；NPC、敌人刷出点、豆、剧情物品、洞口、出口、桥桩和剧情区域均可在 2D 编辑器直接拖动。详细步骤见 `LEVEL_AUTHORING.md`。`StoryMapCatalog` 不再保存这些坐标。

办公室电脑的 Godot 4.7.2 官方标准导出模板已安装在 `D:\GodotExportTemplates\4.7.2.stable`。导出模板是本机配置，到 N8 导出阶段才要求每台构建机器分别安装。

## 文档

- `GDD.md`：本项目唯一设计基线，主要来自网页版剧情模式当前行为。
- `CONTENT_SCOPE.md`：剧情、玩法、阶段、素材和验收的防遗漏追踪台账。
- `ASSET_MANIFEST.md`：已选用源资产、代码占位表现和 N7/N8 必需资产缺口的交接清单。
- `ARCHITECTURE.md`：最小架构、状态边界和阶段出口。
- `AGENTS.md`：两套团队共同遵守的开发规则、动态协作方案与阶段审阅流程。
- `HANDOFF.md`：办公室与家庭团队的接手/交出流程、当前停止线和本机配置边界。
- `UI_HUD_HANDOFF.md`：完整菜单、设置、HUD、已选素材、编辑方式和验收门禁。
- `UI_HUD_REVIEW.md`：正式 UI/HUD 交付内容、自动验证与制作人试玩清单。
- `LEAD_ONBOARDING.md`：新团队负责人的 Godot 技术基线、阶段学习路线和成熟项目参考。
- `N1_REVIEW.md`：N1 交付范围与验证记录。
- `N2_REVIEW.md`：N2 资源循环、自动门禁、视觉验收与阶段边界。
- `N3_REVIEW.md`：N3 战斗、NPC、监狱、素材接入与回归证据。
- `N4_REVIEW.md`：N4 地图、机关、会话、三槽存档与回归证据。
- `N5_N6_REVIEW.md`：剧情基础设施、序章垂直切片、视觉与回归证据。
- `LEVEL_AUTHORING.md`：TileMap、角色、机关、出口、物品和刷怪点的编辑器操作指南。
- `N7A_REVIEW.md`：N7A 可视化关卡编排、镜头、转场和验证证据。
- `N7_REVIEW.md`：第一章剧情、角色状态、战斗、机关、结算和存档恢复的审阅证据。
- `PLAYTEST_FEEDBACK_ROUND2.md`：最新八项试玩优化、验证结果与下一轮试玩清单；上一轮见 `PLAYTEST_FEEDBACK_REVIEW.md`。
- `CG_REVIEW.md`：CG 组合结构、试验场操作、剧情接入点与本轮验证。

本项目仅供个人学习。素材在真正需要时只复制当前阶段用到的最小集合。
