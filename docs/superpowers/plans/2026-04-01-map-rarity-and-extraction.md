# 迷雾地图改造：稀有度简化 + 撤离点机制 — 实施方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将迷雾地图从"5档光晕+随时上线+10格刷新"改为"2档光晕+撤离点连通才能上线"。

**Architecture:** 改动集中在4个文件：Config（新增常量、删除旧常量）→ FogMapGenerator（EXIT从3个改为1个+开局可见）→ MapCell（光晕逻辑简化+揭示动画强化）→ DevRunning（删除10格刷新、新增BFS连通判定+撤离点弹窗+上线按钮锁定）。FogMap 数据层新增 `exit_pos` 字段和 `check_path_connected()` 方法。

**Tech Stack:** Godot 4.6.1 + GDScript，headless 测试验证

**测试命令：**
```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1
```

---

## Task 1: Config 常量更新

**Files:**
- Modify: `game/scripts/autoload/config.gd:108-147`

- [ ] **Step 1: 更新测试用例 — 新增 Config 常量断言**

在 `game/tests/test_runner.gd` 的 autoload 测试段（约 line 50-80 附近）新增断言：

```gdscript
# 迷雾地图新常量
_assert(Config.MAP_EXIT_COUNT == 1, "MAP_EXIT_COUNT=1")
_assert(Config.MAP_EXIT_ALWAYS_VISIBLE == true, "MAP_EXIT_ALWAYS_VISIBLE=true")
_assert(Config.MAP_GLOW_ALPHA > 0.0, "MAP_GLOW_ALPHA>0")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 编译错误（常量不存在）

- [ ] **Step 3: 修改 Config.gd — 新增常量、删除旧常量**

在 `game/scripts/autoload/config.gd` 的迷雾地图区域做以下修改：

```gdscript
## ===== 迷雾地图探索系统 =====
const MAP_SIZE: int = 8                         ## 地图尺寸 8×8
const MAP_GUARANTEED_FIGHT_CELL: int = 5        ## 第N格必定触发小游戏（保底机制）

## 撤离点
const MAP_EXIT_COUNT: int = 1                   ## 撤离点固定1个
const MAP_EXIT_MIN_DISTANCE: int = 5            ## 撤离点距起点最小曼哈顿距离
const MAP_EXIT_ALWAYS_VISIBLE: bool = true      ## 撤离点开局即可见
const MAP_EXIT_BORDER_COLOR: Color = Color(1.0, 0.6, 0.2) ## 撤离点橙色边框

## 稀有度光晕（2档制：暗格/亮格）
const MAP_GLOW_COLOR: Color = Color(0.9, 0.85, 0.7)  ## 亮格统一光晕颜色（暖白）
const MAP_GLOW_ALPHA: float = 0.20                     ## 亮格光晕透明度
const MAP_GLOW_RARITY_THRESHOLD: int = 2               ## 稀有度≥RARE(2)显示光晕

## 传说级揭示特效
const LEGENDARY_REVEAL_SCALE: float = 1.15      ## 传说揭示脉冲缩放
const LEGENDARY_REVEAL_DURATION: float = 0.3    ## 传说揭示脉冲时长（秒）

## 强制上线品质惩罚（时间耗尽未连通撤离点 = 失败，此项不再使用）
## 已删除: MAP_LAUNCH_PROMPT_INTERVAL
```

同时删除：
- `const MAP_LAUNCH_PROMPT_INTERVAL: int = 10` （line 131）
- `MAP_CELL_RATIOS` 字典中的 `"exit": 0.05` 行（line 139）

保留 `MAP_WALL_MAX`、`MAP_CELL_RATIOS`（去掉exit后）、空地品质、宝箱收益等不变。

- [ ] **Step 4: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过（新断言 PASS）

- [ ] **Step 5: Commit**

```bash
git add game/scripts/autoload/config.gd game/tests/test_runner.gd
git commit -m "feat(config): add extraction point and 2-tier glow constants, remove 10-cell refresh"
```

---

## Task 2: FogMap 数据层 — 新增 exit_pos + 连通判定

**Files:**
- Modify: `game/scripts/systems/fog_map.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: 新增测试用例 — exit_pos 和 check_path_connected**

