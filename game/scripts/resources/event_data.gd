# event_data.gd — 事件数据 Resource 基类
class_name EventData
extends Resource

## 事件类型
enum EventType { SEARCH, FIGHT }

## 搜类事件收益类型
enum SearchBenefitType { QUALITY_CAP, DEV_SPEED, QUALITY_FLAT, ENERGY }

@export var event_id: String                   ## 唯一标识（如 "search_talent_01"）
@export var title: String                      ## 事件标题
@export_multiline var description: String      ## 事件描述
@export var event_type: EventType              ## 搜 or 打

## ===== 搜类事件参数 =====
@export_group("搜类事件")
@export var search_benefit_type: SearchBenefitType  ## 收益类型
@export var search_benefit_value: float = 0.0       ## 收益数值
@export var search_benefit_desc: String = ""        ## 收益描述文本
@export var search_month_cost: int = 1              ## 时间消耗（月）

## ===== 打类事件参数 =====
@export_group("打类事件")
@export var fight_preset_path: String = ""     ## 代码急救预设路径（res://resources/minigame_presets/xxx.tres）
@export var minigame_type: String = "code_rescue"  ## "code_rescue" 或 "bug_survivor"
## 保守结果（小游戏 <60%）
@export var fight_conservative_desc: String = ""
@export var fight_conservative_quality: float = 0.0     ## 负数=惩罚
@export var fight_conservative_month_cost: int = 0
## 稳妥结果（小游戏 60-90%）
@export var fight_steady_desc: String = ""
@export var fight_steady_quality: float = 0.0
@export var fight_steady_month_cost: int = 0
## 冒险结果（小游戏 >=90%）
@export var fight_risky_desc: String = ""
@export var fight_risky_quality: float = 0.0
@export var fight_risky_speed_bonus: float = 0.0        ## 永久速度加成（0=无）
@export var fight_risky_month_cost: int = 0

## ===== 阶段限制 =====
@export_group("触发条件")
@export var allowed_phases: Array[StringName] = [&"early", &"mid", &"late"]
@export var is_fixed: bool = false             ## true=固定探索点，false=随机


## 根据小游戏存活率返回结果等级
func get_fight_result(survival_rate: float) -> String:
	if survival_rate >= 0.9:
		return "risky"
	elif survival_rate >= 0.6:
		return "steady"
	else:
		return "conservative"


## 获取打类事件指定结果的效果字典
func get_fight_effects(result_level: String) -> Dictionary:
	match result_level:
		"risky":
			return {
				"quality": fight_risky_quality,
				"speed_bonus": fight_risky_speed_bonus,
				"month_cost": fight_risky_month_cost,
				"desc": fight_risky_desc,
			}
		"steady":
			return {
				"quality": fight_steady_quality,
				"speed_bonus": 0.0,
				"month_cost": fight_steady_month_cost,
				"desc": fight_steady_desc,
			}
		_:  # conservative
			return {
				"quality": fight_conservative_quality,
				"speed_bonus": 0.0,
				"month_cost": fight_conservative_month_cost,
				"desc": fight_conservative_desc,
			}
