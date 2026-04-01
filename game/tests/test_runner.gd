# test_runner.gd — 自动化测试，作为场景节点运行（Autoload 可用）
extends Node

var _frame: int = 0
var _test_phase: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_log: Array[String] = []
var _done: bool = false


func _process(_delta: float) -> void:
	if _done:
		return

	_frame += 1

	# 等几帧让场景树稳定
	if _frame < 5:
		return

	match _test_phase:
		0:
			_run_autoload_tests()
			_test_phase = 1
		1:
			_run_menu_test()
			_test_phase = 2
			return  # 等一帧让场景切换
		2:
			_run_shop_test()
			_test_phase = 3
			return
		3:
			_run_topic_test()
			_test_phase = 4
			return
		4:
			_run_dev_running_test()
			_test_phase = 5
			return
		5:
			_run_launch_confirm_test()
			_test_phase = 6
			return
		6:
			_run_settlement_test()
			_test_phase = 7
			return
		7:
			_run_second_loop_test()
			_test_phase = 8
			return
		8:
			_run_time_expire_test()
			_test_phase = 9
		9:
			_run_ai_competitor_test()
			_test_phase = 10
		10:
			_run_event_scheduler_test()
			_test_phase = 11
		11:
			_run_code_rescue_grid_test()
			_test_phase = 12
		12:
			_run_quality_system_test()
			_test_phase = 13
		13:
			_run_settlement_calculator_test()
			_test_phase = 14
		14:
			_run_fog_map_test()
			_test_phase = 15
		15:
			_run_bug_survivor_data_test()
			_test_phase = 16
		16:
			_run_minigame_no_repeat_test()
			_test_phase = 17
		17:
			_run_memory_match_data_test()
			_test_phase = 99
		99:
			_print_summary()
			_done = true
			get_tree().quit(0 if _tests_failed == 0 else 1)


## ===== 工具函数 =====

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_tests_passed += 1
		_test_log.append("  ✅ %s" % test_name)
	else:
		_tests_failed += 1
		_test_log.append("  ❌ %s" % test_name)


func _log_section(name: String) -> void:
	_test_log.append("\n=== %s ===" % name)


func _log_info(msg: String) -> void:
	_test_log.append("  ℹ️ %s" % msg)


func _find_button(root: Node, text_contains: String) -> Button:
	if root is Button and text_contains in (root as Button).text:
		return root as Button
	for child in root.get_children():
		var found := _find_button(child, text_contains)
		if found:
			return found
	return null


func _get_scene_container() -> Node:
	return get_node_or_null("/root/Main/SceneContainer")


func _get_current_scene() -> Node:
	var container := _get_scene_container()
	if container and container.get_child_count() > 0:
		return container.get_child(0)
	return null


## ===== 测试阶段 =====

func _run_autoload_tests() -> void:
	_log_section("Autoload 单例测试")

	_assert(Config != null, "Config 已加载")
	_assert(EventBus != null, "EventBus 已加载")
	_assert(TimeManager != null, "TimeManager 已加载")
	_assert(GameManager != null, "GameManager 已加载")

	var has_economy: bool = get_node_or_null("/root/EconomyManager") != null
	_assert(has_economy, "EconomyManager 已加载")

	var has_market: bool = get_node_or_null("/root/MarketHeat") != null
	_assert(has_market, "MarketHeat 已加载")

	var has_ai: bool = get_node_or_null("/root/AICompetitors") != null
	_assert(has_ai, "AICompetitors 已加载")

	_assert(Config.TIME_TOTAL_MONTHS == 36, "总月份 = 36")
	_assert(Config.INITIAL_MONEY == 600, "初始金钱 = 600")
	_assert(Config.MIN_MONEY == 300, "保底金钱 = 300")

	# 迷雾地图新常量
	_assert(Config.MAP_EXIT_COUNT == 1, "MAP_EXIT_COUNT=1")
	_assert(Config.MAP_EXIT_ALWAYS_VISIBLE == true, "MAP_EXIT_ALWAYS_VISIBLE=true")
	_assert(Config.MAP_GLOW_ALPHA > 0.0, "MAP_GLOW_ALPHA>0")

	_assert(
		GameManager.current_state == GameManager.GameState.MENU,
		"初始状态 = MENU"
	)


func _run_menu_test() -> void:
	_log_section("主菜单 → 入场选购")

	var scene := _get_current_scene()
	_assert(scene != null, "主菜单场景已加载")
	if not scene:
		_test_phase = 99
		return

	# 模拟点击"开始新游戏"
	GameManager.start_new_run()
	GameManager.transition_to(GameManager.GameState.ENTRY_SHOP)

	_assert(
		GameManager.current_state == GameManager.GameState.ENTRY_SHOP,
		"状态 = ENTRY_SHOP"
	)
	_assert(
		GameManager.persistent_data.get("total_runs", 0) == 1,
		"总局数 = 1"
	)


func _run_shop_test() -> void:
	_log_section("入场选购 → 选题")

	var money_before: int = GameManager.persistent_data.get("money", 0)
	_assert(money_before == Config.INITIAL_MONEY, "初始金钱正确: %d" % money_before)

	# 通过 EconomyManager 或直接设置资源
	var economy: Node = get_node_or_null("/root/EconomyManager")
	if economy and economy.has_method("purchase_loadout"):
		# 模拟购买最低配：3×100=300
		economy.call("purchase_loadout", 300)
		_log_info("通过 EconomyManager 扣款 300")
	else:
		GameManager.persistent_data["money"] -= 300
		_log_info("直接扣款 300")

	# 设置资源配置
	GameManager.run_data["resources"] = {
		"creator": 1,
		"outsource": 1,
		"business": 1,
	}
	GameManager.run_data["quality_cap"] = Config.QUALITY_CAP.get(1, 40.0)
	GameManager.run_data["money_spent"] = 300

	_assert(
		GameManager.persistent_data.get("money", 0) == money_before - 300,
		"扣款后金钱: %d" % GameManager.persistent_data.get("money", 0)
	)

	GameManager.transition_to(GameManager.GameState.TOPIC_SELECT)
	_assert(
		GameManager.current_state == GameManager.GameState.TOPIC_SELECT,
		"状态 = TOPIC_SELECT"
	)


func _run_topic_test() -> void:
	_log_section("选题 → 研发")

	GameManager.run_data["topic"] = "test_topic"
	GameManager.run_data["game_name"] = "自动测试游戏"

	GameManager.transition_to(GameManager.GameState.DEV_RUNNING)

	_assert(
		GameManager.current_state == GameManager.GameState.DEV_RUNNING,
		"状态 = DEV_RUNNING"
	)
	_assert(TimeManager.is_active, "TimeManager 已激活")
	_assert(TimeManager.get_remaining() == 36, "剩余 = 36 月")
	_assert(TimeManager.get_dev_phase() == &"early", "阶段 = early")


