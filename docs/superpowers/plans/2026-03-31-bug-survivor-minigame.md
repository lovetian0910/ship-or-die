# Bug Survivor 小游戏实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增幸存者 Like 小游戏，与现有代码急救并存，作为部分打类事件的载体。

**Architecture:** 三层分离（数据层 RefCounted + 游戏层 Node2D + 预设层 Resource），全 Area2D 碰撞，信号接口与代码急救完全一致（`game_finished(result, survival_rate)`）。FightEventPopup 根据事件数据中的 `minigame_type` 字段选择加载哪个小游戏场景。

**Tech Stack:** Godot 4.6.1 + GDScript，纯代码构建 UI（无 .tscn 预制），Area2D 碰撞检测。

**设计规格:** `docs/superpowers/specs/2026-03-31-bug-survivor-minigame-design.md`

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `game/scripts/resources/bug_survivor_preset.gd` | 预设 Resource：竞技场尺寸、速度、生成曲线等参数 |
| 新建 | `game/scripts/minigame/bug_survivor_data.gd` | 数据层（RefCounted）：难度曲线计算、存活率计算 |
| 新建 | `game/scripts/minigame/bug_survivor_game.gd` | 游戏层（Control）：主控脚本，玩家/子弹/虫子/碰撞/HUD |
| 新建 | `game/scenes/minigame/bug_survivor_game.tscn` | 最小场景壳（仅挂脚本） |
| 新建 | `game/resources/minigame_presets/bug_swarm.tres` | 预设：虫群爆发（标准难度） |
| 新建 | `game/resources/minigame_presets/bug_invasion.tres` | 预设：虫族入侵（困难难度） |
| 新建 | `game/resources/events/fight_survivor_01.tres` | 打类事件：虫群爆发 |
| 新建 | `game/resources/events/fight_survivor_02.tres` | 打类事件：虫族入侵 |
| 修改 | `game/scripts/autoload/config.gd` | 新增 BUG_SURVIVOR 数值配置区 |
| 修改 | `game/scripts/resources/event_data.gd` | 新增 `minigame_type` 字段（默认 "code_rescue"，新事件用 "bug_survivor"） |
| 修改 | `game/scripts/popups/fight_event_popup.gd` | 根据 `minigame_type` 分发加载不同小游戏场景 |
| 修改 | `game/tests/test_runner.gd` | 新增 bug_survivor 数据层测试 |

---

### Task 1: Config 数值配置

**Files:**
- Modify: `game/scripts/autoload/config.gd`

- [ ] **Step 1: 在 config.gd 末尾新增 BUG_SURVIVOR 配置区**

在 `config.gd` 文件的 `RARITY_TYPE_WEIGHTS` 之后追加：

```gdscript
## ===== Bug Survivor 小游戏 =====
const BUG_SURVIVOR_GAME_DURATION: float = 60.0      ## 总时长（秒）
const BUG_SURVIVOR_ARENA_SIZE: Vector2 = Vector2(800, 600)  ## 竞技场尺寸
const BUG_SURVIVOR_PLAYER_SPEED: float = 200.0      ## 玩家移速（像素/秒）
const BUG_SURVIVOR_PLAYER_RADIUS: float = 16.0      ## 玩家碰撞半径
const BUG_SURVIVOR_BULLET_SPEED: float = 400.0      ## 子弹速度（像素/秒）
const BUG_SURVIVOR_BULLET_INTERVAL: float = 0.3     ## 射击间隔（秒）
const BUG_SURVIVOR_BULLET_RADIUS: float = 6.0       ## 子弹碰撞半径
const BUG_SURVIVOR_BUG_RADIUS: float = 12.0         ## 虫子碰撞半径

## 难度曲线：[{time_start, spawn_interval, speed_multiplier}]
## time_start: 该阶段从第几秒开始
## spawn_interval: 虫子生成间隔（秒）
## speed_multiplier: 虫子速度倍率（基于预设的 bug_base_speed）
const BUG_SURVIVOR_SPAWN_CURVE: Array = [
	{"time_start": 0.0, "spawn_interval": 1.0, "speed_multiplier": 1.0},
	{"time_start": 15.0, "spawn_interval": 0.6, "speed_multiplier": 1.2},
	{"time_start": 30.0, "spawn_interval": 0.35, "speed_multiplier": 1.5},
	{"time_start": 45.0, "spawn_interval": 0.2, "speed_multiplier": 1.8},
]
```

- [ ] **Step 2: 运行测试确认无编译错误**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit**

