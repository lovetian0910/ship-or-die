# bug_survivor_preset.gd — Bug Survivor 小游戏参数预设
class_name BugSurvivorPreset
extends Resource

@export var preset_id: String                ## 预设标识
@export var preset_name: String              ## 显示名称
@export_multiline var flavor_text: String    ## 叙事包装文本

@export_group("游戏参数")
@export var bug_base_speed: float = 80.0     ## 虫子基础速度（像素/秒）
@export var player_speed_override: float = 0.0  ## 0=使用Config默认值
@export var bullet_interval_override: float = 0.0  ## 0=使用Config默认值
@export var game_duration_override: float = 0.0    ## 0=使用Config默认值

@export_group("难度调整")
@export var spawn_interval_scale: float = 1.0  ## 生成间隔缩放（<1=更密，>1=更稀）
@export var speed_scale: float = 1.0           ## 速度缩放（>1=更快）


## 获取实际游戏时长
func get_duration() -> float:
	if game_duration_override > 0.0:
		return game_duration_override
	return Config.BUG_SURVIVOR_GAME_DURATION


## 获取实际玩家速度
func get_player_speed() -> float:
	if player_speed_override > 0.0:
		return player_speed_override
	return Config.BUG_SURVIVOR_PLAYER_SPEED


## 获取实际射击间隔
func get_bullet_interval() -> float:
	if bullet_interval_override > 0.0:
		return bullet_interval_override
	return Config.BUG_SURVIVOR_BULLET_INTERVAL


## 获取指定时间点的生成间隔
func get_spawn_interval(elapsed: float) -> float:
	var curve: Array = Config.BUG_SURVIVOR_SPAWN_CURVE
	var interval: float = 1.0
	for entry: Dictionary in curve:
		var ts: float = entry.get("time_start", 0.0) as float
		if elapsed >= ts:
			interval = entry.get("spawn_interval", 1.0) as float
	return interval * spawn_interval_scale


## 获取指定时间点的虫子实际速度
func get_bug_speed(elapsed: float) -> float:
	var curve: Array = Config.BUG_SURVIVOR_SPAWN_CURVE
	var multiplier: float = 1.0
	for entry: Dictionary in curve:
		var ts: float = entry.get("time_start", 0.0) as float
		if elapsed >= ts:
			multiplier = entry.get("speed_multiplier", 1.0) as float
	return bug_base_speed * multiplier * speed_scale
