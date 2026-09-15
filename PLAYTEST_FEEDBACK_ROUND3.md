# 第三轮试玩优化

- 可蒂在荒野被打空生命后保留为不可继续受伤的濒死实体；再次头触可选择吃掉或离开，两条路线均生成史莱姆，清场后等待六秒进入呕吐剧情。
- 导出版长选项按 Label 实际换行数和行高二次计算按钮高度，避免字体最终排版多一行时错位、裁切。
- `chapter1_meeting` 的饥饿叙述移入正文，选项缩为“顺从饥饿”；全图不再含叙述型超长选项。
- 巴克/米罗倒地后的首次回触优先进入搜刮并领取一次6金币；之后回触只显示昏迷，奖励保持幂等。

验证入口：`tests/story_feedback_round3.gd`、`tests/dialogue_export_feedback.gd`、`tests/feedback_round3_audit.gd` 与 `tests/run_tests.gd`。自动门禁不代替制作人对Windows导出包的视觉试玩。