```bash
git add game/scripts/autoload/config.gd
git commit -m "feat: add Bug Survivor config values"
```

---

### Task 2: BugSurvivorPreset Resource

**Files:**
- Create: `game/scripts/resources/bug_survivor_preset.gd`

- [ ] **Step 1: 创建预设 Resource 类**

```gdscript
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
```

- [ ] **Step 2: 运行测试确认无编译错误**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit**

```bash
git add game/scripts/resources/bug_survivor_preset.gd
git commit -m "feat: add BugSurvivorPreset resource class"
```

---

### Task 3: BugSurvivorData 数据层

**Files:**
- Create: `game/scripts/minigame/bug_survivor_data.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: 创建数据层类**

```gdscript
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
	elif rate >= 0.6:
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
```

- [ ] **Step 2: 在 test_runner.gd 中新增测试**

在 `_run_fog_map_test` 之后、`99:` 之前插入新的测试阶段。修改 test_runner.gd：

在 `_process` 的 match 语句中，将：
```gdscript
	14:
		_run_fog_map_test()
		_test_phase = 99
```
改为：
```gdscript
	14:
		_run_fog_map_test()
		_test_phase = 15
	15:
		_run_bug_survivor_data_test()
		_test_phase = 99
```

然后在文件末尾 `_print_summary()` 之前添加测试方法：

```gdscript
## ===== Bug Survivor 数据层测试 =====
func _run_bug_survivor_data_test() -> void:
	_log_section("Bug Survivor 数据层测试")

	# 创建预设
	var preset := BugSurvivorPreset.new()
	preset.preset_id = "test"
	preset.preset_name = "测试预设"
	preset.bug_base_speed = 80.0
	preset.spawn_interval_scale = 1.0
	preset.speed_scale = 1.0

	# 初始化数据层
	var data := BugSurvivorData.new()
	data.setup(preset)

	_assert(data.is_alive, "初始存活")
	_assert(data.elapsed == 0.0, "初始时间 = 0")
	_assert(data.kill_count == 0, "初始击杀 = 0")
	_assert(data.get_survival_rate() == 0.0, "初始存活率 = 0")

	# 推进时间
	var alive: bool = data.advance(10.0)
	_assert(alive, "10秒后仍在进行")
	_assert(is_equal_approx(data.elapsed, 10.0), "elapsed = 10")

	# 记录击杀
	data.record_kill()
	data.record_kill()
	_assert(data.kill_count == 2, "击杀数 = 2")

	# 存活率
	var rate: float = data.get_survival_rate()
	_assert(is_equal_approx(rate, 10.0 / 60.0), "存活率 = 10/60: %.3f" % rate)

	# 推进到30秒 → steady
	data.advance(20.0)
	_assert(data.get_result() == "steady", "30秒 → steady: %s" % data.get_result())

	# 推进到55秒 → risky
	data.advance(25.0)
	_assert(data.get_result() == "risky", "55秒 → risky: %s" % data.get_result())

	# 推进超时 → 游戏结束
	var still_going: bool = data.advance(10.0)
	_assert(not still_going, "超时后游戏结束")
	_assert(is_equal_approx(data.get_survival_rate(), 1.0), "满时间存活率 = 1.0")

	# 玩家死亡测试
	var data2 := BugSurvivorData.new()
	data2.setup(preset)
	data2.advance(15.0)
	data2.player_died()
	_assert(not data2.is_alive, "死亡后 is_alive = false")
	_assert(not data2.advance(1.0), "死亡后不能继续推进")
	_assert(data2.get_result() == "conservative", "15秒死亡 → conservative")

	# 难度曲线测试
	_log_section("Bug Survivor — 难度曲线验证")
	var data3 := BugSurvivorData.new()
	data3.setup(preset)

	# 0秒：生成间隔1.0，速度80
	var si_0: float = data3.get_current_spawn_interval()
	var sp_0: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_0, 1.0), "0秒生成间隔 = 1.0: %.2f" % si_0)
	_assert(is_equal_approx(sp_0, 80.0), "0秒速度 = 80: %.1f" % sp_0)

	# 20秒：生成间隔0.6，速度96
	data3.advance(20.0)
	var si_20: float = data3.get_current_spawn_interval()
	var sp_20: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_20, 0.6), "20秒生成间隔 = 0.6: %.2f" % si_20)
	_assert(is_equal_approx(sp_20, 80.0 * 1.2), "20秒速度 = 96: %.1f" % sp_20)

	# 35秒：生成间隔0.35，速度120
	data3.advance(15.0)
	var si_35: float = data3.get_current_spawn_interval()
	var sp_35: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_35, 0.35), "35秒生成间隔 = 0.35: %.2f" % si_35)
	_assert(is_equal_approx(sp_35, 80.0 * 1.5), "35秒速度 = 120: %.1f" % sp_35)

	# 50秒：生成间隔0.2，速度144
	data3.advance(15.0)
	var si_50: float = data3.get_current_spawn_interval()
	var sp_50: float = data3.get_current_bug_speed()
	_assert(is_equal_approx(si_50, 0.2), "50秒生成间隔 = 0.2: %.2f" % si_50)
	_assert(is_equal_approx(sp_50, 80.0 * 1.8), "50秒速度 = 144: %.1f" % sp_50)

	# 边缘位置生成测试
	_log_section("Bug Survivor — 边缘位置生成")
	var arena: Vector2 = Config.BUG_SURVIVOR_ARENA_SIZE
	for _i: int in range(20):
		var pos: Vector2 = BugSurvivorData.random_edge_position(arena)
		var on_edge: bool = pos.x < 0 or pos.x > arena.x or pos.y < 0 or pos.y > arena.y
		_assert(on_edge, "生成位置在边缘外: (%.0f, %.0f)" % [pos.x, pos.y])

	# 难度缩放测试
	_log_section("Bug Survivor — 难度缩放预设")
	var hard_preset := BugSurvivorPreset.new()
	hard_preset.preset_id = "hard_test"
	hard_preset.bug_base_speed = 100.0
	hard_preset.spawn_interval_scale = 0.7  # 更密
	hard_preset.speed_scale = 1.3           # 更快

	var data4 := BugSurvivorData.new()
	data4.setup(hard_preset)
	var hard_si: float = data4.get_current_spawn_interval()
	var hard_sp: float = data4.get_current_bug_speed()
	_assert(is_equal_approx(hard_si, 1.0 * 0.7), "困难预设生成间隔 = 0.7: %.2f" % hard_si)
	_assert(is_equal_approx(hard_sp, 100.0 * 1.0 * 1.3), "困难预设速度 = 130: %.1f" % hard_sp)
	_log_info("困难预设验证通过: 间隔%.2f, 速度%.1f" % [hard_si, hard_sp])