func _run_dev_running_test() -> void:
	_log_section("研发流程测试")

	# 测试月份消耗
	var alive: bool = TimeManager.consume_months(6)
	_assert(alive, "消耗 6 月后存活")
	_assert(TimeManager.get_remaining() == 30, "剩余 = 30 月")

	# 测试品质积累
	var outsource_level: int = GameManager.run_data.get("resources", {}).get("outsource", 1)
	var speed: float = Config.OUTSOURCE_SPEED.get(outsource_level, 1.0)
	var gain: float = Config.QUALITY_PER_MONTH * 6.0 * speed
	GameManager.run_data["quality"] = gain
	_assert(
		GameManager.run_data["quality"] > 0.0,
		"品质积累: %.1f" % GameManager.run_data["quality"]
	)

	# 消耗到中期
	TimeManager.consume_months(6)
	_assert(TimeManager.get_dev_phase() == &"mid", "阶段 = mid (progress=%.2f)" % TimeManager.get_progress())

	# 模拟内测验证
	GameManager.run_data["did_playtest"] = true
	GameManager.run_data["quality_revealed"] = true
	_log_info("执行内测验证，品质已揭示")

	# 消耗到后期（需要 progress > 0.7，即 elapsed > 25 月，当前已消耗 12，还需 14）
	TimeManager.consume_months(14)
	_assert(TimeManager.get_dev_phase() == &"late", "阶段 = late (progress=%.2f)" % TimeManager.get_progress())

	# 模拟打磨（成功路径）
	GameManager.run_data["did_polish"] = true
	GameManager.run_data["quality"] += Config.POLISH_QUALITY_BOOST
	_log_info("执行打磨，品质提升 %.1f" % Config.POLISH_QUALITY_BOOST)

	# 发起上线
	GameManager.transition_to(GameManager.GameState.LAUNCH_CONFIRM)
	_assert(
		GameManager.current_state == GameManager.GameState.LAUNCH_CONFIRM,
		"状态 = LAUNCH_CONFIRM"
	)
	_log_info("剩余 %d 月，品质 %.1f" % [TimeManager.get_remaining(), GameManager.run_data.get("quality", 0.0)])


func _run_launch_confirm_test() -> void:
	_log_section("上线确认 → 结算")

	var quality: float = GameManager.run_data.get("quality", 0.0)
	var earnings: int = int(quality * 10.0)
	_assert(earnings > 0, "收益 > 0: %d" % earnings)

	var money_before: int = GameManager.persistent_data.get("money", 0)
	GameManager.end_run_success(earnings)
	var money_after: int = GameManager.persistent_data.get("money", 0)

	_assert(money_after == money_before + earnings, "金钱增加: %d → %d (+%d)" % [money_before, money_after, earnings])

	GameManager.transition_to(GameManager.GameState.SETTLEMENT)
	_assert(
		GameManager.current_state == GameManager.GameState.SETTLEMENT,
		"状态 = SETTLEMENT"
	)


func _run_settlement_test() -> void:
	_log_section("结算 → 第二局")

	var money: int = GameManager.persistent_data.get("money", 0)
	_assert(money > Config.MIN_MONEY, "结算后金钱 > 保底: %d" % money)
	_log_info("第一局结束，当前金钱: %d" % money)


func _run_second_loop_test() -> void:
	_log_section("第二局循环 + 时间耗尽测试")

	var money_before: int = GameManager.persistent_data.get("money", 0)

	# 开始第二局
	GameManager.start_new_run()
	GameManager.transition_to(GameManager.GameState.ENTRY_SHOP)
	_assert(GameManager.persistent_data.get("total_runs", 0) == 2, "总局数 = 2")
	_assert(GameManager.run_data.get("quality", 0.0) == 0.0, "品质已重置")

	# 快进到研发
	GameManager.run_data["resources"] = {"creator": 2, "outsource": 2, "business": 2}
	GameManager.run_data["quality_cap"] = Config.QUALITY_CAP.get(2, 70.0)
	GameManager.run_data["money_spent"] = 900
	GameManager.persistent_data["money"] -= 900
	GameManager.transition_to(GameManager.GameState.TOPIC_SELECT)
	GameManager.run_data["topic"] = "test_topic_2"
	GameManager.run_data["game_name"] = "第二局测试"
	GameManager.transition_to(GameManager.GameState.DEV_RUNNING)

	_assert(TimeManager.is_active, "第二局 TimeManager 激活")
	_assert(TimeManager.get_remaining() == 36, "第二局剩余 = 36")
	_log_info("第二局开始，金钱: %d" % GameManager.persistent_data.get("money", 0))


func _run_time_expire_test() -> void:
	_log_section("时间耗尽（撤离失败）测试")

	var remaining: int = TimeManager.get_remaining()
	_log_info("消耗全部 %d 月" % remaining)

	TimeManager.consume_months(remaining)

	_assert(TimeManager.get_remaining() == 0, "剩余 = 0")
	_assert(not TimeManager.is_active, "TimeManager 已停止")
	_assert(
		GameManager.current_state == GameManager.GameState.SETTLEMENT,
		"时间耗尽 → 自动 SETTLEMENT"
	)

	var money: int = GameManager.persistent_data.get("money", 0)
	_assert(money >= Config.MIN_MONEY, "保底金钱: %d >= %d" % [money, Config.MIN_MONEY])
	_log_info("失败结算，金钱保底: %d" % money)


## ===== AI竞品数据结构测试 =====
func _run_ai_competitor_test() -> void:
	_log_section("AI竞品数据结构测试")

	var comp := AICompetitorData.new()
	comp.competitor_name = "测试工作室"
	comp.personality = AICompetitorData.Personality.AGGRESSIVE
	comp.quality = 50.0
	comp.planned_launch_month = 10
	comp.launched = false
	comp.topic_id = &"test"

	# 验证属性存在且可读写（覆盖 studio_name/game_name bug）
	_assert(comp.competitor_name == "测试工作室", "AICompetitorData.competitor_name 可读写")
	_assert(comp.quality == 50.0, "AICompetitorData.quality 可读写")
	_assert(comp.planned_launch_month == 10, "AICompetitorData.planned_launch_month 可读写")
	_assert(comp.launched == false, "AICompetitorData.launched 默认 false")
	_assert(comp.topic_id == &"test", "AICompetitorData.topic_id 可读写")

	# 验证不存在错误属性名（通过反射检查）
	_assert(not ("studio_name" in comp), "AICompetitorData 无 studio_name 属性")
	_assert(not ("game_name" in comp), "AICompetitorData 无 game_name 属性")

	# 模拟上线
	comp.launched = true
	_assert(comp.launched == true, "AICompetitorData.launched 可设为 true")

	# 验证 AICompetitors autoload 的 get_competitors 返回类型
	if AICompetitors.has_method("get_competitors"):
		var competitors: Array = AICompetitors.get_competitors()
		_assert(competitors is Array, "AICompetitors.get_competitors() 返回 Array")
		for c: Variant in competitors:
			var cd: AICompetitorData = c as AICompetitorData
			_assert(cd != null, "竞品对象是 AICompetitorData 类型")
			_assert(cd.competitor_name != "", "竞品有 competitor_name: %s" % cd.competitor_name)
			break  # 只检查第一个
	else:
		_log_info("AICompetitors 无 get_competitors 方法，跳过")


## ===== 事件调度器测试 =====
func _run_event_scheduler_test() -> void:
	_log_section("事件调度器测试")

	var scheduler := EventScheduler.new()
	scheduler.init_schedule("test_topic")

	# 冷却测试：连续检查同月不应触发两次
	var event1: EventData = scheduler.check_events(3)
	var event2: EventData = scheduler.check_events(3)  # 同月，应被冷却
	if event1 != null:
		_assert(event2 == null, "冷却机制：同月不会连续触发")
		_assert(event1.event_id != "", "事件有 event_id: %s" % event1.event_id)
		_assert(event1.title != "", "事件有 title: %s" % event1.title)
		_assert(event1.description != "", "事件有 description")

		# 检查事件类型合法
		_assert(
			event1.event_type == EventData.EventType.SEARCH or event1.event_type == EventData.EventType.FIGHT,
			"事件类型合法: %d" % event1.event_type
		)

		# 搜类事件字段检查
		if event1.event_type == EventData.EventType.SEARCH:
			_assert(event1.search_month_cost > 0, "搜类事件 month_cost > 0")
			_log_info("搜类事件: %s (消耗%d月)" % [event1.title, event1.search_month_cost])

		# 打类事件字段检查
		if event1.event_type == EventData.EventType.FIGHT:
			_assert(event1.fight_preset_path != "", "打类事件有 preset_path")
			_assert(event1.fight_conservative_desc != "", "打类事件有 conservative_desc")
			var effects: Dictionary = event1.get_fight_effects("conservative")
			_assert(effects.has("quality"), "get_fight_effects 返回含 quality")
			_assert(effects.has("desc"), "get_fight_effects 返回含 desc")
			_log_info("打类事件: %s" % event1.title)
	else:
		_log_info("首次检查未触发事件（正常，取决于随机预算）")

	# 间隔足够后应能再次触发
	var event3: EventData = scheduler.check_events(8)  # 间隔5月，超过冷却
	_log_info("间隔5月后检查: %s" % ("触发" if event3 != null else "未触发"))


