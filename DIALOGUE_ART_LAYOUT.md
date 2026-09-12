# 对话框美术布局编辑

打开 game/ui/dialogue_box.tscn，切换 Godot 的 2D 视图。
当前方案：框外左上方144×144方形头像框，框内左上方横排姓名，姓名下方独立分隔线，下面是可滚动正文及选项。

## 自由拖动

- Layout/PortraitFrame：拖动整个头像及边框。
- Layout/SpeakerName：拖动姓名，检查器 Theme Overrides > Font Sizes 修改字号。实际文字来自对白。
- Layout/DividerFade：自由拖动分隔线，Layout > Transform 修改位置和尺寸，不再受容器强制排版。
- Layout/ContentScroll：拖动正文区域。内部正文和选项仍由容器排版。

只移动这些节点，不移动其父节点 Layout（它仍跟随根面板自动填充）。
保存后打开 game/art_review/keti_portrait_review.tscn，按 F6 看运行效果；正式游戏共用此布局。

## 头像与裁切

Layout/PortraitFrame/PortraitClip 开启 Clip Contents，超出其128×128范围的头像不会显示。
里面的 Portrait 可单独移动或放大；保持 nearest 过滤和 Keep Aspect Centered，避免变形。
Border 使用现有UI transparent_border.png 的九宫格边框；它与裁切区域独立，默认144×144。
如果调整头像框尺寸，要同步调整 PortraitClip 的四边偏移，保持正方形。

新源图 assets/portraits/keti/source.png 来自制作人 keti3.png。管线仅切图、统一留白及最近邻缩放，保留原透明度，不再去背景或清除像素。旧源图保存在 source_initial.png。

## 整体位置

根节点检查器 Dialogue Layout 控制窗口适配。若要自己拖动根节点，先关闭 Auto Fit Viewport；关闭后不同窗口大小需要自行检查。
本轮只调整美术布局、头像和对应专项检查，不修改剧情或战斗。