```

- [ ] **Step 3: 运行测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 4: Commit**

```bash
git add game/scripts/minigame/bug_survivor_data.gd game/tests/test_runner.gd
git commit -m "feat: add BugSurvivorData with tests"
```

---

### Task 4: BugSurvivorGame 游戏层（核心）

**Files:**
- Create: `game/scripts/minigame/bug_survivor_game.gd`
- Create: `game/scenes/minigame/bug_survivor_game.tscn`

- [ ] **Step 1: 创建游戏主控脚本**

```gdscript
# bug_survivor_game.gd — Bug Survivor 小游戏：游戏层
# 职责：玩家移动、子弹发射、虫子生成、碰撞处理、HUD、结算
extends Control

## ===== 信号（与代码急救完全一致）=====
signal game_finished(result: String, survival_rate: float)

## ===== 碰撞层定义 =====
## Layer 1: 玩家
## Layer 2: 子弹
## Layer 3: 虫子

## ===== 颜色 =====
const COLOR_BG: Color = Color("#0a0a1a")
const COLOR_GRID: Color = Color(0.15, 0.15, 0.25)
const COLOR_PLAYER: Color = Color("#4ecca3")
const COLOR_BULLET: Color = Color("#f0e68c")
const COLOR_BUG: Color = Color("#e94560")
const COLOR_HUD: Color = Color(0.85, 0.85, 0.85)

## ===== 节点引用 =====
var _arena: Node2D
var _player: Area2D
var _bullets_container: Node2D
var _bugs_container: Node2D
var _timer_label: Label
var _kill_label: Label
var _result_panel: PanelContainer
var _result_label: Label
var _result_btn: Button
var _arena_bg: ColorRect

## ===== 游戏数据 =====
var _data: BugSurvivorData
var _preset: BugSurvivorPreset
var _is_running: bool = false
var _spawn_timer: float = 0.0
var _shoot_timer: float = 0.0
var _arena_size: Vector2
var _arena_offset: Vector2  ## 竞技场在屏幕中的偏移（居中用）


func _ready() -> void:
	_build_ui()


