# asset_registry.gd — 美术资源注册表（Autoload 单例）
# 所有美术素材路径集中管理，替换时只改这里
# 路径为空字符串""表示使用占位（代码生成的 ColorRect/Label）
extends Node

## ===== 角色头像（128×128）=====
var portraits: Dictionary = {
	"creator_low": "res://assets/sprites/portraits/creator_low.png",           # 独立游戏愤青
	"creator_mid": "res://assets/sprites/portraits/creator_mid.png",           # 鹅皇互娱主创
	"creator_high": "res://assets/sprites/portraits/creator_high.png",         # 天命堂制作人
	"outsource_low": "res://assets/sprites/portraits/outsource_low.png",       # 大学生兼职组
	"outsource_mid": "res://assets/sprites/portraits/outsource_mid.png",       # 外包铁军
	"outsource_high": "res://assets/sprites/portraits/outsource_high.png",     # 越南闪电队
	"business_low": "res://assets/sprites/portraits/business_low.png",         # 实习商务
	"business_mid": "res://assets/sprites/portraits/business_mid.png",         # 万能商务
	"business_high": "res://assets/sprites/portraits/business_high.png",       # 前渠道教父
}

## ===== 题材图标（96×96）=====
var topic_icons: Dictionary = {
	"phantom_realm": "res://assets/sprites/topics/topic_phantom_realm.png",           # 抽象大陆
	"mecha_royale": "res://assets/sprites/topics/topic_mecha_royale.png",             # 枪枪枪
	"waifu_collection": "res://assets/sprites/topics/topic_waifu_collection.png",     # 二次元觉醒
	"star_ranch": "res://assets/sprites/topics/topic_star_ranch.png",                 # 像素怀旧谷
}

## ===== 背景图（1280×720）=====
var backgrounds: Dictionary = {
	"menu": "res://assets/sprites/backgrounds/bg_menu.png",         # 主菜单
	"office": "res://assets/sprites/backgrounds/bg_office.png",     # 研发界面
	"success": "res://assets/sprites/backgrounds/bg_success.png",   # 成功结算
	"failure": "res://assets/sprites/backgrounds/bg_failure.png",   # 失败结算
}

## ===== 事件配图（256×256）=====
var event_images: Dictionary = {
	"search_talent_01": "res://assets/sprites/events/event_search_talent_01.png",         # 野生大神出没
	"search_talent_02": "res://assets/sprites/events/event_search_talent_02.png",         # 灵感时刻
	"search_tech_01": "res://assets/sprites/events/event_search_tech_01.png",             # 开源宝藏
	"search_tech_02": "res://assets/sprites/events/event_search_tech_02.png",             # 外包加急通道
	"search_quality_01": "res://assets/sprites/events/event_search_quality_01.png",       # 反面教材研究
	"search_resource_01": "res://assets/sprites/events/event_search_resource_01.png",     # 友商内鬼
	"fight_team_01": "res://assets/sprites/events/event_fight_team_01.png",               # 核心程序员提桶跑路
	"fight_team_02": "res://assets/sprites/events/event_fight_team_02.png",               # 团队内战
	"fight_tech_01": "res://assets/sprites/events/event_fight_tech_01.png",               # 引擎突然收费
	"fight_tech_02": "res://assets/sprites/events/event_fight_tech_02.png",               # 服务器着火了
	"fight_external_01": "res://assets/sprites/events/event_fight_external_01.png",       # 美术素材碰瓷
	"fight_external_02": "res://assets/sprites/events/event_fight_external_02.png",       # 平台政策突变
	"fight_survivor_01": "res://assets/sprites/events/event_fight_survivor_01.png",       # 代码库虫群爆发
	"fight_survivor_02": "res://assets/sprites/events/event_fight_survivor_02.png",       # 虫族母巢入侵
}

## ===== UI 图标 =====
var ui_icons: Dictionary = {
	"money": "res://assets/sprites/ui/icon_money.png",         # 金钱（32×32）
	"time": "res://assets/sprites/ui/icon_time.png",           # 时间（32×32）
	"quality": "res://assets/sprites/ui/icon_quality.png",     # 品质（32×32）
	"energy": "res://assets/sprites/ui/icon_energy.png",       # 精力（32×32）
	"speed": "res://assets/sprites/ui/icon_speed.png",         # 速度（32×32）
	"launch": "res://assets/sprites/ui/icon_launch.png",       # 上线（48×48）
}

## ===== Emoji 图标（24×24，替代 emoji 字符）=====
const ICON_DIR: String = "res://assets/sprites/icons/"

