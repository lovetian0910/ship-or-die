# time_manager.gd — 混合制时间系统
# 离散月份（主流程）+ 实时秒（代码急救小游戏）
extends Node

## ===== 离散时间（月份制）=====
var total_months: int = Config.TIME_TOTAL_MONTHS
var remaining_months: int = Config.TIME_TOTAL_MONTHS
var elapsed_months: int = 0
var is_active: bool = false    ## 当前局是否在进行中

## ===== 实时时间（仅小游戏期间有效）=====
var minigame_running: bool = false
var minigame_remaining: float = 0.0       ## 真实秒
var minigame_display_total: int = 0       ## UI显示的工时总量
var minigame_display_remaining: int = 0   ## UI显示的工时剩余

var _last_phase: StringName = &"early"
var _warning_fired: bool = false


func _process(delta: float) -> void:
	# 只有小游戏期间才有实时倒计时
	if not minigame_running:
		return

	minigame_remaining -= delta
	# 实时秒→映射为UI显示的工时
	var pct: float = minigame_remaining / Config.MINIGAME_REAL_SECONDS
	minigame_display_remaining = int(minigame_display_total * pct)

	# 发射tick信号给小游戏UI
	EventBus.time_tick.emit(minigame_remaining, 0.0, Config.MINIGAME_REAL_SECONDS)

	if minigame_remaining <= 0.0:
		minigame_remaining = 0.0
		minigame_display_remaining = 0
		_end_minigame()


## ===== 开始新局 =====
func start_new_round() -> void:
	total_months = Config.TIME_TOTAL_MONTHS
	remaining_months = total_months
	elapsed_months = 0
	is_active = true
	_warning_fired = false
	_last_phase = &"early"
	minigame_running = false
	_emit_month_update()


## ===== 消耗月份（离散制核心接口）=====
## 返回 true 如果还有时间，false 如果时间耗尽
func consume_months(months: int) -> bool:
	if not is_active:
		return false

	elapsed_months += months
	remaining_months = max(0, total_months - elapsed_months)

	# 阶段变化
	var current_phase := _get_phase()
	if current_phase != _last_phase:
		_last_phase = current_phase
		EventBus.dev_phase_changed.emit(current_phase)

	# 警告
	if not _warning_fired and get_progress() >= (1.0 - Config.TIME_WARNING_THRESHOLD):
		_warning_fired = true
		EventBus.time_warning.emit(float(remaining_months))

	_emit_month_update()

	# 时间耗尽
	if remaining_months <= 0:
		_expire()
		return false

	return true


## ===== 小游戏：启动实时倒计时 =====
func start_minigame() -> void:
	minigame_running = true
	minigame_remaining = Config.MINIGAME_REAL_SECONDS
	minigame_display_total = Config.MINIGAME_DISPLAY_HOURS
	minigame_display_remaining = minigame_display_total


## ===== 小游戏：结束 =====
func _end_minigame() -> void:
	minigame_running = false
	# 小游戏结束后消耗对应月数
	consume_months(Config.MINIGAME_MONTH_COST)


## ===== 手动停止小游戏（提前结束用）=====
func stop_minigame() -> void:
	minigame_running = false


## ===== 结束当前局 =====
func stop() -> void:
	is_active = false
	minigame_running = false


## ===== 查询接口 =====

## 获取已消耗比例 0.0~1.0
func get_progress() -> float:
	if total_months <= 0:
		return 0.0
	return clampf(float(elapsed_months) / float(total_months), 0.0, 1.0)


## 获取当前研发阶段
func get_dev_phase() -> StringName:
	return _get_phase()


## 获取剩余月数
func get_remaining() -> int:
	return remaining_months


## 检查是否够支付某个时间消耗
func can_afford_months(months: int) -> bool:
	return remaining_months >= months


## ===== 内部 =====

func _get_phase() -> StringName:
	var progress: float = get_progress()
	if progress < Config.PHASE_EARLY_END:
		return &"early"
	elif progress < Config.PHASE_MID_END:
		return &"mid"
	else:
		return &"late"


func _expire() -> void:
	is_active = false
	minigame_running = false
	EventBus.time_expired.emit()


func _emit_month_update() -> void:
	# 复用 time_tick 信号：remaining=剩余月, elapsed=已消耗月, total=总月
	EventBus.time_tick.emit(
		float(remaining_months),
		float(elapsed_months),
		float(total_months)
	)
