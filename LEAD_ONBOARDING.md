# Godot 团队负责人上岗基线

本文件用于让新的当值负责人迅速达到可接力开发的技术基线。目标不是通读所有资料，而是掌握当前项目真正使用的 Godot 原生能力、理解成熟项目的取舍，并能用源码和测试验证判断。

## 学习原则

1. 先继承本仓库已经确认的设计和架构结论，再研究尚未解决的问题，避免重新发明第二套方案。
2. 引擎行为优先查与 Godot 4.7.2 匹配的官方文档和类参考；`latest` 文档可能描述未发布行为，不能直接作为 4.7.2 事实。
3. 成熟项目用于学习问题拆分、状态所有权、场景组织和验证方式，不按目录复制，也不因为示例使用某种模式就引入本项目没有第二个使用者的抽象。
4. 任何外部方案必须经过四个问题：它解决本项目的什么真实问题、是否适合连续移动的动作 RPG、是否符合当前阶段、如何用测试证明。
5. 已经沉淀到 `GDD.md`、`ARCHITECTURE.md` 和阶段审阅记录的结论无需每次重新研究；只有 API 不确定、出现新系统或证据冲突时才补课。

## 首次接手必须掌握

- Godot 的 Node、Scene、SceneTree、signal 和实例化生命周期。
- `_process`、`_physics_process`、输入分发、暂停与 `process_mode` 的区别。
- `CharacterBody2D`、`Area2D`、`StaticBody2D`、碰撞层/遮罩以及移动与 overlap 的职责边界。
- Scene、脚本、纯数据对象和 Resource 的使用边界；共享 Resource 默认只读，运行时状态只有一个写入口。
- Tween、Timer、signal 连接和异步流程为什么不能直接作为存档状态。
- Godot 项目导入、headless 脚本校验、真实输入测试和运行时错误检查。
- 本项目 `BodyChain`、`StomachInventory`、`BeanProjectile`、`RingNode` 与 `EnclosureDetector` 各自拥有的事实及相互边界。

首次接手不要求提交学习报告。负责人应在开始修改前用一段简短说明复述：当前阶段、停止线、状态所有者、准备修改的边界和验证方式；内容错误时先纠正再开发。

## 随阶段定向学习

| 阶段 | 负责人需要补充的官方主题 | 成熟项目重点 |
|---|---|---|
| N3 | 2D 物理、CharacterBody2D、Area2D、碰撞层、定时伤害和信号生命周期 | 敌人状态、hurtbox/hitbox 边界、NPC 交互去重 |
| N4 | TileMapLayer、TileSet 物理层、场景切换、FileAccess、序列化与资源加载 | 地图所有权、检查点、换图清理、存档迁移 |
| N5 | Control/Container、Tween、暂停处理域、原生 JSON 剧情图 | 对话展示与剧情状态分离、命令白名单和幂等副作用 |
| N6–N7 | 性能分析器、导航/触发区、资源导入和大型场景组织 | 垂直切片、剧情关卡组合、回归设计 |
| N8 | 导出、平台差异、性能监视器和资源清理 | 构建可复现性、压力测试和发布前收口 |

未进入对应阶段时不提前通读或实现这些系统。

## 推荐的外部学习源

- [Godot 官方稳定版最佳实践](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)：场景组织、场景与脚本、Autoload 边界、数据和项目组织。
- [Godot 官方节点与场景基础](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html)：统一节点、场景与实例化心智模型。
- [Godot 官方 Demo Projects](https://github.com/godotengine/godot-demo-projects)：按与引擎匹配的稳定分支选取单个相关 demo，观察原生 API 用法；不要克隆进本仓库。
- [Godot 官方 2D RPG Demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/role_playing_game)：参考 TileMapLayer、角色、地图和 UI 的原生组织方式；版本不匹配时只研究概念。
- [GDQuest Godot 4 Open RPG](https://github.com/gdquest-demos/godot-open-rpg)：参考较完整 RPG 的模块边界、地图切换、对话、库存和 UI；它是回合制教学项目，与本项目的实时连续移动不同，只能选择性借鉴。

需要新的成熟项目样本时，由负责人针对当前问题选择一到两个来源并记录结论，不建立庞大项目收藏，也不把第三方依赖或素材带入仓库。

## 上岗验证

新负责人第一次接力至少完成：

```powershell
git status
git log -1 --oneline
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

随后检查当前阶段相关的一个真实场景和核心脚本，确认测试确实覆盖公开输入/碰撞/signal 路径，而不是只调用内部方法。通过这些检查只表示具备接手条件，不等于制作人已经批准进入下一阶段。
