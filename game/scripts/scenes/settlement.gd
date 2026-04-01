# settlement.gd — 结算场景（成功/失败分支，逐条Tween动画）
extends Control

## ===== 常量 =====
const ITEM_SLIDE_DURATION: float = 0.35
const ITEM_INTERVAL: float = 0.8
const NUMBER_ROLL_DURATION: float = 0.8
const BUTTON_FADE_DURATION: float = 0.3

## 失败标题变体
const FAIL_TITLES: Array[String] = [
	"开发超期，项目流产",
	"投资人的耐心比你的工期先耗尽了",
	"恭喜你成功模拟了行业95%项目的结局",
]
## 失败副标题
const FAIL_SUBTITLES: Array[String] = [
	"又一个死在Alpha的好点子。你并不孤独，这条路上尸骨遍地。",
	"他的钱还在，只是不给你了。",
	"你不是失败了，你只是体验了完整的游戏开发流程。",
]

## 成功标题变体
const SUCCESS_TITLES: Array[String] = [
	"恭喜，你的游戏活着上线了！",
	"《%s》正式发售！",
	"它上线了，而且没有崩服！",
]
const SUCCESS_SUBTITLES: Array[String] = [
	"在这个行业，这已经比大多数项目强了。",
	"别想什么编辑推荐了，但至少上架了。",
	"技术总监哭了，是喜极而泣那种。",
]

## 资源损失文案模板 { category_key: { tier: text } }
const LOSS_COPY: Dictionary = {
	"creator": {
		1: "他回去继续写博客了，标题是《资本毁了游戏》。",
		2: "他发了条朋友圈：'人生需要沉淀'，然后更新了领英。",
		3: "他说'这个项目配不上我'，然后头也不回地走了。",
	},
	"outsource": {
		1: "他们倒是无所谓，反正下学期还有新的甲方。",
		2: "他们在群里发了最后一条消息：'好的收到，祝好。'",
		3: "他们十分钟后就接了新单。你的项目只是他们日程表上一个已删除的条目。",
	},
	"business": {
		1: "他在朋友圈写了一段感悟，获得了3个赞，其中一个是他妈。",
		2: "他说'没关系，做人留一线'，然后把你从'重要客户'群移到了'普通联系人'。",
		3: "他只是叹了口气。在他的职业生涯里，你的失败排不进前一百。",
	},
}

## 资源显示名 { category_key: { tier: name } }
const RESOURCE_NAMES: Dictionary = {
	"creator": {
		1: "独立游戏愤青",
		2: "鹅皇互娱主创",
		3: "天命堂制作人",
	},
	"outsource": {
		1: "大学生兼职组",
		2: "外包铁军",
		3: "越南闪电队",
	},
	"business": {
		1: "实习商务",
		2: "万能商务",
		3: "前渠道教父",
	},
}

## 资源图标 emoji（用于 emoji_bbcode 转换为内嵌图标）
const RESOURCE_ICONS: Dictionary = {
	"creator": "🧑‍💻",
	"outsource": "🏭",
	"business": "🤝",
}

## ===== 节点引用 =====
@onready var dim_bg: ColorRect = %DimBackground
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var content_list: VBoxContainer = %ContentList
@onready var separator: HSeparator = %Separator
@onready var total_label: Label = %TotalLabel
@onready var _money_label_placeholder: Label = %MoneyLabel
@onready var retry_btn: Button = %RetryBtn
@onready var menu_btn: Button = %MenuBtn

## 运行时替换为 RichTextLabel（支持内嵌图标）
var money_label: RichTextLabel

var _rolling_value: int = 0


func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)
	menu_btn.pressed.connect(_on_menu)

	# 将 MoneyLabel 替换为 RichTextLabel（支持 BBCode 内嵌图标）
	money_label = RichTextLabel.new()
	money_label.bbcode_enabled = true
	money_label.fit_content = true
	money_label.scroll_active = false
	money_label.add_theme_font_size_override("normal_font_size", 18)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var parent: Node = _money_label_placeholder.get_parent()
	var idx: int = _money_label_placeholder.get_index()
	parent.add_child(money_label)
	parent.move_child(money_label, idx)
	_money_label_placeholder.queue_free()

	_hide_all()

	# 判断成功/失败
	var is_success: bool = GameManager.run_data.get("_settlement_success", false) as bool

	# 设置背景图
	_setup_background("success" if is_success else "failure")

	if is_success:
		_setup_success()
	else:
		_setup_failure()


