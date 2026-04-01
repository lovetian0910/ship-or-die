# 素材归档（记忆翻牌小游戏）实施方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增第三种小游戏"素材归档"（记忆翻牌），4×3网格6对配对，3D翻牌动画，15秒限时，接入现有打类事件系统。

**Architecture:** 遵循现有小游戏的三层架构（Preset Resource → Data 纯逻辑层 → Game 场景脚本），通过 `fight_event_popup.gd` 的 `minigame_type` 分发。新增4个文件 + 修改2个文件 + 2个资源文件。

**Tech Stack:** Godot 4.6.1 + GDScript，headless 测试验证

**测试命令：**
```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1
```

---

## Task 1: Config 常量 + MemoryMatchPreset 预设类

**Files:**
- Modify: `game/scripts/autoload/config.gd`
- Create: `game/scripts/resources/memory_match_preset.gd`

- [ ] **Step 1: 新增 Config 常量**

在 `game/scripts/autoload/config.gd` 末尾（`BUG_SURVIVOR_SPAWN_CURVE` 之后）追加：

```gdscript
## ===== 素材归档小游戏 =====
const MEMORY_MATCH_TIME_LIMIT: float = 15.0      ## 时限（秒）
const MEMORY_MATCH_GRID_ROWS: int = 3             ## 行数
const MEMORY_MATCH_GRID_COLS: int = 4             ## 列数
const MEMORY_MATCH_FLIP_DURATION: float = 0.3     ## 翻牌动画时长（秒）
const MEMORY_MATCH_PEEK_DURATION: float = 0.5     ## 配对失败停留时长（秒）
const MEMORY_MATCH_MONTH_COST: int = 2            ## 小游戏消耗月数
```

- [ ] **Step 2: 创建 MemoryMatchPreset**

创建 `game/scripts/resources/memory_match_preset.gd`：

```gdscript
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
```

- [ ] **Step 3: 运行测试确认无编译错误**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过（新文件不影响现有测试）

- [ ] **Step 4: Commit**

```bash
git add game/scripts/autoload/config.gd game/scripts/resources/memory_match_preset.gd
git commit -m "feat: add MemoryMatchPreset resource class and Config constants"
```

---

## Task 2: MemoryMatchData 数据层（纯逻辑，可独立测试）

**Files:**
- Create: `game/scripts/minigame/memory_match_data.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: 新增测试用例**

在 `game/tests/test_runner.gd` 中，找到测试调度列表（`_run_xxx_test` 的调用序列），在最后一个测试调用之后追加：

```gdscript
	_run_memory_match_data_test()
