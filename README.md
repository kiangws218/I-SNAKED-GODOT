# I SNAKED-GODOT

《我蛇了》的独立 Godot 4.7.2 原生剧情项目。

这个仓库只实现剧情模式。旧 `IM-SNAKE` 是只读的玩法事实和内容参考，不是要搬运的代码库。新项目不复制网页引擎、旧 Godot `main.gd`、肉鸽、战役、Boss 挑战、本地双人、移动端或素材候选库。

## 当前阶段

N1：蛇头、连续移动与轨迹身体已完成，等待制作人审阅。

运行主场景会进入 TestArena：WASD/方向键连续转向，按住当前方向以 2 倍速度移动；撞墙或自撞后有 0.5 秒安全转向窗口。N1 只验证移动核心，不包含豆子、敌人或剧情。

## 打开与验证

用 Godot 4.7.2 打开本目录的 `project.godot`。本机已定位到的控制台程序为：

```text
D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
```

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

若安装了 GDA，可以补充执行：

```powershell
gda --version --json
gda script validate --all --project . --json
gda scene validate game/main.tscn --project . --json
gda scene preflight game/main.tscn --project . --json
```

GDA 是效率工具，不是项目依赖。Godot 4.7.2 已完成首次无界面导入，N0 项目契约测试通过；`gda` 当前未加入 PATH，后续可用时再补充其结构化检查。

Godot 4.7.2 官方标准导出模板已安装在 `D:\GodotExportTemplates\4.7.2.stable`。默认模板目录 `%APPDATA%\Godot\export_templates\4.7.2.stable` 使用目录联接指向 D 盘，避免占用空间紧张的系统盘；Windows 与 Web 的 Debug/Release 模板均已验证存在。

## 文档

- `GDD.md`：本项目唯一设计基线，主要来自网页版剧情模式当前行为。
- `CONTENT_SCOPE.md`：剧情、玩法、阶段、素材和验收的防遗漏追踪台账。
- `ARCHITECTURE.md`：最小架构、状态边界和阶段出口。
- `AGENTS.md`：开发规则与阶段审阅流程。
- `N1_REVIEW.md`：N1 交付范围、验证数据、差异与人工手感清单。

本项目仅供个人学习。素材在真正需要时只复制当前阶段用到的最小集合。
