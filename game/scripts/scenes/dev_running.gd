# dev_running.gd — 研发流程主控（迷雾地图探索驱动）
# 职责：地图交互、品质积累、事件触发、可选节点、UI刷新
extends Control

## ===== 信号 =====
signal dev_advanced(progress: float, phase: StringName, remaining: int)
signal launch_pressed()

## ===== 品质系统 =====
var quality_system: QualitySystem = null

## ===== 事件调度器 =====
var event_scheduler: EventScheduler = null

## ===== 迷雾地图 =====
var fog_map: FogMap = null

## ===== 状态标记 =====
var _playtest_triggered: bool = false
var _polish_triggered: bool = false
var _popup_active: bool = false
var _loading_active: bool = false                ## 格子正在 loading 中
var _cells_revealed_count: int = 0              ## 当前地图揭开格子计数（不含起点）
var _fight_triggered_count: int = 0             ## 已触发小游戏次数
var _exit_reached: bool = false                  ## 撤离点是否已连通
var _last_minigame_type: String = ""            ## 上次小游戏类型（避免连续相同）

## ===== 预加载弹窗场景 =====
const PlaytestPopupScene: PackedScene = preload("res://scenes/popups/playtest_popup.tscn")
const PolishPopupScene: PackedScene = preload("res://scenes/popups/polish_popup.tscn")
const SearchEventPopupScene: PackedScene = preload("res://scenes/popups/search_event_popup.tscn")
const FightEventPopupScene: PackedScene = preload("res://scenes/popups/fight_event_popup.tscn")
const MapCellScene: PackedScene = preload("res://scenes/ui/map_cell.tscn")

## ===== UI 引用 =====
@onready var quality_grade_label: Label = %QualityGradeLabel
@onready var explore_label: Label = %ExploreLabel
@onready var quality_hint: Label = %QualityHint
@onready var event_log: VBoxContainer = %EventLog
@onready var launch_button: Button = %LaunchButton
@onready var popup_layer: CanvasLayer = %PopupLayer
@onready var map_grid: GridContainer = %MapGrid
@onready var bottom_hint: Label = %BottomHint

## ===== 竞争态势栏 UI 引用 =====
@onready var competitor_list: VBoxContainer = %CompetitorList
@onready var market_heat_label: Label = %MarketHeatLabel
@onready var competitor_summary: Label = %CompetitorSummary
@onready var toast_label: Label = %ToastLabel

## ===== 格子UI引用 =====
var _cell_nodes: Array = []  # [row][col] = MapCell Button


func _ready() -> void:
	var resources: Dictionary = GameManager.run_data.get("resources", {})
	var creator_level: int = resources.get("creator", 1)
	var outsource_level: int = resources.get("outsource", 1)

	# 初始化品质系统
	quality_system = QualitySystem.new(creator_level, outsource_level)

	# 恢复已有品质（从确认界面返回时）
	var existing_quality: float = GameManager.run_data.get("quality", 0.0) as float
	if existing_quality > 0.0:
		quality_system.raw_score = existing_quality
	var existing_cap: float = GameManager.run_data.get("quality_cap", 0.0) as float
	if existing_cap > 0.0:
		quality_system.cap = existing_cap
	else:
		GameManager.run_data["quality_cap"] = quality_system.cap

	# 恢复内测状态
	if GameManager.run_data.get("quality_revealed", false) as bool:
		quality_system.revealed = true

	# 恢复可选节点触发状态
	_playtest_triggered = GameManager.run_data.get("did_playtest", false) as bool
	_polish_triggered = GameManager.run_data.get("did_polish", false) as bool

	# 初始化事件调度器
	event_scheduler = EventScheduler.new()
	var topic_id: String = str(GameManager.run_data.get("topic", ""))
	event_scheduler.init_schedule(topic_id)

	# 生成迷雾地图
	fog_map = FogMapGenerator.generate()

	# 构建地图UI
	_build_map_grid()

	# 绑定按钮
	launch_button.pressed.connect(_on_launch_pressed)
	# 上线按钮初始锁定（需要连通撤离点才能解锁）
	launch_button.disabled = true
	launch_button.tooltip_text = "需要连通撤离点才能上线"

	# 初始化UI
	_update_ui()

	# 开场日志
	if existing_quality <= 0.0:
		_add_log("%s 研发启动！前方迷雾重重，点击相邻格子探索" % AssetRegistry.emoji_bbcode("📋"))
		_add_log("%s 找到撤离点 %s 才能上线！" % [AssetRegistry.emoji_bbcode("💡"), AssetRegistry.emoji_bbcode("🚀")])
	else:
		_add_log("%s 返回研发——继续探索" % AssetRegistry.emoji_bbcode("🔙"))

	# 初始化竞争态势栏
	_refresh_competitor_panel()

	# 监听竞品上线信号（Toast提示）
	EventBus.competitor_launched.connect(_on_competitor_launched_toast)

	# 设置背景图
	_setup_background()


