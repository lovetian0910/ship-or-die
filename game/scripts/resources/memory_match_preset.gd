# memory_match_preset.gd — 素材归档小游戏参数预设
class_name MemoryMatchPreset
extends Resource

@export var preset_id: String                ## 预设标识
@export var preset_name: String              ## 显示名称
@export_multiline var flavor_text: String    ## 叙事包装文本

@export_group("游戏参数")
@export var grid_rows: int = 3               ## 行数
@export var grid_cols: int = 4               ## 列数
@export var time_limit: float = 15.0         ## 时间限制（秒）
@export var flip_duration: float = 0.3       ## 翻牌动画时长（秒）
@export var peek_duration: float = 0.5       ## 配对失败停留时长（秒）


## 获取实际时限
func get_time_limit() -> float:
	if time_limit > 0.0:
		return time_limit
	return Config.MEMORY_MATCH_TIME_LIMIT


## 获取总对数
func get_total_pairs() -> int:
	return (grid_rows * grid_cols) / 2
