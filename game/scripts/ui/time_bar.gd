# time_bar.gd — 时间条 UI 组件（月份制，自适应分辨率）
extends Control

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var time_label: Label = $TimeLabel

var _is_warning: bool = false

const COLOR_NORMAL := Color(0.2, 0.7, 0.3)
const COLOR_WARNING := Color(0.9, 0.2, 0.2)


func _ready() -> void:
	# Fill 用锚点控制宽度比例，不用固定像素
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 1.0  # 初始满宽
	fill.anchor_bottom = 1.0
	fill.offset_left = 0
	fill.offset_top = 0
	fill.offset_right = 0
	fill.offset_bottom = 0
	fill.color = COLOR_NORMAL

	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_warning.connect(_on_time_warning)
	EventBus.run_started.connect(_on_run_started)


func _on_run_started() -> void:
	_is_warning = false
	fill.color = COLOR_NORMAL
	fill.modulate.a = 1.0
	fill.anchor_right = 1.0
	time_label.text = ""


func _on_time_tick(remaining: float, _elapsed: float, total: float) -> void:
	if TimeManager.minigame_running:
		return

	var pct: float = remaining / max(total, 1.0)
	# 用 anchor_right 控制比例，自适应任何分辨率
	fill.anchor_right = pct

	var months_left: int = int(remaining)
	var years: int = months_left / 12
	var months: int = months_left % 12

	if years > 0:
		time_label.text = "剩余: %d年%d个月" % [years, months]
	else:
		time_label.text = "剩余: %d个月" % months

	if _is_warning:
		var flash: float = absf(sin(Time.get_ticks_msec() * 0.005))
		fill.modulate.a = 0.5 + flash * 0.5
		fill.color = COLOR_WARNING
	else:
		fill.modulate.a = 1.0
		fill.color = COLOR_NORMAL


func _on_time_warning(_remaining: float) -> void:
	_is_warning = true
	fill.color = COLOR_WARNING
