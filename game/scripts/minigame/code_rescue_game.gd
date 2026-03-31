# code_rescue_game.gd — 代码急救小游戏：UI渲染+输入处理+倒计时
extends Control

## ===== 信号 =====
signal game_finished(result: String, survival_rate: float)

## ===== 颜色常量 =====
const COLOR_PENDING: Color = Color("#4ecca3")
const COLOR_BUG: Color = Color("#e94560")
const COLOR_REPAIRED: Color = Color("#2d8f6f")
const COLOR_CRASHED: Color = Color("#1a1a2e")
const COLOR_BG: Color = Color("#16213e")
const COLOR_FLASH: Color = Color("#ffffff")

## ===== 节点引用（代码创建，不依赖.tscn中的节点名）=====
var _grid_container: GridContainer
var _timer_label: Label
var _energy_label: Label
var _flavor_label: Label
var _title_label: Label
var _result_panel: PanelContainer
var _result_label: Label
var _result_btn: Button

## ===== 游戏数据 =====
var _grid: CodeRescueGrid
var _preset: CodeRescuePreset
var _energy: int = 10
var _max_energy: int = 10
var _time_remaining: float = 0.0
var _spread_timer: float = 0.0
var _is_running: bool = false
var _cell_buttons: Array = []  ## Array[Array[Button]]  [row][col]

## ===== 常量 =====
const CELL_SIZE: int = 64
const CELL_GAP: int = 2


func _ready() -> void:
	_build_ui()


## ===== 外部调用：初始化并开始 =====
func setup(preset: CodeRescuePreset, business_level: int) -> void:
	_preset = preset
	_energy = preset.get_energy(business_level)
	_max_energy = _energy

	# 初始化网格数据
	_grid = CodeRescueGrid.new()
	var bug_positions: Array = CodeRescueGrid.generate_bug_positions(
		preset.initial_bug_count, preset.spawn_mode
	)
	_grid.init_grid(bug_positions)

	# 设置文本
	_title_label.text = _preset.preset_name
	_flavor_label.text = _preset.flavor_text
	_result_panel.visible = false

	# 启动实时倒计时
	_time_remaining = Config.MINIGAME_REAL_SECONDS
	_spread_timer = 0.0
	_is_running = true

	# 通知TimeManager启动小游戏时钟
	TimeManager.start_minigame()

	# 初始渲染
	_render_grid()
	_update_hud()


func _process(delta: float) -> void:
	if not _is_running:
		return

	# 倒计时
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_end_game()
		return

	# 扩散计时
	_spread_timer += delta
	if _spread_timer >= _preset.spread_interval:
		_spread_timer -= _preset.spread_interval
		_grid.spread_tick()
		_render_grid()

		# bug全部清零 → 提前结束，大成功
		if _grid.bug_count == 0:
			_end_game()
			return

	_update_hud()


## ===== 格子点击 =====
func _on_cell_pressed(row: int, col: int) -> void:
	if not _is_running:
		return
	if _energy <= 0:
		return

	if _grid.repair_cell(row, col):
		_energy -= 1
		_flash_cell(row, col)
		_update_cell_color(row, col)
		_update_hud()

		# bug全部清零 → 提前结束，大成功
		if _grid.bug_count == 0:
			_end_game()
			return

		# 精力耗尽 → 立刻结束
		if _energy <= 0:
			_end_game()


## ===== 渲染 =====

func _render_grid() -> void:
	for row: int in range(CodeRescueGrid.GRID_SIZE):
		for col: int in range(CodeRescueGrid.GRID_SIZE):
			_update_cell_color(row, col)


func _update_cell_color(row: int, col: int) -> void:
	var btn: Button = _cell_buttons[row][col]
	var state: int = _grid.get_cell(row, col)
	var color: Color
	match state:
		CodeRescueGrid.CellState.PENDING:
			color = COLOR_PENDING
		CodeRescueGrid.CellState.BUG:
			color = COLOR_BUG
		CodeRescueGrid.CellState.REPAIRED:
			color = COLOR_REPAIRED
		CodeRescueGrid.CellState.CRASHED:
			color = COLOR_CRASHED
		_:
			color = COLOR_BG

	# 使用 StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.15)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.2)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# 格子文本
	match state:
		CodeRescueGrid.CellState.PENDING:
			btn.text = ";"
		CodeRescueGrid.CellState.BUG:
			btn.text = "!"
		CodeRescueGrid.CellState.REPAIRED:
			btn.text = "\u2713"
		CodeRescueGrid.CellState.CRASHED:
			btn.text = "X"


func _apply_changes(changes: Array) -> void:
	for change: Dictionary in changes:
		var pos: Vector2i = change.get("pos", Vector2i.ZERO) as Vector2i
		_update_cell_color(pos.x, pos.y)
		# 扩散动画：红色脉冲
		var new_state: int = change.get("new_state", 0) as int
		if new_state == CodeRescueGrid.CellState.BUG:
			_pulse_cell(pos.x, pos.y, COLOR_BUG)
		elif new_state == CodeRescueGrid.CellState.CRASHED:
			_pulse_cell(pos.x, pos.y, Color.BLACK)