## ===== 构建8×8地图网格 =====
func _build_map_grid() -> void:
	map_grid.columns = FogMap.MAP_SIZE

	_cell_nodes.resize(FogMap.MAP_SIZE)
	for row: int in range(FogMap.MAP_SIZE):
		var row_arr: Array = []
		row_arr.resize(FogMap.MAP_SIZE)
		for col: int in range(FogMap.MAP_SIZE):
			var cell_node: Button = MapCellScene.instantiate()
			var cell_type: FogMap.CellType = fog_map.get_cell_type(row, col)
			var cell_state: FogMap.CellState = fog_map.get_cell_state(row, col)
			var cell_rarity: FogMap.Rarity = fog_map.get_cell_rarity(row, col)
			cell_node.setup(row, col, cell_type, cell_state, cell_rarity)

			# 标记起点
			if Vector2i(row, col) == fog_map.start_pos:
				cell_node.is_start = true

			cell_node.cell_clicked.connect(_on_cell_clicked)
			cell_node.cell_loading_finished.connect(_on_cell_loading_finished)
			cell_node.cell_month_tick.connect(_on_cell_month_tick)
			map_grid.add_child(cell_node)
			row_arr[col] = cell_node
		_cell_nodes[row] = row_arr


## ===== 格子点击处理（启动 loading 动画）=====
func _on_cell_clicked(row: int, col: int) -> void:
	if _popup_active or _loading_active:
		return
	if not TimeManager.is_active:
		return

	var cell_node: Button = _cell_nodes[row][col]
	var month_cost: int = cell_node.get_month_cost()

	# 锁定所有格子，开始 loading
	_loading_active = true
	_disable_all_cells()

	var rarity_name: String = FogMap.RARITY_NAMES[cell_node.rarity]
	var rarity_label: String = Config.RARITY_LEVELS.get(rarity_name, {}).get("label", "普通") as String
	var verbs: Array[String] = ["埋头开发中", "疯狂写码中", "需求评审中", "联调测试中", "技术攻关中"]
	var verb: String = verbs[randi_range(0, verbs.size() - 1)]
	_add_log("%s [%s] %s..." % [AssetRegistry.emoji_bbcode("⏳"), rarity_label, verb])

	cell_node.start_loading()


## ===== loading 期间每消耗1个月的回调 =====
func _on_cell_month_tick(row: int, col: int) -> void:
	# 逐月消耗时间 + 品质积累
	TimeManager.consume_months(1)
	quality_system.accumulate(1)
	_sync_quality_to_run_data()

	# 发射信号更新顶部 UI
	var progress: float = TimeManager.get_progress()
	var phase: StringName = TimeManager.get_dev_phase()
	var remaining: int = TimeManager.get_remaining()
	dev_advanced.emit(progress, phase, remaining)


## ===== loading 完成回调（执行揭开逻辑）=====
func _on_cell_loading_finished(row: int, col: int) -> void:
	_loading_active = false

	# 揭开格子
	var result: Variant = fog_map.reveal_cell(row, col)
	if result == null:
		_enable_clickable_cells()
		_update_ui()
		return

	var cell_type: FogMap.CellType = result as FogMap.CellType

	# 揭开计数（用于保底小游戏触发）
	_cells_revealed_count += 1

	# 保底机制：每 N 格未触发小游戏，强制变为打类事件
	if _fight_triggered_count == 0 and _cells_revealed_count >= Config.MAP_GUARANTEED_FIGHT_CELL:
		if cell_type == FogMap.CellType.EMPTY or cell_type == FogMap.CellType.SEARCH_EVENT:
			cell_type = FogMap.CellType.FIGHT_EVENT
			fog_map.set_cell(row, col, FogMap.CellType.FIGHT_EVENT)
			_add_log("%s [color=orange]局势突变——危机降临！[/color]" % AssetRegistry.emoji_bbcode("💥"))

	# 月数已在 loading 过程中逐月消耗，此处不再 consume_months

	# 更新地图视觉
	_refresh_map_visuals()

	# 时间耗尽检查
	if not TimeManager.is_active:
		_add_log("[color=red]%s 时间耗尽！研发被迫终止[/color]" % AssetRegistry.emoji_bbcode("⏰"))
		_disable_all_cells()
		_update_ui()
		return

	# 根据格子类型触发内容
	match cell_type:
		FogMap.CellType.EMPTY:
			_handle_empty_cell()
		FogMap.CellType.SEARCH_EVENT:
			_handle_search_event(row, col)
		FogMap.CellType.FIGHT_EVENT:
			_handle_fight_event()
		FogMap.CellType.TREASURE:
			_handle_treasure()
		FogMap.CellType.PLAYTEST:
			_handle_playtest()
		FogMap.CellType.POLISH:
			_handle_polish()
		FogMap.CellType.EXIT:
			_handle_exit()

	# AI竞品上线检查
	_check_competitor_launches()

	# 撤离点连通判定
	if not _exit_reached and not _popup_active and fog_map.check_path_connected():
		_exit_reached = true
		_handle_exit_reached()
		_update_ui()
		return

	# 解锁格子（如果没有弹窗激活的话）
	if not _popup_active:
		_enable_clickable_cells()

	# 刷新UI
	_update_ui()