## ===== 外部调用：初始化并开始 =====
func setup(preset: BugSurvivorPreset, _business_level: int) -> void:
	_preset = preset
	_arena_size = Config.BUG_SURVIVOR_ARENA_SIZE

	# 初始化数据层
	_data = BugSurvivorData.new()
	_data.setup(preset)

	# 计算竞技场居中偏移
	var viewport_size: Vector2 = get_viewport_rect().size
	_arena_offset = (viewport_size - _arena_size) / 2.0
	_arena.position = _arena_offset

	# 设置竞技场背景大小
	_arena_bg.size = _arena_size

	# 玩家初始位置（居中）
	_player.position = _arena_size / 2.0

	# 重置
	_spawn_timer = 0.0
	_shoot_timer = 0.0
	_is_running = true
	_result_panel.visible = false

	# 通知 TimeManager
	TimeManager.start_minigame()
	_update_hud()


func _process(delta: float) -> void:
	if not _is_running:
		return

	# 推进游戏时间
	var still_going: bool = _data.advance(delta)
	if not still_going:
		_end_game()
		return

	# 玩家移动
	_move_player(delta)

	# 子弹发射
	_shoot_timer += delta
	var interval: float = _preset.get_bullet_interval()
	if _shoot_timer >= interval:
		_shoot_timer -= interval
		_shoot_nearest_bug()

	# 虫子生成
	_spawn_timer += delta
	var spawn_iv: float = _data.get_current_spawn_interval()
	if _spawn_timer >= spawn_iv:
		_spawn_timer -= spawn_iv
		_spawn_bug()

	# 移动所有虫子
	_move_bugs(delta)

	# 移动所有子弹
	_move_bullets(delta)

	_update_hud()


## ===== 玩家移动 =====
func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0

	if dir.length_squared() > 0:
		dir = dir.normalized()

	var speed: float = _preset.get_player_speed()
	_player.position += dir * speed * delta

	# Clamp 到竞技场内
	var r: float = Config.BUG_SURVIVOR_PLAYER_RADIUS
	_player.position.x = clampf(_player.position.x, r, _arena_size.x - r)
	_player.position.y = clampf(_player.position.y, r, _arena_size.y - r)


## ===== 子弹发射 =====
func _shoot_nearest_bug() -> void:
	if _bugs_container.get_child_count() == 0:
		return

	# 找最近的虫子
	var nearest: Area2D = null
	var nearest_dist: float = INF
	for child: Node in _bugs_container.get_children():
		var bug: Area2D = child as Area2D
		if bug == null:
			continue
		var dist: float = _player.position.distance_to(bug.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = bug

	if nearest == null:
		return

	# 计算发射方向
	var direction: Vector2 = (_player.position.direction_to(nearest.position)).normalized()

	# 创建子弹
	var bullet := Area2D.new()
	bullet.position = _player.position

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.BUG_SURVIVOR_BULLET_RADIUS
	col_shape.shape = circle
	bullet.add_child(col_shape)

	# 碰撞层：子弹 Layer 2，检测虫子 Layer 3
	bullet.collision_layer = 2
	bullet.collision_mask = 4

	# 占位图：小方块
	var visual := ColorRect.new()
	var bsize: float = Config.BUG_SURVIVOR_BULLET_RADIUS * 2.0
	visual.size = Vector2(bsize, bsize)
	visual.position = Vector2(-bsize / 2.0, -bsize / 2.0)
	visual.color = COLOR_BULLET
	bullet.add_child(visual)

	# 存储方向和速度
	bullet.set_meta("direction", direction)
	bullet.set_meta("speed", Config.BUG_SURVIVOR_BULLET_SPEED)

	# 碰撞回调
	bullet.area_entered.connect(_on_bullet_hit.bind(bullet))

	_bullets_container.add_child(bullet)


## ===== 虫子生成 =====
func _spawn_bug() -> void:
	var bug := Area2D.new()
	bug.position = BugSurvivorData.random_edge_position(_arena_size)

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.BUG_SURVIVOR_BUG_RADIUS
	col_shape.shape = circle
	bug.add_child(col_shape)

	# 碰撞层：虫子 Layer 3，检测玩家 Layer 1 和子弹 Layer 2
	bug.collision_layer = 4
	bug.collision_mask = 3

	# 占位图
	var visual := ColorRect.new()
	var bsize: float = Config.BUG_SURVIVOR_BUG_RADIUS * 2.5
	visual.size = Vector2(bsize, bsize)
	visual.position = Vector2(-bsize / 2.0, -bsize / 2.0)
	visual.color = COLOR_BUG
	bug.add_child(visual)

	var label := Label.new()
	label.text = "BUG"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-12, -8)
	bug.add_child(label)

	_bugs_container.add_child(bug)


