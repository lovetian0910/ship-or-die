# entry_resource_data.gd — 入场资源数据定义（Resource子类）
class_name EntryResourceData
extends Resource

## 资源类别
enum Category { CREATOR, OUTSOURCE, BUSINESS }

## 资源等级
enum Tier { LOW, MID, HIGH }

@export var category: Category
@export var tier: Tier

@export var display_name: String          ## 显示名称（如"鹅皇互娱主创"）
@export_multiline var description: String ## 简介
@export var price: int                    ## 购买价格
@export var icon: Texture2D              ## 头像/图标（可选，无则用占位）

## ---- 效果参数（按类别只填对应字段） ----
@export_group("品质上限 (主创)")
@export var quality_cap: float = 0.0      ## 品质上限分数

@export_group("时间效率 (外包)")
@export var dev_speed: float = 1.0        ## 研发速度倍率

@export_group("事件应对 (商务)")
@export var energy: int = 0               ## 代码急救精力值
@export var option_unlock: String = ""    ## 选项解锁级别: "partial" / "full" / "all_risky"


## 获取效果字典（供其他模块读取）
func get_effects() -> Dictionary:
	match category:
		Category.CREATOR:
			return { "quality_cap": quality_cap }
		Category.OUTSOURCE:
			return { "dev_speed": dev_speed }
		Category.BUSINESS:
			return { "energy": energy, "option_unlock": option_unlock }
	return {}


## 获取等级数字（1/2/3）
func get_tier_number() -> int:
	return tier + 1
