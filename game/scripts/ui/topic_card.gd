# topic_card.gd — 单张题材卡片
extends PanelContainer

signal card_selected(topic: TopicData)

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var heat_label: Label = %HeatLabel

var topic_data: TopicData
var _is_selected: bool = false

## 默认样式
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func _ready() -> void:
	_setup_styles()
	add_theme_stylebox_override("panel", _normal_style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup(topic: TopicData) -> void:
	topic_data = topic
	# 优先从 AssetRegistry 加载图标
	var tex: Texture2D = AssetRegistry.get_texture("topic", String(topic.id))
	if tex:
		icon_rect.texture = tex
	elif topic.icon:
		icon_rect.texture = topic.icon
	name_label.text = topic.display_name
	desc_label.text = topic.description
	refresh_heat()


func refresh_heat() -> void:
	if not topic_data:
		return
	heat_label.text = MarketHeat.get_fuzzy_text(topic_data.id)
	heat_label.add_theme_color_override("font_color", MarketHeat.get_fuzzy_color(topic_data.id))


func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _is_selected:
		add_theme_stylebox_override("panel", _selected_style)
	else:
		add_theme_stylebox_override("panel", _normal_style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			card_selected.emit(topic_data)


func _on_mouse_entered() -> void:
	if not _is_selected:
		add_theme_stylebox_override("panel", _hover_style)


func _on_mouse_exited() -> void:
	if not _is_selected:
		add_theme_stylebox_override("panel", _normal_style)


func _setup_styles() -> void:
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	_normal_style.border_color = Color(0.3, 0.3, 0.4)
	_normal_style.set_border_width_all(2)
	_normal_style.set_corner_radius_all(8)
	_normal_style.set_content_margin_all(12)

	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = Color(0.18, 0.22, 0.3, 0.95)
	_hover_style.border_color = Color(0.5, 0.6, 0.8)
	_hover_style.set_border_width_all(2)
	_hover_style.set_corner_radius_all(8)
	_hover_style.set_content_margin_all(12)

	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.15, 0.25, 0.45, 0.95)
	_selected_style.border_color = Color(0.4, 0.7, 1.0)
	_selected_style.set_border_width_all(3)
	_selected_style.set_corner_radius_all(8)
	_selected_style.set_content_margin_all(12)
