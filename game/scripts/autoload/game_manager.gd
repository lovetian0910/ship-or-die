# game_manager.gd — 主状态机 + 局数据 + 场景调度
extends Node

## ===== 游戏主状态枚举 =====
enum GameState {
	MENU,
	ENTRY_SHOP,
	TOPIC_SELECT,
	DEV_RUNNING,
	LAUNCH_CONFIRM,
	SETTLEMENT,
}

## ===== 合法状态转移表 =====
const TRANSITIONS: Dictionary = {
	GameState.MENU:           [GameState.ENTRY_SHOP],
	GameState.ENTRY_SHOP:     [GameState.TOPIC_SELECT],
	GameState.TOPIC_SELECT:   [GameState.DEV_RUNNING],
	GameState.DEV_RUNNING:    [GameState.LAUNCH_CONFIRM, GameState.SETTLEMENT],
	GameState.LAUNCH_CONFIRM: [GameState.SETTLEMENT, GameState.DEV_RUNNING],
	GameState.SETTLEMENT:     [GameState.MENU, GameState.ENTRY_SHOP],
}

## ===== 场景路径映射 =====
const SCENE_PATHS: Dictionary = {
	GameState.MENU:           "res://scenes/main_menu.tscn",
	GameState.ENTRY_SHOP:     "res://scenes/entry_shop.tscn",
	GameState.TOPIC_SELECT:   "res://scenes/topic_select.tscn",
	GameState.DEV_RUNNING:    "res://scenes/dev_running.tscn",
	GameState.LAUNCH_CONFIRM: "res://scenes/launch_confirm.tscn",
	GameState.SETTLEMENT:     "res://scenes/settlement.tscn",
}

## ===== 当前状态 =====
var current_state: GameState = GameState.MENU

## ===== 局运行时数据（每局重置）=====
var run_data: Dictionary = {}

## ===== 跨局持久数据 =====
var persistent_data: Dictionary = {
	"money": Config.INITIAL_MONEY,
	"total_runs": 0,
}

## ===== 场景容器引用 =====
var _scene_container: Node = null
var _current_scene_instance: Node = null


func _ready() -> void:
	EventBus.time_expired.connect(_on_time_expired)


## 初始化（由 main.tscn 调用）
func setup(scene_container: Node) -> void:
	_scene_container = scene_container
	_load_scene(GameState.MENU)


## ===== 状态转移 =====
func transition_to(next_state: GameState) -> bool:
	var allowed: Array = TRANSITIONS.get(current_state, [])
	if next_state not in allowed:
		push_warning("非法状态转移: %s → %s" % [
			GameState.keys()[current_state],
			GameState.keys()[next_state]
		])
		return false

	var from_state := current_state
	current_state = next_state

	EventBus.state_changed.emit(
		GameState.keys()[from_state],
		GameState.keys()[next_state]
	)

	# 状态进入的前置逻辑（必须在场景加载之前）
	match next_state:
		GameState.DEV_RUNNING:
			# 只在首次进入研发时启动时间，从确认界面返回不重置
			if from_state == GameState.TOPIC_SELECT:
				TimeManager.start_new_round()

	_load_scene(next_state)

	# 状态进入的后置逻辑（场景加载之后）
	match next_state:
		GameState.SETTLEMENT:
			TimeManager.stop()

	return true


## ===== 场景切换（手动管理，保留永驻UI）=====
func _load_scene(state: GameState) -> void:
	if _current_scene_instance:
		_current_scene_instance.queue_free()
		_current_scene_instance = null

	var scene_path: String = SCENE_PATHS.get(state, "")
	if scene_path.is_empty():
		push_error("未找到状态 %s 对应的场景路径" % GameState.keys()[state])
		return

	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		push_error("场景加载失败: %s" % scene_path)
		return

	_current_scene_instance = packed_scene.instantiate()
	_scene_container.add_child(_current_scene_instance)


## ===== 新局初始化 =====
func start_new_run() -> void:
	persistent_data["total_runs"] += 1
	run_data = {
		"money_spent": 0,
		"resources": {
			"creator": 0,
			"outsource": 0,
			"business": 0,
		},
		"topic": "",
		"game_name": "",
		"quality": 0.0,
		"quality_cap": 0.0,
		"dev_phase": "early",
		"did_playtest": false,
		"competitor_revealed": false,
		"did_polish": false,
	}
	EventBus.run_started.emit()


## ===== 局结算：成功 =====
func end_run_success(earnings: int) -> void:
	persistent_data["money"] += earnings
	EventBus.money_changed.emit(persistent_data["money"])
	EventBus.run_ended.emit(true, earnings)


## ===== 局结算：失败 =====
func end_run_fail() -> void:
	persistent_data["money"] = max(persistent_data["money"], Config.MIN_MONEY)
	EventBus.money_changed.emit(persistent_data["money"])
	EventBus.run_ended.emit(false, 0)


## ===== 时间耗尽回调 =====
func _on_time_expired() -> void:
	end_run_fail()
	transition_to(GameState.SETTLEMENT)
