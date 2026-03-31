# entry_shop.gd — 入场选购界面主控脚本
extends Control

## 资源数据（代码加载，避免编辑器拖拽依赖）
var creator_resources: Array[EntryResourceData] = []
var outsource_resources: Array[EntryResourceData] = []
var business_resources: Array[EntryResourceData] = []

## UI 引用
@onready var money_label: Label = %MoneyLabel
@onready var total_label: Label = %TotalLabel
@onready var confirm_button: Button = %ConfirmButton

@onready var creator_container: VBoxContainer = %CreatorCardContainer
@onready var outsource_container: VBoxContainer = %OutsourceCardContainer
@onready var business_container: VBoxContainer = %BusinessCardContainer

## 卡片场景预加载
var card_scene: PackedScene = preload("res://scenes/ui/resource_card.tscn")

## 当前选中状态（每列一个）
var selected: Dictionary = {
	"creator": null,     # ResourceCard
	"outsource": null,
	"business": null,
}

## 所有卡片引用（用于刷新状态）
var all_cards: Array[ResourceCard] = []


func _ready() -> void:
	_load_resource_data()
	_build_column(creator_container, creator_resources, "creator")
	_build_column(outsource_container, outsource_resources, "outsource")
	_build_column(business_container, business_resources, "business")

	confirm_button.pressed.connect(_on_confirm)
	EventBus.money_changed.connect(_on_money_changed)

	_refresh_ui()


## 从 .tres 文件加载资源数据
func _load_resource_data() -> void:
	creator_resources = [
		preload("res://resources/entry_resources/creator_low.tres"),
		preload("res://resources/entry_resources/creator_mid.tres"),
		preload("res://resources/entry_resources/creator_high.tres"),
	]
	outsource_resources = [
		preload("res://resources/entry_resources/outsource_low.tres"),
		preload("res://resources/entry_resources/outsource_mid.tres"),
		preload("res://resources/entry_resources/outsource_high.tres"),
	]
	business_resources = [
		preload("res://resources/entry_resources/business_low.tres"),
		preload("res://resources/entry_resources/business_mid.tres"),
		preload("res://resources/entry_resources/business_high.tres"),
	]


## 构建一列卡片
func _build_column(container: VBoxContainer, resources: Array[EntryResourceData], category_key: String) -> void:
	for res_data: EntryResourceData in resources:
		var card: ResourceCard = card_scene.instantiate()
		container.add_child(card)
		card.setup(res_data)
		card.card_selected.connect(_on_card_selected.bind(category_key))
		all_cards.append(card)

	# 默认选中最低级（数组第0个）
	if container.get_child_count() > 0:
		var first_card: ResourceCard = container.get_child(0) as ResourceCard
		first_card.set_selected(true)
		selected[category_key] = first_card


## 卡片被选中的回调
func _on_card_selected(card: ResourceCard, category_key: String) -> void:
	# 取消同列旧选中
	var old_card: ResourceCard = selected[category_key]
	if old_card and old_card != card:
		old_card.set_selected(false)

	card.set_selected(true)
	selected[category_key] = card
	_refresh_ui()


## 计算当前已选总价
func _get_total_cost() -> int:
	var total: int = 0
	for card: Variant in selected.values():
		if card:
			total += (card as ResourceCard).resource_data.price
	return total


## 刷新所有 UI 状态
func _refresh_ui() -> void:
	var current_money: int = EconomyManager.get_money()
	var total_cost: int = _get_total_cost()

	# 更新金钱和总价显示
	money_label.text = "持有金钱: %d" % current_money
	total_label.text = "已选总价: %d / %d" % [total_cost, current_money]

	# 总价颜色提示
	if total_cost > current_money:
		total_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		total_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# 计算每张卡片的可选状态
	for card: ResourceCard in all_cards:
		var simulated_cost: int = total_cost
		var cat_key: String = _category_to_key(card.resource_data.category)
		var current_card: Variant = selected[cat_key]
		if current_card:
			simulated_cost -= (current_card as ResourceCard).resource_data.price
		simulated_cost += card.resource_data.price
		card.set_affordable(simulated_cost <= current_money)

	# 确认按钮状态
	confirm_button.disabled = total_cost > current_money


## 确认选购
func _on_confirm() -> void:
	var total_cost: int = _get_total_cost()
	if not EconomyManager.purchase_loadout(total_cost):
		return  # 防御性检查

	var creator_card: ResourceCard = selected["creator"] as ResourceCard
	var outsource_card: ResourceCard = selected["outsource"] as ResourceCard
	var business_card: ResourceCard = selected["business"] as ResourceCard

	# 存储装备数据
	EconomyManager.set_loadout(
		creator_card.resource_data,
		outsource_card.resource_data,
		business_card.resource_data
	)

	# 记录本局花费
	GameManager.run_data["money_spent"] = total_cost

	# 发射信号通知外部
	var loadout: Dictionary = {
		"creator": creator_card.resource_data,
		"outsource": outsource_card.resource_data,
		"business": business_card.resource_data,
	}
	EventBus.shop_completed.emit(loadout)

	# 状态转移
	GameManager.transition_to(GameManager.GameState.TOPIC_SELECT)


## 金钱变化回调（局间重入时更新）
func _on_money_changed(_new_amount: int) -> void:
	if is_inside_tree():
		_refresh_ui()


## 辅助：Category枚举 → 字典key
func _category_to_key(category: EntryResourceData.Category) -> String:
	match category:
		EntryResourceData.Category.CREATOR:
			return "creator"
		EntryResourceData.Category.OUTSOURCE:
			return "outsource"
		EntryResourceData.Category.BUSINESS:
			return "business"
	return ""


## 重入时重置选中状态（每局开始调用）
func reset_selection() -> void:
	for category_key: String in selected.keys():
		if selected[category_key]:
			(selected[category_key] as ResourceCard).set_selected(false)
		selected[category_key] = null

	# 重新默认选中每列最低级
	_default_select(creator_container, "creator")
	_default_select(outsource_container, "outsource")
	_default_select(business_container, "business")
	_refresh_ui()


func _default_select(container: VBoxContainer, category_key: String) -> void:
	if container.get_child_count() > 0:
		var first_card: ResourceCard = container.get_child(0) as ResourceCard
		first_card.set_selected(true)
		selected[category_key] = first_card