## ===== 代码急救网格测试 =====
func _run_code_rescue_grid_test() -> void:
	_log_section("代码急救网格测试 — 基础")

	var grid := CodeRescueGrid.new()
	var positions: Array = [Vector2i(0, 0), Vector2i(2, 2), Vector2i(5, 5)]
	grid.init_grid(positions)

	_assert(grid.pending_count == 33, "初始待处理格 = 33 (36-3)")
	_assert(grid.bug_count == 3, "初始bug = 3")
	_assert(grid.repaired_count == 0, "初始修复 = 0")
	_assert(grid.crashed_count == 0, "初始崩溃 = 0")
	_assert_counts_consistent(grid, "初始化后")

	# 修复测试
	var repaired: bool = grid.repair_cell(0, 0)
	_assert(repaired, "修复 (0,0) 成功")
	_assert(grid.bug_count == 2, "修复后 bug = 2")
	_assert(grid.get_cell(0, 0) == CodeRescueGrid.CellState.REPAIRED, "修复后状态 = REPAIRED")
	_assert(grid.repaired_count == 1, "修复后 repaired_count = 1")
	_assert_counts_consistent(grid, "修复后")

	# 不能修复待处理格/崩溃格
	_assert(not grid.repair_cell(1, 1), "不能修复待处理格")
	var cg := CodeRescueGrid.new()
	cg.init_grid([Vector2i(0, 0)])
	cg.spread_tick(); cg.spread_tick(); cg.spread_tick()
	_assert(not cg.repair_cell(0, 0), "不能修复崩溃格")

	# 崩溃阈值：3次tick
	var tg := CodeRescueGrid.new()
	tg.init_grid([Vector2i(3, 3)])
	tg.spread_tick(); tg.spread_tick(); tg.spread_tick()
	_assert(tg.get_cell(3, 3) == CodeRescueGrid.CellState.CRASHED, "3次tick → 崩溃")
	_assert_counts_consistent(tg, "崩溃后")

	# 崩溃格不被覆盖
	var tg2 := CodeRescueGrid.new()
	tg2.init_grid([Vector2i(3, 3)])
	tg2.spread_tick(); tg2.spread_tick(); tg2.spread_tick()
	tg2.cells[3][4] = CodeRescueGrid.CellState.BUG
	tg2.bug_count += 1; tg2.pending_count -= 1
	tg2.spread_tick()
	_assert(tg2.get_cell(3, 3) == CodeRescueGrid.CellState.CRASHED, "崩溃格不被覆盖")

	# bug清零后不再自动刷新（已移除无限刷新机制）
	_log_section("代码急救网格测试 — 清零=胜利")
	var g_win := CodeRescueGrid.new()
	g_win.init_grid([Vector2i(1, 1)])
	g_win.repair_cell(1, 1)
	_assert(g_win.bug_count == 0, "修完所有bug后 bug = 0")
	_assert(g_win.get_cell(1, 1) == CodeRescueGrid.CellState.REPAIRED, "修复后格子状态 = REPAIRED")
	g_win.spread_tick()
	_assert(g_win.bug_count == 0, "清零后spread_tick不会刷新新bug")
	_assert_counts_consistent(g_win, "清零后")

	# 修复后的格子不会被重新感染
	_log_section("代码急救网格测试 — 修复格免疫")
	var g_immune := CodeRescueGrid.new()
	g_immune.init_grid([Vector2i(2, 2), Vector2i(2, 3)])
	g_immune.repair_cell(2, 2)
	_assert(g_immune.get_cell(2, 2) == CodeRescueGrid.CellState.REPAIRED, "修复(2,2)为REPAIRED")
	# 多次扩散tick，(2,2)应保持REPAIRED
	for _tick: int in range(5):
		g_immune.spread_tick()
	_assert(g_immune.get_cell(2, 2) == CodeRescueGrid.CellState.REPAIRED, "多次扩散后(2,2)仍为REPAIRED")

	# ===== 数值模拟：不同预设 × 不同点击速度 =====
	_log_section("代码急救 — 数值模拟（可通关性验证）")

	# 预设参数：[名称, 初始bug, 扩散间隔秒, 精力]
	var presets: Array = [
		["技术事故(商务低)", 3, 1.5, 8],
		["技术事故(商务中)", 3, 1.5, 12],
		["技术事故(商务高)", 3, 1.5, 16],
		["团队内讧(固定)", 5, 2.0, 10],
		["外部冲击(商务低)", 2, 1.0, 8],
		["外部冲击(商务中)", 2, 1.0, 12],
		["外部冲击(商务高)", 2, 1.0, 16],
	]

	# 模拟不同点击间隔（秒）
	var click_intervals: Array = [0.1, 0.2, 0.3, 0.5, 0.8, 1.0]

	for preset: Array in presets:
		var p_name: String = preset[0] as String
		var p_bugs: int = preset[1] as int
		var p_spread: float = preset[2] as float
		var p_energy: int = preset[3] as int

		for click_iv: float in click_intervals:
			var result: Dictionary = _simulate_minigame(p_bugs, p_spread, p_energy, click_iv)
			var health: float = result.get("health", 0.0) as float
			var cleared: bool = result.get("cleared", false) as bool
			var clicks_used: int = result.get("clicks", 0) as int
			var grade: String = "大成功" if cleared else ("一般" if health >= 0.6 else "失败")

			if click_iv == 0.2 or click_iv == 0.5 or cleared:
				_log_info("%s | 点击间隔%.1fs | %s | 健康率%.0f%% | 用%d次点击" % [
					p_name, click_iv, grade, health * 100, clicks_used
				])

		# 核心断言：商务高 + 快速点击应该能通关
		var fast_result: Dictionary = _simulate_minigame(p_bugs, p_spread, p_energy, 0.15)
		var fast_cleared: bool = fast_result.get("cleared", false) as bool
		_assert(fast_cleared or fast_result.get("health", 0.0) as float >= 0.9,
			"%s 快速点击(0.15s)应可大成功" % p_name)

	# 核心断言：精力最低+最快点击，外部冲击（最难）也应该有机会
	var hard_fast: Dictionary = _simulate_minigame(2, 1.0, 8, 0.1)
	_assert(hard_fast.get("health", 0.0) as float >= 0.6,
		"外部冲击(商务低)+极速点击 健康率≥60%%")


