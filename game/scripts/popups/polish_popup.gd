# polish_popup.gd — 临上线打磨弹窗（含bug二次选择）
extends PanelContainer

signal accepted()
signal skipped()
signal bug_fix_chosen()
signal bug_ignore_chosen()

@onready var main_panel: VBoxContainer = %PolishMainPanel
@onready var bug_panel: VBoxContainer = %PolishBugPanel

## 主面板
@onready var desc_label: RichTextLabel = %PolishDesc
@onready var odds_label: Label = %PolishOddsLabel
@onready var cost_label: Label = %PolishCostLabel
@onready var accept_btn: Button = %PolishAcceptBtn
@onready var skip_btn: Button = %PolishSkipBtn

## Bug二次选择面板
@onready var bug_desc: RichTextLabel = %BugDesc
@onready var fix_btn: Button = %BugFixBtn
@onready var ignore_btn: Button = %BugIgnoreBtn


func _ready() -> void:
	accept_btn.pressed.connect(func() -> void: accepted.emit())
	skip_btn.pressed.connect(func() -> void: skipped.emit())
	fix_btn.pressed.connect(func() -> void: bug_fix_chosen.emit())
	ignore_btn.pressed.connect(func() -> void: bug_ignore_chosen.emit())

	# 初始状态：显示主面板，隐藏bug面板
	bug_panel.visible = false


func setup(
	month_cost: int,
	success_chance: float,
	quality_boost: float,
	bug_penalty: float,
	bug_fix_months: int,
	grade_name: String,
	remaining_months: int
) -> void:
	var remaining_years: int = remaining_months / 12
	var remaining_m: int = remaining_months % 12
	var time_str: String = ""
	if remaining_years > 0:
		time_str = "%d年%d个月" % [remaining_years, remaining_m]
	else:
		time_str = "%d个月" % remaining_m

	desc_label.text = (
		"是否进行最终打磨？\n\n"
		+ "当前品质：[b]%s[/b]\n"
		+ "剩余时间：[b]%s[/b]\n\n"
		+ "花费 [b]%d个月[/b] 进行打磨。"
	) % [grade_name, time_str, month_cost]

	odds_label.text = "%d%%：品质+%.0f  |  %d%%：发现严重bug" % [
		int(success_chance * 100.0),
		quality_boost,
		int((1.0 - success_chance) * 100.0),
	]

	cost_label.text = "消耗时间：%d个月" % month_cost

	if remaining_months <= month_cost:
		cost_label.add_theme_color_override("font_color", Color.RED)
		cost_label.text += "  [!] 时间紧张！"


## 打磨失败时，切换到bug二次选择面板
func show_bug_choice(fix_months: int, penalty: float, remaining_months: int) -> void:
	main_panel.visible = false
	bug_panel.visible = true

	var will_expire: bool = remaining_months < fix_months
	var expire_warning: String = ""
	if will_expire:
		expire_warning = "\n\n[color=red][!] 警告：当前剩余时间不足以完成修复，选择修复将导致时间耗尽！[/color]"

	bug_desc.text = (
		"打磨过程中发现 [color=red][b]严重Bug[/b][/color]！\n\n"
		+ "你有两个选择：%s"
	) % expire_warning

	fix_btn.text = "紧急修复（消耗%d个月）" % fix_months
	ignore_btn.text = "放弃修复（品质-%.0f分）" % penalty

	if will_expire:
		fix_btn.add_theme_color_override("font_color", Color.RED)