```

在文件末尾（最后一个测试函数之后）新增测试函数：

```gdscript
## ===== 素材归档数据层测试 =====
func _run_memory_match_data_test() -> void:
	_log_section("素材归档（记忆翻牌）数据层测试")

	# 创建预设
	var preset := MemoryMatchPreset.new()
	preset.preset_id = "test"
	preset.preset_name = "测试预设"
	preset.grid_rows = 3
	preset.grid_cols = 4
	preset.time_limit = 15.0
	preset.flip_duration = 0.3
	preset.peek_duration = 0.5

	# 初始化
	var data := MemoryMatchData.new()
	data.setup(preset)
	_assert(data.total_pairs == 6, "总对数=6: %d" % data.total_pairs)
	_assert(data.matched_pairs == 0, "初始配对=0")
	_assert(not data.is_finished, "初始未结束")
	_assert(data.get_completion_rate() == 0.0, "初始完成率=0")

	# 网格验证：12格，6种ID各出现2次
	var id_counts: Dictionary = {}
	for row: int in range(3):
		for col: int in range(4):
			var card_id: int = data.grid[row][col]
			_assert(card_id >= 0 and card_id < 6, "卡牌ID合法: %d" % card_id)
			var cur: int = id_counts.get(card_id, 0) as int
			id_counts[card_id] = cur + 1
	for id: int in range(6):
		_assert(id_counts.get(id, 0) as int == 2, "ID %d 出现2次: %d" % [id, id_counts.get(id, 0) as int])

	# 翻牌测试：翻第一张
	var r1: MemoryMatchData.PickResult = data.pick_card(0, 0)
	_assert(r1 == MemoryMatchData.PickResult.FIRST_REVEALED, "第一张翻开: %d" % r1)
	_assert(data.revealed[0][0] == true, "第一张已翻开")

	# 找一个配对的位置
	var first_id: int = data.grid[0][0]
	var match_pos: Vector2i = Vector2i(-1, -1)
	for row: int in range(3):
		for col: int in range(4):
			if Vector2i(row, col) != Vector2i(0, 0) and data.grid[row][col] == first_id:
				match_pos = Vector2i(row, col)
				break
		if match_pos != Vector2i(-1, -1):
			break

	# 翻第二张（配对成功）
	var r2: MemoryMatchData.PickResult = data.pick_card(match_pos.x, match_pos.y)
	_assert(r2 == MemoryMatchData.PickResult.MATCH_SUCCESS, "配对成功: %d" % r2)
	_assert(data.matched[0][0] == true, "第一张已消除")
	_assert(data.matched[match_pos.x][match_pos.y] == true, "第二张已消除")
	_assert(data.matched_pairs == 1, "配对数=1")

	# 无效操作：点击已消除的牌
	var r3: MemoryMatchData.PickResult = data.pick_card(0, 0)
	_assert(r3 == MemoryMatchData.PickResult.INVALID, "已消除牌不可点击")

	# 配对失败测试：找两张不同的未消除牌
	var pos_a: Vector2i = Vector2i(-1, -1)
	var pos_b: Vector2i = Vector2i(-1, -1)
	for row: int in range(3):
		for col: int in range(4):
			if not data.matched[row][col]:
				if pos_a == Vector2i(-1, -1):
					pos_a = Vector2i(row, col)
				elif data.grid[row][col] != data.grid[pos_a.x][pos_a.y] and pos_b == Vector2i(-1, -1):
					pos_b = Vector2i(row, col)
		if pos_b != Vector2i(-1, -1):
			break

	if pos_a != Vector2i(-1, -1) and pos_b != Vector2i(-1, -1):
		var r4: MemoryMatchData.PickResult = data.pick_card(pos_a.x, pos_a.y)
		_assert(r4 == MemoryMatchData.PickResult.FIRST_REVEALED, "翻开A")
		var r5: MemoryMatchData.PickResult = data.pick_card(pos_b.x, pos_b.y)
		_assert(r5 == MemoryMatchData.PickResult.MATCH_FAIL, "配对失败: %d" % r5)
		# 失败后两张牌翻回
		_assert(data.revealed[pos_a.x][pos_a.y] == false, "失败后A翻回")
		_assert(data.revealed[pos_b.x][pos_b.y] == false, "失败后B翻回")

	# 时间耗尽测试
	var data2 := MemoryMatchData.new()
	data2.setup(preset)
	data2.advance_time(16.0)
	_assert(data2.is_finished, "时间耗尽后结束")
	_assert(data2.get_result_tier() == "conservative", "0配对=conservative: %s" % data2.get_result_tier())

	# 结果等级验证
	var data3 := MemoryMatchData.new()
	data3.setup(preset)
	# 手动设置配对数来验证等级
	data3.matched_pairs = 6
	_assert(data3.get_completion_rate() == 1.0, "6/6=1.0")
	_assert(data3.get_result_tier() == "risky", "6/6=risky")
	data3.matched_pairs = 4
	_assert(data3.get_result_tier() == "steady", "4/6=steady: %s" % data3.get_result_tier())
	data3.matched_pairs = 2
	_assert(data3.get_result_tier() == "conservative", "2/6=conservative: %s" % data3.get_result_tier())
```

- [ ] **Step 2: 运行测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 编译错误（MemoryMatchData 不存在）

- [ ] **Step 3: 实现 MemoryMatchData**

创建 `game/scripts/minigame/memory_match_data.gd`：

```gdscript
# memory_match_data.gd — 素材归档小游戏：纯数据层
# 负责：网格生成、翻牌判定、配对逻辑、结算
# 零UI依赖，完全可测试
class_name MemoryMatchData
extends RefCounted

## 翻牌操作结果
enum PickResult { FIRST_REVEALED, MATCH_SUCCESS, MATCH_FAIL, INVALID }

var preset: MemoryMatchPreset
var grid: Array = []             ## [row][col] = int（素材ID，0 ~ total_pairs-1）
var revealed: Array = []         ## [row][col] = bool（是否翻开）
var matched: Array = []          ## [row][col] = bool（是否已配对消除）
var first_pick: Vector2i = Vector2i(-1, -1)  ## 第一张翻开的位置
var matched_pairs: int = 0
var total_pairs: int = 0
var elapsed: float = 0.0
var time_limit: float = 15.0
var is_finished: bool = false