## ===== 格子类型处理 =====

func _handle_empty_cell() -> void:
	var bonus: float = randf_range(Config.MAP_EMPTY_QUALITY_MIN, Config.MAP_EMPTY_QUALITY_MAX)
	quality_system.apply_boost(bonus)
	_sync_quality_to_run_data()
	_add_log("%s 又是平淡的一个月（品质+%.1f）" % [AssetRegistry.emoji_bbcode("🏗️"), bonus])


func _handle_search_event(row: int, col: int) -> void:
	var elapsed: int = TimeManager.elapsed_months
	var event: EventData = event_scheduler.check_events(elapsed)
	if event == null or event.event_type != EventData.EventType.SEARCH:
		event = _find_any_search_event()
	if event == null:
		# fallback: 当成空地
		var bonus: float = randf_range(1.0, 2.0)
		quality_system.apply_boost(bonus)
		_sync_quality_to_run_data()
		_add_log("%s 探索了一番，发现了一些有用的东西（品质+%.1f）" % [AssetRegistry.emoji_bbcode("🔍"), bonus])
		return

	# 根据稀有度决定：高稀有度弹窗展示，低稀有度静默日志
	var cell_rarity: FogMap.Rarity = fog_map.get_cell_rarity(row, col)
	if cell_rarity >= Config.MAP_GLOW_RARITY_THRESHOLD:
		# 稀有+史诗+传说：弹窗展示
		_trigger_search_event(event)
	else:
		# 普通+优良：静默获得收益，只写日志
		_apply_search_benefit(event)
		_add_log("%s %s — %s" % [AssetRegistry.emoji_bbcode("🔍"), event.title, event.search_benefit_desc])
		_sync_quality_to_run_data()
		_update_ui()


func _handle_fight_event() -> void:
	_fight_triggered_count += 1
	var event: EventData = _pick_fight_event()
	if event != null:
		_last_minigame_type = _get_minigame_type(event)
		_trigger_fight_event(event)
	else:
		quality_system.apply_penalty(2.0)
		_sync_quality_to_run_data()
		_add_log("%s 遇到小麻烦，处理完了（品质-2.0）" % AssetRegistry.emoji_bbcode("⚠️"))


## 统一选择打类事件，保证：首次必出 survivor、不连续同类型
func _pick_fight_event() -> EventData:
	var elapsed: int = TimeManager.elapsed_months

	# 首次强制 Bug Survivor
	if _fight_triggered_count == 1:
		var ev: EventData = _load_survivor_event()
		if ev != null:
			return ev

	# 尝试从调度器获取
	var candidates: Array[EventData] = []

	var scheduled: EventData = event_scheduler.check_events(elapsed)
	if scheduled != null and scheduled.event_type == EventData.EventType.FIGHT:
		candidates.append(scheduled)

	# 补充 fallback 候选（洗牌）
	var fallback_paths: Array[String] = FALLBACK_FIGHT_EVENTS.duplicate()
	fallback_paths.append_array(SURVIVOR_EVENTS)
	fallback_paths.shuffle()
	for path: String in fallback_paths:
		var res: Resource = load(path)
		if res is EventData:
			var ev: EventData = res as EventData
			# 去重：不重复已有候选
			var already: bool = false
			for c: EventData in candidates:
				if c.event_id == ev.event_id:
					already = true
					break
			if not already:
				candidates.append(ev)

	# 优先选不同类型的
	for ev: EventData in candidates:
		if _get_minigame_type(ev) != _last_minigame_type:
			return ev

	# 实在只有同类型，也得返回一个
	if candidates.size() > 0:
		return candidates[0]

	return null


