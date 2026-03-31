# search_event_popup.gd — 搜类事件弹窗
extends Control

## 事件处理完毕信号
## accepted: 是否接受  effects: 收益字典
signal event_resolved(accepted: bool, effects: Dictionary)

var _event: EventData

## 节点引用
var _title_label: Label
var _desc_label: Label
var _benefit_label: Label
var _accept_btn: Button
var _reject_btn: Button
var _event_image: TextureRect


func _ready() -> void:
	_build_ui()


## ===== 外部调用：设置事件数据 =====
func setup(event_data: EventData) -> void:
	_event = event_data
	_title_label.text = event_data.title
	_desc_label.text = event_data.description
	_benefit_label.text = "收益：%s" % event_data.search_benefit_desc

	# 加载事件配图
	var tex: Texture2D = AssetRegistry.get_texture("event", event_data.event_id)
	if tex and is_instance_valid(_event_image):
		_event_image.texture = tex
		_event_image.visible = true


## ===== 按钮回调 =====

func _on_accept() -> void:
	if _event == null:
		return

	var effects: Dictionary = {
		"benefit_type": _event.search_benefit_type,
		"benefit_value": _event.search_benefit_value,
		"month_cost": _event.search_month_cost,
	}

	event_resolved.emit(true, effects)
	queue_free()


func _on_reject() -> void:
	event_resolved.emit(false, {})
	queue_free()


## ===== 构建UI =====

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 半透明遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 居中面板
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	panel_style.border_color = Color("#4ecca3")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# 标题 — 带图标
	_title_label = Label.new()
	_title_label.text = "事件标题"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#4ecca3"))
	vbox.add_child(_title_label)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
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
	_desc_label.text = "事件描述"
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_desc_label)

	# 收益
	_benefit_label = Label.new()
	_benefit_label.text = "收益："
	_benefit_label.add_theme_font_size_override("font_size", 17)
	_benefit_label.add_theme_color_override("font_color", Color("#4ecca3"))
	vbox.add_child(_benefit_label)

	# 按钮行
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_hbox)

	_accept_btn = Button.new()
	_accept_btn.text = "接受"
	_accept_btn.custom_minimum_size = Vector2(140, 44)
	_accept_btn.pressed.connect(_on_accept)
	btn_hbox.add_child(_accept_btn)

	# 接受按钮样式
	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color("#4ecca3")
	accept_style.set_corner_radius_all(6)
	accept_style.set_content_margin_all(8)
	_accept_btn.add_theme_stylebox_override("normal", accept_style)
	_accept_btn.add_theme_color_override("font_color", Color.BLACK)

	var accept_hover := StyleBoxFlat.new()
	accept_hover.bg_color = Color("#4ecca3").lightened(0.2)
	accept_hover.set_corner_radius_all(6)
	accept_hover.set_content_margin_all(8)
	_accept_btn.add_theme_stylebox_override("hover", accept_hover)

	_reject_btn = Button.new()
	_reject_btn.text = "放弃"
	_reject_btn.custom_minimum_size = Vector2(140, 44)
	_reject_btn.pressed.connect(_on_reject)
	btn_hbox.add_child(_reject_btn)

	# 放弃按钮样式
	var reject_style := StyleBoxFlat.new()
	reject_style.bg_color = Color(0.3, 0.3, 0.3)
	reject_style.set_corner_radius_all(6)
	reject_style.set_content_margin_all(8)
	_reject_btn.add_theme_stylebox_override("normal", reject_style)

	var reject_hover := StyleBoxFlat.new()
	reject_hover.bg_color = Color(0.4, 0.4, 0.4)
	reject_hover.set_corner_radius_all(6)
	reject_hover.set_content_margin_all(8)
	_reject_btn.add_theme_stylebox_override("hover", reject_hover)