func setup(p_preset: MemoryMatchPreset) -> void:
	preset = p_preset
	var rows: int = p_preset.grid_rows
	var cols: int = p_preset.grid_cols
	total_pairs = (rows * cols) / 2
	time_limit = p_preset.get_time_limit()
	matched_pairs = 0
	elapsed = 0.0
	is_finished = false
	first_pick = Vector2i(-1, -1)

	# 生成配对数组并洗牌
	var cards: Array[int] = []
	for i: int in range(total_pairs):
		cards.append(i)
		cards.append(i)
	cards.shuffle()

	# 填入网格
	grid.resize(rows)
	revealed.resize(rows)
	matched.resize(rows)
	var idx: int = 0
	for row: int in range(rows):
		var grid_row: Array[int] = []
		var revealed_row: Array[bool] = []
		var matched_row: Array[bool] = []
		grid_row.resize(cols)
		revealed_row.resize(cols)
		matched_row.resize(cols)
		for col: int in range(cols):
			grid_row[col] = cards[idx]
			revealed_row[col] = false
			matched_row[col] = false
			idx += 1
		grid[row] = grid_row
		revealed[row] = revealed_row
		matched[row] = matched_row


## 翻牌操作
func pick_card(row: int, col: int) -> PickResult:
	if is_finished:
		return PickResult.INVALID
	# 不能点已消除或已翻开的牌
	if matched[row][col] or revealed[row][col]:
		return PickResult.INVALID

	if first_pick == Vector2i(-1, -1):
		# 翻第一张
		first_pick = Vector2i(row, col)
		revealed[row][col] = true
		return PickResult.FIRST_REVEALED
	else:
		# 翻第二张
		revealed[row][col] = true
		var first_id: int = grid[first_pick.x][first_pick.y]
		var second_id: int = grid[row][col]

		if first_id == second_id:
			# 配对成功
			matched[first_pick.x][first_pick.y] = true
			matched[row][col] = true
			matched_pairs += 1
			first_pick = Vector2i(-1, -1)
			# 检查是否全部配对
			if matched_pairs >= total_pairs:
				is_finished = true
			return PickResult.MATCH_SUCCESS
		else:
			# 配对失败：翻回去
			revealed[first_pick.x][first_pick.y] = false
			revealed[row][col] = false
			first_pick = Vector2i(-1, -1)
			return PickResult.MATCH_FAIL


## 推进时间
func advance_time(delta: float) -> void:
	if is_finished:
		return
	elapsed += delta
	if elapsed >= time_limit:
		elapsed = time_limit
		is_finished = true


## 完成率
func get_completion_rate() -> float:
	if total_pairs <= 0:
		return 0.0
	return float(matched_pairs) / float(total_pairs)


## 结果等级
func get_result_tier() -> String:
	var rate: float = get_completion_rate()
	if rate >= 0.9:
		return "risky"
	elif rate >= 0.6:
		return "steady"
	else:
		return "conservative"
```

- [ ] **Step 4: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add game/scripts/minigame/memory_match_data.gd game/tests/test_runner.gd
git commit -m "feat: add MemoryMatchData with grid generation, card matching logic, and tests"
```

---

## Task 3: MemoryMatchGame 场景脚本（UI + 翻牌动画）

**Files:**
- Create: `game/scripts/minigame/memory_match_game.gd`
- Create: `game/scenes/minigame/memory_match_game.tscn`

- [ ] **Step 1: 创建游戏场景脚本**

创建 `game/scripts/minigame/memory_match_game.gd`：

