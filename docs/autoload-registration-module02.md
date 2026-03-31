# 模块02 Autoload 注册说明

请在 `project.godot` 的 `[autoload]` 区段添加以下行（注意顺序：放在 GameManager 之前，因为 EconomyManager 依赖 Config 和 EventBus，但被 GameManager 的场景使用）：

```ini
EconomyManager="*res://scripts/autoload/economy_manager.gd"
```

完整的 autoload 区段应为：

```ini
[autoload]

Config="*res://scripts/autoload/config.gd"
EventBus="*res://scripts/autoload/event_bus.gd"
TimeManager="*res://scripts/autoload/time_manager.gd"
EconomyManager="*res://scripts/autoload/economy_manager.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
```

**注意：** EconomyManager 必须在 GameManager 之前加载，因为 `economy_manager.gd` 的 `set_loadout()` 方法会写入 `GameManager.run_data`，需要 GameManager 已初始化。但由于 Godot Autoload 的加载顺序是从上到下，EconomyManager 放在 GameManager 前面可以确保 Config 和 EventBus 已经可用。实际调用 `set_loadout()` 时 GameManager 也已经初始化完毕（发生在玩家交互时，而非 `_ready` 时）。
