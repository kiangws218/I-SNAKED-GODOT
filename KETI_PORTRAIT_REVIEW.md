# 可蒂头像试接入

后续美术反馈已实现：竖排姓名位于左侧，头像扩大置于右侧区域。静态布局已迁入game/ui/dialogue_box.tscn，可由制作人在2D编辑器修改；具体步骤见DIALOGUE_ART_LAYOUT.md。旧46×46头像槽描述只代表首轮试接入，不再是当前布局。八项玩法优化由其他对话负责，本美术任务不跟进。

九格原图保留在assets/portraits/keti/source.png。按原图从左到右、从上到下，暂命名neutral、happy、angry、blushing、crying、surprised、tired、smug、terrified，语义仍可由制作人调整。

每格418×418，同一画布原点与缩放规则输出128×128透明PNG。复用NPC前处理中的外围去背景；额外保留底部开放裁切处的白衣，清理小色点，不独立拉伸各表情，不使用AI重绘。没有变化时按源图、程序及输出指纹跳过。

重复导入：godot --headless --path . --script res://tools/import_keti_portraits.gd，然后godot --headless --path . --editor --quit。--force可显式重建。

实际对话：可蒂默认neutral；现有剧情crying标记选crying。expression字段可指定九种表情，未知值回退neutral。玩家仍使用蛇头像，其他角色不残留可蒂图。本次不根据台词自动猜情绪，不修改剧情正文、分支或名字流程。

Godot打开game/art_review/keti_portrait_review.tscn按F6：左侧九表情对照，右侧使用实际DialoguePanel。点击下一种表情或按回车切换。保留原有头像槽46×46；工程中检测到其他玩法/UI反馈正在同步修改，头像接入不覆盖那些修改，不将它们描述为本次已修复。

验证：tests/test_keti_portraits.gd通过，覆盖九种资源及映射、透明背景、哭泣标记、未知表情回退、玩家/旁白切换不串图、DialogueRunner传递头像信息。实际审阅场景已GPU启动捕获。接入过程中同步玩法修改曾使4项旧流程断言失败；2026-09-12两轮反馈统一收口后，头像专项与完整N1–N7/UI/HUD回归均重新通过。按制作人批准，与人物动画和反馈优化一起提交推送；实际同步以git log为准。
