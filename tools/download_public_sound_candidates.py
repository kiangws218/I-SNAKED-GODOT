from pathlib import Path
import shutil
import time
import requests


ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "public_candidates"
ARCHIVE_DIR = ROOT / "原始素材包"
STONE_DIR = ROOT / "石门音效"
VARIOUS_DIR = ROOT / "通用动作音效"

PROXY = "http://127.0.0.1:7890"
SESSION = requests.Session()
SESSION.proxies.update({"http": PROXY, "https": PROXY})
SESSION.headers.update({"User-Agent": "I-SNAKED-GODOT-audio-importer/1.0"})


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and destination.stat().st_size > 0:
        print(f"已存在，跳过: {destination.name}")
        return
    response = SESSION.get(url, verify=False, timeout=60)
    response.raise_for_status()
    destination.write_bytes(response.content)
    print(f"下载完成: {destination} ({len(response.content)} bytes)")
    time.sleep(0.15)


def main() -> None:
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    STONE_DIR.mkdir(parents=True, exist_ok=True)
    VARIOUS_DIR.mkdir(parents=True, exist_ok=True)

    download(
        "https://opengameart.org/sites/default/files/stone_door.ogg",
        STONE_DIR / "石门开启与关闭（石门实体演出）.ogg",
    )
    download(
        "https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip",
        ARCHIVE_DIR / "Kenney界面音效包（CC0）.zip",
    )
    download(
        "https://opengameart.org/sites/default/files/sfx_100_v2.zip",
        ARCHIVE_DIR / "100个CC0通用音效包.zip",
    )
    download(
        "https://opengameart.org/sites/default/files/hits.7z",
        ARCHIVE_DIR / "21个战斗打击音效包（CC0）.7z",
    )

    various_files = {
        "bangs.wav": "重击碰撞（阿杰丽丝战斗受击）.wav",
        "beep1.wav": "短提示音（机关反馈）.wav",
        "big_amber.wav": "大型宝石音（重要物品）.wav",
        "break_stone.wav": "石头碎裂（石门破碎或撞击）.wav",
        "bup.wav": "短促弹起（角色被击退）.wav",
        "cannonball_tap.wav": "轻型撞击（投掷物命中）.wav",
        "click.wav": "机械点击（机关确认）.wav",
        "crush.wav": "挤压撞击（蛇身碰撞）.wav",
        "death.wav": "倒地失败（敌人战败）.wav",
        "dull_explosion.wav": "闷爆（强力攻击）.wav",
        "fall.wav": "跌落（角色倒地）.wav",
        "get_important_item.wav": "获得重要物品（剧情奖励）.wav",
        "glug.wav": "吞咽声（恶心或吞食演出）.wav",
        "moan.wav": "痛苦呻吟（昏迷角色）.wav",
        "nom.wav": "咀嚼声（吃掉NPC或物品）.wav",
        "player_hit.wav": "玩家受击（敌人攻击命中）.wav",
        "pop.wav": "弹出声（吐出载荷）.wav",
        "powered_door.wav": "动力门开启（石门开启演出）.wav",
        "rustling_of_the_weeds.wav": "草丛窸窣（森林环境）.wav",
        "scooter_p.wav": "快速移动（角色冲刺）.wav",
        "small_amber.wav": "小型宝石音（普通物品）.wav",
        "small_rock_impact.wav": "小石块撞击（环境碰撞）.wav",
        "spear.wav": "长矛挥击（武器攻击）.wav",
        "steal.wav": "偷窃提示（劫匪事件）.wav",
        "swim.wav": "水流游动（洞穴或水域）.wav",
        "tap_stone.wav": "敲击石头（石门机关）.wav",
        "teleport.wav": "传送转场（地图切换）.wav",
        "tick.wav": "计时滴答（倒计时提示）.wav",
        "uff.wav": "用力喘息（攻击或吐出）.wav",
        "snd_ambient_impact1.wav": "环境低沉撞击（洞穴环境）.wav",
        "snd_batwings.wav": "蝙蝠振翅（洞穴环境）.wav",
        "snd_death1.wav": "敌人死亡一（战斗结束）.wav",
        "snd_death2.wav": "敌人死亡二（战斗结束）.wav",
        "snd_fillenergy.wav": "能量填充（能力恢复）.wav",
        "snd_footsteps1.wav": "脚步声（角色移动）.wav",
        "snd_fox_footstep.wav": "轻快脚步（NPC移动）.wav",
        "snd_getpowerup.wav": "获得强化（道具拾取）.wav",
        "snd_menu_move.wav": "菜单移动（选项切换）.wav",
        "snd_menu_select.wav": "菜单确认（选项确认）.wav",
        "snd_npc_message.wav": "NPC提示音（对话出现）.wav",
        "snd_slip_on_ice.wav": "滑倒（角色失衡）.wav",
        "snd_splathit.wav": "湿润命中（吐出撞击）.wav",
        "snd_splat.wav": "湿润落地（角色落地）.wav",
        "snd_splurt.wav": "喷溅（吐出或液体效果）.wav",
        "snd_sproing.wav": "弹簧弹射（角色弹飞）.wav",
        "snd_throw1.wav": "投掷飞行（吐出载荷）.wav",
        "snd_treasure.wav": "宝物提示（剧情奖励）.wav",
        "snd_warp_in.wav": "传送进入（地图切换）.wav",
        "snd_warp_out.wav": "传送离开（地图切换）.wav",
        "snd_yoghurtblast.wav": "喷射爆发（特殊攻击）.wav",
        "snd_birdcrash.wav": "飞行撞击（可蒂飞行演出）.wav",
        "snd_birdscream.wav": "受惊叫声（NPC受惊）.wav",
        "snd_bulletcrackle.wav": "弹道嗖声（远程攻击）.wav",
        "snd_enemyjump.wav": "敌人跃起（敌人攻击起手）.wav",
        "snd_bullethit.wav": "远程命中（攻击命中）.wav",
        "snd_enemyland.wav": "敌人落地（敌人演出）.wav",
        "snd_enemyscream.wav": "敌人喊叫（敌人受击）.wav",
        "snd_enemysword.wav": "敌人挥剑（阿杰攻击）.wav",
        "snd_flap.wav": "翅膀拍动（角色飞行）.wav",
        "snd_gunshot1.wav": "枪声（远程攻击）.wav",
    }
    for source_name, chinese_name in various_files.items():
        download(
            f"https://opengameart.org/sites/default/files/{source_name}",
            VARIOUS_DIR / chinese_name,
        )


if __name__ == "__main__":
    main()