```gdscript
# memory_match_game.gd — 素材归档小游戏：场景脚本
# 4×3 翻牌配对，3D翻转动画，15秒限时
extends Control

signal game_finished(result: String, survival_rate: float)

var _data: MemoryMatchData = null
var _preset: MemoryMatchPreset = null
var _card_nodes: Array = []        ## [row][col] = Button
var _card_icons: Array = []        ## [row][col] = Control（正面内容节点）
var _card_backs: Array = []        ## [row][col] = Control（背面内容节点）
var _asset_keys: Array = []        ## 素材key列表，索引对应 data.grid 中的ID
var _time_label: Label = null
var _pairs_label: Label = null
var _grid_container: GridContainer = null
var _animating: bool = false       ## 动画锁
var _peek_pair: Array = []         ## 配对失败时暂存的两个位置 [Vector2i, Vector2i]

## 素材池：category + key 组合
const ICON_POOL: Array = [
	["icon", "icon_money"],
	["icon", "icon_warning"],
	["icon", "icon_success"],
	["icon", "icon_search"],
	["icon", "icon_treasure"],
	["icon", "icon_launch"],
	["icon", "icon_polish"],
	["icon", "icon_time"],
	["icon", "icon_gamepad"],
	["icon", "icon_team"],
	["icon", "icon_mystery"],
]

const PORTRAIT_POOL: Array = [
	["portrait", "creator_low"],
	["portrait", "creator_mid"],
	["portrait", "creator_high"],
	["portrait", "outsource_low"],
	["portrait", "outsource_mid"],
	["portrait", "outsource_high"],
	["portrait", "business_low"],
	["portrait", "business_mid"],
	["portrait", "business_high"],
]


func setup(preset: MemoryMatchPreset, _business_level: int) -> void:
	_preset = preset
	_data = MemoryMatchData.new()
	_data.setup(preset)

	# 从混合池随机选6个素材
	var full_pool: Array = ICON_POOL.duplicate()
	full_pool.append_array(PORTRAIT_POOL)
	full_pool.shuffle()
	_asset_keys.clear()
	for i: int in range(_data.total_pairs):
		_asset_keys.append(full_pool[i])

	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 顶部 HUD
	var hud := HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	hud.offset_top = 20
	hud.offset_left = 40
	hud.offset_right = -40
	hud.offset_bottom = 60
	hud.add_theme_constant_override("separation", 40)
	add_child(hud)

	_time_label = Label.new()
	_time_label.text = "剩余：15.0s"
	_time_label.add_theme_font_size_override("font_size", 22)
	_time_label.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(_time_label)

	_pairs_label = Label.new()
	_pairs_label.text = "配对：0/6"
	_pairs_label.add_theme_font_size_override("font_size", 22)
	_pairs_label.add_theme_color_override("font_color", Color("#4ecca3"))
	hud.add_child(_pairs_label)

	var title := Label.new()
	title.text = "素材归档"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0a030"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(title)

	# 卡牌网格
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.offset_top = 70
	add_child(center)

	_grid_container = GridContainer.new()
	_grid_container.columns = _preset.grid_cols
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	center.add_child(_grid_container)

	# 创建卡牌
	var rows: int = _preset.grid_rows
	var cols: int = _preset.grid_cols
	_card_nodes.resize(rows)
	_card_icons.resize(rows)
	_card_backs.resize(rows)

	for row: int in range(rows):
		var node_row: Array = []
		var icon_row: Array = []
		var back_row: Array = []
		node_row.resize(cols)
		icon_row.resize(cols)
		back_row.resize(cols)

		for col: int in range(cols):
			var card := Button.new()
			card.custom_minimum_size = Vector2(90, 110)
			card.clip_contents = true
			card.pressed.connect(_on_card_pressed.bind(row, col))

			# 卡牌样式
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.25, 0.30)
			style.set_corner_radius_all(8)
			style.set_content_margin_all(4)
			card.add_theme_stylebox_override("normal", style)

			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.30, 0.30, 0.38)
			hover.set_corner_radius_all(8)
			hover.set_content_margin_all(4)
			card.add_theme_stylebox_override("hover", hover)

			var pressed_style := StyleBoxFlat.new()
			pressed_style.bg_color = Color(0.35, 0.35, 0.42)
			pressed_style.set_corner_radius_all(8)
			pressed_style.set_content_margin_all(4)
			card.add_theme_stylebox_override("pressed", pressed_style)

			var disabled_style := StyleBoxFlat.new()
			disabled_style.bg_color = Color(0.2, 0.6, 0.2, 0.3)
			disabled_style.set_corner_radius_all(8)
			disabled_style.set_content_margin_all(4)
			card.add_theme_stylebox_override("disabled", disabled_style)

			# 背面内容（?）
			var back_label := Label.new()
			back_label.text = "?"
			back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			back_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			back_label.add_theme_font_size_override("font_size", 32)
			back_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			card.add_child(back_label)

			# 正面内容（素材图标）
			var card_id: int = _data.grid[row][col]
			var asset_info: Array = _asset_keys[card_id]
			var category: String = asset_info[0] as String
			var key: String = asset_info[1] as String
			var icon_node: Control = _create_card_face(category, key)
			icon_node.visible = false
			card.add_child(icon_node)

			_grid_container.add_child(card)
			node_row[col] = card
			icon_row[col] = icon_node
			back_row[col] = back_label

		_card_nodes[row] = node_row
		_card_icons[row] = icon_row
		_card_backs[row] = back_row


## 创建卡牌正面显示内容
func _create_card_face(category: String, key: String) -> Control:
	var container := CenterContainer.new()
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 尝试加载图片
	var tex: Texture2D = null
	if category == "icon":
		# icon 类从 ICON_DIR 加载
		var path: String = AssetRegistry.ICON_DIR + key + ".png"
		if ResourceLoader.exists(path) and DisplayServer.get_name() != "headless":
			tex = load(path) as Texture2D
	elif category == "portrait":
		tex = AssetRegistry.get_texture("portrait", key)

	if tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(tex_rect)
	else:
		# 占位：色块 + 文字
		var fallback := Label.new()
		fallback.text = key.substr(0, 3).to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 16)
		fallback.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(fallback)

	return container


func _process(delta: float) -> void:
	if _data == null or _data.is_finished:
		return
	_data.advance_time(delta)
	_update_hud()
	if _data.is_finished:
		_finish_game()


func _update_hud() -> void:
	var remaining: float = maxf(_data.time_limit - _data.elapsed, 0.0)
	_time_label.text = "剩余：%.1fs" % remaining
	if remaining <= 5.0:
		_time_label.add_theme_color_override("font_color", Color.RED)
	_pairs_label.text = "配对：%d/%d" % [_data.matched_pairs, _data.total_pairs]


func _on_card_pressed(row: int, col: int) -> void:
	if _animating or _data == null or _data.is_finished:
		return

	var result: MemoryMatchData.PickResult = _data.pick_card(row, col)

	match result:
		MemoryMatchData.PickResult.FIRST_REVEALED:
			_animating = true
			_flip_to_front(row, col, func() -> void:
				_animating = false
			)
		MemoryMatchData.PickResult.MATCH_SUCCESS:
			_animating = true
			var first: Vector2i = Vector2i(-1, -1)
			# 找到另一张配对的牌（刚才翻开的）
			for r: int in range(_preset.grid_rows):
				for c: int in range(_preset.grid_cols):
					if _data.matched[r][c] and Vector2i(r, c) != Vector2i(row, col):
						if _card_nodes[r][c].disabled == false:
							first = Vector2i(r, c)
			_flip_to_front(row, col, func() -> void:
				# 配对成功：两张牌消除
				_match_success_anim(first, Vector2i(row, col))
			)
		MemoryMatchData.PickResult.MATCH_FAIL:
			_animating = true
			# 找到第一张翻开的位置（刚被翻回的）
			# data已经翻回了，但我们需要知道它在哪
			# 用_peek_pair暂存
			_peek_pair = []
			for r: int in range(_preset.grid_rows):
				for c: int in range(_preset.grid_cols):
					if not _data.matched[r][c] and (_card_icons[r][c] as Control).visible:
						_peek_pair.append(Vector2i(r, c))
			_peek_pair.append(Vector2i(row, col))
			_flip_to_front(row, col, func() -> void:
				# 停留一下让玩家记住
				var timer: SceneTreeTimer = get_tree().create_timer(_preset.peek_duration)
				timer.timeout.connect(_flip_back_pair)
			)
		MemoryMatchData.PickResult.INVALID:
			pass


## 翻到正面动画（scale.x 压缩→换内容→展开）
func _flip_to_front(row: int, col: int, on_complete: Callable) -> void:
	var card: Button = _card_nodes[row][col]
	var icon: Control = _card_icons[row][col]
	var back: Control = _card_backs[row][col]
	var duration: float = _preset.flip_duration * 0.5

	if DisplayServer.get_name() == "headless":
		back.visible = false
		icon.visible = true
		on_complete.call()
		return

	card.pivot_offset = card.size / 2.0
	var tween: Tween = create_tween()
	# 压缩
	tween.tween_property(card, "scale:x", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	# 换内容
	tween.tween_callback(func() -> void:
		back.visible = false
		icon.visible = true
	)
	# 展开
	tween.tween_property(card, "scale:x", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(on_complete)


## 翻回背面动画
func _flip_to_back(row: int, col: int, on_complete: Callable) -> void:
	var card: Button = _card_nodes[row][col]
	var icon: Control = _card_icons[row][col]
	var back: Control = _card_backs[row][col]
	var duration: float = _preset.flip_duration * 0.5

	if DisplayServer.get_name() == "headless":
		icon.visible = false
		back.visible = true
		on_complete.call()
		return

	card.pivot_offset = card.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		icon.visible = false
		back.visible = true
	)
	tween.tween_property(card, "scale:x", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(on_complete)


## 配对失败：翻回两张牌
func _flip_back_pair() -> void:
	if _peek_pair.size() < 2:
		_animating = false
		return
	var pos_a: Vector2i = _peek_pair[0] as Vector2i
	var pos_b: Vector2i = _peek_pair[1] as Vector2i
	_peek_pair.clear()

	# 闪红
	_flash_card(pos_a, Color.RED, 0.15)
	_flash_card(pos_b, Color.RED, 0.15)

	# 翻回两张
	var done_count: int = 0
	var check_done: Callable = func() -> void:
		done_count += 1
		if done_count >= 2:
			_animating = false
	_flip_to_back(pos_a.x, pos_a.y, check_done)
	_flip_to_back(pos_b.x, pos_b.y, check_done)


## 配对成功动画：闪绿 + 缩小消失
func _match_success_anim(pos_a: Vector2i, pos_b: Vector2i) -> void:
	_flash_card(pos_a, Color.GREEN, 0.2)
	_flash_card(pos_b, Color.GREEN, 0.2)

	if DisplayServer.get_name() == "headless":
		(_card_nodes[pos_a.x][pos_a.y] as Button).disabled = true
		(_card_nodes[pos_b.x][pos_b.y] as Button).disabled = true
		_animating = false
		if _data.is_finished:
			_finish_game()
		return

	var done_count: int = 0
	var check_done: Callable = func() -> void:
		done_count += 1
		if done_count >= 2:
			_animating = false
			if _data.is_finished:
				_finish_game()

	for pos: Vector2i in [pos_a, pos_b]:
		var card: Button = _card_nodes[pos.x][pos.y]
		card.pivot_offset = card.size / 2.0
		var tween: Tween = create_tween()
		tween.tween_interval(0.2)
		tween.tween_property(card, "scale", Vector2.ZERO, 0.3) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(func() -> void:
			card.disabled = true
			card.modulate.a = 0.0
			check_done.call()
		)


## 闪色效果
func _flash_card(pos: Vector2i, color: Color, duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var card: Button = _card_nodes[pos.x][pos.y]
	var original: Color = card.modulate
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate", color, duration * 0.5)
	tween.tween_property(card, "modulate", original, duration * 0.5)


## 游戏结束
func _finish_game() -> void:
	var result: String = _data.get_result_tier()
	var rate: float = _data.get_completion_rate()
	game_finished.emit(result, rate)
```