func _handle_treasure() -> void:
	# 随机三种收益之一
	var roll: int = randi_range(0, 2)
	match roll:
		0:
			quality_system.apply_boost(Config.MAP_TREASURE_QUALITY)
			_sync_quality_to_run_data()
			_add_log("%s 发现宝箱！品质+%.0f" % [AssetRegistry.emoji_bbcode("💎"), Config.MAP_TREASURE_QUALITY])
		1:
			var current_bonus: float = GameManager.run_data.get("speed_bonus", 0.0) as float
			GameManager.run_data["speed_bonus"] = current_bonus + Config.MAP_TREASURE_SPEED_BONUS
			_add_log("%s 发现宝箱！研发效率+%.0f%%" % [AssetRegistry.emoji_bbcode("💎"), Config.MAP_TREASURE_SPEED_BONUS * 100])
		2:
			var current_energy: int = GameManager.run_data.get("bonus_energy", 0) as int
			GameManager.run_data["bonus_energy"] = current_energy + Config.MAP_TREASURE_ENERGY_BONUS
			_add_log("%s 发现宝箱！精力+%d" % [AssetRegistry.emoji_bbcode("💎"), Config.MAP_TREASURE_ENERGY_BONUS])


func _handle_playtest() -> void:
	if _playtest_triggered:
		_add_log("%s 内测设备还在，但已经用过了" % AssetRegistry.emoji_bbcode("🔬"))
		return
	_playtest_triggered = true
	_trigger_playtest()


func _handle_polish() -> void:
	if _polish_triggered:
		_add_log("%s 打磨工具还在，但已经用过了" % AssetRegistry.emoji_bbcode("✨"))
		return
	_polish_triggered = true
	_trigger_polish()


func _handle_exit() -> void:
	# 撤离点格子被揭开时的处理（实际上撤离点通过连通判定自动处理）
	# 此方法保留作为安全兜底
	if not _exit_reached:
		_exit_reached = true
		_handle_exit_reached()


## ===== 撤离点连通处理 =====
func _handle_exit_reached() -> void:
	_popup_active = true
	_disable_all_cells()

	# 将撤离点标记为 REVEALED
	var ep: Vector2i = fog_map.exit_pos
	fog_map.states[ep.x][ep.y] = FogMap.CellState.REVEALED
	_refresh_map_visuals()

	_add_log("%s [color=orange]撤离点已到达！是否现在上线？[/color]" % AssetRegistry.emoji_bbcode("🚀"))

	# 构建确认弹窗
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.border_color = Color("#f0a030")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "撤离点已到达！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f0a030"))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var grade_name: String = quality_system.get_display_grade_name()
	var remaining: int = TimeManager.get_remaining()
	var desc := Label.new()
	desc.text = "当前品质：%s\n剩余 %d 个月\n\n现在上线，还是继续探索周边提升品质？" % [grade_name, remaining]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(desc)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_hbox)

	var launch_btn := Button.new()
	launch_btn.text = "上线发布"
	launch_btn.custom_minimum_size = Vector2(140, 44)
	var launch_style := StyleBoxFlat.new()
	launch_style.bg_color = Color("#f0a030")
	launch_style.set_corner_radius_all(6)
	launch_style.set_content_margin_all(8)
	launch_btn.add_theme_stylebox_override("normal", launch_style)
	launch_btn.add_theme_color_override("font_color", Color.BLACK)
	var launch_hover := StyleBoxFlat.new()
	launch_hover.bg_color = Color("#f0a030").lightened(0.2)
	launch_hover.set_corner_radius_all(6)
	launch_hover.set_content_margin_all(8)
	launch_btn.add_theme_stylebox_override("hover", launch_hover)
	btn_hbox.add_child(launch_btn)

	var continue_btn := Button.new()
	continue_btn.text = "继续探索"
	continue_btn.custom_minimum_size = Vector2(140, 44)
	var continue_style := StyleBoxFlat.new()
	continue_style.bg_color = Color(0.3, 0.3, 0.3)
	continue_style.set_corner_radius_all(6)
	continue_style.set_content_margin_all(8)
	continue_btn.add_theme_stylebox_override("normal", continue_style)
	var continue_hover := StyleBoxFlat.new()
	continue_hover.bg_color = Color(0.4, 0.4, 0.4)
	continue_hover.set_corner_radius_all(6)
	continue_hover.set_content_margin_all(8)
	continue_btn.add_theme_stylebox_override("hover", continue_hover)
	btn_hbox.add_child(continue_btn)

	panel.add_child(vbox)
	center.add_child(panel)

	var popup_root := Control.new()
	popup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_root.add_child(overlay)
	popup_root.add_child(center)
	popup_layer.add_child(popup_root)

	launch_btn.pressed.connect(_on_exit_launch.bind(popup_root))
	continue_btn.pressed.connect(_on_exit_continue.bind(popup_root))