在 `_run_fog_map_test()` 函数末尾（line 926 之前）追加：

```gdscript
# 撤离点位置记录
_log_section("迷雾地图 — 撤离点连通判定")
var path_map: FogMap = FogMapGenerator.generate(42)
_assert(path_map.exit_pos != Vector2i(-1, -1), "撤离点位置已记录: %s" % str(path_map.exit_pos))
_assert(FogMap.manhattan_distance(path_map.start_pos, path_map.exit_pos) >= Config.MAP_EXIT_MIN_DISTANCE,
	"撤离点距起点≥%d" % Config.MAP_EXIT_MIN_DISTANCE)

# 初始状态：未连通
_assert(not path_map.check_path_connected(), "初始状态未连通")

# 模拟从起点到撤离点的路径揭开
var path_to_exit: Array[Vector2i] = path_map.find_shortest_path(path_map.start_pos, path_map.exit_pos)
_assert(path_to_exit.size() > 0, "存在从起点到撤离点的路径: %d步" % path_to_exit.size())

# 逐格揭开路径
for pos: Vector2i in path_to_exit:
	if path_map.get_cell_state(pos.x, pos.y) == FogMap.CellState.FOGGY:
		path_map.reveal_cell(pos.x, pos.y)
	elif path_map.get_cell_state(pos.x, pos.y) == FogMap.CellState.HIDDEN:
		# 先让它变成FOGGY再揭开（模拟正常游玩）
		path_map.states[pos.x][pos.y] = FogMap.CellState.FOGGY
		path_map.reveal_cell(pos.x, pos.y)

# 揭开路径后应连通
_assert(path_map.check_path_connected(), "揭开路径后已连通")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 编译错误（`exit_pos`、`check_path_connected`、`find_shortest_path` 不存在）

- [ ] **Step 3: 实现 FogMap 新功能**

在 `game/scripts/systems/fog_map.gd` 中新增以下内容：

在成员变量区域（line 25 之后）新增：
```gdscript
var exit_pos: Vector2i = Vector2i(-1, -1)      ## 撤离点位置
```

在 `_in_bounds()` 之前新增以下方法：

```gdscript
## 检查起点到撤离点是否通过 REVEALED 格子连通
## 连通条件：撤离点的某个邻格为 REVEALED（不要求撤离点本身 REVEALED）
func check_path_connected() -> bool:
	if exit_pos == Vector2i(-1, -1):
		return false
	# 检查撤离点是否有已揭示的邻居
	var exit_has_revealed_neighbor: bool = false
	for n: Vector2i in get_neighbors(exit_pos.x, exit_pos.y):
		if states[n.x][n.y] == CellState.REVEALED:
			exit_has_revealed_neighbor = true
			break
	if not exit_has_revealed_neighbor:
		return false
	# BFS：从起点出发，只走 REVEALED 格子，看能否到达撤离点的邻格
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		# 检查是否到达撤离点邻格
		for n: Vector2i in get_neighbors(exit_pos.x, exit_pos.y):
			if current == n:
				return true
		for n: Vector2i in get_neighbors(current.x, current.y):
			if n not in visited and states[n.x][n.y] == CellState.REVEALED:
				visited[n] = true
				queue.append(n)
	return false


## 寻找从 from 到 to 的最短路径（BFS，忽略状态，只避开 WALL）
## 返回路径数组（不含 from，含 to 的邻格但不含 to 本身）
func find_shortest_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		# 到达 to 的邻格即算完成
		for n: Vector2i in get_neighbors(to.x, to.y):
			if current == n:
				# 回溯路径
				var path: Array[Vector2i] = []
				var step: Vector2i = current
				while step != from:
					path.append(step)
					step = parent[step] as Vector2i
				path.reverse()
				return path
		for n: Vector2i in get_neighbors(current.x, current.y):
			if n not in visited and cells[n.x][n.y] != CellType.WALL:
				visited[n] = true
				parent[n] = current
				queue.append(n)

	return [] as Array[Vector2i]
