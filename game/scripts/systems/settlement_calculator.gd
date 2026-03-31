# settlement_calculator.gd — 收益计算纯函数（无节点依赖，可单元测试）
class_name SettlementCalculator
extends RefCounted


## 热度乘数查表
static func get_heat_multiplier(heat: float) -> float:
	if heat >= 80.0:
		return 2.0
	elif heat >= 60.0:
		return 1.5
	elif heat >= 40.0:
		return 1.0
	elif heat >= 20.0:
		return 0.6
	else:
		return 0.3


## 核心结算计算
## params 字典结构：
##   total_users: int        — 题材用户池大小 (1000-5000)
##   pay_ability: float      — 用户付费能力 (0.5-2.0)
##   window_ratio: float     — 空窗期时长占比 (0.0-1.0)
##   heat: float             — 上线时刻的市场热度 (0-100)
##   player_quality: float   — 玩家产品品质分
##   competitor_qualities: Array — 已上线竞品品质分列表
## 返回 Dictionary：各分项 + 总收益 + breakdown 明细行
static func calculate(params: Dictionary) -> Dictionary:
	var total_users: int = int(params.get("total_users", 3000))
	var pay_ability: float = float(params.get("pay_ability", 1.0))
	var window_ratio: float = clampf(float(params.get("window_ratio", 0.0)), 0.0, 1.0)
	var heat: float = float(params.get("heat", 50.0))
	var player_quality: float = float(params.get("player_quality", 50.0))
	var competitor_qualities: Array = params.get("competitor_qualities", []) as Array

	var heat_multiplier: float = get_heat_multiplier(heat)

	# 1. 空窗期用户（先到先得）
	var window_users: int = floori(float(total_users) * window_ratio * heat_multiplier)
	var window_revenue: int = floori(float(window_users) * pay_ability)

	# 2. 存量用户争夺（品质权重分配）
	var remaining_users: int = total_users - window_users
	var total_quality: float = player_quality
	for q: Variant in competitor_qualities:
		total_quality += float(q)
	var share_ratio: float = player_quality / total_quality if total_quality > 0.0 else 0.0
	var share_users: int = floori(float(remaining_users) * share_ratio)
	var share_revenue: int = floori(float(share_users) * pay_ability)

	# 3. 最终收益
	var total_revenue: int = window_revenue + share_revenue

	# 4. 竞品份额明细（用于UI展示）
	var share_details: Array[Dictionary] = []
	for q: Variant in competitor_qualities:
		var comp_q: float = float(q)
		var comp_ratio: float = comp_q / total_quality if total_quality > 0.0 else 0.0
		share_details.append({
			"quality": comp_q,
			"share_ratio": comp_ratio,
		})

	return {
		"window_users": window_users,
		"window_revenue": window_revenue,
		"share_users": share_users,
		"share_revenue": share_revenue,
		"heat_multiplier": heat_multiplier,
		"total_revenue": total_revenue,
		"player_quality": player_quality,
		"player_share_ratio": share_ratio,
		"competitor_share_details": share_details,
		"window_ratio": window_ratio,
		"breakdown": [
			{
				"label": "空窗期用户收入",
				"value": window_revenue,
				"detail": "%d 用户 × %.1f" % [window_users, pay_ability],
			},
			{
				"label": "品质竞争收入",
				"value": share_revenue,
				"detail": "%d 用户 × %.1f" % [share_users, pay_ability],
			},
			{
				"label": "热度加成",
				"value": -1,  # 特殊标记：非金额行
				"detail": "×%.1f（已计入上述收入）" % heat_multiplier,
			},
		],
	}
