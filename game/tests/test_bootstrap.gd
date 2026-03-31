# test_bootstrap.gd — 测试启动器，挂在独立场景，等 main 场景就绪后注入测试
extends Node

const TestRunnerScript: GDScript = preload("res://tests/test_runner.gd")

func _ready() -> void:
	# 等一帧确保 main 场景加载完毕
	await get_tree().process_frame
	await get_tree().process_frame

	# 在根节点创建测试 runner
	var runner := Node.new()
	runner.name = "TestRunner"
	runner.set_script(TestRunnerScript)
	get_tree().root.add_child(runner)