## 模拟一局小游戏：返回 {health, cleared, clicks}
func _simulate_minigame(initial_bugs: int, spread_interval: float, energy: int, click_interval: float) -> Dictionary:
	var sim_grid := CodeRescueGrid.new()

	# 生成随机位置
	var bug_pos: Array = CodeRescueGrid.generate_bug_positions(initial_bugs, "random")
	sim_grid.init_grid(bug_pos)

	var game_time: float = 15.0  # 总时长
	var elapsed: float = 0.0
	var spread_timer: float = 0.0
	var click_timer: float = 0.0
	var clicks_used: int = 0
	var dt: float = 0.05  # 模拟步长 50ms

	while elapsed < game_time:
		elapsed += dt
		spread_timer += dt
		click_timer += dt

		# 扩散
		if spread_timer >= spread_interval:
			spread_timer -= spread_interval
			sim_grid.spread_tick()

			# 清零=提前胜利
			if sim_grid.bug_count == 0:
				return {"health": sim_grid.get_health_rate(), "cleared": true, "clicks": clicks_used}

		# 玩家点击修复（按间隔）
		if click_timer >= click_interval and energy > 0:
			click_timer -= click_interval
			# 找一个bug修复（优先靠近崩溃区的）
			var fixed: bool = false
			for row: int in range(CodeRescueGrid.GRID_SIZE):
				for col: int in range(CodeRescueGrid.GRID_SIZE):
					if sim_grid.get_cell(row, col) == CodeRescueGrid.CellState.BUG:
						sim_grid.repair_cell(row, col)
						energy -= 1
						clicks_used += 1
						fixed = true
						break
				if fixed:
					break

			# 修复后清零=胜利
			if sim_grid.bug_count == 0:
				return {"health": sim_grid.get_health_rate(), "cleared": true, "clicks": clicks_used}

			# 精力耗尽=立刻结束
			if energy <= 0:
				return {"health": sim_grid.get_health_rate(), "cleared": false, "clicks": clicks_used}

	return {"health": sim_grid.get_health_rate(), "cleared": false, "clicks": clicks_used}


## 辅助：验证 pending + bug + repaired + crashed == 36
func _assert_counts_consistent(grid: CodeRescueGrid, context: String) -> void:
	var total: int = grid.pending_count + grid.bug_count + grid.repaired_count + grid.crashed_count
	_assert(total == 36, "计数一致(%s): %d+%d+%d+%d=%d" % [
		context, grid.pending_count, grid.bug_count, grid.repaired_count, grid.crashed_count, total
	])


## ===== 品质系统测试 =====
func _run_quality_system_test() -> void:
	_log_section("品质系统测试")

	var qs := QualitySystem.new(2, 2)  # 中级主创+中级外包
	_assert(qs.cap == Config.QUALITY_CAP.get(2, 70.0), "品质上限 = %.0f" % qs.cap)
	_assert(qs.raw_score == 0.0, "初始品质 = 0")
	_assert(not qs.revealed, "初始未揭示")

	# 积累
	qs.accumulate(6)
	_assert(qs.raw_score > 0.0, "积累6月后品质 > 0: %.1f" % qs.raw_score)

	# 不超上限
	qs.accumulate(100)
	_assert(qs.raw_score <= qs.cap, "品质不超上限: %.1f <= %.1f" % [qs.raw_score, qs.cap])

	# 模糊等级
	var fuzzy: String = qs.get_display_grade_name()
	_assert(fuzzy != "", "模糊等级非空: %s" % fuzzy)

	# 揭示
	qs.reveal()
	_assert(qs.revealed, "揭示后 revealed = true")
	var true_grade: String = qs.get_true_grade_name()
	_assert(true_grade != "", "真实等级非空: %s" % true_grade)

	# 打磨提升（先降低品质确保不在上限）
	qs.raw_score = 50.0
	var before: float = qs.raw_score
	qs.apply_boost(8.0)
	_assert(qs.raw_score > before, "打磨后品质提升: %.1f → %.1f" % [before, qs.raw_score])

	# 惩罚
	var before2: float = qs.raw_score
	qs.apply_penalty(25.0)
	_assert(qs.raw_score < before2, "惩罚后品质下降")
	_assert(qs.raw_score >= 0.0, "品质不为负")


## ===== 结算计算器测试 =====
func _run_settlement_calculator_test() -> void:
	_log_section("结算计算器测试")

	# 热度乘数查表
	_assert(SettlementCalculator.get_heat_multiplier(10.0) == 0.4, "热度10 → 0.4x")
	_assert(SettlementCalculator.get_heat_multiplier(30.0) == 0.7, "热度30 → 0.7x")
	_assert(SettlementCalculator.get_heat_multiplier(50.0) == 1.0, "热度50 → 1.0x")
	_assert(SettlementCalculator.get_heat_multiplier(70.0) == 1.3, "热度70 → 1.3x")
	_assert(SettlementCalculator.get_heat_multiplier(90.0) == 1.6, "热度90 → 1.6x")

	# 品质因子测试
	var qf_zero: float = SettlementCalculator.get_quality_factor(0.0)
	_assert(is_equal_approx(qf_zero, Config.SETTLEMENT_QUALITY_FLOOR), "品质0 → floor=%.2f" % qf_zero)
	var qf_baseline: float = SettlementCalculator.get_quality_factor(Config.SETTLEMENT_QUALITY_BASELINE)
	_assert(is_equal_approx(qf_baseline, 1.0), "品质baseline → 1.0: %.2f" % qf_baseline)
	var qf_high: float = SettlementCalculator.get_quality_factor(100.0)
	_assert(qf_high > 1.0, "品质100 → >1.0: %.2f" % qf_high)

	# 完整计算（时间线分段结算）
	var result: Dictionary = SettlementCalculator.calculate({
		"total_users": 2000,
		"pay_ability": 0.8,
		"heat": 50.0,
		"player_quality": 60.0,
		"player_launch_month": 15,
		"total_months": 36,
		"competitors": [
			{"quality": 40.0, "launch_month": 20},
			{"quality": 30.0, "launch_month": 28},
		],
	})

	_assert(result.has("total_revenue"), "结果含 total_revenue")
	_assert(result.has("window_revenue"), "结果含 window_revenue")
	_assert(result.has("compete_revenue"), "结果含 compete_revenue")
	_assert(result.has("window_months"), "结果含 window_months")
	_assert(result.has("compete_months"), "结果含 compete_months")

	var total_rev: float = result.get("total_revenue", 0.0) as float
	_assert(total_rev > 0, "总收益 > 0: %.0f" % total_rev)

	# 独占月份应该 > 0（竞品2在25月上线，玩家20月~25月有独占）
	var win_months: int = result.get("window_months", 0) as int
	_assert(win_months > 0, "有独占月份: %d" % win_months)
	# 竞争月份也应该 > 0（竞品1在12月上线，竞品2在25月上线）
	var comp_months: int = result.get("compete_months", 0) as int
	_assert(comp_months > 0, "有竞争月份: %d" % comp_months)

	_log_info("时间线结算: 独占%d月 + 竞争%d月 = 收益%.0f" % [win_months, comp_months, total_rev])

	# 品质越高收益越高
	var result_high: Dictionary = SettlementCalculator.calculate({
		"total_users": 2000,
		"pay_ability": 1.0,
		"heat": 50.0,
		"player_quality": 90.0,
		"player_launch_month": 20,
		"total_months": 36,
		"competitors": [{"quality": 40.0, "launch_month": 22}],
	})
	var result_low_q: Dictionary = SettlementCalculator.calculate({
		"total_users": 2000,
		"pay_ability": 1.0,
		"heat": 50.0,
		"player_quality": 30.0,
		"player_launch_month": 20,
		"total_months": 36,
		"competitors": [{"quality": 40.0, "launch_month": 22}],
	})
	var total_high: float = result_high.get("total_revenue", 0.0) as float
	var total_low_q: float = result_low_q.get("total_revenue", 0.0) as float
	_assert(total_high > total_low_q, "品质90收益 > 品质30收益: %.0f > %.0f" % [total_high, total_low_q])

	# 早上线 vs 晚上线（竞品在月15上线）
	var result_early: Dictionary = SettlementCalculator.calculate({
		"total_users": 2000, "pay_ability": 1.0, "heat": 50.0,
		"player_quality": 50.0, "player_launch_month": 10, "total_months": 36,
		"competitors": [{"quality": 50.0, "launch_month": 15}],
	})
	var result_late: Dictionary = SettlementCalculator.calculate({
		"total_users": 2000, "pay_ability": 1.0, "heat": 50.0,
		"player_quality": 50.0, "player_launch_month": 28, "total_months": 36,
		"competitors": [{"quality": 50.0, "launch_month": 15}],
	})
	var early_rev: float = result_early.get("total_revenue", 0.0) as float
	var late_rev: float = result_late.get("total_revenue", 0.0) as float
	# 早上线有更多独占月，但后续全是竞争月；晚上线运营期短但竞争少不了
	_log_info("早上线(月10)=%.0f vs 晚上线(月28)=%.0f" % [early_rev, late_rev])


