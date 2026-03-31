# 模块01：核心框架与时间系统 — Godot 4.6.1 实施方案

> 对应规格：`docs/specs/modules/01-core-framework.md`
> 技术栈：**Godot 4.6.1 + GDScript**
> 预估总工时：**4-5小时**
> 优先级：P0（所有模块的骨架，必须第一个完成）

---

## 一、架构设计总览

### 设计原则
- **用 Godot 的原生能力，不手造轮子**：Autoload 做全局单例，Signal 做模块通信，SceneTree 做场景管理
- **4天红线**：只搭骨架，不做花活。能用内置节点解决的绝不自己写
- **enum + match 状态机**：GDScript 原生支持，零开销，调试直观

### 核心架构图

```
Autoload 单例层（项目启动时自动加载）
├── GameManager     # 状态机 + 场景调度 + 局数据
├── TimeManager     # 倒计时 + 暂停/恢复 + 阶段判定
├── EventBus        # 全局信号中转站
└── Config          # 数值配置常量

场景层（按需加载/切换）
├── MainMenu        # 主菜单
├── EntryShop       # 入场选购
├── TopicSelect     # 选题
├── DevRunning      # 研发流程（核心场景，最复杂）
├── LaunchConfirm   # 上线确认
└── Settlement      # 结算
```

---

## 二、Godot 项目目录结构

```
game/
├── project.godot                      # Godot 项目配置（注册 Autoload）
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd            # 主状态机 + 局数据 + 场景调度
│   │   ├── time_manager.gd            # 时间系统
│   │   ├── event_bus.gd               # 全局信号总线
│   │   └── config.gd                  # 数值配置
│   ├── ui/
│   │   └── time_bar.gd                # 时间条 UI 组件脚本
│   └── base/
│       └── base_scene.gd              # 场景基类（可选，提供通用接口）
├── scenes/
│   ├── main.tscn                      # 根场景（永驻层 + 场景容器）
│   ├── main_menu.tscn                 # 主菜单场景
│   ├── entry_shop.tscn                # 入场选购场景
│   ├── topic_select.tscn              # 选题场景
│   ├── dev_running.tscn               # 研发流程场景
│   ├── launch_confirm.tscn            # 上线确认场景
│   └── settlement.tscn                # 结算场景
├── resources/
│   └── game_data.tres                 # （预留）局运行时数据 Resource（如需持久化）
└── export/
    └── （导出配置）
```

### project.godot 中的 Autoload 注册顺序

```ini
[autoload]
Config="*res://scripts/autoload/config.gd"
EventBus="*res://scripts/autoload/event_bus.gd"
TimeManager="*res://scripts/autoload/time_manager.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
```

> 顺序很重要：Config 和 EventBus 无依赖，先加载；TimeManager 依赖 EventBus；GameManager 依赖前三者。

---

## 三、核心文件职责与代码结构

### 3.1 `event_bus.gd` — 全局信号总线

**职责：** 所有跨模块通信的中枢。利用 Godot 原生 signal 机制，任何脚本通过 `EventBus.xxx.emit()` 和 `EventBus.xxx.connect()` 通信。

```gdscript
# event_bus.gd
extends Node

## ===== 状态机信号 =====
signal state_changed(from_state: StringName, to_state: StringName)

## ===== 时间系统信号 =====
signal time_tick(remaining: float, elapsed: float, total: float)
signal time_warning(remaining: float)       # 剩余 < 20%
signal time_expired()                        # 时间耗尽
signal time_paused()
signal time_resumed()

## ===== 研发阶段信号 =====
signal dev_phase_changed(new_phase: StringName)  # "early" / "mid" / "late"

## ===== 局生命周期信号 =====
signal run_started()                         # 新局开始
signal run_ended(success: bool, earnings: int)  # 局结束

## ===== 预留：其他模块将在此扩展 =====
# signal event_triggered(event_data: Dictionary)
# signal market_updated(market_data: Dictionary)
# signal quality_changed(new_quality: float)
```

> **为什么用集中式信号而不是各节点自己 emit？**
> 4天项目，模块间需要快速互联。集中式避免"信号在哪定义的"这种查找成本。所有信号一个文件看完。

---

### 3.2 `config.gd` — 数值配置

**职责：** 所有可调数值集中管理，方便后期调参。

