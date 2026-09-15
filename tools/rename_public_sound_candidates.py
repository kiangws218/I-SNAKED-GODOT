from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "public_candidates"


def rename_unique(path: Path, new_name: str) -> None:
    target = path.with_name(new_name)
    if path == target:
        return
    if target.exists():
        print(f"目标已存在，保留: {target.name}")
        return
    path.rename(target)


def rename_various() -> None:
    folder = ROOT / "通用动作音效"
    for path in folder.glob("*.wav"):
        # These files were already downloaded with Chinese usage-oriented names.
        if "（" in path.stem:
            continue
        rename_unique(path, f"通用候选音效（{path.stem}）.wav")


def rename_100_cc0() -> None:
    folder = ROOT / "100个通用CC0音效"
    labels = {
        "air": "空气流动（环境气流）",
        "door": "门开关（石门或洞门）",
        "footstep": "脚步（角色移动）",
        "footstep_wet": "湿地脚步（泥水地面）",
        "footstep_wood": "木地板脚步（室内或营地）",
        "glass": "玻璃破碎（脆响反馈）",
        "hit": "撞击（战斗受击）",
        "items": "物品反馈（拾取或放置）",
        "lock_open": "锁具开启（机关解锁）",
        "loop_ambient": "环境循环（场景氛围）",
        "loop_construction_site": "工地循环（环境氛围）",
        "loop_highway": "道路循环（环境氛围）",
        "loop_machine": "机械循环（环境氛围）",
        "loop_water": "水流循环（洞穴或水域）",
        "metal": "金属碰撞（武器或机关）",
        "metal_hit": "金属重击（武器命中）",
        "misc": "杂项音效（通用候选）",
        "stones": "石块碰撞（洞穴环境）",
        "switch": "开关拨动（机关操作）",
        "thunder": "雷鸣（环境氛围）",
        "wood": "木头碰撞（环境反馈）",
        "wood_hit": "木头重击（攻击命中）",
    }
    for path in sorted(folder.rglob("*.ogg")):
        match = re.match(r"sfx100v2_(.+?)(?:_(\d+))?\.ogg$", path.name)
        if not match:
            continue
        category, number = match.groups()
        label = labels.get(category, f"{category}（通用候选）")
        suffix = number or ""
        rename_unique(path, f"{label}{suffix}.ogg")

    # Older runs may have used the generic fallback before the detailed labels
    # above were added; repair those names in place.
    fallback_labels = {
        "footstep_wet": "湿地脚步（泥水地面）",
        "footstep_wood": "木地板脚步（室内或营地）",
        "loop_ambient": "环境循环（场景氛围）",
        "loop_construction_site": "工地循环（环境氛围）",
        "loop_highway": "道路循环（环境氛围）",
        "loop_machine": "机械循环（环境氛围）",
        "loop_water": "水流循环（洞穴或水域）",
    }
    for path in sorted(folder.glob("*.ogg")):
        match = re.match(r"(.+?)（通用候选）(\d*)\.ogg$", path.name)
        if not match:
            continue
        category, number = match.groups()
        label = fallback_labels.get(category)
        if label:
            rename_unique(path, f"{label}{number}.ogg")


def rename_kenney() -> None:
    folder = ROOT / "Kenney界面音效"
    labels = {
        "back": "返回（对话或菜单取消）",
        "bong": "钟声提示（重要提示）",
        "click": "点击（UI按钮）",
        "close": "关闭（窗口或菜单）",
        "confirmation": "确认（UI选项确认）",
        "drop": "放下（物品或载荷）",
        "error": "错误（操作失败提示）",
        "glass": "玻璃反馈（脆响UI）",
        "glitch": "故障提示（异常状态）",
        "maximize": "放大（镜头或窗口提示）",
        "minimize": "缩小（镜头或窗口提示）",
        "open": "打开（窗口或菜单）",
        "pluck": "拨弦提示（轻量UI反馈）",
        "question": "疑问提示（选择等待）",
        "scratch": "刮擦（操作反馈）",
        "scroll": "滚动（对话或列表）",
        "select": "选择（对话选项移动）",
        "switch": "切换（背包或选项）",
        "tick": "滴答（计时提示）",
        "toggle": "开关切换（设置选项）",
    }
    for path in sorted(folder.rglob("*.ogg")):
        match = re.match(r"(.+?)_(\d+)\.ogg$", path.name)
        if not match:
            continue
        category, number = match.groups()
        label = labels.get(category, f"{category}（UI候选）")
        rename_unique(path, f"{label}{number}.ogg")


def rename_hits() -> None:
    folder = ROOT / "战斗打击音效"
    labels = {
        "Hammer Hit": "锤击（重型攻击）",
        "Hard Hits": "硬质重击（战斗命中）",
        "Hard Metal Hits": "硬金属重击（武器命中）",
        "Harder Metal Hits 1": "强力金属重击一（Boss攻击）",
        "Harder Metal Hits": "强力金属重击（Boss攻击）",
        "Hit": "普通打击（战斗命中）",
        "Hits": "连续打击（战斗连击）",
        "Metal Hit 1": "金属命中一（剑击）",
        "Metal Hit 2": "金属命中二（剑击）",
        "Metal Hit 3": "金属命中三（剑击）",
        "Metal Hit 4": "金属命中四（剑击）",
        "Metal Hit 5": "金属命中五（剑击）",
        "Metal Hit 6": "金属命中六（剑击）",
        "Metal Hit": "金属命中（剑击）",
        "Moving Metal Hits 1": "移动金属撞击一（武器挥动）",
        "Moving Metal Hits": "移动金属撞击（武器挥动）",
        "Plain Metal Hits 1": "清脆金属命中一（剑击）",
        "Plain Metal Hits": "清脆金属命中（剑击）",
        "Wood Hits 1": "木质打击一（钝击）",
        "Wood Hits 2": "木质打击二（钝击）",
        "Wood Hits": "木质打击（钝击）",
    }
    for path in sorted(folder.rglob("*.wav")):
        label = labels.get(path.stem)
        if label:
            rename_unique(path, f"{label}.wav")


if __name__ == "__main__":
    rename_various()
    rename_100_cc0()
    rename_kenney()
    rename_hits()