## ===== 迷雾地图测试 =====
func _run_fog_map_test() -> void:
	_log_section("迷雾地图生成与探索测试")

	# 生成地图（固定种子可复现）
	var fog_map: FogMap = FogMapGenerator.generate(42)
	_assert(fog_map != null, "地图生成成功")
	_assert(fog_map.start_pos.x >= 2 and fog_map.start_pos.x <= 5, "起点行在2~5: %d" % fog_map.start_pos.x)
	_assert(fog_map.start_pos.y >= 2 and fog_map.start_pos.y <= 5, "起点列在2~5: %d" % fog_map.start_pos.y)

	# 起点已揭开
	var start_state: FogMap.CellState = fog_map.get_cell_state(fog_map.start_pos.x, fog_map.start_pos.y)
	_assert(start_state == FogMap.CellState.REVEALED, "起点已揭开")
	_assert(fog_map.revealed_count >= 1, "至少揭开1格: %d" % fog_map.revealed_count)

	# 邻居有 FOGGY 状态
	var clickable: Array[Vector2i] = fog_map.get_clickable_cells()
	_assert(clickable.size() > 0, "有可点击格子: %d" % clickable.size())

	# 格子类型统计（预放置格子）
	var wall_count: int = 0
	var playtest_count: int = 0
	var polish_count: int = 0
	var exit_count: int = 0
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var ct: FogMap.CellType = fog_map.get_cell_type(row, col)
			if ct == FogMap.CellType.WALL:
				wall_count += 1
			elif ct == FogMap.CellType.PLAYTEST:
				playtest_count += 1
			elif ct == FogMap.CellType.POLISH:
				polish_count += 1
			elif ct == FogMap.CellType.EXIT:
				exit_count += 1

	_assert(wall_count <= Config.MAP_WALL_MAX, "路障数≤%d: %d" % [Config.MAP_WALL_MAX, wall_count])
	_assert(playtest_count == 1, "内测节点=1: %d" % playtest_count)
	_assert(polish_count == 1, "打磨节点=1: %d" % polish_count)
	_assert(exit_count == 1, "撤离点=1: %d" % exit_count)

	# 撤离点开局可见：状态应为 FOGGY（不是 HIDDEN）
	var exit_state: FogMap.CellState = fog_map.get_cell_state(fog_map.exit_pos.x, fog_map.exit_pos.y)
	_assert(exit_state != FogMap.CellState.HIDDEN, "撤离点非HIDDEN（开局可见）: state=%d" % exit_state)

	# 稀有度分配验证：非预放置的EMPTY格子应有稀有度分布
	var rarity_counts: Dictionary = {}
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			if not fog_map.is_preplaced(row, col):
				var r: FogMap.Rarity = fog_map.get_cell_rarity(row, col)
				var key: int = r as int
				var cur: int = rarity_counts.get(key, 0) as int
				rarity_counts[key] = cur + 1

	var total_rarity_cells: int = 0
	for key: int in rarity_counts.keys():
		total_rarity_cells += rarity_counts[key] as int
	_assert(total_rarity_cells > 0, "有格子被分配了稀有度: %d" % total_rarity_cells)
	_log_info("稀有度分布: %s" % str(rarity_counts))

	# 验证至少有2种不同稀有度（固定种子42应该有多种）
	_assert(rarity_counts.size() >= 2, "至少有2种不同稀有度: %d种" % rarity_counts.size())

	# 连通性验证：从起点 flood fill，非路障格都应可达
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [fog_map.start_pos]
	visited[fog_map.start_pos] = true
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for n: Vector2i in fog_map.get_neighbors(current.x, current.y):
			if n not in visited and fog_map.get_cell_type(n.x, n.y) != FogMap.CellType.WALL:
				visited[n] = true
				queue.append(n)

	var expected_reachable: int = FogMap.MAP_SIZE * FogMap.MAP_SIZE - wall_count
	_assert(visited.size() == expected_reachable, "连通性: 可达%d = 期望%d" % [visited.size(), expected_reachable])

	# 揭开测试：reveal_cell 应返回延迟随机后的类型
	if clickable.size() > 0:
		var first: Vector2i = clickable[0]
		var result: Variant = fog_map.reveal_cell(first.x, first.y)
		_assert(result != null, "揭开格子返回非null")
		_assert(fog_map.get_cell_state(first.x, first.y) == FogMap.CellState.REVEALED, "揭开后状态=REVEALED")

		# 揭开后的类型应该是有效类型（延迟随机结果）
		var revealed_type: FogMap.CellType = result as FogMap.CellType
		_assert(
			revealed_type == FogMap.CellType.EMPTY or
			revealed_type == FogMap.CellType.SEARCH_EVENT or
			revealed_type == FogMap.CellType.FIGHT_EVENT or
			revealed_type == FogMap.CellType.TREASURE,
			"揭开的非预放置格子类型合法: %d" % revealed_type
		)

		# 不能重复揭开
		var result2: Variant = fog_map.reveal_cell(first.x, first.y)
		_assert(result2 == null, "不能重复揭开已揭开格子")

	# HIDDEN 格子不能揭开
	var hidden_found: bool = false
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			if fog_map.get_cell_state(row, col) == FogMap.CellState.HIDDEN:
				var r: Variant = fog_map.reveal_cell(row, col)
				_assert(r == null, "HIDDEN格子不能直接揭开")
				hidden_found = true
				break
		if hidden_found:
			break

	# 延迟随机验证：多次生成，检查LEGENDARY稀有度出宝箱概率明显高于COMMON
	_log_section("迷雾地图 — 延迟随机验证")
	var common_treasure: int = 0
	var legendary_treasure: int = 0
	var roll_count: int = 200
	for _i: int in range(roll_count):
		var ct_common: FogMap.CellType = FogMap._roll_cell_type(FogMap.Rarity.COMMON)
		if ct_common == FogMap.CellType.TREASURE:
			common_treasure += 1
		var ct_legendary: FogMap.CellType = FogMap._roll_cell_type(FogMap.Rarity.LEGENDARY)
		if ct_legendary == FogMap.CellType.TREASURE:
			legendary_treasure += 1

	_log_info("200次roll: COMMON宝箱=%d, LEGENDARY宝箱=%d" % [common_treasure, legendary_treasure])
	_assert(common_treasure <= legendary_treasure, "LEGENDARY出宝箱概率≥COMMON: %d vs %d" % [legendary_treasure, common_treasure])
	# COMMON的宝箱权重=0，理论上不应有宝箱
	_assert(common_treasure == 0, "COMMON稀有度不出宝箱: %d" % common_treasure)

	# 数值模拟：36月预算能走多少格
	_log_section("迷雾地图 — 数值模拟（36月预算，稀有度消耗）")
	var sim_map: FogMap = FogMapGenerator.generate(123)
	var months_left: int = 36
	var cells_explored: int = 1  # 起点
	var found_exit: bool = false

	while months_left > 0:
		var sim_clickable: Array[Vector2i] = sim_map.get_clickable_cells()
		if sim_clickable.size() == 0:
			break
		# 过滤掉EXIT类型（不可直接点击）
		var valid_sim: Array[Vector2i] = []
		for c: Vector2i in sim_clickable:
			if sim_map.get_cell_type(c.x, c.y) != FogMap.CellType.EXIT:
				valid_sim.append(c)
		if valid_sim.size() == 0:
			break
		# 随机选一个格子
		var pick: Vector2i = valid_sim[randi_range(0, valid_sim.size() - 1)]
		# 按稀有度计算月数消耗
		var pick_rarity: FogMap.Rarity = sim_map.get_cell_rarity(pick.x, pick.y)
		var rarity_name: String = FogMap.RARITY_NAMES[pick_rarity]
		var cost: int = Config.RARITY_MONTH_COST.get(rarity_name, 1) as int
		if months_left < cost:
			break
		var cell_result: Variant = sim_map.reveal_cell(pick.x, pick.y)
		if cell_result != null:
			months_left -= cost
			cells_explored += 1
			if sim_map.check_path_connected():
				found_exit = true

	var coverage: float = float(cells_explored) / float(FogMap.MAP_SIZE * FogMap.MAP_SIZE)
	_log_info("随机探索: %d格, 覆盖率%.0f%%, 找到出口: %s" % [cells_explored, coverage * 100, "是" if found_exit else "否"])
	_assert(cells_explored >= 2, "至少探索2格: %d" % cells_explored)
	_assert(coverage < 0.8, "覆盖率<80%%（有策略取舍空间）: %.0f%%" % (coverage * 100))

	# 多次模拟检查撤离点连通性（定向寻路 vs 随机探索）
	var exit_connected_count: int = 0
	for sim_i: int in range(10):
		var test_map: FogMap = FogMapGenerator.generate(sim_i * 7 + 1)
		var m_left: int = 36
		while m_left > 0:
			var sc: Array[Vector2i] = test_map.get_clickable_cells()
			if sc.size() == 0:
				break
			# 过滤掉EXIT类型的格子（不可直接点击）
			var valid_cells: Array[Vector2i] = []
			for c: Vector2i in sc:
				if test_map.get_cell_type(c.x, c.y) != FogMap.CellType.EXIT:
					valid_cells.append(c)
			if valid_cells.size() == 0:
				break
			var p: Vector2i = valid_cells[randi_range(0, valid_cells.size() - 1)]
			var p_rarity: FogMap.Rarity = test_map.get_cell_rarity(p.x, p.y)
			var p_rarity_name: String = FogMap.RARITY_NAMES[p_rarity]
			var p_cost: int = Config.RARITY_MONTH_COST.get(p_rarity_name, 1) as int
			if m_left < p_cost:
				break
			test_map.reveal_cell(p.x, p.y)
			m_left -= p_cost
			if test_map.check_path_connected():
				exit_connected_count += 1
				break

	_log_info("10次随机模拟中连通撤离点: %d/10" % exit_connected_count)
	_assert(exit_connected_count >= 1, "至少10%%的随机模拟能连通撤离点: %d/10" % exit_connected_count)

	# 撤离点位置记录
	_log_section("迷雾地图 — 撤离点连通判定")
	var path_map: FogMap = FogMapGenerator.generate(42)
	_assert(path_map.exit_pos != Vector2i(-1, -1), "撤离点位置已记录: %s" % str(path_map.exit_pos))
	_assert(FogMap.manhattan_distance(path_map.start_pos, path_map.exit_pos) >= Config.MAP_EXIT_MIN_DISTANCE,
		"撤离点距起点≥%d" % Config.MAP_EXIT_MIN_DISTANCE)

	# 初始状态：未连通
	_assert(not path_map.check_path_connected(), "初始状态未连通")

	# 模拟从起点到撤离点的路径揭开
	var path_to_exit: Array[Vector2i] = path_map.find_shortest_path(path_map.start_pos, path_map.exit_pos)
	_assert(path_to_exit.size() > 0, "存在从起点到撤离点的路径: %d步" % path_to_exit.size())

	# 逐格揭开路径
	for pos: Vector2i in path_to_exit:
		if path_map.get_cell_state(pos.x, pos.y) == FogMap.CellState.FOGGY:
			path_map.reveal_cell(pos.x, pos.y)
		elif path_map.get_cell_state(pos.x, pos.y) == FogMap.CellState.HIDDEN:
			# 先让它变成FOGGY再揭开（模拟正常游玩）
			path_map.states[pos.x][pos.y] = FogMap.CellState.FOGGY
			path_map.reveal_cell(pos.x, pos.y)

	# 揭开路径后应连通
	_assert(path_map.check_path_connected(), "揭开路径后已连通")


