# 模块04：研发流程与可选节点 — 实施方案

> 对应设计规格：`docs/specs/modules/04-dev-pipeline.md`
> 技术栈：**Godot 4.6.1 + GDScript**
> 预估总工时：**10-12 小时**

---

## 一、架构概览

本模块是玩家停留时间最长的核心场景，采用**单场景 + 弹窗叠加**架构：

- 研发主界面为一个完整 Scene，包含进度条、品质标签、剩余时间、上线按钮、市场热度面板
- 内测验证 / 临上线打磨两个可选节点以 **PopupPanel 弹窗**覆盖在主界面上
- 弹窗期间通过 `get_tree().paused = true` 暂停时间流逝和品质积累（弹窗节点设置 `process_mode = PROCESS_MODE_WHEN_PAUSED`）

### 暂停策略

| 状态 | get_tree().paused | 说明 |
|------|-------------------|------|
| 正常研发 | `false` | 时间流逝、品质积累、事件检测均正常运行 |
| 节点弹窗 | `true` | 主界面冻结，仅弹窗可交互（弹窗 `process_mode = WHEN_PAUSED`） |
| bug二次选择弹窗 | `true` | 同上，保持暂停 |

---

## 二、文件结构与职责

```
project/
├── scenes/
│   └── dev_pipeline/
│       ├── dev_pipeline.tscn           # 研发主界面场景
│       ├── playtest_popup.tscn         # 内测验证弹窗
│       ├── polish_popup.tscn           # 临上线打磨弹窗
│       └── polish_bug_popup.tscn       # 打磨触发bug后的二次选择弹窗
│
├── scripts/
│   └── dev_pipeline/
│       ├── dev_pipeline_manager.gd     # 研发流程主控：阶段推进、节点触发、tick协调
│       ├── quality_system.gd           # 品质积累、模糊等级映射、内测揭示
│       ├── playtest_node.gd            # 内测验证节点逻辑（挂在弹窗场景根节点）
│       ├── polish_node.gd              # 临上线打磨节点逻辑（挂在弹窗场景根节点）
│       └── polish_bug_popup.gd         # bug二次选择弹窗逻辑
│
├── resources/
│   └── dev_pipeline/
│       └── dev_config.tres             # 研发数值配置（Resource）
│
└── autoload/
    ├── game_state.gd                   # 模块01提供：全局状态单例
    ├── time_system.gd                  # 模块01提供：时间系统单例
    └── event_bus.gd                    # 模块01提供：事件总线单例
```

### 各文件职责

| 文件 | 类型 | 职责 |
|------|------|------|
| `dev_pipeline.tscn` | 场景 | 研发主界面布局：进度条、品质标签、时间显示、上线按钮、阶段指示、市场热度区域 |
| `dev_pipeline_manager.gd` | 脚本 | 挂在主场景根节点。每帧驱动品质积累、阶段判定、节点触发检测、信号派发 |
| `quality_system.gd` | 脚本 | 独立 RefCounted 类。品质积累公式、模糊等级映射（含边界偏移）、内测揭示标记、打磨增减 |
| `dev_config.tres` | Resource | 所有可调数值：基础速率、效率倍率、品质上限、节点触发进度、打磨概率等 |
| `playtest_popup.tscn` | 场景 | 内测验证弹窗UI + `playtest_node.gd` 逻辑 |
| `polish_popup.tscn` | 场景 | 打磨弹窗UI + `polish_node.gd` 逻辑 |
| `polish_bug_popup.tscn` | 场景 | bug二次选择弹窗 + `polish_bug_popup.gd` |

---

## 三、场景树结构

### 3.1 研发主界面 `dev_pipeline.tscn`