```gdscript
# config.gd
extends Node

## ===== 时间系统 =====
const TIME_LIMIT: float = 300.0              # 局时间上限（秒）
const TIME_WARNING_THRESHOLD: float = 0.2    # 剩余20%触发警告
const TIME_TICK_INTERVAL: float = 1.0        # tick间隔（秒）

## ===== 研发阶段划分（按已消耗时间的比例）=====
const PHASE_EARLY_END: float = 0.3           # 0~30% = 前期
const PHASE_MID_END: float = 0.7             # 30~70% = 中期, 70%+ = 后期

## ===== 经济 =====
const INITIAL_MONEY: int = 100               # 初始金钱
const MIN_MONEY: int = 20                    # 保底金钱

## ===== 外包效率对时间消耗的乘数 =====
const OUTSOURCE_SPEED: Dictionary = {
    1: 1.0,    # 大学生兼职组：标准速度
    2: 0.8,    # 外包铁军：探索/事件耗时×0.8
    3: 0.6,    # 越南闪电队：探索/事件耗时×0.6
}

## ===== 入场资源价格（参考值，模块02会细化）=====
const RESOURCE_PRICES: Dictionary = {
    "creator":   { 1: 10, 2: 25, 3: 50 },
    "outsource": { 1: 10, 2: 25, 3: 50 },
    "business":  { 1: 10, 2: 25, 3: 50 },
}
```

---

### 3.3 `game_manager.gd` — 主状态机 + 局数据 + 场景调度

**职责：** 游戏的大脑。管理状态流转、场景切换、局运行时数据。

```gdscript
# game_manager.gd
extends Node

## ===== 游戏主状态枚举 =====
enum GameState {
    MENU,
    ENTRY_SHOP,
    TOPIC_SELECT,
    DEV_RUNNING,
    LAUNCH_CONFIRM,
    SETTLEMENT,
}

## ===== 合法状态转移表 =====
const TRANSITIONS: Dictionary = {
    GameState.MENU:           [GameState.ENTRY_SHOP],
    GameState.ENTRY_SHOP:     [GameState.TOPIC_SELECT],
    GameState.TOPIC_SELECT:   [GameState.DEV_RUNNING],
    GameState.DEV_RUNNING:    [GameState.LAUNCH_CONFIRM, GameState.SETTLEMENT],
    GameState.LAUNCH_CONFIRM: [GameState.SETTLEMENT, GameState.DEV_RUNNING],
    GameState.SETTLEMENT:     [GameState.MENU, GameState.ENTRY_SHOP],
}

## ===== 场景路径映射 =====
const SCENE_PATHS: Dictionary = {
    GameState.MENU:           "res://scenes/main_menu.tscn",
    GameState.ENTRY_SHOP:     "res://scenes/entry_shop.tscn",
    GameState.TOPIC_SELECT:   "res://scenes/topic_select.tscn",
    GameState.DEV_RUNNING:    "res://scenes/dev_running.tscn",
    GameState.LAUNCH_CONFIRM: "res://scenes/launch_confirm.tscn",
    GameState.SETTLEMENT:     "res://scenes/settlement.tscn",
}

## ===== 当前状态 =====
var current_state: GameState = GameState.MENU

## ===== 局运行时数据（每局重置）=====
var run_data: Dictionary = {}

## ===== 跨局持久数据 =====
var persistent_data: Dictionary = {
    "money": Config.INITIAL_MONEY,
    "total_runs": 0,
}

## ===== 场景容器引用（main.tscn 中的节点）=====
var _scene_container: Node = null
var _current_scene_instance: Node = null


func _ready() -> void:
    # 连接时间耗尽信号 → 强制失败结算
    EventBus.time_expired.connect(_on_time_expired)
    # main.tscn 加载后由 main.tscn 脚本调用 setup()


## ===== 初始化（由 main.tscn 调用）=====
func setup(scene_container: Node) -> void:
    _scene_container = scene_container
    _load_scene(GameState.MENU)


## ===== 状态转移 =====
func transition_to(next_state: GameState) -> bool:
    var allowed: Array = TRANSITIONS.get(current_state, [])
    if next_state not in allowed:
        push_warning("非法状态转移: %s → %s" % [
            GameState.keys()[current_state],
            GameState.keys()[next_state]
        ])
        return false

    var from_state := current_state
    current_state = next_state

    # 发射全局信号
    EventBus.state_changed.emit(
        GameState.keys()[from_state],
        GameState.keys()[next_state]
    )

    # 切换场景
    _load_scene(next_state)

    # 状态进入时的特殊逻辑
    match next_state:
        GameState.DEV_RUNNING:
            TimeManager.start_timer()
        GameState.SETTLEMENT:
            TimeManager.stop_timer()

    return true


## ===== 场景切换（手动管理，不用 change_scene）=====
func _load_scene(state: GameState) -> void:
    # 移除旧场景
    if _current_scene_instance:
        _current_scene_instance.queue_free()
        _current_scene_instance = null

    # 加载新场景
    var scene_path: String = SCENE_PATHS.get(state, "")
    if scene_path.is_empty():
        push_error("未找到状态 %s 对应的场景路径" % GameState.keys()[state])
        return

    var packed_scene := load(scene_path) as PackedScene
    if not packed_scene:
        push_error("场景加载失败: %s" % scene_path)
        return

    _current_scene_instance = packed_scene.instantiate()
    _scene_container.add_child(_current_scene_instance)


## ===== 新局初始化 =====
func start_new_run() -> void:
    persistent_data["total_runs"] += 1
    run_data = {
        "money": persistent_data["money"],
        "resources": {
            "creator": 0,      # 主创等级 1/2/3，0=未选
            "outsource": 0,    # 外包等级
            "business": 0,     # 商务等级
        },
        "topic": "",           # 选中题材
        "game_name": "",       # 玩家自定义游戏名
        "quality": 0.0,        # 品质分（隐藏）
        "quality_cap": 0.0,    # 品质上限
        "dev_phase": "early",  # 当前阶段
        "did_playtest": false, # 是否做了内测
        "did_polish": false,   # 是否做了打磨
    }
    EventBus.run_started.emit()


## ===== 局结算：成功 =====
func end_run_success(earnings: int) -> void:
    persistent_data["money"] = run_data["money"] + earnings
    EventBus.run_ended.emit(true, earnings)


## ===== 局结算：失败 =====
func end_run_fail() -> void:
    # 金钱已在购买时扣除，不退回，但保底
    persistent_data["money"] = max(run_data["money"], Config.MIN_MONEY)
    EventBus.run_ended.emit(false, 0)


## ===== 时间耗尽回调 =====
func _on_time_expired() -> void:
    end_run_fail()
    transition_to(GameState.SETTLEMENT)
```