## ===== 移动虫子 =====
func _move_bugs(delta: float) -> void:
	var bug_speed: float = _data.get_current_bug_speed()
	var player_pos: Vector2 = _player.position

	for child: Node in _bugs_container.get_children():
		var bug: Area2D = child as Area2D
		if bug == null:
			continue
		var dir: Vector2 = (player_pos - bug.position).normalized()
		bug.position += dir * bug_speed * delta

		# 检测是否碰到玩家（距离检测，作为 area_entered 的补充）
		var dist: float = bug.position.distance_to(player_pos)
		if dist < Config.BUG_SURVIVOR_PLAYER_RADIUS + Config.BUG_SURVIVOR_BUG_RADIUS:
			_on_player_hit()
			return


## ===== 移动子弹 =====
func _move_bullets(delta: float) -> void:
	for child: Node in _bullets_container.get_children():
		var bullet: Area2D = child as Area2D
		if bullet == null:
			continue
		var dir: Vector2 = bullet.get_meta("direction", Vector2.RIGHT) as Vector2
		var spd: float = bullet.get_meta("speed", 400.0) as float
		bullet.position += dir * spd * delta

		# 超出竞技场边界 → 销毁
		var margin: float = 50.0
		if bullet.position.x < -margin or bullet.position.x > _arena_size.x + margin \
			or bullet.position.y < -margin or bullet.position.y > _arena_size.y + margin:
			bullet.queue_free()


## ===== 碰撞回调 =====
func _on_bullet_hit(area: Area2D, bullet: Area2D) -> void:
	# 子弹碰到虫子
	if area.get_parent() == _bugs_container:
		_data.record_kill()
		area.queue_free()
		bullet.queue_free()


func _on_player_hit() -> void:
	if not _is_running:
		return
	_data.player_died()
	_end_game()


## ===== HUD =====
func _update_hud() -> void:
	var remaining: float = _data.game_duration - _data.elapsed
	_timer_label.text = "剩余：%.1f 秒" % maxf(remaining, 0.0)
	_kill_label.text = "击杀：%d" % _data.kill_count

	# 颜色根据时间变化
	if remaining > 30.0:
		_timer_label.add_theme_color_override("font_color", COLOR_PLAYER)
	elif remaining > 15.0:
		_timer_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_timer_label.add_theme_color_override("font_color", COLOR_BUG)


## ===== 游戏结束 =====
func _end_game() -> void:
	_is_running = false
	TimeManager.stop_minigame()

	var survival_rate: float = _data.get_survival_rate()
	var result: String = _data.get_result()

	var result_text: String
	if survival_rate >= 0.9:
		result_text = "【大成功】坚持了 %.1f 秒！\n击杀 %d 只虫子！" % [_data.elapsed, _data.kill_count]
	elif survival_rate >= 0.6:
		result_text = "【一般】坚持了 %.1f 秒\n还可以更好。" % _data.elapsed
	else:
		result_text = "【失败】仅坚持了 %.1f 秒\n虫子入侵了代码库……" % _data.elapsed

	_result_label.text = result_text
	_result_panel.visible = true
	_result_panel.set_meta("result", result)
	_result_panel.set_meta("survival_rate", survival_rate)


func _on_result_confirm() -> void:
	var result: String = _result_panel.get_meta("result", "conservative") as String
	var survival_rate: float = _result_panel.get_meta("survival_rate", 0.0) as float
	game_finished.emit(result, survival_rate)
	queue_free()