```
DevPipeline (Control) [dev_pipeline_manager.gd]
├── BG (ColorRect)                          # 背景
├── TopBar (HBoxContainer)                  # 顶部信息栏
│   ├── TimeIcon (TextureRect)
│   ├── TimeLabel (Label)                   # "剩余：180秒"
│   ├── Spacer (Control, h_expand)
│   ├── PhaseLabel (Label)                  # "【中期】"
│   └── QualityLabel (Label)                # "品质：精良"
│
├── CenterArea (VBoxContainer)              # 中央区域
│   ├── ProgressSection (VBoxContainer)
│   │   ├── ProgressTitle (Label)           # "研发进度"
│   │   ├── ProgressBar (ProgressBar)       # 时间进度条（value=已用时间比例）
│   │   └── ProgressDetail (Label)          # "45% — 前期→中期"
│   ├── QualitySection (PanelContainer)
│   │   ├── QualityTitle (Label)            # "当前品质评估"
│   │   ├── QualityGrade (Label)            # 大字显示 "精良" / "合格（未验证）"
│   │   └── QualityHint (Label)             # 小字提示 "品质评估可能存在偏差"
│   └── EventLog (VBoxContainer)            # 最近事件日志（3-4条）
│       └── LogEntry (Label) × N
│
├── SidePanel (PanelContainer)              # 右侧：市场热度（模块03提供）
│   └── MarketHeatPlaceholder (Label)       # 占位，由模块03填充
│
├── BottomBar (HBoxContainer)               # 底部操作栏
│   ├── Spacer (Control, h_expand)
│   └── LaunchButton (Button)               # "上线发布"——始终可见
│
├── PlaytestPopup (预留挂载点)               # 运行时实例化 playtest_popup.tscn
└── PolishPopup (预留挂载点)                 # 运行时实例化 polish_popup.tscn
```

### 3.2 内测验证弹窗 `playtest_popup.tscn`

```
PlaytestPopup (PopupPanel) [playtest_node.gd]  # process_mode = WHEN_PAUSED
├── Panel (PanelContainer)
│   └── VBox (VBoxContainer)
│       ├── Title (Label)                   # "内测验证"
│       ├── Desc (RichTextLabel)            # "花费30秒进行内测，揭示真实品质等级..."
│       ├── CostLabel (Label)               # "消耗时间：30秒"
│       ├── HSeparator
│       └── ButtonRow (HBoxContainer)
│           ├── AcceptBtn (Button)          # "进行内测"
│           └── SkipBtn (Button)            # "跳过"
```

### 3.3 打磨弹窗 `polish_popup.tscn`

```
PolishPopup (PopupPanel) [polish_node.gd]   # process_mode = WHEN_PAUSED
├── Panel (PanelContainer)
│   └── VBox (VBoxContainer)
│       ├── Title (Label)                   # "临上线打磨"
│       ├── Desc (RichTextLabel)            # 概率说明 + 当前品质
│       ├── OddsLabel (Label)               # "70%：品质+8  |  30%：发现严重bug"
│       ├── CostLabel (Label)               # "消耗时间：30秒"
│       ├── HSeparator
│       └── ButtonRow (HBoxContainer)
│           ├── AcceptBtn (Button)          # "进行打磨"
│           └── SkipBtn (Button)            # "跳过"
```

### 3.4 Bug二次选择弹窗 `polish_bug_popup.tscn`

```
PolishBugPopup (PopupPanel) [polish_bug_popup.gd]  # process_mode = WHEN_PAUSED
├── Panel (PanelContainer)
│   └── VBox (VBoxContainer)
│       ├── Title (Label)                   # "⚠ 发现严重Bug！"
│       ├── Desc (RichTextLabel)            # 描述当前困境
│       ├── HSeparator
│       ├── FixBtn (Button)                 # "紧急修复（消耗18秒）"
│       └── IgnoreBtn (Button)              # "放弃修复（品质-25分）"
```

---

## 四、核心代码结构

### 4.1 数值配置资源 `dev_config.tres`