func _on_exit_launch(popup: Control) -> void:
	popup.queue_free()
	_popup_active = false
	_on_launch_pressed()


func _on_exit_continue(popup: Control) -> void:
	popup.queue_free()
	_popup_active = false
	_add_log("%s [color=cyan]决定继续探索——提升品质再上线[/color]" % AssetRegistry.emoji_bbcode("🔄"))
	_enable_clickable_cells()
	_update_ui()


## ===== 辅助：找搜类/打类事件 =====
func _find_any_search_event() -> EventData:
	# 直接调用 check_events，接受任何类型
	var elapsed: int = TimeManager.elapsed_months
	var event: EventData = event_scheduler.check_events(elapsed)
	if event != null and event.event_type == EventData.EventType.SEARCH:
		return event
	return null


func _find_any_fight_event() -> EventData:
	var elapsed: int = TimeManager.elapsed_months
	var event: EventData = event_scheduler.check_events(elapsed)
	if event != null and event.event_type == EventData.EventType.FIGHT:
		return event
	return null


## 兜底：直接从资源目录加载一个打类事件（绕过调度器的冷却/预算限制）
const FALLBACK_FIGHT_EVENTS: Array[String] = [
	"res://resources/events/fight_tech_01.tres",
	"res://resources/events/fight_tech_02.tres",
	"res://resources/events/fight_team_01.tres",
	"res://resources/events/fight_external_01.tres",
	"res://resources/events/fight_survivor_01.tres",
	"res://resources/events/fight_survivor_02.tres",
	"res://resources/events/fight_memory_01.tres",
]

func _load_fallback_fight_event() -> EventData:
	var path: String = FALLBACK_FIGHT_EVENTS[randi_range(0, FALLBACK_FIGHT_EVENTS.size() - 1)]
	var res: Resource = load(path)
	if res is EventData:
		return res as EventData
	return null


## 加载一个 Bug Survivor 事件（首次打类事件优先触发）
const SURVIVOR_EVENTS: Array[String] = [
	"res://resources/events/fight_survivor_01.tres",
	"res://resources/events/fight_survivor_02.tres",
]

func _load_survivor_event() -> EventData:
	var path: String = SURVIVOR_EVENTS[randi_range(0, SURVIVOR_EVENTS.size() - 1)]
	var res: Resource = load(path)
	if res is EventData:
		return res as EventData
	return null


## 获取事件的小游戏类型（空字符串表示 code_rescue）
func _get_minigame_type(event: EventData) -> String:
	if event.minigame_type != "":
		return event.minigame_type
	return "code_rescue"


## ===== 随机事件触发（复用原有逻辑）=====
func _trigger_search_event(event: EventData) -> void:
	_popup_active = true
	_disable_all_cells()

	_add_log("%s [color=yellow]探索发现：%s[/color]" % [AssetRegistry.emoji_bbcode("🔍"), event.title])

	var popup: Control = SearchEventPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(event)
	popup.event_resolved.connect(_on_search_resolved.bind(popup, event))


func _on_search_resolved(accepted: bool, effects: Dictionary, popup: Control, event: EventData) -> void:
	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()

	if accepted:
		_apply_search_benefit(event)
	_sync_quality_to_run_data()
	_update_ui()


## 应用搜类事件收益（静默和弹窗共用）
func _apply_search_benefit(event: EventData) -> void:
	match event.search_benefit_type:
		EventData.SearchBenefitType.QUALITY_CAP:
			quality_system.cap += event.search_benefit_value
			GameManager.run_data["quality_cap"] = quality_system.cap
			_add_log("%s %s — 品质上限+%.0f" % [AssetRegistry.emoji_bbcode("✅"), event.title, event.search_benefit_value])
		EventData.SearchBenefitType.DEV_SPEED:
			var current_bonus: float = GameManager.run_data.get("speed_bonus", 0.0) as float
			GameManager.run_data["speed_bonus"] = current_bonus + event.search_benefit_value
			_add_log("%s %s — 研发效率+%.0f%%" % [AssetRegistry.emoji_bbcode("✅"), event.title, event.search_benefit_value * 100])
		EventData.SearchBenefitType.QUALITY_FLAT:
			quality_system.apply_boost(event.search_benefit_value)
			_add_log("%s %s — 品质+%.0f" % [AssetRegistry.emoji_bbcode("✅"), event.title, event.search_benefit_value])
		EventData.SearchBenefitType.ENERGY:
			var current_energy: int = GameManager.run_data.get("bonus_energy", 0) as int
			GameManager.run_data["bonus_energy"] = current_energy + int(event.search_benefit_value)
			_add_log("%s %s — 精力+%d" % [AssetRegistry.emoji_bbcode("✅"), event.title, int(event.search_benefit_value)])