## ===== Bug Survivor 数据层测试 =====
func _run_bug_survivor_data_test() -> void:
	_log_section("Bug Survivor 数据层测试")

	# 创建预设
	var preset := BugSurvivorPreset.new()
	preset.preset_id = "test"
	preset.preset_name = "测试预设"
	preset.bug_base_speed = 80.0
	preset.spawn_interval_scale = 1.0
	preset.speed_scale = 1.0

	# 初始化数据层
	var data := BugSurvivorData.new()
	data.setup(preset)

	_assert(data.is_alive, "初始存活")
	_assert(data.elapsed == 0.0, "初始时间 = 0")
	_assert(data.kill_count == 0, "初始击杀 = 0")
	_assert(data.get_survival_rate() == 0.0, "初始存活率 = 0")

	# 推进时间
	var alive: bool = data.advance(10.0)
	_assert(alive, "10秒后仍在进行")
	_assert(is_equal_approx(data.elapsed, 10.0), "elapsed = 10")

	# 记录击杀
	data.record_kill()
	data.record_kill()
	_assert(data.kill_count == 2, "击杀数 = 2")

	# 存活率
	var rate: float = data.get_survival_rate()
	_assert(is_equal_approx(rate, 10.0 / 30.0), "存活率 = 10/30: %.3f" % rate)

	# 推进到18秒 → steady (18/30=0.6)
	data.advance(8.0)
	_assert(data.get_result() == "steady", "18秒 → steady: %s" % data.get_result())

	# 推进到27秒 → risky (27/30=0.9)
	data.advance(9.0)
	_assert(data.get_result() == "risky", "27秒 → risky: %s" % data.get_result())

	# 推进超时 → 游戏结束
	var still_going: bool = data.advance(10.0)
	_assert(not still_going, "超时后游戏结束")
	_assert(is_equal_approx(data.get_survival_rate(), 1.0), "满时间存活率 = 1.0")

	# 玩家死亡测试
	var data2 := BugSurvivorData.new()
	data2.setup(preset)
	data2.advance(15.0)
	data2.player_died()
	_assert(not data2.is_alive, "死亡后 is_alive = false")
	_assert(not data2.advance(1.0), "死亡后不能继续推进")
	_assert(data2.get_result() == "conservative", "15秒死亡 → conservative")

	# 难度曲线测试
	_log_section("Bug Survivor — 难度曲线验证")
	var data3 := BugSurvivorData.new()
	data3.setup(preset)

	var si_0: float = data3.get_current_spawn_interval()
	var sp_0: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_0, 0.9), "0秒生成间隔 = 0.9: %.2f" % si_0)
	_assert(is_equal_approx(sp_0, 80.0 * 1.2), "0秒速度 = 96: %.1f" % sp_0)

	data3.advance(9.0)
	var si_9: float = data3.get_current_spawn_interval()
	var sp_9: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_9, 0.55), "9秒生成间隔 = 0.55: %.2f" % si_9)
	_assert(is_equal_approx(sp_9, 80.0 * 1.6), "9秒速度 = 128: %.1f" % sp_9)

	data3.advance(8.0)
	var si_17: float = data3.get_current_spawn_interval()
	var sp_17: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_17, 0.35), "17秒生成间隔 = 0.35: %.2f" % si_17)
	_assert(is_equal_approx(sp_17, 80.0 * 2.0), "17秒速度 = 160: %.1f" % sp_17)

	data3.advance(7.0)
	var si_24: float = data3.get_current_spawn_interval()
	var sp_24: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_24, 0.25), "24秒生成间隔 = 0.25: %.2f" % si_24)
	_assert(is_equal_approx(sp_24, 80.0 * 2.4), "24秒速度 = 192: %.1f" % sp_24)

	# 站着不动模拟：验证25秒内必死
	_log_section("Bug Survivor — 站桩死亡模拟")
	var sim_death_times: Array[float] = []
	for trial: int in range(20):
		var death_t: float = _simulate_standing_still(preset)
		sim_death_times.append(death_t)

	var max_survive: float = 0.0
	var min_survive: float = 999.0
	var avg_survive: float = 0.0
	for t: float in sim_death_times:
		if t > max_survive:
			max_survive = t
		if t < min_survive:
			min_survive = t
		avg_survive += t
	avg_survive /= float(sim_death_times.size())

	_log_info("20次站桩模拟: 最短%.1fs, 最长%.1fs, 平均%.1fs" % [min_survive, max_survive, avg_survive])
	_assert(max_survive < 50.0, "站着不动最长存活 < 50秒: %.1f" % max_survive)
	_assert(avg_survive < 40.0, "站着不动平均存活 < 40秒: %.1f" % avg_survive)

	# 边缘位置生成测试
	_log_section("Bug Survivor — 边缘位置生成")
	var arena: Vector2 = Config.BUG_SURVIVOR_ARENA_SIZE
	for _i: int in range(20):
		var pos: Vector2 = BugSurvivorData.random_edge_position(arena)
		var on_edge: bool = pos.x < 0 or pos.x > arena.x or pos.y < 0 or pos.y > arena.y
		_assert(on_edge, "生成位置在边缘外: (%.0f, %.0f)" % [pos.x, pos.y])

	# 难度缩放测试
	_log_section("Bug Survivor — 难度缩放预设")
	var hard_preset := BugSurvivorPreset.new()
	hard_preset.preset_id = "hard_test"
	hard_preset.bug_base_speed = 100.0
	hard_preset.spawn_interval_scale = 0.7
	hard_preset.speed_scale = 1.3

	var data4 := BugSurvivorData.new()
	data4.setup(hard_preset)
	var hard_si: float = data4.get_current_spawn_interval()
	var hard_sp: float = data4.get_current_bug_speed()
	_assert(is_equal_approx(hard_si, 0.9 * 0.7), "困难预设生成间隔 = 0.63: %.3f" % hard_si)
	_assert(is_equal_approx(hard_sp, 100.0 * 1.2 * 1.3), "困难预设速度 = 156: %.1f" % hard_sp)
	_log_info("困难预设验证通过: 间隔%.2f, 速度%.1f" % [hard_si, hard_sp])


