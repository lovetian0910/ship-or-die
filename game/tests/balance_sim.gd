# balance_sim.gd — Monte Carlo 数值平衡模拟器（走真实游戏代码路径）
# 直接调用 GameManager / TimeManager / EconomyManager / MarketHeat /
# AICompetitors / QualitySystem / SettlementCalculator
# 不重复实现任何游戏逻辑
extends Node

const SIM_COUNT: int = 2000  ## 每种策略模拟次数

## ===== 玩家策略枚举 =====
enum Strategy { RUSH, BALANCED, PATIENT, POLISH_MAX, SMART, RANDOM }

const STRATEGY_NAMES: Dictionary = {
	Strategy.RUSH: "速攻型",
	Strategy.BALANCED: "均衡型",
	Strategy.PATIENT: "耐心型",
	Strategy.POLISH_MAX: "极致打磨",
	Strategy.SMART: "聪明型",
	Strategy.RANDOM: "随机型",
}

## ===== 资源文件路径 =====
const CREATOR_PATHS: Array[String] = [
	"res://resources/entry_resources/creator_low.tres",
	"res://resources/entry_resources/creator_mid.tres",
	"res://resources/entry_resources/creator_high.tres",
]
const OUTSOURCE_PATHS: Array[String] = [
	"res://resources/entry_resources/outsource_low.tres",
	"res://resources/entry_resources/outsource_mid.tres",
	"res://resources/entry_resources/outsource_high.tres",
]
const BUSINESS_PATHS: Array[String] = [
	"res://resources/entry_resources/business_low.tres",
	"res://resources/entry_resources/business_mid.tres",
	"res://resources/entry_resources/business_high.tres",
]
const TOPIC_PATHS: Array[String] = [
	"res://resources/topics/topic_phantom_realm.tres",
	"res://resources/topics/topic_mecha_royale.tres",
	"res://resources/topics/topic_waifu_collection.tres",
	"res://resources/topics/topic_star_ranch.tres",
]

## ===== 预加载资源 =====
var _creators: Array[EntryResourceData] = []
var _outsources: Array[EntryResourceData] = []
var _businesses: Array[EntryResourceData] = []
var _topics: Array[TopicData] = []

## ===== 常用配置组合 [creator_idx, outsource_idx, business_idx] =====
const LOADOUTS: Array = [
	[0, 0, 0],  # 全低 300
	[1, 0, 0],  # 中低低 500
	[0, 1, 0],  # 低中低 500
	[1, 1, 0],  # 中中低 700
	[1, 0, 1],  # 中低中 700
	[1, 1, 1],  # 全中 900
	[2, 0, 0],  # 高低低 800
	[2, 1, 0],  # 高中低 1000
	[2, 1, 1],  # 高中中 1200
	[2, 2, 1],  # 高高中 1500
]


func _ready() -> void:
	# 预加载所有资源
	for path in CREATOR_PATHS:
		var res: EntryResourceData = load(path) as EntryResourceData
		if res:
			_creators.append(res)
	for path in OUTSOURCE_PATHS:
		var res: EntryResourceData = load(path) as EntryResourceData
		if res:
			_outsources.append(res)
	for path in BUSINESS_PATHS:
		var res: EntryResourceData = load(path) as EntryResourceData
		if res:
			_businesses.append(res)
	for path in TOPIC_PATHS:
		var res: TopicData = load(path) as TopicData
		if res:
			_topics.append(res)

	print("  加载资源: %d 主创, %d 外包, %d 商务, %d 题材" % [
		_creators.size(), _outsources.size(), _businesses.size(), _topics.size()])

	if _topics.is_empty() or _creators.is_empty():
		print("  ❌ 资源加载失败！")
		get_tree().quit(1)
		return

	_run_full_simulation()
	get_tree().quit(0)


