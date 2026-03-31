# launch_confirm.gd — 上线确认界面
extends Control

## ===== 节点引用 =====
@onready var dim_bg: ColorRect = %DimBackground
@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var quality_label: Label = %QualityLabel
@onready var time_label: Label = %TimeLabel
@onready var heat_label: Label = %HeatLabel
@onready var competitor_label: Label = %CompetitorLabel
@onready var confirm_btn: Button = %ConfirmBtn
@onready var cancel_btn: Button = %CancelBtn

## ===== 新增：竞品详情与份额预估 =====
@onready var competitor_detail_box: VBoxContainer = %CompetitorDetailBox
@onready var pending_label: Label = %PendingLabel
@onready var share_bar_fill: ColorRect = %ShareBarFill
@onready var share_label: Label = %ShareLabel
@onready var share_hint: Label = %ShareHint


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	cancel_btn.pressed.connect(_on_cancel)
	_populate_summary()


## ===== 填充状态摘要 =====
func _populate_summary() -> void:
	title_label.text = "真的要上线了？"
	desc_label.text = "你即将把你的心血推向市场，接受全赛道的审判。"

	# 品质（模糊/真实取决于是否做过内测）
	var did_playtest: bool = GameManager.run_data.get("did_playtest", false) as bool
	var quality: float = float(GameManager.run_data.get("quality", 0.0))
	if did_playtest:
		quality_label.text = "品质：%d 分" % int(quality)
	else:
		quality_label.text = "品质：%s" % _get_fuzzy_quality(quality)

	# 剩余时间
	var remaining: int = TimeManager.get_remaining()
	time_label.text = "剩余时间：%d 个月" % remaining

	# 市场热度
	var topic_id: StringName = StringName(str(GameManager.run_data.get("topic", "")))
	var heat_text: String = MarketHeat.get_fuzzy_text(topic_id)
	var heat_color: Color = MarketHeat.get_fuzzy_color(topic_id)
	heat_label.text = "市场热度：%s" % heat_text
	heat_label.add_theme_color_override("font_color", heat_color)

	# 已上线竞品数 + 详情列表
	var launched_count: int = 0
	var pending_count: int = 0
	var comp_qualities: Array = []
	for comp: AICompetitorData in AICompetitors.get_competitors():
		if comp.launched:
			launched_count += 1
			comp_qualities.append(comp.quality)
			# 添加竞品详情条目
			var detail := Label.new()
			var quality_hint: String = AICompetitors.get_fuzzy_quality_text(comp.quality)
			detail.text = "  · %s — %s" % [comp.competitor_name, quality_hint]
			detail.add_theme_font_size_override("font_size", 13)
			detail.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			competitor_detail_box.add_child(detail)
		else:
			pending_count += 1
	competitor_label.text = "已上线竞品：%d 款" % launched_count

	# 未上线竞品提示
	if pending_count > 0:
		pending_label.text = "⚡ 未上线竞品：%d 家（还在潜伏）" % pending_count
	else:
		pending_label.text = ""

	# 市场份额预估
	var player_quality: float = float(GameManager.run_data.get("quality", 0.0))
	_update_share_estimate(player_quality, comp_qualities)


## ===== 模糊品质映射 =====
func _get_fuzzy_quality(score: float) -> String:
	if score >= 80.0:
		return "薛定谔的品质：感觉还不错"
	elif score >= 50.0:
		return "薛定谔的品质：中规中矩吧"
	else:
		return "薛定谔的品质：不测不知道"