## ===== 小游戏类型不重复测试 =====

func _run_minigame_no_repeat_test() -> void:
	_log_section("小游戏类型不连续重复测试")

	# 模拟 _pick_fight_event 的核心逻辑：
	# 加载所有打类事件，按 minigame_type 分两组
	var all_fight_paths: Array[String] = [
		"res://resources/events/fight_tech_01.tres",
		"res://resources/events/fight_tech_02.tres",
		"res://resources/events/fight_team_01.tres",
		"res://resources/events/fight_team_02.tres",
		"res://resources/events/fight_external_01.tres",
		"res://resources/events/fight_external_02.tres",
		"res://resources/events/fight_survivor_01.tres",
		"res://resources/events/fight_survivor_02.tres",
	]
	var code_rescue_events: Array[EventData] = []
	var bug_survivor_events: Array[EventData] = []
	for path: String in all_fight_paths:
		var res: Resource = load(path)
		if res is EventData:
			var ev: EventData = res as EventData
			if ev.minigame_type == "bug_survivor":
				bug_survivor_events.append(ev)
			else:
				code_rescue_events.append(ev)

	_assert(code_rescue_events.size() >= 2, "code_rescue 事件 >= 2: %d" % code_rescue_events.size())
	_assert(bug_survivor_events.size() >= 2, "bug_survivor 事件 >= 2: %d" % bug_survivor_events.size())

	# 模拟连续10次选择，验证不会连续同类型
	var last_type: String = ""
	var repeat_found: bool = false
	var sequence: String = ""
	for i: int in range(10):
		# 模拟 _pick_fight_event 的核心逻辑
		var candidates: Array[EventData] = []
		candidates.append_array(code_rescue_events)
		candidates.append_array(bug_survivor_events)
		candidates.shuffle()

		var picked: EventData = null
		# 优先选不同类型
		for ev: EventData in candidates:
			var ev_type: String = ev.minigame_type if ev.minigame_type != "" else "code_rescue"
			if ev_type != last_type:
				picked = ev
				break
		if picked == null:
			picked = candidates[0]

		var picked_type: String = picked.minigame_type if picked.minigame_type != "" else "code_rescue"
		sequence += picked_type.substr(0, 1)  # b 或 c
		if picked_type == last_type:
			repeat_found = true
		last_type = picked_type

	_assert(not repeat_found, "10次选择无连续重复类型: %s" % sequence)
	_log_info("选择序列: %s" % sequence)