> **为什么手动管理场景而不用 `SceneTree.change_scene_to_packed()`？**
> `change_scene` 会替换整个场景树根节点，导致永驻 UI（时间条、金钱显示）被销毁。手动管理让我们在 `main.tscn` 中保留永驻层，只切换内容区。

---

### 3.4 `time_manager.gd` — 时间系统

**职责：** 局内倒计时，支持暂停/恢复，触发时间相关信号，判定研发阶段。

```gdscript
# time_manager.gd
extends Node

var total: float = Config.TIME_LIMIT
var remaining: float = Config.TIME_LIMIT
var elapsed: float = 0.0
var is_running: bool = false
var is_paused: bool = false

var _tick_accumulator: float = 0.0   # 累积 delta，每秒触发一次 tick 信号
var _warning_fired: bool = false
var _last_phase: StringName = &"early"


func _process(delta: float) -> void:
    if not is_running or is_paused:
        return

    remaining -= delta
    elapsed += delta
    _tick_accumulator += delta

    # 每秒触发一次 tick 信号（UI 刷新用）
    if _tick_accumulator >= Config.TIME_TICK_INTERVAL:
        _tick_accumulator -= Config.TIME_TICK_INTERVAL
        EventBus.time_tick.emit(remaining, elapsed, total)

    # 阶段变化检测
    var current_phase := _get_phase()
    if current_phase != _last_phase:
        _last_phase = current_phase
        EventBus.dev_phase_changed.emit(current_phase)

    # 警告检测
    if not _warning_fired and remaining <= total * Config.TIME_WARNING_THRESHOLD:
        _warning_fired = true
        EventBus.time_warning.emit(remaining)

    # 时间耗尽
    if remaining <= 0.0:
        remaining = 0.0
        _expire()


## ===== 开始计时 =====
func start_timer() -> void:
    total = Config.TIME_LIMIT
    remaining = total
    elapsed = 0.0
    is_running = true
    is_paused = false
    _tick_accumulator = 0.0
    _warning_fired = false
    _last_phase = &"early"


## ===== 暂停（事件决策期间调用）=====
func pause_timer() -> void:
    is_paused = true
    EventBus.time_paused.emit()


## ===== 恢复 =====
func resume_timer() -> void:
    is_paused = false
    EventBus.time_resumed.emit()


## ===== 外部消耗时间（探索/事件/打磨）=====
func consume(seconds: float) -> void:
    # 受外包效率影响
    var outsource_level: int = GameManager.run_data.get("resources", {}).get("outsource", 1)
    var speed_mult: float = Config.OUTSOURCE_SPEED.get(outsource_level, 1.0)
    var actual_cost: float = seconds * speed_mult

    remaining = max(0.0, remaining - actual_cost)
    elapsed += actual_cost

    if not _warning_fired and remaining <= total * Config.TIME_WARNING_THRESHOLD:
        _warning_fired = true
        EventBus.time_warning.emit(remaining)

    if remaining <= 0.0:
        _expire()


## ===== 停止计时 =====
func stop_timer() -> void:
    is_running = false
    is_paused = false


## ===== 获取当前研发阶段 =====
func get_dev_phase() -> StringName:
    return _get_phase()


func _get_phase() -> StringName:
    var progress: float = elapsed / total
    if progress < Config.PHASE_EARLY_END:
        return &"early"
    elif progress < Config.PHASE_MID_END:
        return &"mid"
    else:
        return &"late"


func _expire() -> void:
    stop_timer()
    EventBus.time_expired.emit()
```