## emoji → 图标文件名（不含路径和后缀）
const EMOJI_ICON_MAP: Dictionary = {
	"💰": "icon_money",
	"⚠️": "icon_warning",
	"⚠": "icon_warning",
	"⚡": "icon_warning",
	"✅": "icon_success",
	"🏆": "icon_success",
	"💔": "icon_fail",
	"💥": "icon_fail",
	"❌": "icon_fail",
	"🔍": "icon_search",
	"🔬": "icon_search",
	"💎": "icon_treasure",
	"🚀": "icon_launch",
	"✨": "icon_polish",
	"🔧": "icon_polish",
	"⏰": "icon_time",
	"⏳": "icon_time",
	"⏱️": "icon_time",
	"⏭️": "icon_time",
	"📋": "icon_info",
	"💡": "icon_info",
	"📊": "icon_info",
	"📢": "icon_info",
	"🗺️": "icon_info",
	"🔙": "icon_info",
	"🔄": "icon_info",
	"🏗️": "icon_info",
	"🎮": "icon_gamepad",
	"🐛": "icon_gamepad",
	"🧑‍💻": "icon_team",
	"🏭": "icon_team",
	"🤝": "icon_team",
	"📦": "icon_team",
	"❓": "icon_mystery",
}

## ===== 小游戏素材 =====
var minigame_assets: Dictionary = {
	"bg": "res://assets/sprites/minigame/minigame_bg.png",                 # 背景（1280×720）
	"bug": "res://assets/sprites/minigame/minigame_bug.png",               # Bug敌人（32×32）
	"player_run": "res://assets/sprites/minigame/minigame_player_run.png", # 玩家序列帧（192×48, 6帧）
	"powerup": "res://assets/sprites/minigame/minigame_powerup.png",       # 能量道具（24×24）
}

## ===== 占位色（无图时用 ColorRect 填充）=====
const PLACEHOLDER_COLORS: Dictionary = {
	"creator_low": Color(0.3, 0.5, 0.8),
	"creator_mid": Color(0.2, 0.6, 0.4),
	"creator_high": Color(0.8, 0.3, 0.3),
	"outsource_low": Color(0.5, 0.5, 0.3),
	"outsource_mid": Color(0.4, 0.4, 0.6),
	"outsource_high": Color(0.2, 0.7, 0.7),
	"business_low": Color(0.6, 0.5, 0.3),
	"business_mid": Color(0.5, 0.3, 0.6),
	"business_high": Color(0.7, 0.6, 0.2),
}

## 缓存已加载的纹理
var _texture_cache: Dictionary = {}


## 获取纹理。有图返回 Texture2D，无图返回 null
func get_texture(category: String, key: String) -> Texture2D:
	var full_key: String = "%s/%s" % [category, key]

	# 缓存命中
	if _texture_cache.has(full_key):
		return _texture_cache[full_key]

	# 查找路径
	var path: String = ""
	match category:
		"portrait":
			path = portraits.get(key, "")
		"topic":
			path = topic_icons.get(key, "")
		"background":
			path = backgrounds.get(key, "")
		"event":
			path = event_images.get(key, "")
		"ui":
			path = ui_icons.get(key, "")
		"minigame":
			path = minigame_assets.get(key, "")

	if path.is_empty():
		return null

	# 检查资源是否存在
	if not ResourceLoader.exists(path):
		return null

	# headless 模式下跳过图片加载（避免报错）
	if DisplayServer.get_name() == "headless":
		return null

	# 加载
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_texture_cache[full_key] = tex
	return tex


## 创建显示节点：有图用 TextureRect，无图用带首字母的 ColorRect
func create_display(category: String, key: String, display_size: Vector2 = Vector2(64, 64)) -> Control:
	var tex: Texture2D = get_texture(category, key)

	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = display_size
		return rect
	else:
		# 占位：色块 + 首字母
		var container := Control.new()
		container.custom_minimum_size = display_size

		var bg := ColorRect.new()
		bg.color = PLACEHOLDER_COLORS.get(key, Color(0.3, 0.3, 0.4))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(bg)

		var label := Label.new()
		label.text = key.substr(0, 2).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(label)

		return container


## 将 emoji 转换为 BBCode 内嵌图标。有图标时返回 [img] 标签，无图标时返回原字符串。
## 用于 RichTextLabel（bbcode_enabled = true）的文本中。
func emoji_bbcode(emoji: String, icon_size: int = 20) -> String:
	var icon_name: String = EMOJI_ICON_MAP.get(emoji, "") as String
	if icon_name.is_empty():
		return emoji
	var path: String = ICON_DIR + icon_name + ".png"
	# headless 模式下跳过图片（避免报错），直接返回 fallback 文字
	if DisplayServer.get_name() == "headless":
		return emoji
	if not ResourceLoader.exists(path):
		return emoji
	return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, path]
