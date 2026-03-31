# market_heat.gd — 市场热度动态系统（离散月份制）
# Autoload 单例: MarketHeat
extends Node

signal heat_updated   ## 每次热度刷新后触发，UI 监听

## 热度曲线参数
const PERIOD_MONTHS: float = 24.0          ## 正弦波周期（月）
const NOISE_SCALE: float = 0.15            ## 噪声采样频率
const NOISE_AMPLITUDE: float = 10.0        ## 噪声振幅

## 模糊信号参数
const FUZZY_REFRESH_INTERVAL: int = 3      ## 每3个月刷新一次模糊文字
const PERCEPTION_JITTER: float = 5.0       ## ±5 感知误差

## 热度档位定义
const HEAT_TIERS: Array[Dictionary] = [
	{ "max": 20.0,  "text": "无人问津",   "color": Color(0.5, 0.5, 0.6) },
	{ "max": 40.0,  "text": "逐渐升温",   "color": Color(0.3, 0.7, 0.4) },
	{ "max": 60.0,  "text": "热度攀升中", "color": Color(0.9, 0.8, 0.2) },
	{ "max": 80.0,  "text": "市场火爆",   "color": Color(0.9, 0.4, 0.1) },
	{ "max": 100.0, "text": "全民狂热",   "color": Color(0.9, 0.1, 0.1) },
]

var _topics: Array[TopicData] = []
var _heat_values: Dictionary = {}          ## { topic_id: float } 精确热度
var _drain_accum: Dictionary = {}          ## { topic_id: float } 竞品累计消耗
var _fuzzy_cache: Dictionary = {}          ## { topic_id: { text, color, last_month } }
var _initialized: bool = false


func _ready() -> void:
	# 监听时间流逝——每次 time_tick 都检查月份变化来更新热度
	EventBus.time_tick.connect(_on_time_tick)


## ===== 局初调用：传入题材配置列表，初始化热度 =====
func init_market(topics: Array[TopicData]) -> void:
	_topics = topics
	_heat_values.clear()
	_drain_accum.clear()
	_fuzzy_cache.clear()
	_initialized = true
	for t in topics:
		_heat_values[t.id] = t.initial_heat
		_drain_accum[t.id] = 0.0
		# 初始化模糊缓存
		_refresh_fuzzy(t.id, 0)


## ===== 局结束清理 =====
func reset() -> void:
	_topics.clear()
	_heat_values.clear()
	_drain_accum.clear()
	_fuzzy_cache.clear()
	_initialized = false


## ===== 获取某题材精确热度（内部/结算用）=====
func get_heat(topic_id: StringName) -> float:
	return _heat_values.get(topic_id, 0.0)


## ===== 获取模糊文字（UI用）=====
func get_fuzzy_text(topic_id: StringName) -> String:
	if _fuzzy_cache.has(topic_id):
		return _fuzzy_cache[topic_id]["text"]
	return "未知"


## ===== 获取模糊颜色（UI用）=====
func get_fuzzy_color(topic_id: StringName) -> Color:
	if _fuzzy_cache.has(topic_id):
		return _fuzzy_cache[topic_id]["color"]
	return Color.GRAY


## ===== AI竞品上线：永久消耗热度 =====
func apply_competitor_drain(topic_id: StringName, amount: float) -> void:
	_drain_accum[topic_id] = _drain_accum.get(topic_id, 0.0) + amount


## ===== 偶发市场事件修正 =====
func apply_market_event(topic_id: StringName, delta: float) -> void:
	_drain_accum[topic_id] = _drain_accum.get(topic_id, 0.0) - delta


## ===== 强制刷新所有模糊信号（选题界面首次显示时调用）=====
func refresh_all_fuzzy() -> void:
	var elapsed: int = TimeManager.elapsed_months
	for t in _topics:
		_refresh_fuzzy(t.id, elapsed)


## ===== 获取所有题材 =====
func get_topics() -> Array[TopicData]:
	return _topics


## ===== 内部：时间tick回调 =====
func _on_time_tick(remaining: float, elapsed: float, total: float) -> void:
	if not _initialized:
		return
	# 只在小游戏未运行时更新（小游戏 tick 的 total 是实时秒数，不是月份）
	if total < 100.0:
		return
	_update_heat(int(elapsed))


## ===== 内部：更新所有题材热度 =====
func _update_heat(elapsed_months: int) -> void:
	for t in _topics:
		var base_heat := _calc_base_heat(t, elapsed_months)
		var noise := _simple_noise(t.noise_seed, elapsed_months) * NOISE_AMPLITUDE
		var drain: float = _drain_accum.get(t.id, 0.0)
		_heat_values[t.id] = clampf(base_heat + noise - drain, 0.0, 100.0)

	# 更新模糊缓存（有冷却）
	for t in _topics:
		_maybe_refresh_fuzzy(t.id, elapsed_months)

	heat_updated.emit()

	# 发射 EventBus 信号给其他模块
	for t in _topics:
		EventBus.market_updated.emit(String(t.id), get_fuzzy_text(t.id))


## ===== 正弦波基底 =====
func _calc_base_heat(topic: TopicData, elapsed: int) -> float:
	var sin_value := sin((topic.phase_offset + float(elapsed)) * TAU / PERIOD_MONTHS)
	return 50.0 + sin_value * topic.amplitude


## ===== 简易确定性噪声 =====
func _simple_noise(seed_val: int, month: int) -> float:
	var t: float = float(seed_val) + float(month) * NOISE_SCALE
	var i := floori(t)
	var f := t - float(i)
	var a := _hash(i)
	var b := _hash(i + 1)
	var u := f * f * (3.0 - 2.0 * f)
	return a + (b - a) * u


func _hash(n: int) -> float:
	var x := sin(float(n) * 127.1 + 311.7) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0


## ===== 模糊信号刷新 =====
func _maybe_refresh_fuzzy(topic_id: StringName, elapsed: int) -> void:
	if not _fuzzy_cache.has(topic_id):
		_refresh_fuzzy(topic_id, elapsed)
		return
	var last: int = _fuzzy_cache[topic_id]["last_month"]
	if elapsed - last >= FUZZY_REFRESH_INTERVAL:
		_refresh_fuzzy(topic_id, elapsed)


func _refresh_fuzzy(topic_id: StringName, elapsed: int) -> void:
	var heat: float = _heat_values.get(topic_id, 50.0)
	var perceived: float = heat + randf_range(-PERCEPTION_JITTER, PERCEPTION_JITTER)
	var tier: Dictionary = HEAT_TIERS.back()
	for t in HEAT_TIERS:
		if perceived <= t["max"]:
			tier = t
			break
	_fuzzy_cache[topic_id] = {
		"text": tier["text"],
		"color": tier["color"],
		"last_month": elapsed,
	}