## ===== 站桩死亡模拟 =====
## 模拟玩家站在竞技场中心不动，只靠自动射击，计算何时被虫子碰到
func _simulate_standing_still(p_preset: BugSurvivorPreset) -> float:
	var arena: Vector2 = Config.BUG_SURVIVOR_ARENA_SIZE
	var player_pos: Vector2 = arena / 2.0
	var player_r: float = Config.BUG_SURVIVOR_PLAYER_RADIUS
	var bug_r: float = Config.BUG_SURVIVOR_BUG_RADIUS
	var bullet_speed: float = Config.BUG_SURVIVOR_BULLET_SPEED
	var bullet_r: float = Config.BUG_SURVIVOR_BULLET_RADIUS
	var shoot_interval: float = p_preset.get_bullet_interval()

	var dt: float = 0.05  # 模拟步长
	var elapsed: float = 0.0
	var spawn_timer: float = 0.0
	var shoot_timer: float = 0.0

	# 虫子列表: [{pos: Vector2}]
	var bugs: Array[Dictionary] = []
	# 子弹列表: [{pos: Vector2, dir: Vector2}]
	var bullets: Array[Dictionary] = []

	while elapsed < 60.0:
		elapsed += dt

		# 生成虫子
		var si: float = p_preset.get_spawn_interval(elapsed)
		spawn_timer += dt
		while spawn_timer >= si:
			spawn_timer -= si
			bugs.append({"pos": BugSurvivorData.random_edge_position(arena)})

		# 射击最近虫子
		shoot_timer += dt
		if shoot_timer >= shoot_interval and bugs.size() > 0:
			shoot_timer -= shoot_interval
			var nearest_idx: int = 0
			var nearest_dist: float = INF
			for i: int in range(bugs.size()):
				var d: float = player_pos.distance_to(bugs[i]["pos"] as Vector2)
				if d < nearest_dist:
					nearest_dist = d
					nearest_idx = i
			var dir: Vector2 = player_pos.direction_to(bugs[nearest_idx]["pos"] as Vector2)
			bullets.append({"pos": player_pos, "dir": dir})

		# 移动虫子
		var bug_speed: float = p_preset.get_bug_speed(elapsed)
		var i: int = bugs.size() - 1
		while i >= 0:
			var bpos: Vector2 = bugs[i]["pos"] as Vector2
			var dir: Vector2 = (player_pos - bpos).normalized()
			bpos += dir * bug_speed * dt
			bugs[i]["pos"] = bpos
			# 碰撞检测
			if bpos.distance_to(player_pos) < player_r + bug_r:
				return elapsed
			i -= 1

		# 移动子弹 & 碰撞
		var bi: int = bullets.size() - 1
		while bi >= 0:
			var bpos: Vector2 = bullets[bi]["pos"] as Vector2
			var bdir: Vector2 = bullets[bi]["dir"] as Vector2
			bpos += bdir * bullet_speed * dt
			bullets[bi]["pos"] = bpos
			# 出界
			if bpos.x < -50 or bpos.x > arena.x + 50 or bpos.y < -50 or bpos.y > arena.y + 50:
				bullets.remove_at(bi)
				bi -= 1
				continue
			# 命中虫子
			var hit: bool = false
			var gi: int = bugs.size() - 1
			while gi >= 0:
				var gpos: Vector2 = bugs[gi]["pos"] as Vector2
				if bpos.distance_to(gpos) < bullet_r + bug_r:
					bugs.remove_at(gi)
					hit = true
					break
				gi -= 1
			if hit:
				bullets.remove_at(bi)
			bi -= 1

	return 60.0  # 存活到结束


## ===== 素材归档数据层测试 =====
func _run_memory_match_data_test() -> void:
	_log_section("素材归档（记忆翻牌）数据层测试")

	# 创建预设
	var preset := MemoryMatchPreset.new()
	preset.preset_id = "test"
	preset.preset_name = "测试预设"
	preset.grid_rows = 3
	preset.grid_cols = 4
	preset.time_limit = 15.0
	preset.flip_duration = 0.3
	preset.peek_duration = 0.5

	# 初始化
	var data := MemoryMatchData.new()
	data.setup(preset)
	_assert(data.total_pairs == 6, "总对数=6: %d" % data.total_pairs)
	_assert(data.matched_pairs == 0, "初始配对=0")
	_assert(not data.is_finished, "初始未结束")
	_assert(data.get_completion_rate() == 0.0, "初始完成率=0")

	# 网格验证：12格，6种ID各出现2次
	var id_counts: Dictionary = {}
	for row: int in range(3):
		for col: int in range(4):
			var card_id: int = data.grid[row][col]
			_assert(card_id >= 0 and card_id < 6, "卡牌ID合法: %d" % card_id)
			var cur: int = id_counts.get(card_id, 0) as int
			id_counts[card_id] = cur + 1
	for id: int in range(6):
		_assert(id_counts.get(id, 0) as int == 2, "ID %d 出现2次: %d" % [id, id_counts.get(id, 0) as int])

	# 翻牌测试：翻第一张
	var r1: MemoryMatchData.PickResult = data.pick_card(0, 0)
	_assert(r1 == MemoryMatchData.PickResult.FIRST_REVEALED, "第一张翻开: %d" % r1)
	_assert(data.revealed[0][0] == true, "第一张已翻开")

	# 找一个配对的位置
	var first_id: int = data.grid[0][0]
	var match_pos: Vector2i = Vector2i(-1, -1)
	for row: int in range(3):
		for col: int in range(4):
			if Vector2i(row, col) != Vector2i(0, 0) and data.grid[row][col] == first_id:
				match_pos = Vector2i(row, col)
				break
		if match_pos != Vector2i(-1, -1):
			break

	# 翻第二张（配对成功）
	var r2: MemoryMatchData.PickResult = data.pick_card(match_pos.x, match_pos.y)
	_assert(r2 == MemoryMatchData.PickResult.MATCH_SUCCESS, "配对成功: %d" % r2)
	_assert(data.matched[0][0] == true, "第一张已消除")
	_assert(data.matched[match_pos.x][match_pos.y] == true, "第二张已消除")
	_assert(data.matched_pairs == 1, "配对数=1")

	# 无效操作：点击已消除的牌
	var r3: MemoryMatchData.PickResult = data.pick_card(0, 0)
	_assert(r3 == MemoryMatchData.PickResult.INVALID, "已消除牌不可点击")

	# 配对失败测试：找两张不同的未消除牌
	var pos_a: Vector2i = Vector2i(-1, -1)
	var pos_b: Vector2i = Vector2i(-1, -1)
	for row: int in range(3):
		for col: int in range(4):
			if not data.matched[row][col]:
				if pos_a == Vector2i(-1, -1):
					pos_a = Vector2i(row, col)
				elif data.grid[row][col] != data.grid[pos_a.x][pos_a.y] and pos_b == Vector2i(-1, -1):
					pos_b = Vector2i(row, col)
		if pos_b != Vector2i(-1, -1):
			break

	if pos_a != Vector2i(-1, -1) and pos_b != Vector2i(-1, -1):
		var r4: MemoryMatchData.PickResult = data.pick_card(pos_a.x, pos_a.y)
		_assert(r4 == MemoryMatchData.PickResult.FIRST_REVEALED, "翻开A")
		var r5: MemoryMatchData.PickResult = data.pick_card(pos_b.x, pos_b.y)
		_assert(r5 == MemoryMatchData.PickResult.MATCH_FAIL, "配对失败: %d" % r5)
		# 失败后两张牌翻回
		_assert(data.revealed[pos_a.x][pos_a.y] == false, "失败后A翻回")
		_assert(data.revealed[pos_b.x][pos_b.y] == false, "失败后B翻回")

	# 时间耗尽测试
	var data2 := MemoryMatchData.new()
	data2.setup(preset)
	data2.advance_time(16.0)
	_assert(data2.is_finished, "时间耗尽后结束")
	_assert(data2.get_result_tier() == "conservative", "0配对=conservative: %s" % data2.get_result_tier())

	# 结果等级验证
	var data3 := MemoryMatchData.new()
	data3.setup(preset)
	# 手动设置配对数来验证等级
	data3.matched_pairs = 6
	_assert(data3.get_completion_rate() == 1.0, "6/6=1.0")
	_assert(data3.get_result_tier() == "risky", "6/6=risky")
	data3.matched_pairs = 4
	_assert(data3.get_result_tier() == "steady", "4/6=steady: %s" % data3.get_result_tier())
	data3.matched_pairs = 2
	_assert(data3.get_result_tier() == "conservative", "2/6=conservative: %s" % data3.get_result_tier())


## ===== 汇总 =====

func _print_summary() -> void:
	print("")
	print("=".repeat(50))
	print("  《开发商》自动化测试报告")
	print("=".repeat(50))

	for line in _test_log:
		print(line)

	print("")
	print("-".repeat(50))
	var total: int = _tests_passed + _tests_failed
	print("  总计: %d | ✅ %d 通过 | ❌ %d 失败" % [total, _tests_passed, _tests_failed])

	if _tests_failed == 0:
		print("  🎉 全部通过！")
	else:
		print("  ⚠️ 有 %d 个测试失败" % _tests_failed)

	print("=".repeat(50))