```gdscript
# scripts/dev_pipeline/dev_config.gd
class_name DevConfig
extends Resource

## 品质积累
@export var base_quality_rate: float = 0.15  # 分/秒
@export var efficiency_multiplier: Dictionary = {1: 1.0, 2: 1.5, 3: 2.0}  # 外包等级→倍率
@export var quality_cap: Dictionary = {1: 40, 2: 70, 3: 100}              # 主创等级→上限

## 模糊偏移
@export var fuzzy_offset_range: float = 10.0  # 边界偏移±10

## 品质等级阈值
@export var grade_thresholds: Array[int] = [0, 25, 50, 75]
@export var grade_names: Array[String] = ["粗糙", "合格", "精良", "杰作"]

## 研发阶段
@export var phase_early_end: float = 0.30
@export var phase_mid_end: float = 0.70

## 内测验证节点
@export var playtest_trigger_progress: float = 0.50
@export var playtest_time_cost: float = 30.0

## 临上线打磨节点
@export var polish_trigger_progress: float = 0.85
@export var polish_time_cost: float = 30.0
@export var polish_success_prob: float = 0.70
@export var polish_boost_amount: float = 8.0
@export var polish_bug_fix_time_cost: float = 18.0
@export var polish_bug_penalty: float = 25.0
```

### 4.2 品质系统 `quality_system.gd`

```gdscript
# scripts/dev_pipeline/quality_system.gd
class_name QualitySystem
extends RefCounted

## 品质等级枚举
enum Grade { ROUGH, ACCEPTABLE, EXCELLENT, MASTERPIECE }

## 等级名称映射
const GRADE_NAMES: Dictionary = {
    Grade.ROUGH: "粗糙",
    Grade.ACCEPTABLE: "合格",
    Grade.EXCELLENT: "精良",
    Grade.MASTERPIECE: "杰作",
}

var raw_score: float = 0.0       # 实际品质分（0-100）
var cap: float = 40.0            # 品质上限（由主创等级决定）
var rate: float = 0.15           # 品质增长速率（基础×效率）
var revealed: bool = false       # 是否已做内测（揭示真实值）
var boundary_offset: float = 0.0 # 模糊偏移量（局开始时固定）

var _config: DevConfig


func _init(config: DevConfig, creator_level: int, outsource_level: int) -> void:
    _config = config
    cap = config.quality_cap.get(creator_level, 40.0)
    rate = config.base_quality_rate * config.efficiency_multiplier.get(outsource_level, 1.0)
    # 模糊偏移：局开始时固定，-10 ~ +10
    boundary_offset = randf_range(-config.fuzzy_offset_range, config.fuzzy_offset_range)


## 每帧调用，dt为秒
func accumulate(dt: float) -> void:
    if raw_score >= cap:
        return
    raw_score = minf(raw_score + rate * dt, cap)


## 内部：品质分 → 真实等级
func get_true_grade() -> Grade:
    return _score_to_grade(raw_score)


## 玩家看到的模糊等级
func get_fuzzy_grade() -> Grade:
    if revealed:
        return get_true_grade()
    return _score_to_grade(raw_score + boundary_offset)


## 获取等级显示名称
func get_grade_name(grade: Grade) -> String:
    return GRADE_NAMES.get(grade, "未知")


## 获取玩家可见的等级名称
func get_display_grade_name() -> String:
    return get_grade_name(get_fuzzy_grade())


## 内测揭示：锁定为真实值
func reveal_true() -> void:
    revealed = true


## 打磨成功：品质提升
func apply_polish_boost(amount: float) -> void:
    raw_score = minf(raw_score + amount, cap)


## 打磨失败放弃修复：品质下降
func apply_bug_penalty(amount: float) -> void:
    raw_score = maxf(raw_score - amount, 0.0)


## 品质分 → 等级（纯函数）
func _score_to_grade(score: float) -> Grade:
    if score >= _config.grade_thresholds[3]:  # 75
        return Grade.MASTERPIECE
    elif score >= _config.grade_thresholds[2]:  # 50
        return Grade.EXCELLENT
    elif score >= _config.grade_thresholds[1]:  # 25
        return Grade.ACCEPTABLE
    else:
        return Grade.ROUGH
```

### 4.3 研发流程主控 `dev_pipeline_manager.gd`