- [ ] **Step 2: 创建场景文件**

创建 `game/scenes/minigame/memory_match_game.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/minigame/memory_match_game.gd" id="1"]

[node name="MemoryMatchGame" type="Control"]
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
Expected: 全部通过

- [ ] **Step 4: Commit**

```bash
git add game/scripts/minigame/memory_match_game.gd game/scenes/minigame/memory_match_game.tscn
git commit -m "feat: add MemoryMatchGame scene with 3D flip animation and card matching UI"
```

---

## Task 4: 事件资源 + 预设文件 + fight_event_popup 接入

**Files:**
- Create: `game/resources/minigame_presets/memory_standard.tres`
- Create: `game/resources/events/fight_memory_01.tres`
- Modify: `game/scripts/popups/fight_event_popup.gd`
- Modify: `game/scripts/scenes/dev_running.gd`

- [ ] **Step 1: 创建预设资源**

创建 `game/resources/minigame_presets/memory_standard.tres`：

```
[gd_resource type="Resource" script_class="MemoryMatchPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/memory_match_preset.gd" id="1"]

[resource]
script = ExtResource("1")
preset_id = "memory_standard"
preset_name = "素材归档"
flavor_text = "美术素材库索引损坏，大量文件名丢失！紧急配对归档，找回越多越好。"
grid_rows = 3
grid_cols = 4
time_limit = 15.0
flip_duration = 0.3
peek_duration = 0.5
```

- [ ] **Step 2: 创建事件资源**

创建 `game/resources/events/fight_memory_01.tres`：

```
[gd_resource type="Resource" script_class="EventData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/event_data.gd" id="1"]

