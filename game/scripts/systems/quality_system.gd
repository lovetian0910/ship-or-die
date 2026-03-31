# quality_system.gd — 品质系统（RefCounted，每局一个实例）
# 职责：品质积累、模糊等级映射、内测揭示、打磨增减
class_name QualitySystem
extends RefCounted

## 品质等级枚举
enum Grade { ROUGH, ACCEPTABLE, EXCELLENT, MASTERPIECE }

## 等级名称
const GRADE_NAMES: Array[String] = ["粗糙", "合格", "精良", "杰作"]

## 等级阈值（0-25粗糙, 25-50合格, 50-75精良, 75+杰作）
const GRADE_THRESHOLDS: Array[float] = [0.0, 25.0, 50.0, 75.0]

## 实际品质分（0-100）
var raw_score: float = 0.0

## 品质上限（由主创等级决定）
var cap: float = 40.0

## 每月品质增长 = QUALITY_PER_MONTH * 外包效率倍率
var rate_per_month: float = 1.5

## 是否已做内测（揭示真实值）
var revealed: bool = false

## 模糊偏移量（局开始时固定，-10 ~ +10）
var _boundary_offset: float = 0.0


func _init(creator_level: int, outsource_level: int) -> void:
	# 品质上限：由主创等级决定
	var cap_val: float = Config.QUALITY_CAP.get(creator_level, 40.0)
	cap = cap_val

	# 品质增长速率：基础 × 外包效率
	var base_rate: float = Config.QUALITY_PER_MONTH
	var speed_mult: float = Config.OUTSOURCE_SPEED.get(outsource_level, 1.0)
	rate_per_month = base_rate * speed_mult

	# 模糊偏移：局开始时固定
	_boundary_offset = randf_range(-10.0, 10.0)


## 品质积累：每消耗N月，品质增加 rate_per_month * N
func accumulate(months: int) -> void:
	if raw_score >= cap:
		return
	raw_score = minf(raw_score + rate_per_month * float(months), cap)


## 内部真实等级
func get_true_grade() -> Grade:
	return _score_to_grade(raw_score)


## 玩家看到的模糊等级（内测后显示真实等级）
func get_fuzzy_grade() -> Grade:
	if revealed:
		return get_true_grade()
	return _score_to_grade(raw_score + _boundary_offset)


## 获取玩家可见的等级名称
func get_display_grade_name() -> String:
	var grade: Grade = get_fuzzy_grade()
	return GRADE_NAMES[grade]


## 获取真实等级名称
func get_true_grade_name() -> String:
	var grade: Grade = get_true_grade()
	return GRADE_NAMES[grade]


## 内测揭示：锁定为真实值
func reveal() -> void:
	revealed = true


## 打磨成功：品质提升
func apply_boost(amount: float) -> void:
	raw_score = minf(raw_score + amount, cap)


## 打磨失败/放弃修复：品质下降
func apply_penalty(amount: float) -> void:
	raw_score = maxf(raw_score - amount, 0.0)


## 品质分 → 等级（纯函数）
func _score_to_grade(score: float) -> Grade:
	if score >= GRADE_THRESHOLDS[3]:  # 75
		return Grade.MASTERPIECE
	elif score >= GRADE_THRESHOLDS[2]:  # 50
		return Grade.EXCELLENT
	elif score >= GRADE_THRESHOLDS[1]:  # 25
		return Grade.ACCEPTABLE
	else:
		return Grade.ROUGH
