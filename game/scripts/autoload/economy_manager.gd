# economy_manager.gd — Autoload单例：金钱管理、保底、局间传递
extends Node

## ---- 当前局装备 ----
var current_loadout: Dictionary = {}  # { "creator": EntryResourceData, "outsource": ..., "business": ... }


func _ready() -> void:
	pass


## 获取当前金钱（从 GameManager.persistent_data 读取）
func get_money() -> int:
	return GameManager.persistent_data.get("money", Config.INITIAL_MONEY)


## 设置金钱
func _set_money(amount: int) -> void:
	GameManager.persistent_data["money"] = amount
	EventBus.money_changed.emit(amount)


## 局结算：成功 —— 加收益
func add_earnings(amount: int) -> void:
	_set_money(get_money() + amount)


## 局结算：失败 —— 触底保底
func apply_failure() -> void:
	_set_money(maxi(get_money(), Config.MIN_MONEY))


## 购买入场资源（扣钱），返回是否成功
func purchase_loadout(total_cost: int) -> bool:
	if total_cost > get_money():
		return false
	_set_money(get_money() - total_cost)
	return true


## 检查是否买得起
func can_afford(cost: int) -> bool:
	return get_money() >= cost


## 存储本局选购结果，同时写入 run_data
func set_loadout(creator: EntryResourceData, outsource: EntryResourceData, business: EntryResourceData) -> void:
	current_loadout = {
		"creator": creator,
		"outsource": outsource,
		"business": business,
	}
	# 同步写入 GameManager.run_data
	GameManager.run_data["resources"] = {
		"creator": creator.get_tier_number(),
		"outsource": outsource.get_tier_number(),
		"business": business.get_tier_number(),
	}
	GameManager.run_data["quality_cap"] = creator.quality_cap


## 获取本局合并效果（供研发/事件模块读取）
func get_loadout_effects() -> Dictionary:
	if current_loadout.is_empty():
		return {}
	var effects: Dictionary = {}
	for res: EntryResourceData in current_loadout.values():
		effects.merge(res.get_effects())
	return effects


## 获取本局入场总投入
func get_loadout_cost() -> int:
	var total: int = 0
	for res: EntryResourceData in current_loadout.values():
		total += res.price
	return total


## 重置（新游戏）
func reset() -> void:
	_set_money(Config.INITIAL_MONEY)
	current_loadout = {}
