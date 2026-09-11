# UI / HUD 阶段交接规格

状态：完整实现已完成，等待制作人试玩审阅。

本文是下一位负责人实现 UI/HUD 的唯一阶段规格。玩法与剧情事实仍以 `GDD.md`、`CONTENT_SCOPE.md` 和 `N7_REVIEW.md` 为准。

## 制作人确认的目标

### 开始菜单

- 开始游戏
- 加载游戏
- 设置
- 退出游戏

现有三槽本地存档能力必须保留。开始游戏和加载游戏可以进入各自的槽位选择子界面，不能删除已有的损坏存档提示与删除重建能力。

### 暂停菜单

- 继续游戏
- 返回主菜单
- 保存游戏
- 加载游戏
- 设置
- 退出游戏

暂停层必须 `PROCESS_MODE_ALWAYS`，但不能改变对白演出和世界暂停原因的既有引用计数语义。

### 设置

- 音乐音量滑杆：最左 0%，最右 100%，默认 100%。
- 音效音量滑杆：最左 0%，最右 100%，默认 100%。
- 设置需要本地持久化，并分别控制 `Music` 与 `SFX` 音频总线。没有音乐素材时也要建立稳定的 `Music` 总线，不能用一个滑杆同时改 Master。

### HUD

- 左上角用心形图标显示生命值。
- 生命值下方显示当前任务。现有内容只有“寻找阿见”属于任务；剧情状态文本、机关提示和调试信息都不能伪装成任务。
- 左下角是胃袋栏。豆子为默认主位，当前主位图标较大；相邻已吞食物品显示在两侧且较小。
- Q/E 切换时图标丝滑横移，切换逻辑沿用 `StomachInventory.selected_index`，动画不能修改库存事实。
- 调试状态可以保留在 debug 构建或开发开关下，但正式 HUD 不显示当前的长文本列表。

## 已接入的视觉基线

| 用途 | 仓库资源 | 当前接入点 |
| --- | --- | --- |
| UI 面板和按钮 | `assets/ui/fantasy/panel.png`、`button.png`、`button_focus.png` | `game/ui/fantasy_ui_theme.tres` |
| 生命值 | `assets/ui/heart.png` | `game/ui/health_display.tscn` |
| 治疗药水 | `assets/items/green_potion.png` | 地图拾取物、地图标记和投射载荷 |
| 豆子 | `assets/items/bean.svg` | 16×16 绿色像素图，左上四个浅绿高光像素 |
| 洞穴装饰 | `assets/items/yellow_wand.png` | `yellow_wand_decoration.tscn`，洞穴内 5 个可编辑实例 |

项目默认纹理过滤为 nearest。Kenney 边框通过 `StyleBoxTexture` 九宫格集中配置，后续换图或改色只修改 Theme，不要逐按钮覆盖贴图。

## 当前实现边界

- `MenuController` 已改为 `menu_controller.tscn` 的页面协调器，开始、暂停、槽位和设置布局均由独立场景持有。
- `AudioSettingsStore` 将两个滑杆保存到 `user://settings.cfg`；`default_bus_layout.tres` 定义 `Music` 与 `SFX`，现有音效已路由至 `SFX`。
- `game_hud.tscn` 已组合心形生命、寻找阿见任务和胃袋轮播；旧文字库存只以隐藏兼容节点保留，不进入正式画面。
- 胃袋显示当前项与左右相邻项；只有两个槽时不重复绘制同一邻项。连续 Q/E 会接管旧 Tween。
- “寻找阿见”只读取现有剧情任务和 flag；没有把其他 `goal_changed` 文本当作任务。
- 尚未添加背景音乐素材，但音乐总线和设置接口已稳定，可在 N8 直接接入播放器。
- 没有新增 EventBus、Service Locator 或全局演出控制器。

## 当前场景结构

以下控件应以 `.tscn` 和 Theme 为主要编辑入口，脚本只负责状态绑定、输入和 Tween：

```text
MenuController.tscn
├─ MainMenuScreen.tscn
├─ PauseMenuScreen.tscn
├─ SaveSlotPanel.tscn
│  └─ SaveSlotRow.tscn × 3
└─ SettingsPanel.tscn（开始/暂停共用）

GameHud.tscn
   ├─ TopLeft
   │  ├─ HealthDisplay
   │  └─ QuestDisplay
   └─ InventoryCarousel
```

`menu_controller.gd` 只作为页面协调器；按钮、容器、间距、锚点和资源引用已经迁入场景，制作人可在 Godot 编辑器中直接调整。

## 已完成的实施顺序

1. 已建立 `Music`/`SFX` 总线、设置数据和持久化测试。
2. 已把共享设置页、开始菜单和暂停菜单拆成可编辑场景，并保留三槽存档故障路径。
3. 已将 HUD 拆成可编辑场景，完成心形生命与仅“寻找阿见”的任务显示。
4. 已实现胃袋图标数据映射、两侧缩小布局与 Q/E 横移 Tween。
5. 已增加键盘焦点、Escape 返回、滑杆数值标签和 768×480 原生视口门禁。
6. 已通过 N1–N7 完整回归；下一步是制作人试玩审阅。

## 最低验收门禁

- 新游戏、读取、保存、删除损坏槽、返回主菜单和退出路径均可达。
- 两个音量滑杆的 0/100 边界、默认值、重启恢复和音频总线映射有自动测试。
- 暂停时菜单动画和输入工作，世界、对白与已有演出暂停语义不回归。
- 生命变化立即更新心形；任务栏只在“寻找阿见”有效期间显示。
- 胃袋在空库存、单物品、满重量和存读档恢复后索引合法；连续 Q/E 不重叠 Tween、不跳项。
- 720p 及至少一种不同宽高比下不遮挡关键画面或越界。
- `tests/run_tests.gd` 最终输出 `UI/HUD TESTS PASSED (INCLUDING N1-N7 REGRESSION)`。
