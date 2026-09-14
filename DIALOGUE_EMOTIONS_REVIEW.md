# 透明头像及情绪接入（2026-09-14）

在公司最新版 origin/main 012cada 基础上合并家中已验收的五人透明头像；不回退公司CG系统、构图场景或玩法。
五人九表情，保留可蒂已有九表情。源图使用制作人透明素材，不再抠图。

## 对白情绪

game/story/dialogue_emotions.json 对应116个对白节点、327条原始台词，另外包括两条动态可蒂对白。
每个节点的数组按 story_graph.json 原始 pages 顺序排列；分割成多个运行时短页后继承原标签。
标签即表情名：neutral正常、happy开心、angry生气、blushing害羞、crying哭泣、surprised惊讶、tired疲惫/低落、smug得意、terrified惊恐。
旁白仍有标签，但隐藏姓名和头像，保留装饰线。玩家目前只有一张蛇头像，不会凭空生成九种表情。
未改对白正文；没有使用关键词实时猜测。未显著表露情绪的信息/教学台词标neutral。
可以直接修改标签JSON，再运行 tests/test_dialogue_emotions.gd；增删或重排原始台词时必须同步对应数组。新台词未标时运行会回退neutral，但覆盖测试会报告遗漏。
未来对白文件内的逐页 emotion/expression 优先于旁表；已有显式 expression 次之。旧整段crying仅为未标注对白兼容，不覆盖已标页。
少女称谓映射到阿见头像，仍显示少女，不提前透露姓名。

## CG表情

沿用现有 presentation.portrait_expression，不修改CG动作、持续时间或奖励。
StoryDirector 根据 presentation.portrait_id（优先）或现有 variant 的角色ID确定头像，解决CG来源为旁白时选不到阿见头像的问题。
阿见CG保留surprised，后续害羞台词按blushing切换。丽丝营地CG改为blushing。
只在表现期间覆盖实际头像；后续对白自动回到逐页表情。原来的未知角色占位兼容保留。

## 验证及审阅

- Godot editor headless：脚本/场景导入通过（本机证书及全局编辑器设置权限警告与项目无关）。
- tests/run_tests.gd：完整N1-N7、NPC、UI/HUD回归通过。
- tests/test_npc_portraits.gd、test_keti_portraits.gd：透明头像及回退通过。
- tests/test_dialogue_emotions.gd：327条覆盖、短页继承、少女头像、CG临时覆盖通过。
- tests/cg_tests.gd：CG性能、资源、选项锁定及完成后恢复通过。

F6运行 game/art_review/npc_portrait_review.tscn 审阅五人表情。正式故事对话自动按标签换脸；CG构图仍从原 game/art_review/cg_review.tscn 审阅。
这些是美术情绪判断的第一版，等待制作人试玩；没有进入N8或改写情节。
