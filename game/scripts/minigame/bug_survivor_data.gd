# bug_survivor_data.gd — Bug Survivor 小游戏：纯数据层
# 负责：难度曲线查询、存活率计算、生成位置计算
# 零UI依赖，完全可测试
class_name BugSurvivorData
extends RefCounted

var preset: BugSurvivorPreset
var game_duration: float
var elapsed: float = 0.0
var kill_count: int = 0
var is_alive: bool = true


func setup(p_preset: BugSurvivorPreset) -> void:
	preset = p_preset
	game_duration = p_preset.get_duration()
	elapsed = 0.0
	kill_count = 0
	is_alive = true


## 推进时间，返回 true 如果游戏仍在进行
func advance(delta: float) -> bool:
	if not is_alive:
		return false
	elapsed += delta
	if elapsed >= game_duration:
		elapsed = game_duration
		return false
	return true


## 玩家死亡
func player_died() -> void:
	is_alive = false


## 记录击杀
func record_kill() -> void:
	kill_count += 1


## 获取存活率 (0.0 ~ 1.0)
func get_survival_rate() -> float:
	if game_duration <= 0.0:
		return 0.0
	return clampf(elapsed / game_duration, 0.0, 1.0)


## 获取结果等级
func get_result() -> String:
	var rate: float = get_survival_rate()
	if rate >= 0.9:
		return "risky"
	elif rate >= 0.5:
		return "steady"
	else:
		return "conservative"


## 获取当前虫子生成间隔
func get_current_spawn_interval() -> float:
	return preset.get_spawn_interval(elapsed)


## 获取当前虫子速度
func get_current_bug_speed() -> float:
	return preset.get_bug_speed(elapsed)


## 在竞技场边缘随机生成一个位置
static func random_edge_position(arena_size: Vector2) -> Vector2:
	var side: int = randi_range(0, 3)
	var margin: float = 20.0
	match side:
		0:  # 上边
			return Vector2(randf_range(0, arena_size.x), -margin)
		1:  # 下边
			return Vector2(randf_range(0, arena_size.x), arena_size.y + margin)
		2:  # 左边
			return Vector2(-margin, randf_range(0, arena_size.y))
		_:  # 右边
			return Vector2(arena_size.x + margin, randf_range(0, arena_size.y))
