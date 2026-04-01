# fight_event_popup.gd — 打类事件入口弹窗
# 显示危机描述，然后启动代码急救小游戏
extends Control

## 事件处理完毕信号
## result: "conservative"/"steady"/"risky"
## effects: 对应的效果字典（quality, speed_bonus, month_cost, desc）
signal event_resolved(result: String, effects: Dictionary)

var _event: EventData

## 节点引用
var _title_label: Label
var _desc_label: Label
var _option_labels: Array[Label] = []
var _start_btn: Button
var _info_panel: PanelContainer
var _event_image: TextureRect

## 代码急救场景
var _rescue_game: Control = null


func _ready() -> void:
	_build_ui()


## ===== 外部调用：设置事件数据 =====
func setup(event_data: EventData) -> void:
	_event = event_data
	_title_label.text = "[!] " + event_data.title
	_desc_label.text = event_data.description

	# 加载事件配图
	var tex: Texture2D = AssetRegistry.get_texture("event", event_data.event_id)
	if tex and is_instance_valid(_event_image):
		_event_image.texture = tex
		_event_image.visible = true

	# 显示三个选项对应关系
	_option_labels[0].text = "存活 <60%%：%s" % event_data.fight_conservative_desc
	_option_labels[1].text = "存活 60-90%%：%s" % event_data.fight_steady_desc
	_option_labels[2].text = "存活 ≥90%%：%s" % event_data.fight_risky_desc


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
		"memory_match":
			_start_memory_match(business_level)
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


## ===== 小游戏结束回调 =====
func _on_rescue_finished(result: String, survival_rate: float) -> void:
	_rescue_game = null

	# 根据结果获取效果
	var effects: Dictionary = _event.get_fight_effects(result)
	effects["survival_rate"] = survival_rate

	event_resolved.emit(result, effects)
	queue_free()


## ===== 兜底：直接以保守结果结束 =====
func _finish_with_conservative() -> void:
	var effects: Dictionary = _event.get_fight_effects("conservative")
	effects["survival_rate"] = 0.0
	event_resolved.emit("conservative", effects)
	queue_free()


## ===== 构建UI =====

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 半透明遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 居中面板
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(560, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.05, 0.05, 0.98)
	panel_style.border_color = Color("#e94560")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	_info_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_info_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_info_panel.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.text = "[!] 危机事件"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#e94560"))
	vbox.add_child(_title_label)

	# 分隔线
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 事件配图
	_event_image = TextureRect.new()
	_event_image.visible = false
	_event_image.custom_minimum_size = Vector2(180, 180)
	_event_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_event_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_event_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_event_image)

	# 描述
	_desc_label = Label.new()
	_desc_label.text = "危机描述"
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_desc_label)

	# 分隔线
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# 结果映射说明
	var mapping_title := Label.new()
	mapping_title.text = "代码急救结果对应："
	mapping_title.add_theme_font_size_override("font_size", 16)
	mapping_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(mapping_title)

	# 三个选项
	_option_labels.clear()
	var option_colors: Array[Color] = [Color("#e94560"), Color.YELLOW, Color("#4ecca3")]
	for i: int in range(3):
		var lbl := Label.new()
		lbl.text = ""
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", option_colors[i])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)
		_option_labels.append(lbl)

	# 开始按钮
	_start_btn = Button.new()
	_start_btn.text = "进入代码急救！"
	_start_btn.custom_minimum_size = Vector2(200, 48)
	_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_btn.pressed.connect(_on_start_rescue)
	vbox.add_child(_start_btn)

	# 按钮样式
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#e94560")
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_start_btn.add_theme_stylebox_override("normal", btn_style)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color("#e94560").lightened(0.2)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)
	_start_btn.add_theme_stylebox_override("hover", btn_hover)
