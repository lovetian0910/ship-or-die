# playtest_popup.gd — 游戏展弹窗（揭示竞品品质）
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
		"是否参加游戏展？\n\n"
		+ "花费 [b]%d个月[/b] 带队参展，实地考察同行作品。\n\n"
		+ "参展后将揭示所有竞品的 [color=yellow]真实品质等级[/color]，\n"
		+ "帮助你更准确地判断市场竞争格局。"
	) % [month_cost]

	cost_label.text = "消耗时间：%d个月 | 剩余：%d个月" % [month_cost, remaining_months]

	# 时间不够则警告
	if remaining_months <= month_cost:
		cost_label.add_theme_color_override("font_color", Color.RED)
		cost_label.text += "  [!] 时间紧张！"
