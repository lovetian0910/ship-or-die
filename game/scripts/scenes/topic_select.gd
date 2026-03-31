# topic_select.gd — 选题界面主控
extends Control

## 题材 .tres 路径
const TOPIC_PATHS: Array[String] = [
	"res://resources/topics/topic_phantom_realm.tres",
	"res://resources/topics/topic_mecha_royale.tres",
	"res://resources/topics/topic_waifu_collection.tres",
	"res://resources/topics/topic_star_ranch.tres",
]

const TopicCardScene: PackedScene = preload("res://scenes/ui/topic_card.tscn")

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var confirm_section: VBoxContainer = %ConfirmSection
@onready var selected_label: Label = %SelectedLabel
@onready var game_name_input: LineEdit = %GameNameInput
@onready var confirm_button: Button = %ConfirmButton

var _topics: Array[TopicData] = []
var _cards: Array[Node] = []
var _selected_topic: TopicData = null


func _ready() -> void:
	# 加载题材数据
	for path in TOPIC_PATHS:
		var topic := load(path) as TopicData
		if topic:
			_topics.append(topic)

	# 初始化市场热度系统
	MarketHeat.init_market(_topics)

	# 隐藏确认区域
	confirm_section.visible = false
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm)
	game_name_input.text_changed.connect(_on_name_changed)

	# 动态生成卡片
	for topic in _topics:
		var card: Node = TopicCardScene.instantiate()
		cards_container.add_child(card)
		card.setup(topic)
		card.card_selected.connect(_on_card_selected)
		_cards.append(card)

	# 监听热度更新
	MarketHeat.heat_updated.connect(_on_heat_updated)


func _on_card_selected(topic: TopicData) -> void:
	_selected_topic = topic
	for card in _cards:
		card.set_selected(card.topic_data == topic)
	confirm_section.visible = true
	selected_label.text = "已选题材：%s" % topic.display_name
	game_name_input.text = ""
	game_name_input.placeholder_text = "为你的游戏起个名字..."
	game_name_input.grab_focus()
	confirm_button.disabled = true


func _on_name_changed(new_text: String) -> void:
	confirm_button.disabled = new_text.strip_edges().is_empty()


func _on_confirm() -> void:
	if _selected_topic == null:
		return
	var game_name := game_name_input.text.strip_edges()
	if game_name.is_empty():
		game_name = "未命名项目"

	# 写入局数据
	GameManager.run_data["topic"] = String(_selected_topic.id)
	GameManager.run_data["game_name"] = game_name

	# 初始化AI竞品
	AICompetitors.init_competitors(_selected_topic.id)

	# 发射信号
	EventBus.topic_selected.emit(String(_selected_topic.id), game_name)

	# 状态转移到研发阶段
	GameManager.transition_to(GameManager.GameState.DEV_RUNNING)


func _on_heat_updated() -> void:
	for card in _cards:
		card.refresh_heat()