func _run_full_simulation() -> void:
	print("\n" + "=".repeat(70))
	print("  《开发商》数值平衡 Monte Carlo 模拟器 (真实代码路径)")
	print("  模拟次数: %d / 策略" % SIM_COUNT)
	print("=".repeat(70))

	var all_results: Dictionary = {}
	for strategy_val: int in Strategy.values():
		var strategy: Strategy = strategy_val as Strategy
		var results: Array[Dictionary] = []
		for i: int in range(SIM_COUNT):
			var result: Dictionary = _simulate_one_run(strategy, i)
			results.append(result)
		all_results[strategy] = results
		_print_strategy_report(strategy, results)

	# 汇总全局分布（加权混合）
	print("\n" + "=".repeat(70))
	print("  全策略混合分布（模拟真实玩家群体）")
	print("=".repeat(70))
	var mixed: Array[Dictionary] = []
	var weights: Dictionary = {
		Strategy.RANDOM: 0.40,
		Strategy.BALANCED: 0.25,
		Strategy.SMART: 0.15,
		Strategy.RUSH: 0.10,
		Strategy.PATIENT: 0.07,
		Strategy.POLISH_MAX: 0.03,
	}
	for strategy_val: int in weights:
		var strategy: Strategy = strategy_val as Strategy
		var w: float = weights[strategy_val]
		var count: int = int(SIM_COUNT * w)
		var pool: Array = all_results[strategy]
		for i: int in range(mini(count, pool.size())):
			mixed.append(pool[i])
	_print_strategy_report(-1, mixed)

	# 调优建议
	print("\n" + "=".repeat(70))
	print("  调优建议")
	print("=".repeat(70))
	_print_tuning_advice(all_results)


