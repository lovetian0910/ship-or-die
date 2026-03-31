# event_scheduler.gd — 事件调度器
# 按阶段分配事件预算，提供 check_events() 接口供研发流程调用
class_name EventScheduler
extends RefCounted

## ===== 事件池路径 =====
const EVENT_DIR: String = "res://resources/events/"

## ===== 冷却与阶段预算 =====
const COOLDOWN_MONTHS: int = 2                ## 事件间最小间隔（月）
const PHASE_BUDGET: Dictionary = {
	&"early": { "min": 1, "max": 2 },
	&"mid":   { "min": 2, "max": 3 },
	&"late":  { "min": 0, "max": 1 },
}

## ===== 内部状态 =====
var _all_events: Array[EventData] = []        ## 全部加载的事件
var _available_pool: Array[EventData] = []    ## 本局可用事件（洗牌后）
var _triggered_ids: Array[String] = []        ## 已触发事件ID
var _last_trigger_month: int = -99            ## 上次触发的月份
var _phase_counts: Dictionary = {             ## 各阶段已触发次数
	&"early": 0,
	&"mid": 0,
	&"late": 0,
}
var _phase_budgets: Dictionary = {}           ## 各阶段实际预算（init时随机决定）
var _initialized: bool = false


## ===== 初始化本局事件池 =====
func init_schedule(_topic_id: String) -> void:
	_load_all_events()
	_triggered_ids.clear()
	_last_trigger_month = -99
	_phase_counts = { &"early": 0, &"mid": 0, &"late": 0 }

	# 为每个阶段随机确定本局预算
	for phase: StringName in PHASE_BUDGET:
		var budget_cfg: Dictionary = PHASE_BUDGET[phase]
		var min_val: int = budget_cfg.get("min", 0) as int
		var max_val: int = budget_cfg.get("max", 0) as int
		_phase_budgets[phase] = randi_range(min_val, max_val)

	# 洗牌事件池
	_available_pool = _all_events.duplicate()
	_available_pool.shuffle()
	_initialized = true


## ===== 每次研发推进后调用，检查是否触发事件 =====
## 返回 EventData 表示触发，返回 null 表示没有事件
func check_events(elapsed_months: int) -> EventData:
	if not _initialized:
		return null

	# 冷却检查
	if (elapsed_months - _last_trigger_month) < COOLDOWN_MONTHS:
		return null

	# 当前阶段
	var phase: StringName = _get_phase_from_months(elapsed_months)

	# 阶段预算检查
	var budget: int = _phase_budgets.get(phase, 0) as int
	var used: int = _phase_counts.get(phase, 0) as int
	if used >= budget:
		return null

	# 从可用池中找一个匹配当前阶段的事件
	var event: EventData = _pick_event_for_phase(phase)
	if event == null:
		return null

	# 概率触发（固定事件100%，随机事件60%）
	if not event.is_fixed:
		var roll: float = randf()
		if roll > 0.6:
			return null

	# 触发！
	_last_trigger_month = elapsed_months
	_phase_counts[phase] = used + 1
	_triggered_ids.append(event.event_id)
	_available_pool.erase(event)

	return event


## ===== 加载全部事件资源 =====
func _load_all_events() -> void:
	_all_events.clear()
	var dir := DirAccess.open(EVENT_DIR)
	if dir == null:
		push_error("EventScheduler: 无法打开事件目录 %s" % EVENT_DIR)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path: String = EVENT_DIR + file_name
			var res: Resource = load(path)
			if res is EventData:
				_all_events.append(res as EventData)
		file_name = dir.get_next()
	dir.list_dir_end()


## ===== 从可用池中挑选匹配阶段的事件 =====
func _pick_event_for_phase(phase: StringName) -> EventData:
	# 优先找固定探索点
	for event: EventData in _available_pool:
		if event.is_fixed and phase in event.allowed_phases:
			if event.event_id not in _triggered_ids:
				return event

	# 其次找随机事件
	for event: EventData in _available_pool:
		if not event.is_fixed and phase in event.allowed_phases:
			if event.event_id not in _triggered_ids:
				return event

	return null


## ===== 根据已消耗月份计算阶段 =====
func _get_phase_from_months(elapsed: int) -> StringName:
	var progress: float = float(elapsed) / float(Config.TIME_TOTAL_MONTHS)
	if progress < Config.PHASE_EARLY_END:
		return &"early"
	elif progress < Config.PHASE_MID_END:
		return &"mid"
	else:
		return &"late"
