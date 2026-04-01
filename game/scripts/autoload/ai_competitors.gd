# ai_competitors.gd — AI竞品行为管理
# Autoload 单例: AICompetitors
extends Node

## 性格模板配置
const PERSONALITIES: Dictionary = {
	AICompetitorData.Personality.AGGRESSIVE: {
		"label": "激进派",
		"quality_min": 20.0, "quality_max": 45.0,
		"launch_ratio_min": 0.15, "launch_ratio_max": 0.35,
		"heat_threshold": -1.0,
	},
	AICompetitorData.Personality.CONSERVATIVE: {
		"label": "保守派",
		"quality_min": 55.0, "quality_max": 80.0,
		"launch_ratio_min": 0.65, "launch_ratio_max": 0.85,
		"heat_threshold": -1.0,
	},
	AICompetitorData.Personality.FOLLOWER: {
		"label": "跟风派",
		"quality_min": 35.0, "quality_max": 60.0,
		"launch_ratio_min": 0.35, "launch_ratio_max": 0.65,
		"heat_threshold": 60.0,
	},
}

## 虚构名前后缀（恶搞风格）
const NAME_PREFIXES: Array[String] = [
	"星际", "幻境", "暗影", "铁甲", "灵魂", "深渊", "天际", "零点",
	"赛博", "混沌", "虚空", "量子",
]
const NAME_SUFFIXES: Array[String] = [
	"纪元", "传说", "狂潮", "猎手", "边界", "觉醒", "风暴", "幻想",
	"编年史", "大乱斗", "启示录", "模拟器",
]

## 制作组名（恶搞拟人化）
const STUDIO_NAMES: Array[String] = [
	"肝帝工作室", "PPT游戏社", "梦想永动机", "通宵达旦互娱",
	"氪金圣殿", "咸鱼翻身组", "deadline战士团", "草台班子娱乐",
	"换皮大师坊", "画饼研究所", "跳票宇宙", "情怀收割机",
]

var _competitors: Array[AICompetitorData] = []
var _total_months: int = 0
var _last_checked_month: int = -1
var _initialized: bool = false

## 竞品品质是否已揭示（通过情报侦察）
var qualities_revealed: bool = false


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


## ===== 局初生成竞品（选题确认后调用）=====
func init_competitors(topic_id: StringName) -> void:
	_total_months = Config.TIME_TOTAL_MONTHS
	_last_checked_month = 0
	_competitors.clear()
	_initialized = true

	# 随机2-3个竞品，从三种性格中不重复抽取
	var personalities: Array = [
		AICompetitorData.Personality.AGGRESSIVE,
		AICompetitorData.Personality.CONSERVATIVE,
		AICompetitorData.Personality.FOLLOWER,
	]
	personalities.shuffle()
	var count := randi_range(2, 3)

	for i in range(count):
		var p_key: AICompetitorData.Personality = personalities[i]
		var p: Dictionary = PERSONALITIES[p_key]
		var comp := AICompetitorData.new()
		# 拟人化名字：制作组 + 游戏名
		var studio: String = STUDIO_NAMES.pick_random()
		var game_title := "《%s%s》" % [NAME_PREFIXES.pick_random(), NAME_SUFFIXES.pick_random()]
		comp.competitor_name = "%s 的 %s" % [studio, game_title]
		comp.personality = p_key
		comp.quality = randf_range(p["quality_min"], p["quality_max"])
		comp.planned_launch_month = randi_range(
			int(p["launch_ratio_min"] * _total_months),
			int(p["launch_ratio_max"] * _total_months)
		)
		comp.heat_threshold = p["heat_threshold"]
		comp.launched = false
		comp.topic_id = topic_id
		_competitors.append(comp)


## ===== 局结束清理 =====
func reset() -> void:
	_competitors.clear()
	_initialized = false
	_last_checked_month = -1
	qualities_revealed = false


## ===== 获取竞品列表 =====
func get_competitors() -> Array[AICompetitorData]:
	return _competitors


## ===== 获取性格标签文字 =====
func get_personality_label(personality: AICompetitorData.Personality) -> String:
	return PERSONALITIES[personality]["label"]


## ===== 模糊性格暗示（不直接暴露性格标签）=====
func get_personality_hint(personality: AICompetitorData.Personality) -> String:
	match personality:
		AICompetitorData.Personality.AGGRESSIVE:
			return ["他们动作很快", "听说在赶工", "似乎急着上线"][randi() % 3]
		AICompetitorData.Personality.CONSERVATIVE:
			return ["他们在憋大招", "一直没动静", "据说在反复打磨"][randi() % 3]
		AICompetitorData.Personality.FOLLOWER:
			return ["听说在观望市场", "他们似乎在等风来", "跟风的味道很浓"][randi() % 3]
	return "情报不明"


## ===== 情报侦察：揭示竞品品质 =====
func reveal_qualities() -> void:
	qualities_revealed = true


## ===== 模糊品质感知（揭示后显示精确值）=====
func get_fuzzy_quality_text(quality: float) -> String:
	if qualities_revealed:
		# 揭示后显示精确品质分和等级
		var grade_name: String = _quality_to_grade_name(quality)
		return "品质：%.1f / %s" % [quality, grade_name]
	var perceived: float = quality + randf_range(-10.0, 10.0)
	if perceived >= 70.0:
		return "可能是精品"
	elif perceived >= 50.0:
		return "看起来还行"
	elif perceived >= 30.0:
		return "品质一般"
	else:
		return "品质不高"


## 品质分转等级名称（内部工具函数）
func _quality_to_grade_name(quality: float) -> String:
	if quality >= 75.0:
		return "杰作"
	elif quality >= 50.0:
		return "精良"
	elif quality >= 25.0:
		return "合格"
	else:
		return "粗糙"


## ===== 获取已上线竞品数 =====
func get_launched_count() -> int:
	var count: int = 0
	for comp in _competitors:
		if comp.launched:
			count += 1
	return count


## ===== 获取未上线竞品数 =====
func get_pending_count() -> int:
	var count: int = 0
	for comp in _competitors:
		if not comp.launched:
			count += 1
	return count


## ===== 内部：时间tick回调，检查竞品是否上线 =====
func _on_time_tick(remaining: float, elapsed: float, total: float) -> void:
	if not _initialized:
		return
	# 过滤掉小游戏 tick（小游戏期间由 TimeManager 实时发射 tick，不是月份制）
	if TimeManager.minigame_running:
		return

	var current_month := int(elapsed)
	if current_month <= _last_checked_month:
		return
	_last_checked_month = current_month

	for comp in _competitors:
		if comp.launched:
			continue

		var should_launch := false

		# 跟风派：热度达标且已过最早上线时间
		if comp.heat_threshold >= 0.0:
			var heat := MarketHeat.get_heat(comp.topic_id)
			var p: Dictionary = PERSONALITIES[comp.personality]
			var earliest := int(p["launch_ratio_min"] * _total_months)
			if heat >= comp.heat_threshold and current_month >= earliest:
				should_launch = true

		# 所有性格：到达预设月份必定上线
		if current_month >= comp.planned_launch_month:
			should_launch = true

		if should_launch:
			comp.launched = true
			# 消耗热度：品质越高消耗越大（5~15）
			var drain := 5.0 + (comp.quality / 100.0) * 10.0
			MarketHeat.apply_competitor_drain(comp.topic_id, drain)
			# 发射信号
			EventBus.competitor_launched.emit(comp.competitor_name, String(comp.topic_id))