[resource]
script = ExtResource("1")
event_id = "fight_memory_01"
title = "素材库崩溃"
description = "美术素材库索引损坏，大量文件名丢失！紧急配对归档，找回越多越好。"
event_type = 1
search_benefit_type = 0
search_benefit_value = 0.0
search_benefit_desc = ""
search_month_cost = 0
fight_preset_path = "res://resources/minigame_presets/memory_standard.tres"
minigame_type = "memory_match"
fight_conservative_desc = "大量素材丢失，美术返工严重：品质 -5"
fight_conservative_quality = -5.0
fight_conservative_month_cost = 1
fight_steady_desc = "抢救了大部分素材，损失可控"
fight_steady_quality = 0.0
fight_steady_month_cost = 0
fight_risky_desc = "素材全部归档！研发效率不降反升：品质 +3"
fight_risky_quality = 3.0
fight_risky_speed_bonus = 0.0
fight_risky_month_cost = 0
allowed_phases = [&"early", &"mid", &"late"]
is_fixed = false
```

- [ ] **Step 3: 修改 fight_event_popup.gd — 新增 memory_match 分支**

在 `game/scripts/popups/fight_event_popup.gd` 的 `_on_start_rescue()` 方法（line 60-64），修改 match 语句：

将：
```gdscript
	match minigame_type:
		"bug_survivor":
			_start_bug_survivor(business_level)
		_:
			_start_code_rescue(business_level)