```gdscript
# scripts/dev_pipeline/dev_pipeline_manager.gd
extends Control

## 研发阶段枚举
enum DevPhase { EARLY, MID, LATE }

const PHASE_NAMES: Dictionary = {
    DevPhase.EARLY: "前期",
    DevPhase.MID: "中期",
    DevPhase.LATE: "后期",
}

## 预加载弹窗场景
const PlaytestPopupScene = preload("res://scenes/dev_pipeline/playtest_popup.tscn")
const PolishPopupScene = preload("res://scenes/dev_pipeline/polish_popup.tscn")

## 数值配置（Inspector中拖入 .tres）
@export var config: DevConfig

## UI 节点引用
@onready var time_label: Label = $TopBar/TimeLabel
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var quality_label: Label = $TopBar/QualityLabel
@onready var progress_bar: ProgressBar = $CenterArea/ProgressSection/ProgressBar
@onready var progress_detail: Label = $CenterArea/ProgressSection/ProgressDetail
@onready var quality_grade: Label = $CenterArea/QualitySection/QualityGrade
@onready var quality_hint: Label = $CenterArea/QualitySection/QualityHint
@onready var launch_button: Button = $BottomBar/LaunchButton
@onready var event_log: VBoxContainer = $CenterArea/EventLog

## 内部状态
var quality_system: QualitySystem
var current_phase: DevPhase = DevPhase.EARLY
var playtest_triggered: bool = false
var polish_triggered: bool = false

## 信号（与其他模块通信）
signal dev_tick(progress: float, phase: DevPhase, time_remaining: float)
signal node_triggered(node_type: String)  # "playtest" | "polish"
signal launch_requested(quality_score: float, quality_grade: int, time_remaining: float, playtest_done: bool)
signal dev_time_up()


func _ready() -> void:
    # 从 GameState 获取入场资源等级
    var creator_level: int = GameState.run.resources.creator   # 1/2/3
    var outsource_level: int = GameState.run.resources.outsource

    # 初始化品质系统
    quality_system = QualitySystem.new(config, creator_level, outsource_level)

    # 绑定上线按钮
    launch_button.pressed.connect(_on_launch_pressed)

    # 监听时间耗尽
    EventBus.time_expired.connect(_on_time_expired)

    # 初始化UI
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    quality_hint.text = "品质评估可能存在偏差"

    _update_ui(0.0)


func _process(delta: float) -> void:
    # 暂停期间不执行（由 get_tree().paused 控制）

    # 1. 品质积累
    quality_system.accumulate(delta)

    # 2. 计算进度
    var progress: float = TimeSystem.get_elapsed_ratio()

    # 3. 阶段判定
    var new_phase := _get_phase(progress)
    if new_phase != current_phase:
        current_phase = new_phase
        _add_log("进入%s阶段" % PHASE_NAMES[current_phase])

    # 4. 可选节点触发检测
    if not playtest_triggered and progress >= config.playtest_trigger_progress:
        playtest_triggered = true
        _trigger_playtest_node()

    if not polish_triggered and progress >= config.polish_trigger_progress:
        polish_triggered = true
        _trigger_polish_node()

    # 5. 刷新UI
    _update_ui(progress)

    # 6. 通知外部模块（供事件系统检测阶段）
    dev_tick.emit(progress, current_phase, TimeSystem.get_remaining())


## ---- 阶段判定 ----

func _get_phase(progress: float) -> DevPhase:
    if progress < config.phase_early_end:
        return DevPhase.EARLY
    elif progress < config.phase_mid_end:
        return DevPhase.MID
    else:
        return DevPhase.LATE


## ---- 内测验证节点 ----

func _trigger_playtest_node() -> void:
    get_tree().paused = true
    node_triggered.emit("playtest")

    var popup = PlaytestPopupScene.instantiate()
    popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    add_child(popup)

    # 传入当前状态
    popup.setup(
        config.playtest_time_cost,
        quality_system.get_display_grade_name()
    )
    # 连接选择信号
    popup.accepted.connect(_on_playtest_accepted.bind(popup))
    popup.skipped.connect(_on_playtest_skipped.bind(popup))
    popup.popup_centered()


func _on_playtest_accepted(popup: Node) -> void:
    # 消耗时间
    TimeSystem.consume(config.playtest_time_cost)
    # 揭示真实品质
    quality_system.reveal_true()
    quality_hint.text = "品质已验证（真实值）"
    GameState.run.did_playtest = true

    _add_log("内测完成——真实品质：%s" % quality_system.get_display_grade_name())
    EventBus.playtest_completed.emit(quality_system.get_true_grade())

    popup.queue_free()
    get_tree().paused = false


func _on_playtest_skipped(popup: Node) -> void:
    _add_log("跳过内测验证")
    EventBus.playtest_skipped.emit()
    popup.queue_free()
    get_tree().paused = false


## ---- 临上线打磨节点 ----

func _trigger_polish_node() -> void:
    get_tree().paused = true
    node_triggered.emit("polish")

    var popup = PolishPopupScene.instantiate()
    popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    add_child(popup)

    # 传入当前状态（是否做过内测影响文案）
    popup.setup(
        config,
        quality_system.get_display_grade_name(),
        quality_system.revealed,  # 是否做过内测
        TimeSystem.get_remaining()
    )
    popup.accepted.connect(_on_polish_accepted.bind(popup))
    popup.skipped.connect(_on_polish_skipped.bind(popup))
    popup.popup_centered()


func _on_polish_accepted(popup: Node) -> void:
    # 消耗打磨时间
    TimeSystem.consume(config.polish_time_cost)

    # 概率判定
    var roll: float = randf()
    if roll <= config.polish_success_prob:
        # ---- 成功：品质+8 ----
        quality_system.apply_polish_boost(config.polish_boost_amount)
        GameState.run.did_polish = true
        _add_log("打磨成功！品质提升至：%s" % quality_system.get_display_grade_name())
        EventBus.polish_success.emit(config.polish_boost_amount)
        popup.queue_free()
        get_tree().paused = false
    else:
        # ---- 失败：发现bug，弹出二次选择 ----
        popup.queue_free()
        _show_bug_popup()


func _show_bug_popup() -> void:
    var bug_popup_scene = preload("res://scenes/dev_pipeline/polish_bug_popup.tscn")
    var bug_popup = bug_popup_scene.instantiate()
    bug_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    add_child(bug_popup)

    bug_popup.setup(
        config.polish_bug_fix_time_cost,
        config.polish_bug_penalty,
        TimeSystem.get_remaining()
    )
    bug_popup.fix_chosen.connect(_on_bug_fix.bind(bug_popup))
    bug_popup.ignore_chosen.connect(_on_bug_ignore.bind(bug_popup))
    bug_popup.popup_centered()


func _on_bug_fix(popup: Node) -> void:
    TimeSystem.consume(config.polish_bug_fix_time_cost)
    GameState.run.did_polish = true
    _add_log("紧急修复完成——品质未变，但消耗了额外时间")
    EventBus.polish_bug_fixed.emit()
    popup.queue_free()
    get_tree().paused = false


func _on_bug_ignore(popup: Node) -> void:
    quality_system.apply_bug_penalty(config.polish_bug_penalty)
    GameState.run.did_polish = true
    _add_log("放弃修复——品质降至：%s" % quality_system.get_display_grade_name())
    EventBus.polish_bug_ignored.emit(config.polish_bug_penalty)
    popup.queue_free()
    get_tree().paused = false


func _on_polish_skipped(popup: Node) -> void:
    _add_log("跳过打磨")
    EventBus.polish_skipped.emit()
    popup.queue_free()
    get_tree().paused = false


## ---- 上线按钮 ----

func _on_launch_pressed() -> void:
    launch_requested.emit(
        quality_system.raw_score,
        quality_system.get_fuzzy_grade(),
        TimeSystem.get_remaining(),
        quality_system.revealed
    )
    # 状态转移由上层 GameState 处理
    GameState.transition("LAUNCH_CONFIRM")


## ---- 时间耗尽 ----

func _on_time_expired() -> void:
    dev_time_up.emit()
    # 失败处理由模块01 GameState 统一调度


## ---- UI 刷新 ----

func _update_ui(progress: float) -> void:
    # 进度条
    progress_bar.value = progress
    progress_detail.text = "%d%% — %s" % [int(progress * 100), PHASE_NAMES[current_phase]]

    # 时间
    var remaining := TimeSystem.get_remaining()
    time_label.text = "剩余：%d秒" % int(remaining)

    # 时间紧迫变色（剩余<20%）
    if remaining <= TimeSystem.total * 0.2:
        time_label.add_theme_color_override("font_color", Color.RED)
        progress_bar.modulate = Color(1.0, 0.3, 0.3)  # 红色调

    # 阶段
    phase_label.text = "【%s】" % PHASE_NAMES[current_phase]

    # 品质
    var grade_name := quality_system.get_display_grade_name()
    quality_label.text = "品质：%s" % grade_name
    quality_grade.text = grade_name
    if quality_system.revealed:
        quality_grade.text += "（已验证）"
    else:
        quality_grade.text += "（未验证）"


## ---- 事件日志 ----

const MAX_LOG_ENTRIES: int = 4

func _add_log(text: String) -> void:
    var label := Label.new()
    label.text = "> %s" % text
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    event_log.add_child(label)
    # 超过上限移除最早的
    while event_log.get_child_count() > MAX_LOG_ENTRIES:
        var oldest := event_log.get_child(0)
        event_log.remove_child(oldest)
        oldest.queue_free()


## ---- 外部接口：供事件系统调用 ----

## 事件系统在研发期间修改品质（探索节点收益等）
func modify_quality(amount: float) -> void:
    if amount > 0:
        quality_system.apply_polish_boost(amount)
    else:
        quality_system.apply_bug_penalty(absf(amount))
    _add_log("品质变化：%+.0f" % amount)
```