> **为什么用 `_process(delta)` 而不是 `Timer` 节点？**
> Timer 节点虽然方便，但 `_process` 提供连续时间精度，`consume()` 随时可调用且立即生效。Timer 的 `wait_time` 修改在 tick 间生效有延迟。对于"时间就是生命"的核心机制，`_process` 更可控。

---

### 3.5 `main.tscn` — 根场景（场景树结构）

```
Main (Node)                          # 根节点，挂 main.gd
├── PersistentUI (CanvasLayer)       # 永驻UI层（始终显示）
│   ├── TimeBar (Control)            # 时间条，挂 time_bar.gd
│   ├── MoneyLabel (Label)           # 金钱显示
│   └── PhaseLabel (Label)           # 当前阶段提示
├── SceneContainer (Node)            # 动态场景容器（切换内容）
│   └── （由 GameManager 动态加载子场景）
└── OverlayLayer (CanvasLayer)       # 弹窗层（事件弹窗、确认框）
    └── （由事件系统动态创建）
```

```gdscript
# main.gd — 挂在 Main 根节点
extends Node

@onready var scene_container: Node = $SceneContainer
@onready var money_label: Label = $PersistentUI/MoneyLabel
@onready var phase_label: Label = $PersistentUI/PhaseLabel
@onready var time_bar: Control = $PersistentUI/TimeBar


func _ready() -> void:
    # 把场景容器传给 GameManager
    GameManager.setup(scene_container)

    # 监听信号，更新永驻UI
    EventBus.state_changed.connect(_on_state_changed)
    EventBus.time_tick.connect(_on_time_tick)
    EventBus.dev_phase_changed.connect(_on_dev_phase_changed)
    EventBus.run_started.connect(_on_run_started)


func _on_state_changed(from: StringName, to: StringName) -> void:
    # 只在 DEV_RUNNING 期间显示时间条和阶段标签
    var show_dev_ui: bool = (to == "DEV_RUNNING")
    time_bar.visible = show_dev_ui
    phase_label.visible = show_dev_ui


func _on_time_tick(remaining: float, _elapsed: float, _total: float) -> void:
    # 金钱实时更新（可能被事件修改）
    money_label.text = "资金: %d" % GameManager.run_data.get("money", 0)


func _on_dev_phase_changed(new_phase: StringName) -> void:
    var phase_names: Dictionary = {
        &"early": "前期开发",
        &"mid": "中期开发",
        &"late": "后期冲刺",
    }
    phase_label.text = phase_names.get(new_phase, "")


func _on_run_started() -> void:
    money_label.text = "资金: %d" % GameManager.run_data.get("money", 0)
```

---

### 3.6 `time_bar.gd` — 时间条 UI 组件

**场景树结构（time_bar 作为 Control 子树，内嵌在 main.tscn 中或独立 .tscn）：**

```
TimeBar (Control)                    # 挂 time_bar.gd
├── Background (ColorRect)           # 底色条
├── Fill (ColorRect)                 # 填充条（动态宽度）
├── TimeLabel (Label)                # "剩余: 245秒"
└── AnimationPlayer (AnimationPlayer) # 警告闪烁动画
```