func _trigger_fight_event(event: EventData) -> void:
	_popup_active = true
	_disable_all_cells()

	_add_log("%s [color=red]危机事件：%s[/color]" % [AssetRegistry.emoji_bbcode("⚠️"), event.title])

	var popup: Control = FightEventPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(event)
	popup.event_resolved.connect(_on_fight_resolved.bind(popup, event))


func _on_fight_resolved(result: String, effects: Dictionary, popup: Control, event: EventData) -> void:
	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()

	var quality_change: float = effects.get("quality", 0.0) as float
	var desc: String = effects.get("desc", "") as String

	# 时间成本已在开格子时支付，事件不再额外扣时间
	if quality_change != 0.0:
		if quality_change > 0:
			quality_system.apply_boost(quality_change)
		else:
			quality_system.apply_penalty(absf(quality_change))
		_sync_quality_to_run_data()

	match result:
		"risky":
			_add_log("%s [color=green]大成功！%s[/color]" % [AssetRegistry.emoji_bbcode("🏆"), desc])
		"steady":
			_add_log("%s %s" % [AssetRegistry.emoji_bbcode("✅"), desc])
		_:
			_add_log("%s [color=red]%s[/color]" % [AssetRegistry.emoji_bbcode("💔"), desc])

	_update_ui()


## ===== AI竞品上线检查（已由 AICompetitors._on_time_tick 自动处理）=====
## 此方法保留作为日志补充——检查最近是否有新上线的竞品
func _check_competitor_launches() -> void:
	pass  # 竞品上线由 AICompetitors autoload 自动检测并发射信号


## ===== 上线按钮（强制上线）=====
func _on_launch_pressed() -> void:
	if _popup_active or _loading_active:
		return

	_sync_quality_to_run_data()
	launch_pressed.emit()
	EventBus.launch_requested.emit()
	GameManager.transition_to(GameManager.GameState.LAUNCH_CONFIRM)


## ===== 内测验证节点 =====
func _trigger_playtest() -> void:
	_popup_active = true
	_disable_all_cells()

	var popup: Control = PlaytestPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(
		Config.PLAYTEST_MONTH_COST,
		quality_system.get_display_grade_name(),
		TimeManager.get_remaining()
	)
	popup.accepted.connect(_on_playtest_accepted.bind(popup))
	popup.skipped.connect(_on_playtest_skipped.bind(popup))


func _on_playtest_accepted(popup: Control) -> void:
	var still_alive: bool = TimeManager.consume_months(Config.PLAYTEST_MONTH_COST)
	quality_system.reveal()
	GameManager.run_data["did_playtest"] = true
	GameManager.run_data["quality_revealed"] = true
	_sync_quality_to_run_data()
	EventBus.quality_revealed.emit(quality_system.raw_score, quality_system.get_true_grade_name())
	_add_log("%s 内测完成 — 真实品质：[color=cyan]%s[/color]" % [AssetRegistry.emoji_bbcode("🔬"), quality_system.get_display_grade_name()])

	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()

	if not still_alive:
		_add_log("[color=red]%s 时间耗尽！[/color]" % AssetRegistry.emoji_bbcode("⏰"))
		_disable_all_cells()


func _on_playtest_skipped(popup: Control) -> void:
	_add_log("%s 跳过了内测验证" % AssetRegistry.emoji_bbcode("⏭️"))
	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()


## ===== 临上线打磨节点 =====
func _trigger_polish() -> void:
	_popup_active = true
	_disable_all_cells()

	var popup: Control = PolishPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(
		Config.POLISH_MONTH_COST,
		Config.POLISH_SUCCESS_CHANCE,
		Config.POLISH_QUALITY_BOOST,
		Config.POLISH_FAIL_PENALTY,
		Config.POLISH_BUG_FIX_MONTHS,
		quality_system.get_display_grade_name(),
		quality_system.revealed,
		TimeManager.get_remaining()
	)
	popup.accepted.connect(_on_polish_accepted.bind(popup))
	popup.skipped.connect(_on_polish_skipped.bind(popup))


