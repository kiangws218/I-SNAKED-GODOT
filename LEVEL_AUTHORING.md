# 关卡可视化编辑指南

N7A 起，地图中的位置只保存在 `game/maps/levels/*.tscn`。`StoryMapCatalog` 只登记地图场景、标题和尺寸；不要再把坐标写回目录或剧情脚本。

## 地图结构

每张地图固定包含：

```text
MapLayout
├── Ground / Collision   TileMapLayer 地形与墙体
├── Actors               地图 NPC
├── Interactables         门、充能桩和后续机关
├── Pickups               豆子出生点与剧情物品
├── Triggers              出口和剧情触发区域
└── SpawnPoints           玩家入口与剧情敌人出生点
```

在 Godot 中打开对应地图场景，选中节点后用 2D 移动工具拖动。带箭头、十字或圆圈的 `Marker2D` 只在编辑器显示，运行时不会出现提示球。

## 常用操作

- NPC：把 `game/actors/npc_actor.tscn` 拖入 `Actors`，设置唯一 `npc_id`。尚未接入剧情的预摆角色保持 `initially_active = false`。
- 常驻敌人：把敌人场景拖入 `Actors`；剧情中途出现的敌人使用 `enemy_spawn_point.tscn`，设置唯一 `spawn_id` 和 `enemy_kind`。
- 玩家出生点：拖入 `map_entry.tscn`，设置 `entry_id` 和 `facing`。每张地图必须有一个 `default`。
- 地图出口：拖入 `map_exit.tscn`，设置 `target_map`、`target_entry`，需要锁定时填写 `required_flag` 和提示文字；直接拖动 `CollisionShape2D` 的手柄调整范围。
- 剧情区域：拖入 `story_trigger.tscn`，设置稳定 `trigger_id`，调整其 `CollisionShape2D`。
- 豆子：拖入 `item_spawn_point.tscn`，`item_id` 保持 `bean`，并填写不随位置变化的 `spawn_id`。
- 剧情物品：拖入 `story_pickup.tscn`，设置物品类型 `item_id`、实例唯一 `pickup_id`、显示名和是否自动拾取。同类物品复用一个场景，不为每个名字复制脚本。
- 充能桩：拖入 `bridge_pillar.tscn`，设置充能时长、扫描格区域、完成后清除的桥碰撞格和可选 `AnimationPlayer` 路径。

地形形状用 `Ground`/`Collision` 的 TileMap 面板绘制；具有独立状态、碰撞或动画的机关才使用场景。吊桥等后续表现由自己的 `AnimationPlayer` 持有，充能桩只发出完成事实并调用明确配置的完成动画，不建立全局动画总线。

## 稳定 ID

`npc_id`、`spawn_id`、`trigger_id`、`pillar_id` 和 `item_id` 会参与剧情或存档。移动节点可以，改 ID 前必须考虑旧存档迁移。节点名和 NodePath 只服务编辑器组织，不作为持久身份。