### 4.4 内测验证弹窗脚本 `playtest_node.gd`

```gdscript
# scripts/dev_pipeline/playtest_node.gd
extends PopupPanel

signal accepted
signal skipped

@onready var desc_label: RichTextLabel = $Panel/VBox/Desc
@onready var cost_label: Label = $Panel/VBox/CostLabel
@onready var accept_btn: Button = $Panel/VBox/ButtonRow/AcceptBtn
@onready var skip_btn: Button = $Panel/VBox/ButtonRow/SkipBtn


func _ready() -> void:
    accept_btn.pressed.connect(func(): accepted.emit())
    skip_btn.pressed.connect(func(): skipped.emit())
    # 禁止点击外部关闭
    popup_window = false


func setup(time_cost: float, current_grade_name: String) -> void:
    desc_label.text = (
        "花费 [b]%d秒[/b] 进行内测验证。\n\n"
        + "当前品质评估：[b]%s[/b]（可能有偏差）\n\n"
        + "内测将揭示 [color=yellow]真实品质等级[/color]，"
        + "帮助你做出更准确的上线决策。"
    ) % [int(time_cost), current_grade_name]
    cost_label.text = "消耗时间：%d秒" % int(time_cost)
```

### 4.5 临上线打磨弹窗脚本 `polish_node.gd`

