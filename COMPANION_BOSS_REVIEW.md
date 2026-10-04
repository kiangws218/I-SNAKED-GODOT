# 可蒂骑乘与磐 Boss 地图审阅

制作人于 2026-10-04 批准这两项增量。独立 Boss 入口为 `game/boss/boss_arena.tscn`，在 Godot 打开后按 **F6** 运行当前场景。第二章营救入口仍为 `game/chapter2_preview.tscn`，完成重逢结伴后查看可蒂骑乘。

## 可蒂同行

- 空座结伴后，可蒂走到蛇颈旁并上蛇；只有动画成功后才提交骑乘关系和一次性结伴奖励。
- 蛇背已有乘客时保留原乘客，可蒂先留在地面；空位后可选「可蒂，上蛇同行」。
- 骑乘时按 Enter 与可蒂对话，选「让可蒂下蛇」即可临时落地；地面清醒时可以再上蛇。主动下蛇不被读档或每帧逻辑强行撤销。
- 先下蛇才能攻击或吞下她；击晕、吞吐后的唤醒与再上蛇沿用现有人物流程。结伴、HP、敌意、上下蛇关系随存档保存。
- 跨地图生成的是实际乘客或保存在当前地图的角色，不把所有旧 NPC 自动迁入；同伴对白不会退回第一章首次见面。

## 独立战斗

保留网页版当前唯一可玩 Boss「巨岩茧母·磐」的玩法。来源核对见 `BOSS_SOURCE_REVIEW.md`。使用 Godot 原生 `CharacterBody2D`、`Area2D`、碰撞形状、场景资源和局部信号实现，未复制旧网页运行时。

第一阶段吐两轮环形或瞄准种子弹，并定时召唤史莱姆。半血进入第二阶段，激活四座蓝晶桩并获得护盾。用蛇身围住蓝晶桩，累计三秒打破一座；离开围圈暂停进度。四桩全破清空护盾并眩晕 Boss。种子撞墙反弹，蛇身反射弹可以反击 Boss；头被 Boss 碰到直接失败，身体被碾压则截尾、散落可回收豆。

WASD/方向键转向，J/空格吐豆，F 放节点，K 断尾，P/Escape 暂停。胜败面板支持 Enter/R 重试；暂停面板也可重新开始。重试销毁这一局的 Boss、弹幕、召唤物、桩进度和结算状态，不写剧情存档。

## 编辑入口

| 要编辑的内容 | Godot 编辑位置 |
| --- | --- |
| 地板、边界、岩石、豆位置与出生点 | `boss_arena.tscn` 的 `Battle/Ground`、`Walls`、`Rocks`、`Supplies`、`SpawnPoints`；2D 面板直接拖动节点，碰撞与表现均在场景里 |
| Boss 外形与碰撞大小 | `rock_cocoon_boss.tscn` 的 `Visual` 和两个碰撞区域；原生 Polygon2D/Line2D 可逐个编辑 |
| HP、移动速度、阶段阈值、护盾、弹幕与召唤节奏 | `boss_tuning.tres`；在 Inspector 修改类型化参数，Boss 节点的 `tuning` 可换为独立配置副本 |
| 蓝晶桩布局与充能时长 | `boss_arena.tscn/Battle/StakeLayout` 下四个实例；`blue_crystal_stake.tscn` 内可改外形、`required_capture_seconds`、`shield_damage` |
| Boss 种子弹与豆补给外形/碰撞 | `boss_seed.tscn`、`boss_bean_pickup.tscn`；每个豆实例的补给量和再生秒数可独立设置 |
| 岩石外形与尺寸 | `rock_obstacle.tscn` 或地图中的各实例；移动和缩放碰撞体会影响原生碰撞和围圈格子 |
| 召唤怪物 | 地图根节点 `summon_scene` 指向已有 `enemy_actor.tscn`；复制为独立场景后用其 HP/速度覆盖项调节 |
| 初始身长、心数、节点数量、场地格子范围、视口 | 地图根节点 Inspector；地图尺寸调整时同时改 `arena_cells` 与边界节点 |
| HUD、暂停和胜败面板 | `boss_arena.tscn/UI` 的原生 Control 节点 |

默认 `stakes_follow_boss_on_activation=true`：四桩编辑位置作为相对 Boss 出生点的偏移，在半血时搬到当时的 Boss 周围并避开实体墙。关闭它后使用作者摆放的固定世界位置。

地图是独立测试切片：初始身长 24、三心、三个节点，方便直接测试围圈；出生点向内移动以容纳蛇尾。22 个作者摆放的豆补给每三秒再生。原网页随机初始地图/豆配置未照搬；Boss 战数值采用现行源码，场地和出生资源均可独立调整。当前外观是可编辑的原生图形占位，未制作新的 Boss 美术素材，也未将战斗接进第二章剧情。

## 验证记录

Godot 4.7.2 + GDA 0.17.0 实测：

| 检查 | 结果 |
| --- | --- |
| 全量脚本编译 | 100 个脚本，`valid=true` |
| 六个 Boss 场景、第二章地图静态校验 | 均 `valid=true` |
| 独立 Boss 180 帧、第二章预览 60 帧 preflight | `started=true`、`ready`、`diagnostics=[]` |
| `tests/boss_arena_tests.gd` | 46 项：真实 P/J/K 与 Enter/R 重试、原生豆命中、弹幕与间隔、反弹、四桩/围圈、召唤、碾压、胜败冻结 |
| `tests/keti_companion_tests.gd` | 61 项：真实 Enter、默认骑乘、满座首次结伴、下蛇、跨地图、读档、森林空中吐出存档恢复、攻击/唤醒/再上蛇、取消动画 |
| `tests/chapter_two_tests.gd` | 209 项，四条完整键盘实操营救路线，结尾断言常态骑乘 |
| `tests/chapter_two_dialogue_tests.gd` | 279 项，结伴后结果对白、骑乘 Enter 和存读档后重复交互 |
| `tests/chapter_two_branch_audit.gd` | 1579 项，120 组原有营救组合；原 240 秒上限因新增动画不足，延长至 600 秒后完成 |
| 原 `run_tests.gd`、`cg_tests.gd`、`audio_architecture_tests.gd` | 全部通过，包含第一章/N1–N7/UI/HUD 与 CG/音效恢复 |
| 原生渲染检查 | 已逐图检查 `review/boss_arena_overview.png`、`review/boss_arena_phase_two.png`、`review/keti_companion_riding.png` |

使用 `gda --user-data-root .godot/<独立测试目录> script run res://tests/<测试名>.gd --timeout 240 --json`；分支审计使用 `--timeout 600`。GDA 在此 Windows 不支持 live daemon，因此实际输入由 Godot `Input.parse_input_event` 注入并等待物理/渲染帧，截图使用原生渲染器。Godot stderr 的系统根证书库读取提示来自本机环境；场景和游戏脚本验证通过。

本轮还修复非零出生点下蛇身绘图坐标、Boss/第二章地板盖住蛇身、Enter 打开人物对白又推进同一输入、读档骑乘后下蛇仍保留运行时免伤等问题。回归测试退出前留出音频混音释放时间，避免测试进程提前退出造成资源假泄漏。

停止线：本次两项切片完成后等待试玩；不自动扩展其他 Boss、完整模式菜单、支线或下一章。