```

- [ ] **Step 4: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add game/scripts/systems/fog_map.gd game/tests/test_runner.gd
git commit -m "feat(fog_map): add exit_pos, path connectivity check, and shortest path finder"
```

---

## Task 3: FogMapGenerator — 撤离点从3个改为1个 + 开局可见

**Files:**
- Modify: `game/scripts/systems/fog_map_generator.gd:44-52`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: 更新测试用例 — EXIT 数量断言改为1**

在 `_run_fog_map_test()` 中修改 exit_count 断言（line 783）：

将：
```gdscript
_assert(exit_count >= 1, "上线出口≥1: %d" % exit_count)
```
改为：
```gdscript
_assert(exit_count == 1, "撤离点=1: %d" % exit_count)
```

新增断言（在 exit_count 断言之后）：
```gdscript
# 撤离点开局可见：状态应为 FOGGY（不是 HIDDEN）
var exit_state: FogMap.CellState = fog_map.get_cell_state(fog_map.exit_pos.x, fog_map.exit_pos.y)
_assert(exit_state != FogMap.CellState.HIDDEN, "撤离点非HIDDEN（开局可见）: state=%d" % exit_state)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: FAIL（当前生成3个EXIT）

- [ ] **Step 3: 修改 FogMapGenerator.generate()**

在 `game/scripts/systems/fog_map_generator.gd` 中，将 EXIT 放置逻辑（line 44-52）替换为：

```gdscript
	# 撤离点：固定1个，距起点较远（≥ MAP_EXIT_MIN_DISTANCE）
	var exit_pos: Vector2i = _find_distant_cell(fog_map, occupied, start, Config.MAP_EXIT_MIN_DISTANCE)
	if exit_pos != Vector2i(-1, -1):
		fog_map.set_cell(exit_pos.x, exit_pos.y, FogMap.CellType.EXIT)
		fog_map.mark_preplaced(exit_pos.x, exit_pos.y)
		fog_map.exit_pos = exit_pos
		occupied.append(exit_pos)
	else:
		# fallback：找最远的非占用格
		var best_pos: Vector2i = Vector2i(-1, -1)
		var best_dist: int = 0
		for row: int in range(FogMap.MAP_SIZE):
			for col_i: int in range(FogMap.MAP_SIZE):
				var pos: Vector2i = Vector2i(row, col_i)
				if pos not in occupied and fog_map.get_cell_type(row, col_i) != FogMap.CellType.WALL:
					var dist: int = FogMap.manhattan_distance(pos, start)
					if dist > best_dist:
						best_dist = dist
						best_pos = pos
		if best_pos != Vector2i(-1, -1):
			fog_map.set_cell(best_pos.x, best_pos.y, FogMap.CellType.EXIT)
			fog_map.mark_preplaced(best_pos.x, best_pos.y)
			fog_map.exit_pos = best_pos
			occupied.append(best_pos)
```

在 `fog_map.init_start(start)` 之后（line 57 之后），新增让撤离点开局可见的逻辑：

```gdscript
	# 撤离点开局可见（FOGGY状态，穿透迷雾）
	if Config.MAP_EXIT_ALWAYS_VISIBLE and fog_map.exit_pos != Vector2i(-1, -1):
		var ep: Vector2i = fog_map.exit_pos
		if fog_map.get_cell_state(ep.x, ep.y) == FogMap.CellState.HIDDEN:
			fog_map.states[ep.x][ep.y] = FogMap.CellState.FOGGY
```

- [ ] **Step 4: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add game/scripts/systems/fog_map_generator.gd game/tests/test_runner.gd
git commit -m "feat(generator): single extraction point, always visible on map start"
```

---

## Task 4: MapCell — 2档光晕 + 揭示动画强化

**Files:**
- Modify: `game/scripts/ui/map_cell.gd`

- [ ] **Step 1: 修改 _get_rarity_glow_color() — 2档光晕**

将 `_get_rarity_glow_color()` 方法（line 390-407）替换为：

