# main.gd — 根场景脚本
extends Node

@onready var scene_container: Node = $SceneContainer
@onready var money_label: Label = $PersistentUI/TopBar/MoneyLabel
@onready var phase_label: Label = $PersistentUI/TopBar/PhaseLabel
@onready var time_bar: Control = $PersistentUI/TopBar/TimeBar


func _ready() -> void:
	GameManager.setup(scene_container)

	EventBus.state_changed.connect(_on_state_changed)
	EventBus.dev_phase_changed.connect(_on_dev_phase_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.money_changed.connect(_on_money_changed)

	# 初始状态：隐藏研发UI
	time_bar.visible = false
	phase_label.visible = false
	_update_money_display()


func _on_state_changed(_from: StringName, to: StringName) -> void:
	var show_dev_ui: bool = (to == "DEV_RUNNING")
	time_bar.visible = show_dev_ui
	phase_label.visible = show_dev_ui
	_update_money_display()


func _on_dev_phase_changed(new_phase: StringName) -> void:
	var phase_names: Dictionary = {
		&"early": "前期开发",
		&"mid": "中期开发",
		&"late": "后期冲刺",
	}
	phase_label.text = phase_names.get(new_phase, "")


func _on_run_started() -> void:
	_update_money_display()


func _on_money_changed(_new_amount: int) -> void:
	_update_money_display()


func _update_money_display() -> void:
	money_label.text = "$ %d" % GameManager.persistent_data.get("money", 0)