```gdscript
# scripts/dev_pipeline/polish_node.gd
extends PopupPanel

signal accepted
signal skipped

@onready var desc_label: RichTextLabel = $Panel/VBox/Desc
@onready var odds_label: Label = $Panel/VBox/OddsLabel
@onready var cost_label: Label = $Panel/VBox/CostLabel
@onready var accept_btn: Button = $Panel/VBox/ButtonRow/AcceptBtn
@onready var skip_btn: Button = $Panel/VBox/ButtonRow/SkipBtn


func _ready() -> void:
    accept_btn.pressed.connect(func(): accepted.emit())
    skip_btn.pressed.connect(func(): skipped.emit())


func setup(config: DevConfig, grade_name: String, is_revealed: bool, time_remaining: float) -> void:
    var verified_text := "（已验证）" if is_revealed else "（未验证，可能有偏差）"
    var warning_text := ""
    if not is_revealed:
        warning_text = "\n\n[color=gray]提示：你没有做内测验证，当前品质等级可能不准确。[/color]"

    desc_label.text = (
        "当前品质：[b]%s[/b] %s\n"
        + "剩余时间：[b]%d秒[/b]\n\n"
        + "花费 [b]%d秒[/b] 进行最终打磨。%s"
    ) % [grade_name, verified_text, int(time_remaining), int(config.polish_time_cost), warning_text]

    odds_label.text = "%d%%：品质+%.0f  |  %d%%：发现严重bug" % [
        int(config.polish_success_prob * 100),
        config.polish_boost_amount,
        int((1.0 - config.polish_success_prob) * 100),
    ]
    cost_label.text = "消耗时间：%d秒" % int(config.polish_time_cost)
```