```gdscript
## 获取稀有度对应的光晕颜色（2档制：暗/亮）
func _get_rarity_glow_color() -> Color:
	# 稀有度 >= RARE 显示统一暖白微光，否则无光晕
	if rarity >= Config.MAP_GLOW_RARITY_THRESHOLD:
		return Color(Config.MAP_GLOW_COLOR.r, Config.MAP_GLOW_COLOR.g, Config.MAP_GLOW_COLOR.b, Config.MAP_GLOW_ALPHA)
	else:
		return Color(0, 0, 0, 0)
```

- [ ] **Step 2: 修改 start_loading() — Loading 动画统一白色**

在 `start_loading()` 方法（line 265-299）中，将 loading 颜色改为统一白色：

将：
```gdscript
	_loading_color = level_data.get("color", Color(0.7, 0.7, 0.7)) as Color
```
改为：
```gdscript
	_loading_color = Color.WHITE
```

- [ ] **Step 3: 修改 _start_breath_pulse() — 呼吸脉冲不泄露稀有度**

在 `_start_breath_pulse()` 方法（line 475-491）中，将稀有度颜色混合去掉：

将：
```gdscript
	# 叠加一点稀有度颜色
	var rarity_tint: Color = _loading_color
	bright_color = bright_color.lerp(rarity_tint, 0.3)
```
改为：
```gdscript
	# 呼吸脉冲使用纯白色提亮，不泄露稀有度
	bright_color = bright_color.lerp(Color.WHITE, 0.15)
```

- [ ] **Step 4: 新增揭示动画 — 颜色闪变 + 传说级脉冲**

在 `_on_loading_complete()` 方法（line 349-355）中，在 `cell_loading_finished.emit(row, col)` 之前新增揭示动画触发：

将整个 `_on_loading_complete` 替换为：

```gdscript
func _on_loading_complete() -> void:
	_is_loading = false
	_loading_progress = 0.0
	_stop_breath_pulse()
	if _draw_layer:
		_draw_layer.queue_redraw()
	# 揭示动画：颜色闪变（在 cell_loading_finished 之前，让 dev_running 处理后再更新视觉）
	cell_loading_finished.emit(row, col)
```

在 `_show_revealed()` 方法末尾新增传说级脉冲动画：

将整个 `_show_revealed()` 替换为：

```gdscript
func _show_revealed() -> void:
	_stop_wobble()
	if is_start:
		bg_rect.color = COLOR_START
		_show_icon_texture(START_EMOJI, "★")
	else:
		bg_rect.color = _get_type_color()
		var emoji: String = TYPE_ICON_EMOJI.get(cell_type, "") as String
		var fallback: String = TYPE_ICONS_FALLBACK.get(cell_type, "") as String
		_show_icon_texture(emoji, fallback)
	glow_rect.color = Color(0, 0, 0, 0)
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	# 传说级揭示脉冲动画
	if rarity == FogMap.Rarity.LEGENDARY and not is_start:
		_play_legendary_reveal()
```

新增 `_play_legendary_reveal()` 方法（在 `_stop_breath_pulse()` 之后）：

```gdscript
## 传说级揭示脉冲动画（放大再回弹）
func _play_legendary_reveal() -> void:
	if DisplayServer.get_name() == "headless":
		return
	pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(Config.LEGENDARY_REVEAL_SCALE, Config.LEGENDARY_REVEAL_SCALE), Config.LEGENDARY_REVEAL_DURATION * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, Config.LEGENDARY_REVEAL_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
```

- [ ] **Step 5: 新增撤离点特殊显示**

修改 `_show_foggy()` 方法，在末尾（`_start_wobble()` 之后）追加撤离点特殊处理：

```gdscript
	# 撤离点特殊显示：穿透迷雾，显示橙色边框和图标
	if cell_type == FogMap.CellType.EXIT:
		_show_icon_texture("🚀", "=>")
		glow_rect.color = Color(Config.MAP_EXIT_BORDER_COLOR.r, Config.MAP_EXIT_BORDER_COLOR.g, Config.MAP_EXIT_BORDER_COLOR.b, 0.5)
		# 撤离点不可直接点击（需要连通路径）
		disabled = true
		mouse_default_cursor_shape = Control.CURSOR_ARROW
```