func _on_polish_accepted(popup: Control) -> void:
	var still_alive: bool = TimeManager.consume_months(Config.POLISH_MONTH_COST)

	var roll: float = randf()
	if roll <= Config.POLISH_SUCCESS_CHANCE:
		quality_system.apply_boost(Config.POLISH_QUALITY_BOOST)
		GameManager.run_data["did_polish"] = true
		_sync_quality_to_run_data()
		_add_log("%s 打磨成功！品质提升至：[color=green]%s[/color]" % [AssetRegistry.emoji_bbcode("✨"), quality_system.get_display_grade_name()])

		popup.queue_free()
		_popup_active = false
		_enable_clickable_cells()
		_update_ui()
	else:
		popup.show_bug_choice(
			Config.POLISH_BUG_FIX_MONTHS,
			Config.POLISH_FAIL_PENALTY,
			TimeManager.get_remaining()
		)
		popup.bug_fix_chosen.connect(_on_bug_fix.bind(popup))
		popup.bug_ignore_chosen.connect(_on_bug_ignore.bind(popup))

	if not still_alive:
		_disable_all_cells()


func _on_bug_fix(popup: Control) -> void:
	var still_alive: bool = TimeManager.consume_months(Config.POLISH_BUG_FIX_MONTHS)
	GameManager.run_data["did_polish"] = true
	_sync_quality_to_run_data()
	_add_log("%s 紧急修复完成 — 品质未变，但消耗了额外时间" % AssetRegistry.emoji_bbcode("🔧"))

	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()

	if not still_alive:
		_add_log("[color=red]%s 时间耗尽！[/color]" % AssetRegistry.emoji_bbcode("⏰"))
		_disable_all_cells()


func _on_bug_ignore(popup: Control) -> void:
	quality_system.apply_penalty(Config.POLISH_FAIL_PENALTY)
	GameManager.run_data["did_polish"] = true
	_sync_quality_to_run_data()
	_add_log("%s 放弃修复 — 品质降至：[color=red]%s[/color]" % [AssetRegistry.emoji_bbcode("💥"), quality_system.get_display_grade_name()])

	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()


func _on_polish_skipped(popup: Control) -> void:
	_add_log("%s 跳过了打磨" % AssetRegistry.emoji_bbcode("⏭️"))
	popup.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()


## ===== 品质同步 =====
func _sync_quality_to_run_data() -> void:
	GameManager.run_data["quality"] = quality_system.raw_score
	EventBus.quality_changed.emit(quality_system.raw_score, quality_system.get_display_grade_name())


## ===== 地图视觉刷新 =====
func _refresh_map_visuals() -> void:
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var cell_node: Button = _cell_nodes[row][col]
			var new_state: FogMap.CellState = fog_map.get_cell_state(row, col)
			var new_type: FogMap.CellType = fog_map.get_cell_type(row, col)
			var new_rarity: FogMap.Rarity = fog_map.get_cell_rarity(row, col)
			cell_node.update_state(new_state, new_type, new_rarity)


func _disable_all_cells() -> void:
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			(_cell_nodes[row][col] as Button).disabled = true


func _enable_clickable_cells() -> void:
	if not TimeManager.is_active:
		_disable_all_cells()
		return
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var cell_node: Button = _cell_nodes[row][col]
			var state: FogMap.CellState = fog_map.get_cell_state(row, col)
			if state == FogMap.CellState.FOGGY and fog_map.get_cell_type(row, col) != FogMap.CellType.EXIT:
				cell_node.disabled = false
			else:
				cell_node.disabled = true


## ===== UI 刷新 =====
func _update_ui() -> void:
	var remaining: int = TimeManager.get_remaining()

	# 探索格数（时间/阶段由持久化顶栏 TimeBar 显示）
	explore_label.text = "已探索 %d 格" % fog_map.revealed_count

	var grade_name: String = quality_system.get_display_grade_name()
	if quality_system.revealed:
		quality_grade_label.text = "%s（已验证）" % grade_name
		quality_hint.text = "品质已通过内测验证"
	else:
		quality_grade_label.text = "%s（未验证）" % grade_name
		quality_hint.text = "品质评估可能存在偏差"

	# 底部提示
	if TimeManager.is_active:
		var clickable: int = fog_map.get_clickable_cells().size()
		bottom_hint.text = "点击迷雾格子探索（可探索：%d格）" % clickable
	else:
		bottom_hint.text = "时间已耗尽"
		_disable_all_cells()

	# 上线按钮：连通撤离点后才可用
	launch_button.disabled = _popup_active or not _exit_reached
	if _exit_reached:
		launch_button.tooltip_text = "上线发布"
	else:
		launch_button.tooltip_text = "需要连通撤离点才能上线"

	# 刷新竞争态势栏
	_refresh_competitor_panel()


