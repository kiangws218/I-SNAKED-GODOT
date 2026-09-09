# I SNAKED-GODOT 内容资产交接清单

更新时间：2026-09-09（N7A 交接）

本清单回答三件事：仓库里已经选用了什么、当前哪些视觉仍是占位、后续剧情还需要补什么。它是制作状态清单，不是素材候选库；本个人学习项目不维护素材许可证清单，也不设置发布阻断规则。

## 1. 同步原则

- 只提交游戏当前实际引用、制作人已确认采用，或交接所必需的源文件。
- `.godot/imported/` 是每台电脑由 Godot 重建的缓存，不提交；`assets/` 下的源文件、`.import` 设置和 `.tres` 资源提交。
- 未采用的旧项目候选素材包不复制。需要替换占位时，只挑选最终会进入场景的最小集合。
- “代码绘制占位”没有遗漏图片：它的可见内容就在对应 `.gd` / `.tscn` 中，这些文件随仓库同步。

## 2. 已选用并随仓库同步

| 稳定 ID | 仓库源文件 | 当前实际使用 | 交接状态 |
| --- | --- | --- | --- |
| `enemy.mushroom.idle` | `assets/enemies/mushroom/idle.png`（256×64，4 帧） | `enemy_actor.tscn` 的蘑菇待机 | 已选用；N8 再补攻击/受伤/死亡表现 |
| `enemy.slime.idle` | `assets/enemies/slime/idle.png`（256×64，4 帧） | `enemy_actor.tscn` 的史莱姆待机 | 已选用 |
| `item.ring_node` | `assets/nodes/ring.png`（16×16） | 环形节点实例 | 已选用；N8 再补四状态统一表现 |
| `portrait.player_snake` | `assets/portraits/player_snake.png`（1254×1254） | 对话框玩家头像 | 已选用；N8 检查与其他正式头像的一致性 |
| `font.ui.zh_hans` | `assets/fonts/fusion-pixel-10px-monospaced-zh_hans.ttf` | 主菜单、暂停菜单和对话 UI | 已选用 |
| `tiles.story_native` | `assets/tiles/story_tiles.svg`、`assets/tiles/story_tileset.tres` | 教学、荒野、森林、洞窟的 TileMapLayer 与碰撞 | 当前生产基线；24px 原生图集，可在 Godot TileMap 面板继续绘制 |
| `sfx.spit` | `assets/audio/spit.wav` | 吐豆/投射物 | 已选用 |
| `sfx.pickup` | `assets/audio/pickup.wav` | 回收豆与拾取 | 已选用 |
| `sfx.node` | `assets/audio/node.wav` | 环形节点放置/回收 | 已选用 |
| `sfx.hurt` | `assets/audio/hurt.wav` | 玩家受伤 | 已选用 |
| `sfx.prison` | `assets/audio/prison.wav` | 监狱成立反馈 | 已选用；N8 可拆分成立/解除专用声 |
| `sfx.interact` | `assets/audio/interact.wav` | NPC 接触提示和对话 UI | 已选用 |

以上源文件及其 Godot `.import` 设置均受 Git 跟踪。导出模板和 Godot 导入缓存不是项目资产，不上传。

## 3. 已随代码同步的占位表现

| 稳定 ID / 对象 | 当前占位所有者 | 当前用途 | 替换阶段 |
| --- | --- | --- | --- |
| 玩家蛇头与身体 | `game/player/snake_player.gd`、`game/player/body_chain.gd` | 圆形像素稳定绘制、受伤闪烁与身体链 | N8 统一美术时评估，玩法不依赖外部贴图 |
| 豆、铁剑、药水和角色投射物 | `game/projectiles/bean_projectile.gd` | 颜色/形状区分载荷 | 第一章实体接入时先保证辨识；N8 统一像素素材 |
| 蘑菇针刺弹 / 哥布林箭矢基础形态 | `game/projectiles/enemy_projectile.gd` | 当前敌方弹体绘制 | 哥布林实现时区分箭矢；N8 统一表现 |
| 可蒂、阿杰、丽丝、阿见、巴克、米罗 | `game/actors/npc_actor.gd` | 通用人物轮廓；N7A 已在地图预摆位置 | N7B–N7D 接入角色状态，N8 换正式造型与头像 |
| 教学三豆门 | `game/maps/fragile_gate.gd` | 门体、命中进度 | N8 统一地图道具风格 |
| 森林桥桩与充能环 | `game/maps/bridge_pillar_visual.gd` | 充能进度、完成反馈与动画接点 | N7 吊桥落下接入，N8 定稿色板 |
| 铁剑、汤、药水、洞口等地图标识 | `game/maps/map_prop_visual.gd` | 编辑器与运行时临时辨识 | 对应 N7 剧情实体接入时替换 |
| 剧情拾取物 | `game/maps/authoring/story_pickup.gd` | 可编辑拾取点和本地动画接点 | 对应 N7 剧情实体接入时替换 |
| 出生点、刷怪点和物品点标记 | `game/maps/authoring/` | 仅供 Godot 编辑器摆放与辨识 | 工具标记，不需要正式游戏美术；运行时默认不显示 |

## 4. 后续必需资产缺口

### N7：随真实剧情实体接入

- 角色地图造型：可蒂、阿杰、丽丝、阿见、巴克、米罗；需要统一朝向、受伤/昏迷或被绑状态的最小动画集合。
- 角色对话头像：上述六名角色；姓名和稳定 `npc_id` 必须与剧情数据一致。
- 哥布林弓箭手：待机、移动、攻击预警/射击、受伤、死亡；另需可辨识箭矢。
- 第一章物品：铁剑、汤锅/热汤、治疗药水；环形节点继续使用现有 `ring.png`。
- 森林/河岸/洞窟/营地道具：洞口、吊桥、桥桩、营地与必要遮挡物。吊桥需可由本地 `AnimationPlayer` 表现“落下并开放碰撞”。
- 剧情状态变体：阿见被绑/清醒/危急/骑乘，角色昏迷、尸体或骨头；只为实际分支制作，不建立无用全套动画。
- 第一章关键反馈音效：吊桥落下、哥布林射击/命中、汤/药水剧情反馈。优先复用现有通用音效，只有辨识不足时新增。

### N8：统一视觉与发布前打磨

- 蘑菇攻击、受伤/死亡动画；环形节点未激活、激活、连接、受损四状态。
- 豆、铁剑、药水、敌方弹体、门、桥桩等仍登记为代码占位的统一像素表现。
- 项目标题 Logo、菜单视觉、角色头像统一裁切与色板。
- 专用豆反弹、监狱成立/解除音效；背景音乐仅在先定义使用场景、循环/切换和音量验收后加入。
- 四张地图 TileSet 的细化只扩展当前 `story_tileset.tres` 或明确替换它，不再并行维护第二套地图事实。

## 5. 交接者核对方法

1. 拉取 `origin/main` 后，用 Godot 4.7.2 打开 `project.godot`，等待首次导入完成。
2. 打开 `game/maps/levels/` 的四张地图，确认 `Ground` / `Collision` 使用 `story_tileset.tres`，预摆对象可在 2D 编辑器移动。
3. 运行 `godot --headless --path . --script res://tests/run_tests.gd`，资源存在性和 TileSet 测试应通过。
4. 新增正式资产时同时更新本文件与 `CONTENT_SCOPE.md` 对应稳定 ID；删除占位前先确认所有实际分支已有替代物。