### 4.6 Bug二次选择弹窗脚本 `polish_bug_popup.gd`

```gdscript
# scripts/dev_pipeline/polish_bug_popup.gd
extends PopupPanel

signal fix_chosen
signal ignore_chosen

@onready var desc_label: RichTextLabel = $Panel/VBox/Desc
@onready var fix_btn: Button = $Panel/VBox/FixBtn
@onready var ignore_btn: Button = $Panel/VBox/IgnoreBtn


func _ready() -> void:
    fix_btn.pressed.connect(func(): fix_chosen.emit())
    ignore_btn.pressed.connect(func(): ignore_chosen.emit())


func setup(fix_time_cost: float, penalty: float, time_remaining: float) -> void:
    var will_expire := time_remaining < fix_time_cost
    var expire_warning := ""
    if will_expire:
        expire_warning = "\n\n[color=red]⚠ 警告：当前剩余时间不足以完成修复，选择修复将导致时间耗尽！[/color]"

    desc_label.text = (
        "打磨过程中发现 [color=red][b]严重Bug[/b][/color]！\n\n"
        + "你有两个选择：%s"
    ) % expire_warning

    fix_btn.text = "紧急修复（消耗%d秒）" % int(fix_time_cost)
    ignore_btn.text = "放弃修复（品质-%.0f分）" % penalty

    # 如果修复会导致超时，用红色高亮修复按钮文字
    if will_expire:
        fix_btn.add_theme_color_override("font_color", Color.RED)
```

### 4.7 与事件系统的接口信号（EventBus 扩展）

```gdscript
# 在 autoload/event_bus.gd 中追加以下信号（供本模块使用）

## 研发流程信号
signal dev_phase_changed(phase: int)           # DevPhase枚举值
signal playtest_completed(true_grade: int)     # 内测完成，传真实品质等级
signal playtest_skipped()                      # 内测跳过
signal polish_success(boost: float)            # 打磨成功
signal polish_bug_fixed()                      # bug已修复
signal polish_bug_ignored(penalty: float)      # bug放弃修复
signal polish_skipped()                        # 打磨跳过

## 事件系统 → 研发流程（模块05调用）
signal request_quality_modify(amount: float)   # 外部请求修改品质
signal request_time_consume(seconds: float)    # 外部请求消耗时间
```

---

## 五、实施步骤、工时与依赖

| # | 任务 | 产出文件 | 预估工时 | 依赖 |
|---|------|---------|---------|------|
| **S1** | 品质系统核心实现 | `quality_system.gd`, `dev_config.gd` + `.tres` | 1.5h | 模块02（入场资源等级数据） |
| **S2** | 研发主界面场景搭建 | `dev_pipeline.tscn`（场景树 + 布局） | 2h | 无（纯UI布局） |
| **S3** | 研发流程主控脚本 | `dev_pipeline_manager.gd` | 2.5h | S1 + S2 + 模块01（GameState/TimeSystem/EventBus） |
| **S4** | 内测验证弹窗 | `playtest_popup.tscn` + `playtest_node.gd` | 1h | S1（QualitySystem.reveal_true） |
| **S5** | 打磨弹窗 + bug二次选择弹窗 | `polish_popup.tscn` + `polish_node.gd` + `polish_bug_popup.tscn` + `polish_bug_popup.gd` | 2h | S1 + S4（两节点咬合关系需 revealed 状态） |
| **S6** | EventBus 信号扩展 + 事件系统接口 | `event_bus.gd` 追加信号 | 0.5h | 模块01（EventBus 基础） |
| **S7** | 联调与手感调优 | 调数值、测边界、UI微调 | 1.5h | S1-S6 全部完成 |

### 依赖关系图

```
模块01（GameState/TimeSystem/EventBus）──┐
                                         ├──→ S3（主控脚本）──→ S7（联调）
模块02（入场资源等级）──→ S1（品质系统）──┤                       ↑
                                         ├──→ S4（内测弹窗）──┤
S2（主界面场景）────────────────────────→ S3   S5（打磨弹窗）──┘
                                         │       ↑
                                         └──→ S6（信号接口）

S4 revealed 状态 ──→ S5 文案差异化
```

