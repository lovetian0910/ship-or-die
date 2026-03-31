# settlement_calculator.gd — 时间线分段结算（逐月累计，竞品后续上线会压缩收入）
class_name SettlementCalculator
extends RefCounted


## 热度乘数查表
static func get_heat_multiplier(heat: float) -> float:
	if heat >= 80.0:
		return 1.6
	elif heat >= 60.0:
		return 1.3
	elif heat >= 40.0:
		return 1.0
	elif heat >= 20.0:
		return 0.7
	else:
		return 0.4


## 品质因子：品质越低，收入越少
static func get_quality_factor(quality: float) -> float:
	var baseline: float = Config.SETTLEMENT_QUALITY_BASELINE
	var floor_val: float = Config.SETTLEMENT_QUALITY_FLOOR
	if quality <= 0.0:
		return floor_val
	if quality >= baseline:
		var excess: float = (quality - baseline) / baseline
		return 1.0 + log(1.0 + excess) * 0.30
	var t: float = quality / baseline
	var s: float = t * t * (3.0 - 2.0 * t)
	return floor_val + (1.0 - floor_val) * s


## 市场成熟度：月份越晚，可触达用户越多
static func get_maturity_factor(month: int, total_months: int) -> float:
	var floor_val: float = Config.SETTLEMENT_MATURITY_FLOOR
	var power: float = Config.SETTLEMENT_MATURITY_POWER
	var t: float = clampf(float(month) / float(total_months), 0.0, 1.0)
	return floor_val + (1.0 - floor_val) * pow(t, power)


## 核心结算：时间线分段逐月累计
## params:
##   total_users: int           — 用户池总量
##   pay_ability: float         — 付费能力
##   heat: float                — 上线时市场热度
##   player_quality: float      — 玩家品质
##   player_launch_month: int   — 玩家上线月
##   total_months: int          — 总月数(36)
##   competitors: Array[Dictionary] — [{quality:float, launch_month:int}]
static func calculate(params: Dictionary) -> Dictionary:
	var total_users: int = int(params.get("total_users", 2500))
	var pay_ability: float = float(params.get("pay_ability", 0.9))
	var heat: float = float(params.get("heat", 50.0))
	var player_quality: float = float(params.get("player_quality", 50.0))
	var player_launch: int = int(params.get("player_launch_month", 18))
	var total_months: int = int(params.get("total_months", 36))
	var competitors: Array = params.get("competitors", []) as Array

	var heat_mult: float = get_heat_multiplier(heat)
	var quality_factor: float = get_quality_factor(player_quality)

	# 运营期：从上线月到总月数
	var operating_months: int = total_months - player_launch
	if operating_months <= 0:
		return _empty_result(player_quality, heat_mult, quality_factor)

	# 逐月结算
	var window_revenue_total: float = 0.0   ## 独占月份收入
	var compete_revenue_total: float = 0.0  ## 竞争月份收入
	var window_months: int = 0
	var compete_months: int = 0

	# 每月基础用户 = 总池 / 运营月数（用户均匀分布在各月）
	var users_per_month: float = float(total_users) / float(operating_months)

	for month: int in range(player_launch, total_months):
		# 该月市场成熟度
		var maturity: float = get_maturity_factor(month, total_months)
		var month_users: float = users_per_month * maturity * heat_mult

		# 该月有多少竞品已上线
		var comp_online_qualities: Array[float] = []
		for comp: Variant in competitors:
			var cd: Dictionary = comp as Dictionary
			var comp_launch: int = cd.get("launch_month", 999) as int
			if comp_launch <= month:
				comp_online_qualities.append(cd.get("quality", 40.0) as float)

		if comp_online_qualities.is_empty():
			# 独占月：全部用户归玩家，但品质影响留存
			var month_rev: float = month_users * pay_ability * quality_factor
			window_revenue_total += month_rev
			window_months += 1
		else:
			# 竞争月：按品质权重分摊
			var total_q: float = player_quality
			for cq: float in comp_online_qualities:
				total_q += cq
			var share: float = player_quality / total_q if total_q > 0.0 else 0.0
			var month_rev: float = month_users * share * pay_ability
			compete_revenue_total += month_rev
			compete_months += 1

	var window_revenue: int = floori(window_revenue_total)
	var compete_revenue: int = floori(compete_revenue_total)
	var total_revenue: int = window_revenue + compete_revenue

	# 竞品份额明细（用于UI展示，取最终状态）
	var final_comp_qualities: Array[float] = []
	for comp: Variant in competitors:
		var cd: Dictionary = comp as Dictionary
		var comp_launch: int = cd.get("launch_month", 999) as int
		if comp_launch <= total_months:
			final_comp_qualities.append(cd.get("quality", 40.0) as float)

	var final_total_q: float = player_quality
	for cq: float in final_comp_qualities:
		final_total_q += cq
	var final_share: float = player_quality / final_total_q if final_total_q > 0.0 else 1.0

	var share_details: Array[Dictionary] = []
	for comp: Variant in competitors:
		var cd: Dictionary = comp as Dictionary
		var cq: float = cd.get("quality", 40.0) as float
		var cr: float = cq / final_total_q if final_total_q > 0.0 else 0.0
		share_details.append({"quality": cq, "share_ratio": cr})

	return {
		"window_months": window_months,
		"compete_months": compete_months,
		"window_revenue": window_revenue,
		"compete_revenue": compete_revenue,
		"heat_multiplier": heat_mult,
		"quality_factor": quality_factor,
		"total_revenue": total_revenue,
		"player_quality": player_quality,
		"player_share_ratio": final_share,
		"competitor_share_details": share_details,
		"breakdown": [
			{
				"label": "独占期收入（%d个月）" % window_months,
				"value": window_revenue,
				"detail": "品质因子 %.2f" % quality_factor,
			},
			{
				"label": "竞争期收入（%d个月）" % compete_months,
				"value": compete_revenue,
				"detail": "品质份额 %.0f%%" % (final_share * 100.0),
			},
			{
				"label": "热度加成",
				"value": -1,
				"detail": "×%.1f（已计入上述收入）" % heat_mult,
			},
		],
	}


## 空结果（运营期为0时返回）
static func _empty_result(quality: float, heat_mult: float, qf: float) -> Dictionary:
	return {
		"window_months": 0, "compete_months": 0,
		"window_revenue": 0, "compete_revenue": 0,
		"heat_multiplier": heat_mult, "quality_factor": qf,
		"total_revenue": 0, "player_quality": quality,
		"player_share_ratio": 0.0, "competitor_share_details": [],
		"breakdown": [],
	}