## ===== 构建 UI =====
func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 全屏深色背景
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 竞技场容器
	_arena = Node2D.new()
	add_child(_arena)

	# 竞技场背景
	_arena_bg = ColorRect.new()
	_arena_bg.color = Color(0.06, 0.06, 0.12)
	_arena.add_child(_arena_bg)

	# 网格线装饰
	# （后续可用 _draw 画网格，暂用边框表示）

	# 玩家
	_player = Area2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 4  # 检测虫子

	var player_col := CollisionShape2D.new()
	var player_circle := CircleShape2D.new()
	player_circle.radius = Config.BUG_SURVIVOR_PLAYER_RADIUS
	player_col.shape = player_circle
	_player.add_child(player_col)

	# 玩家占位图
	var player_visual := ColorRect.new()
	var psize: float = Config.BUG_SURVIVOR_PLAYER_RADIUS * 2.5
	player_visual.size = Vector2(psize, psize)
	player_visual.position = Vector2(-psize / 2.0, -psize / 2.0)
	player_visual.color = COLOR_PLAYER
	_player.add_child(player_visual)

	var player_label := Label.new()
	player_label.text = "P"
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	player_label.position = Vector2(-6, -12)
	_player.add_child(player_label)

	# 玩家碰撞回调
	_player.area_entered.connect(_on_player_area_entered)

	_arena.add_child(_player)

	# 子弹容器
	_bullets_container = Node2D.new()
	_arena.add_child(_bullets_container)

	# 虫子容器
	_bugs_container = Node2D.new()
	_arena.add_child(_bugs_container)

	# HUD（使用 CanvasLayer 确保在最上层）
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	var hud_hbox := HBoxContainer.new()
	hud_hbox.position = Vector2(20, 10)
	hud_hbox.add_theme_constant_override("separation", 40)
	hud_layer.add_child(hud_hbox)

	_timer_label = Label.new()
	_timer_label.text = "剩余：60.0 秒"
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", COLOR_PLAYER)
	hud_hbox.add_child(_timer_label)

	_kill_label = Label.new()
	_kill_label.text = "击杀：0"
	_kill_label.add_theme_font_size_override("font_size", 22)
	_kill_label.add_theme_color_override("font_color", COLOR_HUD)
	hud_hbox.add_child(_kill_label)

	# 操作提示
	var hint_label := Label.new()
	hint_label.text = "方向键/WASD 移动 | 自动射击"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_label.position = Vector2(20, 42)
	hud_layer.add_child(hint_label)

	# 结果面板
	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(420, 200)

	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	result_style.border_color = COLOR_PLAYER
	result_style.set_border_width_all(2)
	result_style.set_corner_radius_all(8)
	result_style.set_content_margin_all(20)
	_result_panel.add_theme_stylebox_override("panel", result_style)

	var result_vbox := VBoxContainer.new()
	result_vbox.add_theme_constant_override("separation", 16)
	_result_panel.add_child(result_vbox)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.add_theme_color_override("font_color", Color.WHITE)
	result_vbox.add_child(_result_label)

	_result_btn = Button.new()
	_result_btn.text = "确认"
	_result_btn.custom_minimum_size = Vector2(120, 40)
	_result_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_btn.pressed.connect(_on_result_confirm)
	result_vbox.add_child(_result_btn)

	add_child(_result_panel)


func _on_player_area_entered(area: Area2D) -> void:
	# 虫子碰到玩家
	if area.get_parent() == _bugs_container:
		_on_player_hit()
```

- [ ] **Step 2: 创建最小场景 .tscn 文件**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/minigame/bug_survivor_game.gd" id="1"]

[node name="BugSurvivorGame" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: 运行测试确认无编译错误**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 4: Commit**

```bash
git add game/scripts/minigame/bug_survivor_game.gd game/scenes/minigame/bug_survivor_game.tscn
git commit -m "feat: add BugSurvivorGame with player/bullet/bug mechanics"
```

---

### Task 5: EventData 增加 minigame_type 字段

**Files:**
- Modify: `game/scripts/resources/event_data.gd`

- [ ] **Step 1: 在 event_data.gd 的打类事件参数区新增字段**

在 `fight_preset_path` 之后新增一行：

```gdscript
@export var minigame_type: String = "code_rescue"  ## "code_rescue" 或 "bug_survivor"
```

完整上下文（在 `fight_preset_path` 行之后）：

```gdscript
@export var fight_preset_path: String = ""     ## 代码急救预设路径（res://resources/minigame_presets/xxx.tres）
@export var minigame_type: String = "code_rescue"  ## "code_rescue" 或 "bug_survivor"
```

- [ ] **Step 2: 运行测试确认向后兼容（所有现有事件默认 "code_rescue"）**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit**

```bash
git add game/scripts/resources/event_data.gd
git commit -m "feat: add minigame_type field to EventData"
```

---

### Task 6: FightEventPopup 分发逻辑

**Files:**
- Modify: `game/scripts/popups/fight_event_popup.gd`

- [ ] **Step 1: 修改 _on_start_rescue 方法，根据 minigame_type 分发**

将 `_on_start_rescue` 方法替换为：

```gdscript
## ===== 开始小游戏 =====
func _on_start_rescue() -> void:
	if _event == null:
		return

	# 隐藏信息面板
	_info_panel.visible = false

	# 获取商务等级
	var business_level: int = GameManager.run_data.get("resources", {}).get("business", 1) as int

	# 根据 minigame_type 分发
	var minigame_type: String = _event.minigame_type if _event.minigame_type != "" else "code_rescue"

	match minigame_type:
		"bug_survivor":
			_start_bug_survivor(business_level)
		_:
			_start_code_rescue(business_level)