## ===== 隐藏所有元素 =====
func _hide_all() -> void:
	dim_bg.color.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	separator.modulate.a = 0.0
	total_label.modulate.a = 0.0
	money_label.modulate.a = 0.0
	retry_btn.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	retry_btn.disabled = true
	menu_btn.disabled = true


## =====================================================
## 成功结算
## =====================================================
func _setup_success() -> void:
	var game_name: String = str(GameManager.run_data.get("game_name", "未命名"))
	var result: Dictionary = GameManager.run_data.get("_settlement_result", {}) as Dictionary
	var earnings: int = int(GameManager.run_data.get("_settlement_earnings", 0))
	var current_money: int = int(GameManager.persistent_data.get("money", 0))

	# 标题
	var variant_idx: int = randi() % SUCCESS_TITLES.size()
	var raw_title: String = SUCCESS_TITLES[variant_idx]
	if raw_title.find("%s") >= 0:
		title_label.text = raw_title % game_name
	else:
		title_label.text = raw_title
	subtitle_label.text = SUCCESS_SUBTITLES[variant_idx]

	# 预创建收益条目
	var breakdown: Array = result.get("breakdown", []) as Array
	var item_nodes: Array[Control] = []

	# 市场份额争夺板块
	var share_section: VBoxContainer = _create_share_battle_section(result)
	if share_section != null:
		content_list.add_child(share_section)
		share_section.modulate.a = 0.0
		item_nodes.append(share_section)

	for entry: Variant in breakdown:
		var entry_dict: Dictionary = entry as Dictionary
		var item: HBoxContainer = _create_success_item(entry_dict)
		content_list.add_child(item)
		item.modulate.a = 0.0
		item_nodes.append(item)

	# 预填文字
	total_label.text = "本局总收入：¥0"
	money_label.text = "%s 当前金钱：¥%s" % [AssetRegistry.emoji_bbcode("💰"), Config.format_money(current_money)]

	# ---- Tween 动画编排 ----
	var tween: Tween = create_tween()

	# 遮罩淡入
	tween.tween_property(dim_bg, "color:a", 0.6, 0.3).from(0.0)

	# 标题
	tween.tween_interval(0.2)
	tween.tween_callback(_make_fade_in_cb.bind(title_label, Vector2(0, -20)))

	# 副标题
	tween.tween_interval(0.6)
	tween.tween_callback(_make_fade_in_cb.bind(subtitle_label, Vector2(0, -10)))

	# 逐条收益
	tween.tween_interval(0.6)
	for i: int in item_nodes.size():
		var node: Control = item_nodes[i]
		tween.tween_callback(_make_fade_in_cb.bind(node, Vector2(-30, 0)))
		if i < item_nodes.size() - 1:
			tween.tween_interval(ITEM_INTERVAL)

	# 分割线
	tween.tween_interval(ITEM_INTERVAL)
	tween.tween_callback(func() -> void: separator.modulate.a = 1.0)

	# 总收入数字滚动
	tween.tween_interval(0.2)
	tween.tween_callback(func() -> void: total_label.modulate.a = 1.0)
	_rolling_value = 0
	tween.tween_method(_update_success_total, 0, earnings, NUMBER_ROLL_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 当前金钱
	tween.tween_interval(0.6)
	tween.tween_callback(_make_fade_in_cb.bind(money_label, Vector2(0, 10)))

	# 按钮
	tween.tween_interval(0.6)
	tween.tween_callback(_show_buttons)


## =====================================================
## 失败结算
## =====================================================
func _setup_failure() -> void:
	var current_money: int = int(GameManager.persistent_data.get("money", 0))

	# 标题
	var variant_idx: int = randi() % FAIL_TITLES.size()
	title_label.text = FAIL_TITLES[variant_idx]
	subtitle_label.text = FAIL_SUBTITLES[variant_idx]

	# 收集入场资源数据
	var resources_info: Array[Dictionary] = _collect_resource_info()
	var total_loss: int = 0
	for res: Dictionary in resources_info:
		total_loss += int(res.get("cost", 0))

	# 预创建资源条目
	var item_nodes: Array[Control] = []
	for res: Dictionary in resources_info:
		var item: HBoxContainer = _create_failure_item(res)
		content_list.add_child(item)
		item.modulate.a = 0.0
		item_nodes.append(item)

	# 总计损失文案（随机选一条）
	var loss_quips: Array[String] = [
		"总计损失：¥%s——够在大城市交两个月车位租金了。" % Config.format_money(total_loss),
		"总计损失：¥%s——这些钱本来可以买%d杯奶茶。" % [Config.format_money(total_loss), total_loss / 30],
	]
	total_label.text = "总计损失：¥0"
	money_label.text = "%s 剩余金钱：¥%s" % [AssetRegistry.emoji_bbcode("💰"), Config.format_money(current_money)]

	# ---- Tween 动画编排 ----
	var tween: Tween = create_tween()

	# 遮罩淡入
	tween.tween_property(dim_bg, "color:a", 0.7, 0.3).from(0.0)

	# 标题（红色）
	tween.tween_interval(0.3)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
	tween.tween_callback(_make_fade_in_cb.bind(title_label, Vector2(0, -20)))

	# 副标题
	tween.tween_interval(0.7)
	tween.tween_callback(_make_fade_in_cb.bind(subtitle_label, Vector2(0, -10)))

	# 逐条资源 + 损失标记
	tween.tween_interval(0.6)
	for i: int in item_nodes.size():
		var node: Control = item_nodes[i]
		var loss_mark: Label = node.get_node("LossMark") as Label

		# 资源条从左滑入
		tween.tween_callback(_make_fade_in_cb.bind(node, Vector2(-40, 0)))

		# 0.5s后标红
		tween.tween_interval(0.5)
		tween.tween_callback(_animate_loss_mark.bind(loss_mark))

		# 下一条间隔
		if i < item_nodes.size() - 1:
			tween.tween_interval(ITEM_INTERVAL - 0.5)

	# 分割线
	tween.tween_interval(ITEM_INTERVAL)
	tween.tween_callback(func() -> void: separator.modulate.a = 1.0)

	# 总计损失数字滚动
	tween.tween_interval(0.2)
	tween.tween_callback(func() -> void: total_label.modulate.a = 1.0)
	total_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
	var final_quip: String = loss_quips[randi() % loss_quips.size()]
	tween.tween_method(_update_fail_total.bind(total_loss, final_quip), 0, total_loss, NUMBER_ROLL_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 剩余金钱
	tween.tween_interval(0.6)
	tween.tween_callback(_make_fade_in_cb.bind(money_label, Vector2(0, 10)))

	# 按钮
	tween.tween_interval(0.6)
	tween.tween_callback(_show_buttons)


## =====================================================
## 工具方法
## =====================================================

## 淡入+位移动画
func _fade_slide_in(node: Control, offset: Vector2) -> void:
	var original_pos: Vector2 = node.position
	node.position += offset
	node.modulate.a = 0.0
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 1.0, ITEM_SLIDE_DURATION).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", original_pos, ITEM_SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## 生成可绑定回调（解决 lambda 闭包捕获问题）
func _make_fade_in_cb(node: Control, offset: Vector2) -> void:
	_fade_slide_in(node, offset)


## 已损失标记动画
func _animate_loss_mark(label: Label) -> void:
	label.text = "[已损失]"
	label.modulate = Color(1, 1, 1, 0)
	label.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))

	var t: Tween = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.15)
	t.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)