```gdscript
# time_bar.gd
extends Control

@onready var fill: ColorRect = $Fill
@onready var time_label: Label = $TimeLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _total_width: float = 0.0
var _is_warning: bool = false

const COLOR_NORMAL := Color(0.2, 0.7, 0.3)    # 绿色
const COLOR_WARNING := Color(0.9, 0.2, 0.2)   # 红色
const COLOR_PAUSED := Color(0.5, 0.5, 0.5)    # 灰色


func _ready() -> void:
    _total_width = size.x
    EventBus.time_tick.connect(_on_time_tick)
    EventBus.time_warning.connect(_on_time_warning)
    EventBus.time_paused.connect(_on_time_paused)
    EventBus.time_resumed.connect(_on_time_resumed)


func _on_time_tick(remaining: float, _elapsed: float, total: float) -> void:
    var pct: float = remaining / total
    fill.size.x = _total_width * pct
    time_label.text = "剩余: %d秒" % int(remaining)

    if _is_warning:
        fill.color = COLOR_WARNING
    else:
        fill.color = COLOR_NORMAL


func _on_time_warning(_remaining: float) -> void:
    _is_warning = true
    fill.color = COLOR_WARNING
    # 播放闪烁动画
    if anim_player.has_animation("warning_flash"):
        anim_player.play("warning_flash")


func _on_time_paused() -> void:
    fill.color = COLOR_PAUSED
    time_label.text += " [暂停]"


func _on_time_resumed() -> void:
    fill.color = COLOR_WARNING if _is_warning else COLOR_NORMAL
```

---

### 3.7 场景骨架模式

每个游戏阶段场景遵循统一模式，以 `main_menu.tscn` 为例：

```
MainMenu (Control)                   # 挂 main_menu.gd，填满屏幕
├── VBoxContainer
│   ├── TitleLabel (Label)           # "《开发商》"
│   ├── StartButton (Button)         # "开始新游戏"
│   └── QuitButton (Button)          # "退出"
```

```gdscript
# main_menu.gd
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton


func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
    GameManager.start_new_run()
    GameManager.transition_to(GameManager.GameState.ENTRY_SHOP)
```

**其余5个场景骨架同理，每个只需：**
- 一个根 Control 节点 + 占位文字标签 + 一个"进入下一阶段"按钮
- 挂一个脚本，`_ready` 连按钮信号，按钮回调里调 `GameManager.transition_to()`
- 这样就能跑通完整状态流转

---

## 四、实施步骤与工时

| # | 步骤 | 产出文件 | 预估工时 | 依赖 |
|---|------|---------|---------|------|
| 1 | 创建 Godot 项目 + 目录结构 | `project.godot`, 目录 | 0.25h | 无 |
| 2 | 实现 Config 单例 | `scripts/autoload/config.gd` | 0.25h | 步骤1 |
| 3 | 实现 EventBus 信号总线 | `scripts/autoload/event_bus.gd` | 0.25h | 步骤1 |
| 4 | 实现 TimeManager | `scripts/autoload/time_manager.gd` | 0.75h | 步骤2, 3 |
| 5 | 实现 GameManager 状态机 + 场景调度 | `scripts/autoload/game_manager.gd` | 1.0h | 步骤2, 3, 4 |
| 6 | 搭建 main.tscn 根场景 + 永驻UI | `scenes/main.tscn`, `main.gd` | 0.5h | 步骤5 |
| 7 | 实现 TimeBar UI 组件 | `time_bar.gd` + AnimationPlayer | 0.5h | 步骤3, 4 |
| 8 | 编写6个场景骨架 | `scenes/*.tscn` + `*.gd` | 0.75h | 步骤5, 6 |
| 9 | 注册 Autoload + 集成测试 | project.godot 配置 + 手动验证 | 0.5h | 步骤1-8 |
| | **总计** | | **4.75h** | |

### 依赖关系图

```
步骤1 ──┬── 步骤2 ──┐
        │           │
        ├── 步骤3 ──┼── 步骤4 ──┐
        │           │           │
        │           │           ├── 步骤5 ── 步骤6 ── 步骤8 ──┐
        │           │           │                              ├── 步骤9
        │           └── 步骤7 ─────────────────────────────────┘
        │
        └───────────────────────────────────────────────────────┘
```

**可并行：**
- 步骤2 和 步骤3 互相独立，可并行
- 步骤7（TimeBar UI）和 步骤8（场景骨架）可并行

