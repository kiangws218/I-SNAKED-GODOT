# NPC头像接入

五名角色：ajian/阿见、ajie/阿杰（兼容阿洁）、buck/巴克、lisi/丽丝、miro/米罗。
每人九种表情，默认neutral；未知表情回退neutral。表情顺序沿用可蒂九宫格。
原图备份在assets/portraits/<id>/source.png，桌面原文件未修改。
五人均使用制作人准备的透明素材，只切图、统一留白及最近邻缩放；不再抠图、去背景或清理像素。
替换前的源图保存在assets/portraits/<id>/source_before_transparent.png。当前桌面原文件未修改，布局和对白映射不变。

重复导入：Godot --headless --path . --script res://tools/import_npc_portraits.gd。
源图、脚本及输出哈希未变化时自动跳过。
显示映射在game/ui/npc_portrait_library.gd和dialogue_panel.gd。没有改对白正文、玩法或对话框场景布局。
每名角色统一所有表情的有效范围，居中且切换不抖动。

审阅：打开game/art_review/npc_portrait_review.tscn按F6，右侧按钮切角色和表情；左侧按阿见、阿杰、巴克、丽丝、米罗排列九表情。
专项检查：tests/test_npc_portraits.gd；兼容检查：tests/test_keti_portraits.gd。
本轮本地接入，未提交或推送。