func _flash_cell(row: int, col: int) -> void:
	var btn: Button = _cell_buttons[row][col]
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_FLASH
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	# 0.15秒后恢复
	var tw: Tween = create_tween()
	tw.tween_callback(_update_cell_color.bind(row, col)).set_delay(0.15)


func _pulse_cell(row: int, col: int, color: Color) -> void:
	var btn: Button = _cell_buttons[row][col]
	var tw: Tween = create_tween()
	# 短暂放大再恢复
	tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)


## ===== HUD更新 =====

func _update_hud() -> void:
	# 工时显示（映射15秒→480工时）
	var pct: float = _time_remaining / Config.MINIGAME_REAL_SECONDS
	var display_hours: int = int(Config.MINIGAME_DISPLAY_HOURS * pct)
	_timer_label.text = "剩余工时：%d" % display_hours

	# 精力
	_energy_label.text = "精力：%d / %d" % [_energy, _max_energy]

	# 健康率颜色
	var rate: float = _grid.get_health_rate()
	if rate >= 0.9:
		_timer_label.add_theme_color_override("font_color", COLOR_PENDING)
	elif rate >= 0.6:
		_timer_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_timer_label.add_theme_color_override("font_color", COLOR_BUG)


## ===== 游戏结束 =====

func _end_game() -> void:
	_is_running = false
	TimeManager.stop_minigame()

	var health_rate: float = _grid.get_health_rate()
	var result: String
	var result_text: String

	if health_rate >= 0.9:
		result = "risky"
		result_text = "【大成功】健康率 %.0f%%\n危机变机会！" % (health_rate * 100.0)
	elif health_rate >= 0.6:
		result = "steady"
		result_text = "【一般】健康率 %.0f%%\n惩罚被消除。" % (health_rate * 100.0)
	else:
		result = "conservative"
		result_text = "【失败】健康率 %.0f%%\n不得不承受惩罚……" % (health_rate * 100.0)

	_result_label.text = result_text
	_result_panel.visible = true

	# 存储结果供关闭时发信号
	_result_panel.set_meta("result", result)
	_result_panel.set_meta("survival_rate", health_rate)


func _on_result_confirm() -> void:
	var result: String = _result_panel.get_meta("result", "conservative") as String
	var survival_rate: float = _result_panel.get_meta("survival_rate", 0.0) as float
	game_finished.emit(result, survival_rate)
	queue_free()


## ===== UI构建（纯代码，模拟IDE终端风格）=====

func _build_ui() -> void:
	# 根容器 - 全屏深色背景
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#0a0a1a")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 背景图（办公室）
	var bg_tex: Texture2D = AssetRegistry.get_texture("background", "office")
	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		bg_img.modulate = Color(1, 1, 1, 0.15)
		add_child(bg_img)

	# 主布局
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# 上方间距
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(top_spacer)

	# 标题
	_title_label = Label.new()
	_title_label.text = "代码急救"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_BUG)
	main_vbox.add_child(_title_label)

	# 描述文本
	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 14)
	_flavor_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(_flavor_label)

	# HUD行：工时 + 精力
	var hud_hbox := HBoxContainer.new()
	hud_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(hud_hbox)

	_timer_label = Label.new()
	_timer_label.text = "剩余工时：480"
	_timer_label.add_theme_font_size_override("font_size", 20)
	_timer_label.add_theme_color_override("font_color", COLOR_PENDING)
	hud_hbox.add_child(_timer_label)

	_energy_label = Label.new()
	_energy_label.text = "精力：10 / 10"
	_energy_label.add_theme_font_size_override("font_size", 20)
	_energy_label.add_theme_color_override("font_color", Color.WHITE)
	hud_hbox.add_child(_energy_label)

	# 网格容器 — 居中
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(grid_center)

	_grid_container = GridContainer.new()
	_grid_container.columns = CodeRescueGrid.GRID_SIZE
	_grid_container.add_theme_constant_override("h_separation", CELL_GAP)
	_grid_container.add_theme_constant_override("v_separation", CELL_GAP)
	grid_center.add_child(_grid_container)

	# 创建36个格子按钮
	_cell_buttons.clear()
	for row: int in range(CodeRescueGrid.GRID_SIZE):
		var row_arr: Array = []
		for col: int in range(CodeRescueGrid.GRID_SIZE):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.text = ";"
			btn.add_theme_font_size_override("font_size", 18)
			# 按钮样式
			var style := StyleBoxFlat.new()
			style.bg_color = COLOR_PENDING
			style.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", style)
			# 连接信号（捕获row和col）
			btn.pressed.connect(_on_cell_pressed.bind(row, col))
			btn.pivot_offset = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
			_grid_container.add_child(btn)
			row_arr.append(btn)
		_cell_buttons.append(row_arr)

	# 结果面板（初始隐藏）
	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(400, 200)

	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	result_style.border_color = COLOR_PENDING
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