## ===== 模拟单局：走真实游戏代码 =====
func _simulate_one_run(strategy: Strategy, seed_val: int) -> Dictionary:
	seed(seed_val * 7919 + int(strategy) * 1013)

	# --- 1. 选购阶段：复用真实流程 ---
	var loadout_indices: Array = _pick_loadout(strategy)
	var creator: EntryResourceData = _creators[loadout_indices[0]]
	var outsource: EntryResourceData = _outsources[loadout_indices[1]]
	var business: EntryResourceData = _businesses[loadout_indices[2]]
	var investment: int = creator.price + outsource.price + business.price

	# 真实流程：GameManager.start_new_run() → EconomyManager 扣款 → set_loadout
	GameManager.start_new_run()
	GameManager.persistent_data["money"] = Config.INITIAL_MONEY  # 重置到初始金钱
	EconomyManager.purchase_loadout(investment)
	EconomyManager.set_loadout(creator, outsource, business)
	GameManager.run_data["money_spent"] = investment

	# --- 2. 选题阶段：复用真实初始化 ---
	var topic_idx: int = randi() % _topics.size()
	var topic: TopicData = _topics[topic_idx]
	GameManager.run_data["topic"] = String(topic.id)
	GameManager.run_data["game_name"] = "模拟测试游戏"

	# 真实流程：MarketHeat.init_market → AICompetitors.init_competitors
	# 注意：init_market 内部持有数组引用，reset 时会 clear，所以传副本
	var topics_copy: Array[TopicData] = _topics.duplicate()
	MarketHeat.init_market(topics_copy)
	AICompetitors.init_competitors(topic.id)

	# --- 3. 研发阶段：使用真实 TimeManager + QualitySystem ---
	# 直接启动时间系统（不经过 transition_to 避免加载UI场景）
	GameManager.current_state = GameManager.GameState.DEV_RUNNING
	TimeManager.start_new_round()

	# 创建真实品质系统（与 dev_running.gd 一致）
	var resources: Dictionary = GameManager.run_data.get("resources", {})
	var creator_level: int = resources.get("creator", 1)
	var outsource_level: int = resources.get("outsource", 1)
	var qs := QualitySystem.new(creator_level, outsource_level)

	# 决定上线月份
	var target_launch_month: int = _decide_launch_month(strategy, topic)
	target_launch_month = clampi(target_launch_month, 3, Config.TIME_TOTAL_MONTHS - 1)

	# 模拟每月研发推进（与 dev_running._on_cell_month_tick 逻辑一致）
	var did_playtest: bool = false
	var did_polish: bool = false
	var actual_launch_month: int = -1

	for month: int in range(1, Config.TIME_TOTAL_MONTHS + 1):
		if not TimeManager.is_active:
			break

		# 消耗1月（真实 TimeManager）
		var alive: bool = TimeManager.consume_months(1)
		# 品质积累（真实 QualitySystem）
		qs.accumulate(1)

		if not alive:
			break

		# 可选节点：内测（50%进度时）
		if not did_playtest and strategy != Strategy.RUSH and randf() > 0.3:
			if TimeManager.get_progress() >= Config.PLAYTEST_TRIGGER_PROGRESS:
				did_playtest = true
				qs.reveal()
				if TimeManager.is_active:
					TimeManager.consume_months(Config.PLAYTEST_MONTH_COST)
					qs.accumulate(Config.PLAYTEST_MONTH_COST)

		# 可选节点：打磨（85%进度时）
		if not did_polish:
			if strategy == Strategy.POLISH_MAX or strategy == Strategy.PATIENT or (strategy == Strategy.SMART and randf() > 0.4):
				if TimeManager.get_progress() >= Config.POLISH_TRIGGER_PROGRESS:
					did_polish = true
					if TimeManager.is_active:
						TimeManager.consume_months(Config.POLISH_MONTH_COST)
						qs.accumulate(Config.POLISH_MONTH_COST)
						if randf() <= Config.POLISH_SUCCESS_CHANCE:
							qs.apply_boost(Config.POLISH_QUALITY_BOOST)
						else:
							if randf() < 0.5:
								TimeManager.consume_months(Config.POLISH_BUG_FIX_MONTHS)
								qs.accumulate(Config.POLISH_BUG_FIX_MONTHS)
							else:
								qs.apply_penalty(Config.POLISH_FAIL_PENALTY)

		# 到达目标上线月 → 上线（在时间耗尽前主动停止）
		if TimeManager.elapsed_months >= target_launch_month and TimeManager.is_active:
			actual_launch_month = TimeManager.elapsed_months
			break

	# 同步品质到 run_data
	GameManager.run_data["quality"] = qs.raw_score
	GameManager.run_data["quality_cap"] = qs.cap
	GameManager.run_data["did_playtest"] = did_playtest
	GameManager.run_data["quality_revealed"] = qs.revealed
	GameManager.run_data["did_polish"] = did_polish

	# --- 4. 判断是否超时 ---
	if actual_launch_month < 0 or not TimeManager.is_active:
		# 撤离失败
		GameManager.end_run_fail()
		_cleanup_round()
		return {
			"investment": investment, "revenue": 0, "roi": 0.0,
			"failed": true, "launch_month": -1, "quality": qs.raw_score,
			"heat": 0.0, "comp_count": 0,
		}

	# --- 5. 结算阶段：复用 launch_confirm._on_confirm 的完整逻辑 ---
	var topic_id: StringName = StringName(str(GameManager.run_data.get("topic", "")))
	var player_quality: float = qs.raw_score
	var heat: float = MarketHeat.get_heat(topic_id)

	var elapsed: int = TimeManager.elapsed_months
	var total: int = TimeManager.total_months

	# 收集所有竞品（含未来会上线的 → 时间线分段结算需要）
	var competitors: Array[Dictionary] = []
	var launched_count: int = 0
	for comp: AICompetitorData in AICompetitors.get_competitors():
		competitors.append({
			"quality": comp.quality,
			"launch_month": comp.planned_launch_month,
		})
		if comp.launched:
			launched_count += 1

	# 随机市场参数（与 launch_confirm.gd 完全一致）
	var total_users: int = randi_range(Config.SETTLEMENT_USERS_MIN, Config.SETTLEMENT_USERS_MAX)
	var pay_ability: float = randf_range(Config.SETTLEMENT_PAY_MIN, Config.SETTLEMENT_PAY_MAX)

	# 真实结算计算器（时间线分段）
	var result: Dictionary = SettlementCalculator.calculate({
		"total_users": total_users,
		"pay_ability": pay_ability,
		"heat": heat,
		"player_quality": player_quality,
		"player_launch_month": elapsed,
		"total_months": total,
		"competitors": competitors,
	})

	var revenue: int = int(result.get("total_revenue", 0))
	var roi: float = float(revenue) / float(investment) if investment > 0 else 0.0

	# 清理本局状态
	_cleanup_round()

	return {
		"investment": investment,
		"revenue": revenue,
		"roi": roi,
		"failed": false,
		"launch_month": actual_launch_month,
		"quality": player_quality,
		"heat": heat,
		"window_months": result.get("window_months", 0),
		"compete_months": result.get("compete_months", 0),
		"comp_count": launched_count,
		"total_users": total_users,
		"pay_ability": pay_ability,
		"loadout": loadout_indices,
	}


## ===== 清理本局状态（为下一局做准备）=====
func _cleanup_round() -> void:
	TimeManager.stop()
	MarketHeat.reset()
	AICompetitors.reset()