```
改为：
```gdscript
	match minigame_type:
		"bug_survivor":
			_start_bug_survivor(business_level)
		"memory_match":
			_start_memory_match(business_level)
		_:
			_start_code_rescue(business_level)
```

在 `_start_bug_survivor()` 方法之后新增：

```gdscript
## ===== 启动素材归档小游戏 =====
func _start_memory_match(business_level: int) -> void:
	var preset_res: Resource = load(_event.fight_preset_path)
	if preset_res == null or not (preset_res is MemoryMatchPreset):
		push_error("FightEventPopup: 无法加载素材归档预设 %s" % _event.fight_preset_path)
		_finish_with_conservative()
		return

	var preset: MemoryMatchPreset = preset_res as MemoryMatchPreset

	var match_scene: PackedScene = load("res://scenes/minigame/memory_match_game.tscn")
	if match_scene == null:
		push_error("FightEventPopup: 无法加载素材归档场景")
		_finish_with_conservative()
		return

	_rescue_game = match_scene.instantiate()
	add_child(_rescue_game)
	_rescue_game.setup(preset, business_level)
	_rescue_game.game_finished.connect(_on_rescue_finished)
```

- [ ] **Step 4: 修改 dev_running.gd — 将记忆翻牌事件加入 FALLBACK 列表**

在 `game/scripts/scenes/dev_running.gd` 中，找到 `FALLBACK_FIGHT_EVENTS` 常量，在数组末尾追加：

```gdscript
	"res://resources/events/fight_memory_01.tres",
```

- [ ] **Step 5: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 6: Commit**

```bash
git add game/resources/minigame_presets/memory_standard.tres game/resources/events/fight_memory_01.tres game/scripts/popups/fight_event_popup.gd game/scripts/scenes/dev_running.gd
git commit -m "feat: integrate memory match minigame into fight event system"
```

---

## Task 5: 最终验证

**Files:**
- Review: all modified files

- [ ] **Step 1: 运行完整 headless 测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 🎉 全部通过！❌ 0 失败

- [ ] **Step 2: 检查新文件是否都被正确引用**

```bash
grep -r "memory_match" game/scripts/ game/resources/ game/scenes/
```

Expected: 匹配到 config.gd、memory_match_preset.gd、memory_match_data.gd、memory_match_game.gd、memory_match_game.tscn、fight_event_popup.gd、dev_running.gd、memory_standard.tres、fight_memory_01.tres、test_runner.gd

- [ ] **Step 3: 验证小游戏类型不重复测试仍然通过**

确认 test_runner.gd 中"小游戏类型不连续重复测试"段落仍然能处理三种类型（code_rescue、bug_survivor、memory_match）。如果测试逻辑只检查两种类型，需要更新。

- [ ] **Step 4: Commit（如有清理）**

```bash
git add -A
git commit -m "chore: final verification for memory match minigame integration"
```
