# playtest_popup.gd — 内测验证弹窗
extends PanelContainer

signal accepted()
signal skipped()

@onready var desc_label: RichTextLabel = %PlaytestDesc
@onready var cost_label: Label = %PlaytestCostLabel
@onready var accept_btn: Button = %PlaytestAcceptBtn
@onready var skip_btn: Button = %PlaytestSkipBtn


func _ready() -> void:
	accept_btn.pressed.connect(func() -> void: accepted.emit())
	skip_btn.pressed.connect(func() -> void: skipped.emit())


func setup(month_cost: int, current_grade_name: String, remaining_months: int) -> void:
	desc_label.text = (
		"是否进行内测验证？\n\n"
		+ "花费 [b]%d个月[/b] 进行内测，揭示真实品质等级。\n\n"
		+ "当前品质评估：[b]%s[/b]（可能有偏差）\n\n"
		+ "内测将揭示 [color=yellow]真实品质等级[/color]，"
		+ "帮助你做出更准确的上线决策。"
	) % [month_cost, current_grade_name]

	cost_label.text = "消耗时间：%d个月 | 剩余：%d个月" % [month_cost, remaining_months]

	# 时间不够则警告
	if remaining_months <= month_cost:
		cost_label.add_theme_color_override("font_color", Color.RED)
		cost_label.text += "  [!] 时间紧张！"