## ===== 选择配置 =====
func _pick_loadout(strategy: Strategy) -> Array:
	match strategy:
		Strategy.RUSH:
			return [[0,1,0], [1,0,0], [0,0,0]][randi() % 3]
		Strategy.BALANCED:
			return [[1,1,0], [1,0,1], [1,1,1]][randi() % 3]
		Strategy.PATIENT:
			return [[2,0,0], [2,1,0], [1,1,1]][randi() % 3]
		Strategy.POLISH_MAX:
			return [[2,1,0], [2,1,1], [2,2,1]][randi() % 3]
		Strategy.SMART:
			return [[1,1,0], [2,0,0], [1,1,1], [2,1,0]][randi() % 4]
		_:
			return LOADOUTS[randi() % LOADOUTS.size()]


## ===== 决定上线月份 =====
func _decide_launch_month(strategy: Strategy, topic: TopicData) -> int:
	match strategy:
		Strategy.RUSH:
			return randi_range(8, 14)
		Strategy.BALANCED:
			return randi_range(16, 24)
		Strategy.PATIENT:
			return randi_range(24, 30)
		Strategy.POLISH_MAX:
			return randi_range(28, 34)
		Strategy.SMART:
			# 找热度高峰附近
			var best_month: int = 20
			var best_heat: float = 0.0
			for m: int in range(14, 32):
				# 用真实 MarketHeat 查询（已初始化）
				# 模拟推进到 m 月查热度
				var h: float = MarketHeat.get_heat(topic.id)
				if h > best_heat:
					best_heat = h
					best_month = m
			return clampi(best_month, 14, 34)
		_:
			return randi_range(8, 34)


## ===== 输出策略报告 =====
func _print_strategy_report(strategy: Variant, results: Array) -> void:
	var name: String = STRATEGY_NAMES.get(strategy, "全策略混合") as String
	print("\n--- %s (样本 %d) ---" % [name, results.size()])
	if results.is_empty():
		print("  无数据")
		return

	var failed_count: int = 0
	var rois: Array[float] = []
	var qualities: Array[float] = []
	var heats: Array[float] = []
	var launch_months: Array[int] = []
	var comp_counts: Array[int] = []

	for r: Dictionary in results:
		if r.get("failed", false) as bool:
			failed_count += 1
			rois.append(0.0)
		else:
			rois.append(r.get("roi", 0.0) as float)
			qualities.append(r.get("quality", 0.0) as float)
			heats.append(r.get("heat", 0.0) as float)
			launch_months.append(r.get("launch_month", 0) as int)
			comp_counts.append(r.get("comp_count", 0) as int)

	# ROI 分布
	var lose_count: int = 0
	var breakeven_count: int = 0
	var profit_count: int = 0
	var big_profit_count: int = 0
	for roi: float in rois:
		if roi < 1.0:
			lose_count += 1
		elif roi < 1.5:
			breakeven_count += 1
		elif roi < 2.5:
			profit_count += 1
		else:
			big_profit_count += 1

	var total: int = results.size()
	print("  💰 收益分布:")
	print("    亏损 (ROI<1.0):     %5.1f%% (%d)   [目标: 50%%]" % [float(lose_count) / float(total) * 100.0, lose_count])
	print("    保本小赚 (1.0-1.5): %5.1f%% (%d)   [目标: 30%%]" % [float(breakeven_count) / float(total) * 100.0, breakeven_count])
	print("    赚钱 (1.5-2.5):     %5.1f%% (%d)   [目标: 15%%]" % [float(profit_count) / float(total) * 100.0, profit_count])
	print("    大赚 (ROI≥2.5):     %5.1f%% (%d)   [目标: 5%%]" % [float(big_profit_count) / float(total) * 100.0, big_profit_count])
	print("    撤离失败:           %5.1f%% (%d)" % [float(failed_count) / float(total) * 100.0, failed_count])

	rois.sort()
	var median_roi: float = rois[rois.size() / 2]
	var avg_roi: float = 0.0
	for roi: float in rois:
		avg_roi += roi
	avg_roi /= float(rois.size())
	var p10: float = rois[int(float(rois.size()) * 0.10)]
	var p25: float = rois[int(float(rois.size()) * 0.25)]
	var p75: float = rois[int(float(rois.size()) * 0.75)]
	var p90: float = rois[int(float(rois.size()) * 0.90)]
	var p95: float = rois[int(float(rois.size()) * 0.95)]
	print("  📊 ROI 分位:")
	print("    P10=%.2f  P25=%.2f  中位=%.2f  均值=%.2f  P75=%.2f  P90=%.2f  P95=%.2f" % [p10, p25, median_roi, avg_roi, p75, p90, p95])

	if qualities.size() > 0:
		var avg_q: float = 0.0
		var avg_h: float = 0.0
		var avg_m: float = 0.0
		var avg_c: float = 0.0
		for q: float in qualities: avg_q += q
		for h: float in heats: avg_h += h
		for m: int in launch_months: avg_m += float(m)
		for c: int in comp_counts: avg_c += float(c)
		avg_q /= float(qualities.size())
		avg_h /= float(heats.size())
		avg_m /= float(launch_months.size())
		avg_c /= float(comp_counts.size())
		print("  📈 平均品质=%.1f  平均热度=%.1f  平均上线月=%.1f  平均竞品数=%.1f" % [avg_q, avg_h, avg_m, avg_c])

	# 上线时机分组
	if launch_months.size() > 10:
		var early_rois: Array[float] = []
		var mid_rois: Array[float] = []
		var late_rois: Array[float] = []
		for r: Dictionary in results:
			if r.get("failed", false) as bool:
				continue
			var m: int = r.get("launch_month", 0) as int
			var roi: float = r.get("roi", 0.0) as float
			if m <= 14:
				early_rois.append(roi)
			elif m <= 24:
				mid_rois.append(roi)
			else:
				late_rois.append(roi)
		print("  ⏰ 上线时机 → 平均ROI: 早期(≤14月)=%.2f  中期(15-24月)=%.2f  后期(25+月)=%.2f" % [
			_avg_float(early_rois), _avg_float(mid_rois), _avg_float(late_rois)])


