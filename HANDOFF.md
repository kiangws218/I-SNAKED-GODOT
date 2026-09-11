# I SNAKED-GODOT 负责人交接

这份文件供办公室与家庭两套 Codex 团队接力使用。制作人始终是第一负责人；持有当前接力棒的主 agent 是当值第二负责人，负责本阶段技术决策、团队调度、集成和交付。

## 当前交接状态

- 主分支：`main`
- 远端：`https://github.com/kiangws218/I-SNAKED-GODOT`
- 当前阶段：N7 与正式 UI/HUD 实现均已完成，等待制作人试玩审阅。
- 停止线：只处理制作人的 UI/HUD 试玩反馈；制作人确认前不得进入 N8 的角色美术、全局音效或构建打磨。
- 当前可玩与验证证据：序章见 `N5_N6_REVIEW.md`，N7 见 `N7_REVIEW.md`。
- 下一工作：按 `UI_HUD_REVIEW.md` 试玩清单验收；实现结构见 `UI_HUD_HANDOFF.md`。
- 同步状态：本次交接完成后，本地 `main` 与 `origin/main` 应指向同一提交；接手时仍需用 `git status`、`git log -1 --oneline` 验证。
- 素材状态：本机 `D:\Kenney_CC0_2D_Library` 保存 Kenney 官方 2D 分类的 145 个完整包、CSV/JSON 索引与同步脚本；仓库只保存当前实际引用的 Tiny Dungeon 最小副本，映射见 `assets/placeholders/kenney/README.md`。
- 历史门禁说明：远端素材提交曾记录跨图环形节点失败；后续 N7 状态修复已解决，本次合并后的完整回归重新通过。

仓库中的 `origin/main` 最新提交是交接事实基线。不要依赖聊天记录中的旧 commit 号；接手时用 `git log -1 --oneline` 确认实际版本。

## 接手顺序

1. 从远端克隆，或在已有仓库执行 `git status` 后再运行 `git pull --ff-only`。不得覆盖、清理或重置来源不明的本地修改。
2. 按顺序阅读：`HANDOFF.md`、`UI_HUD_HANDOFF.md`、`AGENTS.md`、`LEAD_ONBOARDING.md`、`GDD.md`、`ARCHITECTURE.md`、`CONTENT_SCOPE.md`、`ASSET_MANIFEST.md`、`N7_REVIEW.md`。
3. 使用 Godot 4.7.2 打开 `project.godot`。Godot、GDA 和导出模板的绝对路径属于各台机器的本地配置，不是仓库事实。
4. 首次接手或拉取脚本/场景改动后运行：

   ```powershell
   godot --headless --path . --editor --quit
   godot --headless --path . --script res://tests/run_tests.gd
   ```

5. 检查 `AGENTS.md` 的当前阶段门禁。若上一阶段仍等待制作人审阅，只能修复该阶段反馈，不能提前开发下一阶段。
6. 开始阶段开发前，向制作人报告本阶段范围、关键路径、需要激活的半固定角色和出口条件。

新负责人第一次接力还必须达到 `LEAD_ONBOARDING.md` 的上岗基线。已经验证过的知识不在每次换班时重学；后续只按阶段补充官方文档和成熟项目研究。

## 接力棒规则

- 任一时刻只有一个当值团队负责人可以修改、提交和推送主线；另一套团队在正式接手前保持只读。
- 制作人的最新明确指示决定接力棒归属。没有明确换班指示时，以最后一次成功推送并报告交接的团队为当值团队。
- 当值负责人可以按 `AGENTS.md` 动态组织 Luna 子 agent，但架构取舍、跨系统集成、阶段门禁和最终提交由当值负责人亲自负责。
- 子对话角色半固定、人数不固定。优先复用有价值的领域上下文，只向成员补充阶段增量、文件所有权和验收标准。
- 两套团队共享同一事实优先级、GDD、架构边界、测试标准和阶段审阅制度，不能各自维护第二份设计事实。
- 若接手后发现远端状态与本文件不一致，以制作人最新指示、实际源码、测试结果和远端提交为准，并立即修正文档。

## 交出顺序

1. 停在当前阶段边界，确认没有未经制作人批准的下一阶段实现混入。
2. 按修改风险完成定向或完整验证，记录实际命令、结果和尚未解决的风险。
3. 更新受影响的 `GDD.md`、`ARCHITECTURE.md`、`CONTENT_SCOPE.md`、`README.md`、`AGENTS.md`、本文件和当前阶段审阅记录；不复制相同事实到所有文件，只更新各自负责的内容。
4. 检查 `git status`、`git diff --check` 和最终差异，保留对方团队或制作人的非相关修改。
5. 提交并推送到 `origin/main`，然后报告最新 commit、验证结果、已知风险和下一位负责人可执行的第一项工作。
6. 推送成功后接力才算完成。若推送失败，明确说明本地 commit 尚未同步，不能让下一团队按远端继续开发。

## 本机配置提示

- 当前电脑使用：`D:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。
- 家庭电脑可把 Godot 4.7.2 控制台程序加入 `PATH`，或在命令中使用自己的绝对路径。
- GDA 可用时所有命令传 `--json`；不可用时直接使用 Godot 4.7.2 headless 和 TestArena。
- 本机当前未安装可调用的 GDA，因此最近一次交付以 Godot 4.7.2 headless 完整测试作为验证证据。
- 导出模板到 N8 才是必需项，每台机器可独立安装，不提交到仓库。
- 旧 `IM-SNAKE` 只读参考通常位于仓库同级目录；家庭电脑没有该目录时，以本仓库 `GDD.md` 和已经提交的审计结论为准，不因此阻断已明确的工作。

## 本次 UI 视觉交接摘要

- UI 风格入口：`game/ui/fantasy_ui_theme.tres`。面板与按钮使用九宫格，不要把边框复制进各个页面。
- 生命组件：`game/ui/health_display.tscn`；正式 HUD 由 `game/ui/game_hud.tscn` 组合。
- 洞穴 Yellow Wand 位于 `game/maps/levels/cave.tscn/Decorations`，每根都是可人工移动的 `yellow_wand_decoration.tscn` 实例。
- 豆、Green Potion、Heart 和 Yellow Wand 的仓库源文件、Godot `.import` 设置与使用状态见 `ASSET_MANIFEST.md`。
- 标题、暂停、槽位与设置均已拆成可编辑 `.tscn`；`menu_controller.gd` 只负责信号和页面切换。
- 音量设置保存到 `user://settings.cfg`，剧情存档仍由 `SaveStore` 独立管理；两者不能混写。
