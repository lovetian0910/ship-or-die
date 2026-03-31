# resource_card.gd — 单张资源卡片交互脚本
class_name ResourceCard
extends PanelContainer

## 信号：被点击选中
signal card_selected(card: ResourceCard)

## 绑定的资源数据
var resource_data: EntryResourceData

## UI引用
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var effect_label: Label = %EffectLabel
@onready var price_label: Label = %PriceLabel
@onready var select_highlight: ColorRect = %SelectHighlight
@onready var tier_label: Label = %TierLabel

var is_selected: bool = false
var is_affordable: bool = true


func setup(data: EntryResourceData) -> void:
	resource_data = data
	if not is_node_ready():
		await ready
	name_label.text = data.display_name
	desc_label.text = data.description
	price_label.text = "$ %d" % data.price

	# 加载头像
	var portrait_key: String = _get_portrait_key(data)
	var tex: Texture2D = AssetRegistry.get_texture("portrait", portrait_key)
	if tex and is_instance_valid(%PortraitRect):
		%PortraitRect.texture = tex

	# 等级星标
	var stars: String = ""
	for i in range(data.get_tier_number()):
		stars += "★"
	tier_label.text = stars

	# 根据类别显示效果文本
	match data.category:
		EntryResourceData.Category.CREATOR:
			effect_label.text = "品质上限: %d分" % int(data.quality_cap)
		EntryResourceData.Category.OUTSOURCE:
			effect_label.text = "研发速度: %.1f×" % data.dev_speed
		EntryResourceData.Category.BUSINESS:
			effect_label.text = "急救精力: %d点" % data.energy

	select_highlight.visible = false


func set_selected(selected: bool) -> void:
	is_selected = selected
	if select_highlight:
		select_highlight.visible = selected


func set_affordable(affordable: bool) -> void:
	is_affordable = affordable
	modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.4)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_affordable:
			card_selected.emit(self)


## 根据资源数据生成 AssetRegistry portrait key
func _get_portrait_key(data: EntryResourceData) -> String:
	var cat: String = ""
	match data.category:
		EntryResourceData.Category.CREATOR:
			cat = "creator"
		EntryResourceData.Category.OUTSOURCE:
			cat = "outsource"
		EntryResourceData.Category.BUSINESS:
			cat = "business"
	var tier_str: String = ""
	match data.tier:
		EntryResourceData.Tier.LOW:
			tier_str = "low"
		EntryResourceData.Tier.MID:
			tier_str = "mid"
		EntryResourceData.Tier.HIGH:
			tier_str = "high"
	return "%s_%s" % [cat, tier_str]