## 数字滚动：成功总收入
func _update_success_total(value: int) -> void:
	total_label.text = "本局总收入：¥%s" % Config.format_money(value)


## 数字滚动：失败总损失
func _update_fail_total(value: int, final_value: int, final_quip: String) -> void:
	if value >= final_value:
		total_label.text = final_quip
	else:
		total_label.text = "总计损失：¥%s" % Config.format_money(value)


## 按钮淡入
func _show_buttons() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(retry_btn, "modulate:a", 1.0, BUTTON_FADE_DURATION)
	t.tween_property(menu_btn, "modulate:a", 1.0, BUTTON_FADE_DURATION)
	t.chain().tween_callback(func() -> void:
		retry_btn.disabled = false
		menu_btn.disabled = false
	)


## 创建成功结算条目
func _create_success_item(entry: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var label_node := Label.new()
	label_node.text = str(entry.get("label", ""))
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label_node)

	var value_label := Label.new()
	var val: int = int(entry.get("value", 0))
	if val >= 0:
		value_label.text = "+¥%s" % Config.format_money(val)
		value_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	else:
		# 热度加成等非金额行
		value_label.text = str(entry.get("detail", ""))
		value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(value_label)

	return hbox


## 创建失败结算条目
func _create_failure_item(res: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 图标：用 TextureRect 显示图标图片
	var icon_emoji: String = str(res.get("icon", "📦"))
	var icon_name: String = AssetRegistry.EMOJI_ICON_MAP.get(icon_emoji, "") as String
	if icon_name != "":
		var icon_path: String = AssetRegistry.ICON_DIR + icon_name + ".png"
		if ResourceLoader.exists(icon_path) and DisplayServer.get_name() != "headless":
			var tex: Texture2D = load(icon_path) as Texture2D
			if tex:
				var icon_rect := TextureRect.new()
				icon_rect.texture = tex
				icon_rect.custom_minimum_size = Vector2(20, 20)
				icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hbox.add_child(icon_rect)
			else:
				var icon_label := Label.new()
				icon_label.text = icon_emoji
				hbox.add_child(icon_label)
		else:
			var icon_label := Label.new()
			icon_label.text = icon_emoji
			hbox.add_child(icon_label)
	else:
		var icon_label := Label.new()
		icon_label.text = icon_emoji
		hbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = str(res.get("name", "未知"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "¥%s" % Config.format_money(int(res.get("cost", 0)))
	hbox.add_child(cost_label)

	# 损失描述
	var copy_label := Label.new()
	copy_label.text = str(res.get("loss_copy", ""))
	copy_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	copy_label.add_theme_font_size_override("font_size", 15)
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy_label.custom_minimum_size.x = 240
	hbox.add_child(copy_label)

	var loss_mark := Label.new()
	loss_mark.name = "LossMark"
	loss_mark.text = ""
	loss_mark.pivot_offset = Vector2(30, 10)  # 缩放锚点
	hbox.add_child(loss_mark)

	return hbox


## 收集本局入场资源信息
func _collect_resource_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resources: Dictionary = GameManager.run_data.get("resources", {}) as Dictionary
	var price_table: Dictionary = Config.RESOURCE_PRICES

	for category_key: String in ["creator", "outsource", "business"]:
		var tier: int = int(resources.get(category_key, 0))
		if tier <= 0:
			continue

		var price: int = 0
		var cat_prices: Variant = price_table.get(category_key, {})
		if cat_prices is Dictionary:
			price = int((cat_prices as Dictionary).get(tier, 0))

		var res_name: String = ""
		var cat_names: Variant = RESOURCE_NAMES.get(category_key, {})
		if cat_names is Dictionary:
			res_name = str((cat_names as Dictionary).get(tier, "未知"))

		var icon: String = str(RESOURCE_ICONS.get(category_key, "📦"))

		var copy: String = ""
		var cat_copy: Variant = LOSS_COPY.get(category_key, {})
		if cat_copy is Dictionary:
			copy = str((cat_copy as Dictionary).get(tier, ""))

		result.append({
			"icon": icon,
			"name": res_name,
			"cost": price,
			"loss_copy": copy,
		})

	return result


## ===== 按钮回调 =====
func _on_retry() -> void:
	EventBus.settlement_complete.emit("next_run")
	GameManager.start_new_run()
	GameManager.transition_to(GameManager.GameState.ENTRY_SHOP)


func _on_menu() -> void:
	EventBus.settlement_complete.emit("main_menu")
	GameManager.transition_to(GameManager.GameState.MENU)


## ===== 设置背景图 =====
func _setup_background(key: String) -> void:
	var tex: Texture2D = AssetRegistry.get_texture("background", key)
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1, 1, 1, 0.2)
	add_child(bg)
	move_child(bg, 0)


## =====================================================
## 市场份额争夺板块（成功结算专用）
## =====================================================
func _create_share_battle_section(result: Dictionary) -> VBoxContainer:
	var player_quality: float = float(result.get("player_quality", 0.0))
	var player_share: float = float(result.get("player_share_ratio", 0.0))
	var comp_details: Array = result.get("competitor_share_details", []) as Array
	var comp_names: Array = GameManager.run_data.get("_settlement_comp_names", []) as Array
	var window_ratio: float = float(result.get("window_ratio", 0.0))

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	# 标题
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.text = "%s 市场争夺战" % AssetRegistry.emoji_bbcode("📊")
	title.add_theme_font_size_override("normal_font_size", 15)
	title.add_theme_color_override("default_color", Color(0.9, 0.8, 0.3))
	section.add_child(title)

	# 玩家品质
	var player_line := RichTextLabel.new()
	player_line.bbcode_enabled = true
	player_line.fit_content = true
	player_line.scroll_active = false
	player_line.text = "%s 你的品质：%d 分" % [AssetRegistry.emoji_bbcode("🎮"), int(player_quality)]
	player_line.add_theme_font_size_override("normal_font_size", 15)
	player_line.add_theme_color_override("default_color", Color(0.4, 0.9, 0.4))
	section.add_child(player_line)

	# 竞品对比
	for i: int in comp_details.size():
		var detail: Dictionary = comp_details[i] as Dictionary
		var comp_q: float = float(detail.get("quality", 0.0))
		var comp_name: String = ""
		if i < comp_names.size():
			comp_name = str(comp_names[i])
		else:
			comp_name = "竞品%d" % (i + 1)

		var compare_text: String = ""
		if player_quality > comp_q + 15.0:
			compare_text = "← 被你碾压"
		elif player_quality > comp_q + 5.0:
			compare_text = "← 你略胜一筹"
		elif player_quality >= comp_q - 5.0:
			compare_text = "← 势均力敌！"
		elif player_quality >= comp_q - 15.0:
			compare_text = "← 他们稍强"
		else:
			compare_text = "← 被碾压了…"

		var comp_line := Label.new()
		comp_line.text = "vs %s：%d 分  %s" % [comp_name, int(comp_q), compare_text]
		comp_line.add_theme_font_size_override("font_size", 15)
		comp_line.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
		comp_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(comp_line)

	# 份额汇总条
	var share_line := Label.new()
	var player_pct: int = int(player_share * 100.0)
	var share_text: String = "市场份额：你 %d%%" % player_pct
	for i: int in comp_details.size():
		var detail: Dictionary = comp_details[i] as Dictionary
		var comp_pct: int = int(float(detail.get("share_ratio", 0.0)) * 100.0)
		var short_name: String = ""
		if i < comp_names.size():
			short_name = _extract_studio_name(str(comp_names[i]))
		else:
			short_name = "竞品%d" % (i + 1)
		share_text += " | %s %d%%" % [short_name, comp_pct]
	share_line.text = share_text
	share_line.add_theme_font_size_override("font_size", 15)
	share_line.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	share_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(share_line)

	# 空窗期提示
	if window_ratio > 0.01:
		var window_months: int = int(window_ratio * float(Config.TIME_TOTAL_MONTHS))
		var window_hint := RichTextLabel.new()
		window_hint.bbcode_enabled = true
		window_hint.fit_content = true
		window_hint.scroll_active = false
		window_hint.text = "%s 你独占了约 %d 个月的市场空窗期" % [AssetRegistry.emoji_bbcode("⏱️"), window_months]
		window_hint.add_theme_font_size_override("normal_font_size", 14)
		window_hint.add_theme_color_override("default_color", Color(0.5, 0.8, 0.9))
		section.add_child(window_hint)

	# 分隔线
	var sep := HSeparator.new()
	section.add_child(sep)

	return section


## 从完整竞品名字提取制作组名
func _extract_studio_name(full_name: String) -> String:
	var idx: int = full_name.find(" 的 ")
	if idx > 0:
		return full_name.substr(0, idx)
	return full_name