## ===== 确认上线 =====
func _on_confirm() -> void:
	# 收集结算参数
	var topic_id: StringName = StringName(str(GameManager.run_data.get("topic", "")))
	var player_quality: float = float(GameManager.run_data.get("quality", 0.0))
	var heat: float = MarketHeat.get_heat(topic_id)

	# 计算空窗期比例：玩家上线月份之前已上线竞品占总时间比例
	var elapsed: int = TimeManager.elapsed_months
	var total: int = TimeManager.total_months
	var window_ratio: float = _calc_window_ratio(topic_id, elapsed, total)

	# 收集已上线竞品品质和名字
	var comp_qualities: Array = []
	var comp_names: Array = []
	for comp: AICompetitorData in AICompetitors.get_competitors():
		if comp.launched:
			comp_qualities.append(comp.quality)
			comp_names.append(comp.competitor_name)

	# 生成随机市场参数（每局固定种子，Demo简化：直接随机）
	var total_users: int = randi_range(1000, 5000)
	var pay_ability: float = randf_range(0.5, 2.0)

	var result: Dictionary = SettlementCalculator.calculate({
		"total_users": total_users,
		"pay_ability": pay_ability,
		"window_ratio": window_ratio,
		"heat": heat,
		"player_quality": player_quality,
		"competitor_qualities": comp_qualities,
	})

	var earnings: int = int(result.get("total_revenue", 0))

	# 写入结算数据供 settlement 场景读取
	GameManager.run_data["_settlement_success"] = true
	GameManager.run_data["_settlement_result"] = result
	GameManager.run_data["_settlement_earnings"] = earnings
	GameManager.run_data["_settlement_comp_names"] = comp_names

	# 调用 GameManager 结算
	GameManager.end_run_success(earnings)
	GameManager.transition_to(GameManager.GameState.SETTLEMENT)


## ===== 取消返回研发 =====
func _on_cancel() -> void:
	GameManager.transition_to(GameManager.GameState.DEV_RUNNING)


## ===== 计算空窗期比例 =====
## 玩家上线时，距离最近的已上线竞品之间的月份间隔 / 总月份
func _calc_window_ratio(topic_id: StringName, elapsed_months: int, total_months_count: int) -> float:
	if total_months_count <= 0:
		return 0.0

	# 找最晚上线的竞品月份（在玩家之前）
	var latest_comp_month: int = 0
	var any_launched: bool = false
	for comp: AICompetitorData in AICompetitors.get_competitors():
		if comp.launched and comp.planned_launch_month < elapsed_months:
			if comp.planned_launch_month > latest_comp_month:
				latest_comp_month = comp.planned_launch_month
				any_launched = true

	if not any_launched:
		# 无竞品上线 → 从0到玩家上线月全是空窗
		return clampf(float(elapsed_months) / float(total_months_count), 0.0, 1.0)

	var gap: int = elapsed_months - latest_comp_month
	return clampf(float(gap) / float(total_months_count), 0.0, 1.0)


## ===== 市场份额预估 =====
func _update_share_estimate(player_quality: float, comp_qualities: Array) -> void:
	# 简化份额估算：品质权重分配（与结算公式一致）
	var total_quality: float = player_quality
	for q: Variant in comp_qualities:
		total_quality += float(q)

	var share_ratio: float = 0.0
	if total_quality > 0.0:
		share_ratio = player_quality / total_quality
	elif player_quality <= 0.0 and comp_qualities.is_empty():
		share_ratio = 1.0  # 无竞品无品质 = 100%
	else:
		share_ratio = 1.0  # 无竞品 = 100%

	# 加模糊偏差（±5%）让玩家不能精确计算
	var display_ratio: float = clampf(share_ratio + randf_range(-0.05, 0.05), 0.0, 1.0)
	var percent: int = int(display_ratio * 100.0)

	# 更新进度条
	var bar_parent: ColorRect = share_bar_fill.get_parent() as ColorRect
	var bar_width: float = bar_parent.custom_minimum_size.x
	if bar_width <= 0.0:
		bar_width = 450.0  # fallback
	share_bar_fill.offset_right = bar_width * display_ratio

	# 更新标签
	share_label.text = "~%d%%" % percent

	# 颜色反馈
	if display_ratio >= 0.5:
		share_bar_fill.color = Color(0.2, 0.8, 0.3, 0.85)
		share_hint.text = "市场份额可观，可以考虑上线"
	elif display_ratio >= 0.3:
		share_bar_fill.color = Color(0.9, 0.8, 0.2, 0.85)
		share_hint.text = "份额中等，提升品质能争取更多"
	else:
		share_bar_fill.color = Color(0.9, 0.3, 0.2, 0.85)
		share_hint.text = "份额偏低，竞争激烈，请三思"