func _avg_float(arr: Array[float]) -> float:
	if arr.is_empty(): return 0.0
	var s: float = 0.0
	for v: float in arr: s += v
	return s / float(arr.size())


## ===== 调优建议 =====
func _print_tuning_advice(all_results: Dictionary) -> void:
	var all_rois: Array[float] = []
	for strategy_val: int in Strategy.values():
		for r: Dictionary in all_results[strategy_val]:
			all_rois.append(r.get("roi", 0.0) as float)

	var total: int = all_rois.size()
	var lose: int = 0
	var breakeven: int = 0
	var profit: int = 0
	var big_profit: int = 0
	for roi: float in all_rois:
		if roi < 1.0: lose += 1
		elif roi < 1.5: breakeven += 1
		elif roi < 2.5: profit += 1
		else: big_profit += 1

	var lp: float = float(lose) / float(total) * 100.0
	var bp: float = float(breakeven) / float(total) * 100.0
	var pp: float = float(profit) / float(total) * 100.0
	var bgp: float = float(big_profit) / float(total) * 100.0

	print("  当前全局分布 vs 目标:")
	print("    亏损:    %.1f%% (目标 50%%，差距 %+.1f%%)" % [lp, lp - 50.0])
	print("    保本:    %.1f%% (目标 30%%，差距 %+.1f%%)" % [bp, bp - 30.0])
	print("    赚钱:    %.1f%% (目标 15%%，差距 %+.1f%%)" % [pp, pp - 15.0])
	print("    大赚:    %.1f%% (目标  5%%，差距 %+.1f%%)" % [bgp, bgp - 5.0])

	var rush_avg: float = 0.0
	var patient_avg: float = 0.0
	for r: Dictionary in all_results[Strategy.RUSH]:
		rush_avg += r.get("roi", 0.0) as float
	rush_avg /= float((all_results[Strategy.RUSH] as Array).size())
	for r: Dictionary in all_results[Strategy.PATIENT]:
		patient_avg += r.get("roi", 0.0) as float
	patient_avg /= float((all_results[Strategy.PATIENT] as Array).size())

	print("\n  ⚠️ 策略平衡检查:")
	print("    速攻型平均ROI: %.2f" % rush_avg)
	print("    耐心型平均ROI: %.2f" % patient_avg)
	if rush_avg > patient_avg * 1.5:
		print("    🔴 速攻过强！需要增加竞品惩罚或降低空窗收益")
	elif patient_avg > rush_avg * 1.5:
		print("    🔴 耐心型过强！需要增加竞品提前上线的惩罚")
	else:
		print("    🟢 策略差距合理")