**可并行：** S1 和 S2 互相独立，可同时开工。S4 和 S6 可并行。
**必须串行：** S1 → S3 → S7；S4 → S5（内测的 revealed 影响打磨文案逻辑）。

---

## 六、关键实现细节

### 6.1 暂停/恢复的正确姿势

```gdscript
# 触发弹窗时
get_tree().paused = true
# 弹窗场景根节点必须设置：
popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
# 这样弹窗内的按钮交互正常，而 _process() 中的品质积累自动停止

# 关闭弹窗时
popup.queue_free()
get_tree().paused = false
```

好处：不需要手动管理 paused flag，Godot 引擎级暂停保证所有 `_process` / `_physics_process` / Timer 均冻结。只有标记为 `WHEN_PAUSED` 的节点继续响应。

### 6.2 两节点咬合的代码保证

咬合关系通过 `quality_system.revealed` 这一个布尔值传递：

- 内测弹窗选择"接受" → `quality_system.reveal_true()` → `revealed = true`
- 打磨弹窗 `setup()` 接收 `is_revealed` 参数 → 差异化文案
- **真正的"咬合"发生在玩家脑中**——做过内测的玩家看到"品质：精良（已验证）"，能理性判断打磨是否值得；没做内测的看到"品质：精良（未验证，可能有偏差）"，只能凭感觉赌

### 6.3 时间耗尽边界处理

```gdscript
# TimeSystem.consume() 中的边界处理
func consume(seconds: float) -> void:
    remaining = maxf(0.0, remaining - seconds)
    elapsed += seconds
    _check_warning()
    if remaining <= 0.0:
        _expire()
        # 不在这里直接结算，而是发信号
        # DevPipelineManager 在下一帧检测并统一处理
```

**关键边界场景：** 打磨 → 触发bug → 选择修复 → 修复消耗18秒超出剩余时间 → 时间耗尽 → 撤离失败。`polish_bug_popup.gd` 中会检测并用红色警告提示玩家。

### 6.4 进度条紧迫感表现

```gdscript
# dev_pipeline_manager.gd _update_ui() 中
if remaining <= TimeSystem.total * 0.2:
    # 红色 + 闪烁（用 Tween 循环）
    time_label.add_theme_color_override("font_color", Color.RED)
    if not _critical_tween:
        _critical_tween = create_tween().set_loops()
        _critical_tween.tween_property(progress_bar, "modulate", Color(1, 0.3, 0.3), 0.4)
        _critical_tween.tween_property(progress_bar, "modulate", Color(1, 0.6, 0.6), 0.4)
```

---

## 七、总工时预估

| 类别 | 工时 |
|------|------|
| 核心逻辑（S1 + S3 + S6） | 4.5h |
| 弹窗实现（S4 + S5） | 3h |
| UI场景搭建（S2） | 2h |
| 联调调优（S7） | 1.5h |
| **合计** | **11h** |

**风险缓冲：** 如果超时，优先砍弹窗的 RichTextLabel 富文本（降为纯 Label），可节省约 0.5h。

**最小可玩版本（7h）：** S1 + S2（简化布局）+ S3 + S4 + S5（不做 bug 二次选择，直接按概率扣品质），跳过 S7 手感调优。

---

## 八、验收标准

- [ ] 品质随时间积累，受主创等级（上限）和外包等级（速率）正确影响
- [ ] 品质显示为模糊等级，边界区域有 ±10 随机偏移
- [ ] 进度约50%时弹出内测验证弹窗，选择后时间正确扣除，品质切换为真实值
- [ ] 进度约85%时弹出打磨弹窗，70/30概率判定正确
- [ ] 触发bug时弹出二次选择，修复扣时间、放弃扣品质，逻辑正确
- [ ] 弹窗期间游戏时间冻结（`get_tree().paused`），弹窗内按钮可正常交互
- [ ] 时间耗尽触发撤离失败
- [ ] 上线按钮始终可见，点击后正确传递品质分+等级+剩余时间给结算模块
- [ ] 剩余时间 < 20% 时进度条红色闪烁
- [ ] bug二次选择弹窗在修复会导致超时时显示红色警告