- [ ] **Step 6: 删除 RARITY_MARKS 常量**

删除 `RARITY_MARKS` 字典（line 93-99），它不再使用（之前迷雾状态在问号旁显示稀有度标记）。

- [ ] **Step 7: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 8: Commit**

```bash
git add game/scripts/ui/map_cell.gd
git commit -m "feat(map_cell): 2-tier glow, unified white loading, legendary reveal pulse, exit display"
```

---

## Task 5: DevRunning — 删除10格刷新 + 新增撤离点连通逻辑

**Files:**
- Modify: `game/scripts/scenes/dev_running.gd`

- [ ] **Step 1: 删除旧的10格刷新相关代码**

删除以下成员变量（line 24-25）：
```gdscript
var _total_cells_revealed: int = 0
var _next_launch_prompt_at: int = Config.MAP_LAUNCH_PROMPT_INTERVAL
```

新增成员变量（在 `_fight_triggered_count` 之后）：
```gdscript
var _exit_reached: bool = false                  ## 撤离点是否已连通
```

- [ ] **Step 2: 修改 _on_cell_loading_finished — 删除10格刷新逻辑，新增连通判定**

在 `_on_cell_loading_finished()` 方法中：

删除 line 195：
```gdscript
	_total_cells_revealed += 1
```

删除 line 236-239（检查上线提示节点那段）：
```gdscript
	# 检查是否达到上线提示节点（在事件弹窗之后判断）
	if not _popup_active and _total_cells_revealed >= _next_launch_prompt_at:
		_trigger_launch_prompt()
		_update_ui()
		return
```

在 `_check_competitor_launches()` 之后（原来删除段的位置），新增连通判定：

```gdscript
	# 撤离点连通判定
	if not _exit_reached and not _popup_active and fog_map.check_path_connected():
		_exit_reached = true
		_handle_exit_reached()
		_update_ui()
		return
```

- [ ] **Step 3: 新增 _handle_exit_reached() 方法**

在 `_handle_exit()` 方法之后新增：

```gdscript
## ===== 撤离点连通处理 =====
func _handle_exit_reached() -> void:
	_popup_active = true
	_disable_all_cells()

	# 将撤离点标记为 REVEALED
	var ep: Vector2i = fog_map.exit_pos
	fog_map.states[ep.x][ep.y] = FogMap.CellState.REVEALED
	_refresh_map_visuals()

	_add_log("%s [color=orange]撤离点已到达！是否现在上线？[/color]" % AssetRegistry.emoji_bbcode("🚀"))

	# 构建确认弹窗
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.border_color = Color("#f0a030")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "撤离点已到达！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f0a030"))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var grade_name: String = quality_system.get_display_grade_name()
	var remaining: int = TimeManager.get_remaining()
	var desc := Label.new()
	desc.text = "当前品质：%s\n剩余 %d 个月\n\n现在上线，还是继续探索周边提升品质？" % [grade_name, remaining]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(desc)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_hbox)

	var launch_btn := Button.new()
	launch_btn.text = "上线发布"
	launch_btn.custom_minimum_size = Vector2(140, 44)
	var launch_style := StyleBoxFlat.new()
	launch_style.bg_color = Color("#f0a030")
	launch_style.set_corner_radius_all(6)
	launch_style.set_content_margin_all(8)
	launch_btn.add_theme_stylebox_override("normal", launch_style)
	launch_btn.add_theme_color_override("font_color", Color.BLACK)
	var launch_hover := StyleBoxFlat.new()
	launch_hover.bg_color = Color("#f0a030").lightened(0.2)
	launch_hover.set_corner_radius_all(6)
	launch_hover.set_content_margin_all(8)
	launch_btn.add_theme_stylebox_override("hover", launch_hover)
	btn_hbox.add_child(launch_btn)

	var continue_btn := Button.new()
	continue_btn.text = "继续探索"
	continue_btn.custom_minimum_size = Vector2(140, 44)
	var continue_style := StyleBoxFlat.new()
	continue_style.bg_color = Color(0.3, 0.3, 0.3)
	continue_style.set_corner_radius_all(6)
	continue_style.set_content_margin_all(8)
	continue_btn.add_theme_stylebox_override("normal", continue_style)
	var continue_hover := StyleBoxFlat.new()
	continue_hover.bg_color = Color(0.4, 0.4, 0.4)
	continue_hover.set_corner_radius_all(6)
	continue_hover.set_content_margin_all(8)
	continue_btn.add_theme_stylebox_override("hover", continue_hover)
	btn_hbox.add_child(continue_btn)

	panel.add_child(vbox)
	center.add_child(panel)

	var popup_root := Control.new()
	popup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_root.add_child(overlay)
	popup_root.add_child(center)
	popup_layer.add_child(popup_root)

	launch_btn.pressed.connect(_on_exit_launch.bind(popup_root))
	continue_btn.pressed.connect(_on_exit_continue.bind(popup_root))


func _on_exit_launch(popup: Control) -> void:
	popup.queue_free()
	_popup_active = false
	_on_launch_pressed()


func _on_exit_continue(popup: Control) -> void:
	popup.queue_free()
	_popup_active = false
	_add_log("%s [color=cyan]决定继续探索——提升品质再上线[/color]" % AssetRegistry.emoji_bbcode("🔄"))
	_enable_clickable_cells()
	_update_ui()
```