**必须串行：**
- 步骤1 → 步骤2/3 → 步骤4 → 步骤5 → 步骤6 → 步骤8 → 步骤9

---

## 五、验收标准

完成本模块后，在 Godot 编辑器中运行应能看到：

1. ✅ 启动项目，显示主菜单场景，有"开始新游戏"按钮
2. ✅ 点击"开始新游戏"，依次经过 ENTRY_SHOP → TOPIC_SELECT → DEV_RUNNING，每个场景有占位文字 + 进入下一步按钮
3. ✅ 进入 DEV_RUNNING 后，时间条开始倒计时，每秒更新剩余时间文字
4. ✅ 剩余时间 < 20% 时，时间条变红并闪烁
5. ✅ 时间归零时，自动跳转 SETTLEMENT 并显示"撤离失败"
6. ✅ 结算后可选"再来一局"回到 ENTRY_SHOP，或"返回菜单"回到 MENU
7. ✅ 永驻UI层（金钱、阶段标签）在场景切换时不消失
8. ✅ 输出面板能看到 `state_changed`、`time_tick`、`dev_phase_changed` 等信号正常触发（用 `print()` 临时验证）

---

## 六、给后续模块的接口约定

其他模块接入核心框架时，只需要知道以下接口：

```gdscript
## ===== 1. 触发状态转移 =====
GameManager.transition_to(GameManager.GameState.NEXT_STATE)

## ===== 2. 读写局数据 =====
GameManager.run_data["quality"] += 10.0
var money: int = GameManager.run_data["money"]

## ===== 3. 消耗时间（自动应用外包效率乘数）=====
TimeManager.consume(30.0)  # 探索节点消耗30秒

## ===== 4. 暂停/恢复时间（事件决策期间）=====
TimeManager.pause_timer()
# ...玩家做决策...
TimeManager.resume_timer()

## ===== 5. 监听全局信号 =====
EventBus.state_changed.connect(_on_state_changed)
EventBus.time_tick.connect(_on_time_tick)
EventBus.dev_phase_changed.connect(_on_dev_phase_changed)
EventBus.time_warning.connect(_on_time_warning)
EventBus.time_expired.connect(_on_time_expired)
EventBus.run_started.connect(_on_run_started)
EventBus.run_ended.connect(_on_run_ended)

## ===== 6. 查询时间状态 =====
var phase: StringName = TimeManager.get_dev_phase()
var time_left: float = TimeManager.remaining
var is_paused: bool = TimeManager.is_paused

## ===== 7. 读取配置 =====
var time_limit: float = Config.TIME_LIMIT
var speed: float = Config.OUTSOURCE_SPEED[level]
```

---

## 七、风险与降级方案

| 风险 | 概率 | 降级方案 |
|------|------|---------|
| 永驻UI布局适配 | 中 | 先用固定分辨率（1280×720），不做自适应 |
| TimeBar 闪烁动画复杂 | 低 | 用代码 `modulate` 闪烁，不建 AnimationPlayer |
| 场景加载卡顿（load 同步阻塞）| 低 | Demo体量极小，同步 load 无感知延迟。若有问题换 `ResourceLoader.load_threaded_request()` |
| 状态机需扩展子状态（DEV_RUNNING 内部）| 高 | DEV_RUNNING 场景脚本内部维护自己的子状态 enum，不污染主状态机 |
| Autoload 初始化顺序问题 | 中 | 严格按 Config → EventBus → TimeManager → GameManager 顺序注册 |

---

## 八、DEV_RUNNING 子状态预留

`DEV_RUNNING` 是最复杂的状态，内部需要子状态管理。**本模块不实现子状态细节**（由模块04-研发流程负责），但预留接口：

```gdscript
# dev_running.gd 内部子状态（模块04实现，此处仅展示结构）
enum DevSubState {
    DEVELOPING,        # 正常开发中，时间流逝
    EVENT_POPUP,       # 事件弹窗，时间暂停
    EXPLORATION,       # 探索节点交互
    PLAYTEST,          # 内测验证节点
    POLISH,            # 打磨节点
    MINI_GAME,         # 代码急救小游戏
}

var sub_state: DevSubState = DevSubState.DEVELOPING
```

主状态机只关心 `DEV_RUNNING` 这一个状态，内部细节完全封装在场景脚本内。这是 Godot 场景树思维的天然优势——**每个场景管好自己的事**。