## ===== 启动代码急救小游戏 =====
func _start_code_rescue(business_level: int) -> void:
	# 加载预设
	var preset_res: Resource = load(_event.fight_preset_path)
	if preset_res == null or not (preset_res is CodeRescuePreset):
		push_error("FightEventPopup: 无法加载预设 %s" % _event.fight_preset_path)
		_finish_with_conservative()
		return

	var preset: CodeRescuePreset = preset_res as CodeRescuePreset

	# 创建代码急救小游戏
	var rescue_scene: PackedScene = load("res://scenes/minigame/code_rescue_game.tscn")
	if rescue_scene == null:
		push_error("FightEventPopup: 无法加载代码急救场景")
		_finish_with_conservative()
		return

	_rescue_game = rescue_scene.instantiate()
	add_child(_rescue_game)
	_rescue_game.setup(preset, business_level)
	_rescue_game.game_finished.connect(_on_rescue_finished)


## ===== 启动 Bug Survivor 小游戏 =====
func _start_bug_survivor(business_level: int) -> void:
	# 加载预设
	var preset_res: Resource = load(_event.fight_preset_path)
	if preset_res == null or not (preset_res is BugSurvivorPreset):
		push_error("FightEventPopup: 无法加载 Bug Survivor 预设 %s" % _event.fight_preset_path)
		_finish_with_conservative()
		return

	var preset: BugSurvivorPreset = preset_res as BugSurvivorPreset

	var survivor_scene: PackedScene = load("res://scenes/minigame/bug_survivor_game.tscn")
	if survivor_scene == null:
		push_error("FightEventPopup: 无法加载 Bug Survivor 场景")
		_finish_with_conservative()
		return

	_rescue_game = survivor_scene.instantiate()
	add_child(_rescue_game)
	_rescue_game.setup(preset, business_level)
	_rescue_game.game_finished.connect(_on_rescue_finished)
```

- [ ] **Step 2: 运行测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit**

```bash
git add game/scripts/popups/fight_event_popup.gd
git commit -m "feat: FightEventPopup dispatches by minigame_type"
```

---

### Task 7: 预设 .tres 和事件 .tres 文件

**Files:**
- Create: `game/resources/minigame_presets/bug_swarm.tres`
- Create: `game/resources/minigame_presets/bug_invasion.tres`
- Create: `game/resources/events/fight_survivor_01.tres`
- Create: `game/resources/events/fight_survivor_02.tres`

- [ ] **Step 1: 创建标准难度预设 bug_swarm.tres**

```
[gd_resource type="Resource" script_class="BugSurvivorPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/bug_survivor_preset.gd" id="1"]

[resource]
script = ExtResource("1")
preset_id = "bug_swarm"
preset_name = "虫群爆发"
flavor_text = "服务器日志里突然出现了大量异常——不是普通的bug，是成群结队的虫子！它们正在吞噬你的代码库，赶紧拿起键盘消灭它们！"
bug_base_speed = 80.0
player_speed_override = 0.0
bullet_interval_override = 0.0
game_duration_override = 0.0
spawn_interval_scale = 1.0
speed_scale = 1.0
```

- [ ] **Step 2: 创建困难预设 bug_invasion.tres**

```
[gd_resource type="Resource" script_class="BugSurvivorPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/bug_survivor_preset.gd" id="1"]

[resource]
script = ExtResource("1")
preset_id = "bug_invasion"
preset_name = "虫族入侵"
flavor_text = "紧急警报！一个未知的开源依赖引入了虫族母巢——虫子以双倍速度从四面八方涌来。你的键盘就是最后的防线！"
bug_base_speed = 100.0
player_speed_override = 0.0
bullet_interval_override = 0.0
game_duration_override = 0.0
spawn_interval_scale = 0.7
speed_scale = 1.3
```

- [ ] **Step 3: 创建事件 fight_survivor_01.tres**

```
[gd_resource type="Resource" script_class="EventData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/event_data.gd" id="1"]