## ===== 事件日志 =====
const MAX_LOG_ENTRIES: int = 10

func _add_log(text: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = "> %s" % text
	label.add_theme_font_size_override("normal_font_size", 15)
	label.custom_minimum_size.y = 22
	event_log.add_child(label)

	while event_log.get_child_count() > MAX_LOG_ENTRIES:
		var oldest: Node = event_log.get_child(0)
		event_log.remove_child(oldest)
		oldest.queue_free()


## ===== 外部接口 =====

func modify_quality(amount: float) -> void:
	if amount > 0:
		quality_system.apply_boost(amount)
	else:
		quality_system.apply_penalty(absf(amount))
	_sync_quality_to_run_data()
	_add_log("品质变化：%+.0f" % amount)
	_update_ui()


func show_popup(popup_node: Control) -> void:
	_popup_active = true
	_disable_all_cells()
	popup_layer.add_child(popup_node)


func close_popup(popup_node: Control) -> void:
	popup_node.queue_free()
	_popup_active = false
	_enable_clickable_cells()
	_update_ui()


## ===== 竞争态势栏刷新 =====
func _refresh_competitor_panel() -> void:
	if not is_instance_valid(AICompetitors):
		return

	# 清空旧列表
	for child in competitor_list.get_children():
		child.queue_free()

	# 逐个竞品显示
	for comp: AICompetitorData in AICompetitors.get_competitors():
		var item := RichTextLabel.new()
		item.bbcode_enabled = true
		item.fit_content = true
		item.scroll_active = false
		item.add_theme_font_size_override("normal_font_size", 14)
		item.custom_minimum_size.y = 28

		if comp.launched:
			var quality_text: String = AICompetitors.get_fuzzy_quality_text(comp.quality)
			item.text = "[color=red]●[/color] %s\n     [color=gray]已上线 | %s[/color]" % [
				_get_short_name(comp.competitor_name), quality_text]
		else:
			var hint: String = AICompetitors.get_personality_hint(comp.personality)
			item.text = "[color=yellow]●[/color] %s\n     [color=gray]开发中 | %s[/color]" % [
				_get_short_name(comp.competitor_name), hint]

		competitor_list.add_child(item)

	# 市场热度
	var topic_id: StringName = StringName(str(GameManager.run_data.get("topic", "")))
	var heat_text: String = MarketHeat.get_fuzzy_text(topic_id)
	var heat_color: Color = MarketHeat.get_fuzzy_color(topic_id)
	market_heat_label.text = "[i] 市场热度：%s" % heat_text
	market_heat_label.add_theme_color_override("font_color", heat_color)

	# 汇总
	var launched: int = AICompetitors.get_launched_count()
	var pending: int = AICompetitors.get_pending_count()
	competitor_summary.text = "已上线：%d 款 | 潜伏中：%d 家" % [launched, pending]


## ===== 截取竞品短名（只取游戏名部分）=====
func _get_short_name(full_name: String) -> String:
	# 格式："制作组 的 《游戏名》"——取《》部分 + 制作组
	var book_start: int = full_name.find("《")
	var book_end: int = full_name.find("》")
	if book_start >= 0 and book_end > book_start:
		var studio: String = full_name.substr(0, full_name.find(" 的 "))
		var game_title: String = full_name.substr(book_start, book_end - book_start + 1)
		return "%s %s" % [studio, game_title]
	return full_name


## ===== Toast 强提示 =====
func _on_competitor_launched_toast(competitor_name: String, _topic_id: String) -> void:
	_add_log("%s [color=orange]竞品上线：%s 已发布！[/color]" % [AssetRegistry.emoji_bbcode("📢"), competitor_name])
	_show_toast("[!] 竞品上线！%s 已发布！市场热度正在被消耗..." % competitor_name)
	_refresh_competitor_panel()


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 0.0

	var tween: Tween = create_tween()
	# 淡入
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	# 停留
	tween.tween_interval(2.0)
	# 淡出
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


## ===== 设置背景图 =====
func _setup_background() -> void:
	var tex: Texture2D = AssetRegistry.get_texture("background", "office")
	if tex == null:
		# fallback: 纯色深底（确保不会是透明空白）
		var fallback_bg := ColorRect.new()
		fallback_bg.color = Color(0.06, 0.07, 0.1)
		fallback_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fallback_bg)
		move_child(fallback_bg, 0)
		return
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1, 1, 1, 0.35)
	add_child(bg)
	move_child(bg, 0)