- [ ] **Step 4: 修改上线按钮初始状态 — 锁定直到连通**

在 `_ready()` 方法中，`launch_button.pressed.connect(_on_launch_pressed)` 之后新增：

```gdscript
	# 上线按钮初始锁定（需要连通撤离点才能解锁）
	launch_button.disabled = true
	launch_button.tooltip_text = "需要连通撤离点才能上线"
```

修改 `_update_ui()` 方法中的上线按钮逻辑（line 850）：

将：
```gdscript
	# 强制上线按钮
	launch_button.disabled = _popup_active
```
改为：
```gdscript
	# 上线按钮：连通撤离点后才可用
	launch_button.disabled = _popup_active or not _exit_reached
	if _exit_reached:
		launch_button.tooltip_text = "上线发布"
	else:
		launch_button.tooltip_text = "需要连通撤离点才能上线"
```

- [ ] **Step 5: 修改 _handle_exit() — 不再自动触发上线**

将 `_handle_exit()` 方法（line 369-371）替换为：

```gdscript
func _handle_exit() -> void:
	# 撤离点格子被揭开时的处理（实际上撤离点通过连通判定自动处理）
	# 此方法保留作为安全兜底
	if not _exit_reached:
		_exit_reached = true
		_handle_exit_reached()
```

- [ ] **Step 6: 删除 _trigger_launch_prompt 和 _reset_map 相关方法**

删除以下方法（完整删除）：
- `_trigger_launch_prompt()` (line 375-470)
- `_on_launch_prompt_launch()` (line 473-476)
- `_on_launch_prompt_continue()` (line 479-485)
- `_reset_map()` (line 489-505)

- [ ] **Step 7: 修改开场日志**

将 line 102 的日志：
```gdscript
		_add_log("%s 格子稀有度越高，消耗时间越长，但奖励也越好！" % AssetRegistry.emoji_bbcode("💡"))
```
改为：
```gdscript
		_add_log("%s 找到撤离点 %s 才能上线！" % [AssetRegistry.emoji_bbcode("💡"), AssetRegistry.emoji_bbcode("🚀")])
```

- [ ] **Step 8: 修改 _enable_clickable_cells — 撤离点不可直接点击**

在 `_enable_clickable_cells()` 方法（line 815-823）中，修改启用逻辑：

将：
```gdscript
			cell_node.disabled = state != FogMap.CellState.FOGGY
```
改为：
```gdscript
			if state == FogMap.CellState.FOGGY and fog_map.get_cell_type(row, col) != FogMap.CellType.EXIT:
				cell_node.disabled = false
			else:
				cell_node.disabled = true
```

- [ ] **Step 9: 运行测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 全部通过

