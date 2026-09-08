# I SNAKED-GODOT

《我蛇了》的独立 Godot 4.7.2 原生剧情项目。

这个仓库只实现剧情模式。旧 `IM-SNAKE` 是只读的玩法事实和内容参考，不是要搬运的代码库。新项目不复制网页引擎、旧 Godot `main.gd`、肉鸽、战役、Boss 挑战、本地双人、移动端或素材候选库。

## 当前阶段

N2：豆子、胃袋、断尾与环形节点已完成，等待制作人审阅。

运行主场景会进入 TestArena：WASD/方向键转向，J/空格吐出，Q/E 切换胃袋，K 断尾，F 放置节点。场内预置 12 节身体、两把铁剑、一瓶药水和三点测试节点充能，可完整验证发射、反弹、落地回收、占长、断尾、节点放置/回收与围圈识别。

## 打开与验证

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

办公室电脑的 Godot 4.7.2 官方标准导出模板已安装在 `D:\GodotExportTemplates\4.7.2.stable`。导出模板是本机配置，到 N8 导出阶段才要求每台构建机器分别安装。

## 文档

- `GDD.md`：本项目唯一设计基线，主要来自网页版剧情模式当前行为。
- `CONTENT_SCOPE.md`：剧情、玩法、阶段、素材和验收的防遗漏追踪台账。
- `ARCHITECTURE.md`：最小架构、状态边界和阶段出口。
- `AGENTS.md`：两套团队共同遵守的开发规则、动态协作方案与阶段审阅流程。
- `HANDOFF.md`：办公室与家庭团队的接手/交出流程、当前停止线和本机配置边界。
- `LEAD_ONBOARDING.md`：新团队负责人的 Godot 技术基线、阶段学习路线和成熟项目参考。
- `N1_REVIEW.md`：N1 交付范围与验证记录。
- `N2_REVIEW.md`：N2 资源循环、自动门禁、视觉验收与阶段边界。

本项目仅供个人学习。素材在真正需要时只复制当前阶段用到的最小集合。