[resource]
script = ExtResource("1")
event_id = "fight_survivor_01"
title = "代码库虫群爆发"
description = "你的CI/CD流水线突然全线飘红——不是编译错误，是字面意义上的虫子！成群的bug从未知的依赖库涌出，正在吞噬你的代码。只有一个办法：拿起键盘，手动消灭它们。"
event_type = 1
search_benefit_type = 0
search_benefit_value = 0.0
search_benefit_desc = ""
search_month_cost = 0
fight_preset_path = "res://resources/minigame_presets/bug_swarm.tres"
minigame_type = "bug_survivor"
fight_conservative_desc = "虫子吞噬了代码：品质 -6"
fight_conservative_quality = -6.0
fight_conservative_month_cost = 1
fight_steady_desc = "控制住了局面：消除品质损失"
fight_steady_quality = 0.0
fight_steady_month_cost = 0
fight_risky_desc = "彻底清除并重构：消除损失 + 品质 +3"
fight_risky_quality = 3.0
fight_risky_speed_bonus = 0.0
fight_risky_month_cost = 0
allowed_phases = [&"early", &"mid", &"late"]
is_fixed = false
```

- [ ] **Step 4: 创建事件 fight_survivor_02.tres**

```
[gd_resource type="Resource" script_class="EventData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/event_data.gd" id="1"]

[resource]
script = ExtResource("1")
event_id = "fight_survivor_02"
title = "虫族母巢入侵"
description = "噩梦升级了——那个你一直没空升级的第三方库，原来藏着一个虫族母巢。虫子以惊人的速度繁殖，你的代码库正在沦陷。这次不是debug，是真正的战斗。"
event_type = 1
search_benefit_type = 0
search_benefit_value = 0.0
search_benefit_desc = ""
search_month_cost = 0
fight_preset_path = "res://resources/minigame_presets/bug_invasion.tres"
minigame_type = "bug_survivor"
fight_conservative_desc = "代码库被严重破坏：品质 -8，耽误 2 个月"
fight_conservative_quality = -8.0
fight_conservative_month_cost = 2
fight_steady_desc = "勉强守住了：消除品质损失"
fight_steady_quality = 0.0
fight_steady_month_cost = 0
fight_risky_desc = "英勇歼灭全部虫族：品质 +5，效率永久 +10%"
fight_risky_quality = 5.0
fight_risky_speed_bonus = 0.1
fight_risky_month_cost = 0
allowed_phases = [&"mid", &"late"]
is_fixed = false
```

- [ ] **Step 5: 运行测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 6: Commit**

```bash
git add game/resources/minigame_presets/bug_swarm.tres game/resources/minigame_presets/bug_invasion.tres game/resources/events/fight_survivor_01.tres game/resources/events/fight_survivor_02.tres
git commit -m "feat: add Bug Survivor presets and event data"
```

---

### Task 8: 事件调度器注册新事件

**Files:**
- Modify: `game/scripts/systems/event_scheduler.gd` (if events need manual registration)

- [ ] **Step 1: 检查事件调度器是否自动扫描 events/ 目录**

先读 `game/scripts/systems/event_scheduler.gd`，确认事件加载方式：
- 如果自动扫描 `res://resources/events/` 目录：新的 .tres 文件会自动被发现，无需修改
- 如果硬编码事件路径列表：需要添加新的两个事件路径

根据实际情况修改。

- [ ] **Step 2: 运行测试验证新事件可被调度器识别**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit（如果有修改）**

```bash
git add game/scripts/systems/event_scheduler.gd
git commit -m "feat: register Bug Survivor events in scheduler"
```

---

### Task 9: WASD 输入映射

**Files:**
- Modify: `game/project.godot`

- [ ] **Step 1: 检查是否需要添加 WASD 输入映射**

当前 project.godot 没有自定义 `[input]` 区。Godot 4.x 内置的 `ui_left/right/up/down` 默认只绑定了方向键。需要添加 WASD 绑定。

在 `project.godot` 的 `[rendering]` 之前添加 `[input]` 区：

```ini
[input]

ui_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
ui_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
ui_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
ui_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

注：keycode 4194319=Left, 4194320=Up, 4194321=Right, 4194322=Down; 65=A, 68=D, 87=W, 83=S

- [ ] **Step 2: 运行测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 3: Commit**

```bash
git add game/project.godot
git commit -m "feat: add WASD input mapping for Bug Survivor"
```

---

### Task 10: 端到端验证

**Files:**
- Modify: `game/tests/test_runner.gd` (可选：添加集成测试)

- [ ] **Step 1: 运行完整测试套件**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: `🎉 全部通过！` 且 `❌ 0 失败`

- [ ] **Step 2: 验证新事件能被事件调度器返回**

在测试输出中确认：
- Bug Survivor 数据层测试全部通过
- 事件调度器测试仍然通过
- 无编译错误或运行时报错

- [ ] **Step 3: 最终 commit（如有修复）**

```bash
git add -A
git commit -m "fix: final adjustments for Bug Survivor integration"
```