- [ ] **Step 10: Commit**

```bash
git add game/scripts/scenes/dev_running.gd
git commit -m "feat(dev_running): extraction point connectivity, remove 10-cell refresh, lock launch button"
```

---

## Task 6: 测试更新 — 修复受影响的已有测试

**Files:**
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: 更新数值模拟测试**

在 `_run_fog_map_test()` 的数值模拟段（line 869-926），将"找到出口"逻辑改为"连通撤离点"：

替换多次模拟部分（line 900-926）为：

```gdscript
	# 多次模拟检查撤离点连通性（定向寻路 vs 随机探索）
	var exit_connected_count: int = 0
	for sim_i: int in range(10):
		var test_map: FogMap = FogMapGenerator.generate(sim_i * 7 + 1)
		var m_left: int = 36
		while m_left > 0:
			var sc: Array[Vector2i] = test_map.get_clickable_cells()
			if sc.size() == 0:
				break
			# 过滤掉EXIT类型的格子（不可直接点击）
			var valid_cells: Array[Vector2i] = []
			for c: Vector2i in sc:
				if test_map.get_cell_type(c.x, c.y) != FogMap.CellType.EXIT:
					valid_cells.append(c)
			if valid_cells.size() == 0:
				break
			var p: Vector2i = valid_cells[randi_range(0, valid_cells.size() - 1)]
			var p_rarity: FogMap.Rarity = test_map.get_cell_rarity(p.x, p.y)
			var p_rarity_name: String = FogMap.RARITY_NAMES[p_rarity]
			var p_cost: int = Config.RARITY_MONTH_COST.get(p_rarity_name, 1) as int
			if m_left < p_cost:
				break
			test_map.reveal_cell(p.x, p.y)
			m_left -= p_cost
			if test_map.check_path_connected():
				exit_connected_count += 1
				break

	_log_info("10次随机模拟中连通撤离点: %d/10" % exit_connected_count)
	_assert(exit_connected_count >= 1, "至少10%%的随机模拟能连通撤离点: %d/10" % exit_connected_count)
```

也修改单次模拟段（line 869-898），让其过滤EXIT格子：

在 `while months_left > 0:` 循环内，`var sim_clickable` 之后加入过滤：

```gdscript
		# 过滤掉EXIT类型（不可直接点击）
		var valid_sim: Array[Vector2i] = []
		for c: Vector2i in sim_clickable:
			if sim_map.get_cell_type(c.x, c.y) != FogMap.CellType.EXIT:
				valid_sim.append(c)
		if valid_sim.size() == 0:
			break
```

并将 pick 的选择改为从 `valid_sim` 中选取。

将找到出口的判定改为连通判定：
```gdscript
			if sim_map.check_path_connected():
				found_exit = true
```

- [ ] **Step 2: 运行完整测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 🎉 全部通过！❌ 0 失败

- [ ] **Step 3: Commit**

```bash
git add game/tests/test_runner.gd
git commit -m "test: update fog map tests for single extraction point and path connectivity"
```

---

## Task 7: 最终验证 + 清理

**Files:**
- Review: all modified files

- [ ] **Step 1: 运行完整 headless 测试**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/kuangjianwei/AI_Discover/sdc/game res://tests/test_main.tscn 2>&1`
Expected: 🎉 全部通过！❌ 0 失败

- [ ] **Step 2: 检查是否有残留引用**

搜索整个 `game/` 目录中是否还有引用已删除常量/方法的地方：

```bash
grep -r "MAP_LAUNCH_PROMPT_INTERVAL\|_reset_map\|_total_cells_revealed\|_next_launch_prompt_at\|_trigger_launch_prompt\|_on_launch_prompt" game/scripts/ game/tests/
```

Expected: 无匹配结果

- [ ] **Step 3: 检查 MAP_CELL_RATIOS 中 exit 是否已移除**

确认 Config.gd 中 `MAP_CELL_RATIOS` 字典不再包含 `"exit"` 键。

- [ ] **Step 4: Commit 清理（如有需要）**

```bash
git add -A
git commit -m "chore: cleanup stale references after map rework"
```
