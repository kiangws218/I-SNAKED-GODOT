# 六名NPC小人导入与审阅

2026-09-12：可蒂移动样板已获制作人确认，同一显示层已扩展到阿洁、丽丝、阿见、巴克、米罗。范围仅含角色小人、站立/行走及对应载荷辨识图，不扩展到全局音效、完整N8打磨或发布。

## 本机唯一开发目录

当前正式工程：`C:\Users\Administrator\Documents\琥珀\I-SNAKED-GODOT`。它由原remote-review目录提升而来，原remote-review路径已移除。

原工程存在未提交修改，完整退役备份在工程外的`C:\Users\Administrator\Documents\琥珀\_project_backups\I-SNAKED-GODOT_before_promotion_20260912`，不作为开发入口，不导入Godot项目列表。桌面原工程快捷方式指向的正式路径仍有效。关闭旧编辑器，再重新打开当前project.godot，避免旧内存场景覆盖新文件。

## 一次配置，重复调用

在工程目录执行：

```powershell
& .\tools\import_npc_sprites.ps1
& .\tools\import_npc_sprites.ps1 -Character miro
& .\tools\import_npc_sprites.ps1 -Character miro -Force
```

其他机器可增加`-GodotPath 'Godot控制台程序的绝对路径'`。脚本优先使用PATH中的godot，本机回退到已验证的D盘Godot 4.7.2。也可直接运行：

```powershell
godot --headless --path . --script res://tools/import_npc_sprites.gd -- --character=miro
godot --headless --path . --editor --quit
```

无Character参数处理全部六人。默认只重建变更项；Force显式重建选中项。旧import_keti_sprite.gd仅为兼容入口，复用同一个实现，不再维护第二套切帧算法。

## 输入和输出

- 输入：`assets/characters/<id>/source.png`，桌面原图的原样副本。
- 配置：`tools/npc_sprite_profiles.json`，记录原图尺寸、12个裁切框、方向、统一缩放及脚部取样规则。新源图改变布局时只改对应配置，不重新让AI猜切片。
- 输出：每人`walk.png`（96×160，3列4行）、`idle.png`（32×40正面中间帧）、`frames.tres`（8个方向动作）、`import_receipt.json`（指纹、输出校验和、逐帧边界与轴线证据）。
- 共用规则：外围近白背景四邻接去除，保留封闭内部浅色区域；按下部身体/脚部轴对齐；12帧共用同一缩放比例，不逐帧独立缩放；nearest缩小后校正整数取样造成的脚底偏差，统一脚底y=38。
- 人物显示高度：可蒂保留已审阅的4倍缩小方式；阿洁/阿见目标32像素，丽丝/巴克34像素，米罗30像素。目标由12帧最大高度控制，姿态差异不会被单独拉伸抹平。
- 缓存指纹覆盖原图、配置、导入程序和输出校验和。未变化时打印SKIP，不读图、不重切帧、不调用AI。程序本身不消耗模型token；由助手调用时只需一条命令及简短结果，不需反复截图或读取全部配置。

程序只用于开发期。运行游戏直接加载已生成PNG和SpriteFrames，不运行去背景或切帧。导入缺少输入、尺寸不符、空帧、越界或裁切会报错并非零退出。源文件不覆盖；receipt仅在输出全部成功后更新。引擎可能提示开发期原始图片读取不能用于导出，此读取不在游戏运行路径中。

## 游戏接入及审阅

六人共用NpcActor的AnimatedSprite2D，根据稳定npc_id选择资源。真实位移决定四方向行走，停止60毫秒内切回站立；短暂缓冲防止渲染帧与物理帧不同步时反复闪切。角色碰撞、交互半径、生命、剧情状态、存档ID和正式地图位置均未改变。

血条统一位于完整人物帧上方。胃袋与角色飞行载荷使用同造型正面帧，飞行载荷按32×40绘制，不挤压成方形。尚无专用倒地/尸体/攻击/骑乘图：倒地用变暗站立帧，骑乘不播放走路；这些仍待后续制作，不视为完稿。

Godot打开`game/art_review/npc_review.tscn`并按F6，可在森林底图中并排看六人绕小方形走动。可蒂单人入口`keti_review.tscn`继续保留。审阅运动只存在于测试场景，不改变正式地图NPC行为。F5仍运行完整剧情游戏。

## 验证与交付状态

- Godot 4.7.2全脚本editor headless导入通过。
- 重复调用确认六人均SKIP；相同输入强制重建应得到相同输出。
- 自动测试通过：透明背景、统一规格、72帧脚底对齐、六人资源/胃袋/载荷映射、真实追击位移驱动四方向、停步及倒地显示。
- 既有N1–N7、UI/HUD完整回归通过，输出ALL SIX NPC VISUAL TESTS PASSED与UI/HUD TESTS PASSED (INCLUDING N1-N7 REGRESSION)。
- 六人审阅场景已实际GPU启动并捕获画面。根证书、user日志和全局编辑器设置写入提示为当前受限环境问题，无角色脚本或资源错误。

首轮接入基于fd2dbd87609a14da1be8a5f21f7a17359af1a398。六人移动已验收；制作人批准角色、管线和头像纳入本轮八项试玩优化提交并推送。实际同步以HANDOFF.md及git log核对，不再将首轮本地状态当作当前交接状态。
