# 模块06：上线决策与市场竞争结算 — 实施方案

> 对应设计规格：`docs/specs/modules/06-launch-settlement.md`
> 技术栈：**Godot 4.6.1 + GDScript**
> 预估总工时：**8 小时**

---

## 一、技术选型

| 层面 | 选型 | 理由 |
|------|------|------|
| 引擎 | Godot 4.6.1 | 项目统一引擎 |
| 语言 | GDScript | 原生支持，开发速度最快 |
| UI 框架 | Control 节点树 | 结算界面是纯 UI，用 VBoxContainer/HBoxContainer 布局 |
| 动画 | **Tween**（代码驱动） | 逐条延迟+淡入+颜色变化，Tween 比 AnimationPlayer 更灵活，节奏可编程控制 |
| 数字滚动 | Tween + `method_tweener` | 用 Tween 插值驱动 Label.text 更新 |
| 持久化 | Autoload 单例（内存），可选 ConfigFile 存盘 | Demo 级别内存够用，ConfigFile 一行代码可加 |
| 场景切换 | 信号驱动 + `get_tree().change_scene_to_packed()` | 结算完发信号，由主框架决定跳转目标 |

---

## 二、文件结构与职责

```
game/
├── scripts/
│   ├── autoload/
│   │   └── player_wallet.gd          # Autoload 单例：金钱持久化（局间传递）
│   ├── settlement/
│   │   ├── settlement_calculator.gd   # 纯函数：收益计算（空窗期+存量份额+热度乘数）
│   │   ├── launch_confirm_dialog.gd   # 上线确认弹窗逻辑
│   │   ├── success_settlement.gd      # 成功结算场景脚本（逐条动画）
│   │   └── failure_settlement.gd      # 失败结算场景脚本（逐条动画，情绪节奏重点）
│   └── data/
│       └── settlement_data.gd         # 数据结构定义（SettlementResult, ResourceEntry 等）
├── scenes/
│   ├── ui/
│   │   └── launch_confirm_dialog.tscn # 上线确认弹窗场景
│   └── settlement/
│       ├── success_settlement.tscn    # 成功结算完整场景
│       └── failure_settlement.tscn    # 失败结算完整场景
└── resources/
    └── themes/
        └── settlement_theme.tres      # 结算界面主题（字体、颜色）
```

### 各文件职责详述

| 文件 | 职责 | 对外接口 |
|------|------|---------|
| `player_wallet.gd` | Autoload 单例，管理金钱增减、读取、存盘 | `get_money()`, `add_money(n)`, `deduct_money(n)`, `save()`, `load()` |
| `settlement_calculator.gd` | 纯计算类，无节点依赖，可单元测试 | `static func calculate(params: Dictionary) -> Dictionary` |
| `launch_confirm_dialog.gd` | 读取当前游戏状态，填充确认弹窗摘要，处理确认/取消 | 信号 `confirmed` / `cancelled` |
| `success_settlement.gd` | 成功结算场景主脚本，驱动 Tween 逐条动画 | `setup(data: Dictionary)`, 信号 `action_chosen(action: String)` |
| `failure_settlement.gd` | 失败结算场景主脚本，驱动 Tween 逐条动画（情绪节奏核心） | `setup(data: Dictionary)`, 信号 `action_chosen(action: String)` |
| `settlement_data.gd` | 纯数据 Resource 类，定义结算输入/输出结构 | `class SettlementParams`, `class SettlementResult` |

---

## 三、实施步骤与核心代码

### Step 1：金钱持久化 Autoload 单例（0.5h）

**依赖：** 无

**操作：**
1. 创建 `player_wallet.gd`，注册为 Autoload（项目设置 → Autoload → 名称 `PlayerWallet`）
2. Demo 阶段用内存变量，可选 ConfigFile 写盘

```gdscript
# player_wallet.gd
extends Node

const SAVE_PATH := "user://player_wallet.cfg"
const DEFAULT_MONEY := 1000

var _money: int = DEFAULT_MONEY

func _ready() -> void:
    load_data()

func get_money() -> int:
    return _money

func add_money(amount: int) -> void:
    _money += amount
    _money = max(_money, 0)

func deduct_money(amount: int) -> bool:
    if amount > _money:
        return false
    _money -= amount
    return true

func set_money(amount: int) -> void:
    _money = max(amount, 0)

func reset() -> void:
    _money = DEFAULT_MONEY

# --- 可选存盘（Demo 可不调用，内存即可） ---
func save_data() -> void:
    var config := ConfigFile.new()
    config.set_value("wallet", "money", _money)
    config.save(SAVE_PATH)

func load_data() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        _money = config.get_value("wallet", "money", DEFAULT_MONEY)
```

---

### Step 2：收益计算纯函数（1.5h）

**依赖：** 模块03（热度值、竞品数据、题材用户池）的数据结构约定

**实现内容：**
- 热度乘数查表
- 空窗期用户计算
- 存量份额计算
- 最终收益 = 空窗期收入 + 存量收入
- 纯 static 函数，无节点依赖，可直接写测试场景验证

```gdscript
# settlement_calculator.gd
class_name SettlementCalculator


## 热度乘数查表
static func get_heat_multiplier(heat: float) -> float:
    if heat >= 80.0:
        return 2.0
    elif heat >= 60.0:
        return 1.5
    elif heat >= 40.0:
        return 1.0
    elif heat >= 20.0:
        return 0.6
    else:
        return 0.3


## 核心结算计算
## params 字典结构：
##   total_users: int        — 题材用户池大小 (1000-5000)
##   pay_ability: float      — 用户付费能力 (0.5-2.0)
##   window_ratio: float     — 空窗期时长占比 (0.0-1.0)
##   heat: float             — 上线时刻的市场热度 (0-100)
##   player_quality: float   — 玩家产品品质分
##   competitor_qualities: Array[float] — 所有竞品品质分
## 返回 Dictionary，包含完整结算明细
static func calculate(params: Dictionary) -> Dictionary:
    var total_users: int = params.get("total_users", 3000)
    var pay_ability: float = params.get("pay_ability", 1.0)
    var window_ratio: float = clampf(params.get("window_ratio", 0.0), 0.0, 1.0)
    var heat: float = params.get("heat", 50.0)
    var player_quality: float = params.get("player_quality", 50.0)
    var competitor_qualities: Array = params.get("competitor_qualities", [])

    var heat_multiplier := get_heat_multiplier(heat)

    # 1. 空窗期用户（先到先得）
    var window_users := floori(total_users * window_ratio * heat_multiplier)
    var window_revenue := floori(window_users * pay_ability)

    # 2. 存量用户争夺（品质权重分配）
    var remaining_users := total_users - window_users
    var total_quality := player_quality
    for q in competitor_qualities:
        total_quality += q
    var share_ratio := player_quality / total_quality if total_quality > 0.0 else 0.0
    var share_users := floori(remaining_users * share_ratio)
    var share_revenue := floori(share_users * pay_ability)

    # 3. 最终收益
    var total_revenue := window_revenue + share_revenue

    return {
        "window_users": window_users,
        "window_revenue": window_revenue,
        "share_users": share_users,
        "share_revenue": share_revenue,
        "heat_multiplier": heat_multiplier,
        "total_revenue": total_revenue,
        # 明细行（供结算界面逐条展示）
        "breakdown": [
            {
                "label": "空窗期用户收入",
                "value": window_revenue,
                "detail": "%d 用户 × ¥%.1f" % [window_users, pay_ability]
            },
            {
                "label": "品质竞争收入",
                "value": share_revenue,
                "detail": "%d 用户 × ¥%.1f" % [share_users, pay_ability]
            },
            {
                "label": "热度加成",
                "value": -1,  # 特殊标记：非金额行
                "detail": "×%.1f（已计入上述收入）" % heat_multiplier
            },
        ],
    }
```

---

### Step 3：上线确认弹窗（1h）

**依赖：** Step 2（热度乘数映射）、模块04（研发主界面存在，gameState 可读取）

**场景树 `launch_confirm_dialog.tscn`：**

```
CanvasLayer (overlay 层级)
└── PanelContainer "ConfirmPanel"
    └── MarginContainer
        └── VBoxContainer
            ├── Label "Title"                   # "确认上线？"
            ├── HSeparator
            ├── VBoxContainer "SummaryList"
            │   ├── Label "QualityLabel"        # 品质（模糊/真实）
            │   ├── Label "TimeLabel"           # 剩余时间
            │   ├── Label "HeatLabel"           # 市场热度信号
            │   └── Label "CompetitorLabel"     # 已上线竞品数
            ├── HSeparator
            └── HBoxContainer "ButtonRow"
                ├── Button "ConfirmBtn"          # "确认上线"
                └── Button "CancelBtn"           # "再想想"
```

```gdscript
# launch_confirm_dialog.gd
extends CanvasLayer

signal confirmed
signal cancelled

@onready var quality_label: Label = %QualityLabel
@onready var time_label: Label = %TimeLabel
@onready var heat_label: Label = %HeatLabel
@onready var competitor_label: Label = %CompetitorLabel
@onready var confirm_btn: Button = %ConfirmBtn
@onready var cancel_btn: Button = %CancelBtn


func _ready() -> void:
    confirm_btn.pressed.connect(_on_confirm)
    cancel_btn.pressed.connect(_on_cancel)
    # 弹窗出现时暂停游戏时间
    get_tree().paused = true


## 用游戏状态填充摘要
func setup(game_state: Dictionary) -> void:
    # 品质：是否做过内测决定显示真实/模糊
    if game_state.get("did_playtest", false):
        quality_label.text = "品质：%d 分" % game_state.get("quality_score", 0)
    else:
        quality_label.text = "品质：%s（未经内测验证）" % _get_fuzzy_quality(
            game_state.get("quality_score", 0)
        )

    time_label.text = "剩余时间：%d 天" % game_state.get("time_left", 0)
    heat_label.text = "市场热度：%s" % _get_heat_label(
        game_state.get("current_heat", 50.0)
    )
    competitor_label.text = "已上线竞品：%d 款" % game_state.get(
        "launched_competitors", 0
    )


## 模糊品质映射：未做内测的玩家只能看到粗略描述
func _get_fuzzy_quality(score: int) -> String:
    if score >= 80:
        return "感觉还不错"
    elif score >= 50:
        return "中规中矩吧"
    else:
        return "心里有点没底"


func _get_heat_label(heat: float) -> String:
    if heat >= 80.0:
        return "🔥 火爆"
    elif heat >= 60.0:
        return "📈 上升中"
    elif heat >= 40.0:
        return "➡️ 平稳"
    elif heat >= 20.0:
        return "📉 降温中"
    else:
        return "🧊 冷门"


func _on_confirm() -> void:
    get_tree().paused = false
    confirmed.emit()
    queue_free()


func _on_cancel() -> void:
    get_tree().paused = false
    cancelled.emit()
    queue_free()
```

---

### Step 4：失败结算场景 + 逐条 Tween 动画（2h）⭐ 核心体验

**依赖：** Step 1（PlayerWallet），模块02（入场资源购入数据）

**设计意图：** 搜打撤"失去恐惧"的情绪高潮。一项一项把资源摆出来、一项一项标红划掉，让玩家感受每一分钱的消失。Tween 链式调用天然适合做这种逐条延迟+淡入+颜色变化。

**场景树 `failure_settlement.tscn`：**

```
Control "FailureSettlement" (全屏，锚点 full_rect)
├── ColorRect "DimBackground"           # 半透明黑色遮罩
└── CenterContainer
    └── PanelContainer "MainPanel"
        └── MarginContainer
            └── VBoxContainer "ContentVBox"
                ├── Label "Title"               # "❌ 开发超期，项目流产"
                ├── Label "Subtitle"            # "你带入了以下资源："
                ├── VBoxContainer "ResourceList" # 动态填充资源条目
                ├── HSeparator
                ├── Label "TotalLossLabel"      # "总计损失：¥XXX"
                ├── Label "RemainingLabel"      # "剩余金钱：¥XXX"
                └── HBoxContainer "ButtonRow"
                    ├── Button "RetryBtn"       # "再来一局"
                    └── Button "MenuBtn"        # "返回主菜单"
```

**资源条目（代码动态创建）：**

```
HBoxContainer "ResourceItem"
├── Label "IconLabel"       # 🧑‍💻 / 🏭 / 🤝
├── Label "NameLabel"       # "鹅皇互娱主创"
├── Label "CostLabel"       # "¥300"
└── Label "LossMarkLabel"   # "[已损失]" ← 先隐藏，后标红出现
```

**动画时间线（Tween 编排）：**

```
0.0s    — 遮罩淡入
0.3s    — 标题淡入滑下："❌ 开发超期，项目流产"
1.0s    — 副标题淡入："你带入了以下资源："
1.8s    — 第1条资源从左滑入
2.4s    — 第1条 [已损失] 标红闪烁
3.0s    — 第2条资源从左滑入
3.6s    — 第2条 [已损失] 标红闪烁
4.2s    — 第3条资源从左滑入
4.8s    — 第3条 [已损失] 标红闪烁
5.6s    — 总计损失（数字从0滚动到目标值）
6.4s    — 剩余金钱显示
7.2s    — 按钮淡入
```

```gdscript
# failure_settlement.gd
extends Control

signal action_chosen(action: String)  # "retry" 或 "menu"

@onready var dim_bg: ColorRect = %DimBackground
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var resource_list: VBoxContainer = %ResourceList
@onready var total_loss_label: Label = %TotalLossLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var retry_btn: Button = %RetryBtn
@onready var menu_btn: Button = %MenuBtn

# 动画时间常量（秒）
const DIM_DURATION := 0.3
const TITLE_DELAY := 0.3
const SUBTITLE_DELAY := 1.0
const FIRST_ITEM_DELAY := 1.8
const ITEM_INTERVAL := 0.6       # 每条资源间隔
const LOSS_MARK_OFFSET := 0.6    # 资源出现后多久标红
const POST_ITEMS_GAP := 0.8      # 最后一条标红后到总计
const NUMBER_ROLL_DURATION := 0.8
const BUTTON_DELAY := 0.8

var _total_loss: int = 0


func _ready() -> void:
    retry_btn.pressed.connect(func(): action_chosen.emit("retry"))
    menu_btn.pressed.connect(func(): action_chosen.emit("menu"))
    # 初始全部隐藏
    _hide_all()


## 外部调用：传入失败数据，启动结算动画
## data 结构：
##   resources: Array[Dictionary]  — [{ icon, name, cost }]
##   total_loss: int
##   remaining_money: int
func setup(data: Dictionary) -> void:
    var resources: Array = data.get("resources", [])
    _total_loss = data.get("total_loss", 0)
    var remaining: int = data.get("remaining_money", 0)

    # 预创建资源条目节点（隐藏状态）
    var item_nodes: Array[HBoxContainer] = []
    for res in resources:
        var item := _create_resource_item(res)
        resource_list.add_child(item)
        item.modulate.a = 0.0
        item_nodes.append(item)

    # 预填文本（隐藏状态）
    title_label.text = "❌ 开发超期，项目流产"
    subtitle_label.text = "你带入了以下资源："
    remaining_label.text = "剩余金钱：¥%d" % remaining

    # --- Tween 动画编排 ---
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

    # 1. 遮罩淡入
    tween.tween_property(dim_bg, "color:a", 0.6, DIM_DURATION).from(0.0)

    # 2. 标题淡入 + 从上方滑下
    tween.tween_interval(TITLE_DELAY - DIM_DURATION)
    tween.tween_callback(func(): _fade_slide_in(title_label, Vector2(0, -20)))

    # 3. 副标题淡入
    tween.tween_interval(SUBTITLE_DELAY - TITLE_DELAY)
    tween.tween_callback(func(): _fade_slide_in(subtitle_label, Vector2(0, -10)))

    # 4. 逐条资源滑入 + 标红
    tween.tween_interval(FIRST_ITEM_DELAY - SUBTITLE_DELAY)
    for i in item_nodes.size():
        var item_node := item_nodes[i]
        var loss_mark: Label = item_node.get_node("LossMarkLabel")

        # 资源条从左滑入
        tween.tween_callback(func(): _fade_slide_in(item_node, Vector2(-40, 0)))

        # 间隔后 [已损失] 标红闪烁
        tween.tween_interval(LOSS_MARK_OFFSET)
        tween.tween_callback(func(): _show_loss_mark(loss_mark))

        # 下一条间隔
        if i < item_nodes.size() - 1:
            tween.tween_interval(ITEM_INTERVAL)

    # 5. 总计损失（数字滚动）
    tween.tween_interval(POST_ITEMS_GAP)
    tween.tween_callback(func(): total_loss_label.modulate.a = 1.0)
    tween.tween_method(_update_total_loss_text, 0, _total_loss, NUMBER_ROLL_DURATION) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

    # 6. 剩余金钱
    tween.tween_interval(BUTTON_DELAY)
    tween.tween_callback(func(): _fade_slide_in(remaining_label, Vector2(0, 10)))

    # 7. 按钮淡入
    tween.tween_interval(BUTTON_DELAY)
    tween.tween_callback(_show_buttons)


func _hide_all() -> void:
    dim_bg.color.a = 0.0
    title_label.modulate.a = 0.0
    subtitle_label.modulate.a = 0.0
    total_loss_label.modulate.a = 0.0
    remaining_label.modulate.a = 0.0
    retry_btn.modulate.a = 0.0
    menu_btn.modulate.a = 0.0
    retry_btn.disabled = true
    menu_btn.disabled = true


## 淡入+位移动画（通用）
func _fade_slide_in(node: Control, offset: Vector2) -> void:
    node.position += offset
    node.modulate.a = 0.0
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(node, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
    t.tween_property(node, "position", node.position - offset, 0.35) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## [已损失] 标红闪烁
func _show_loss_mark(label: Label) -> void:
    label.text = "[已损失]"
    label.modulate = Color(1, 1, 1, 0)
    label.add_theme_color_override("font_color", Color.RED)

    var t := create_tween()
    # 淡入 + 放大回弹
    t.tween_property(label, "modulate:a", 1.0, 0.15)
    t.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
    t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
    # 颜色闪烁：红→深红→红
    t.set_parallel(true)
    t.tween_property(label, "theme_override_colors/font_color",
        Color(0.9, 0.1, 0.1), 0.3).from(Color(1, 0.3, 0.3))


## 数字滚动回调
func _update_total_loss_text(value: int) -> void:
    total_loss_label.text = "总计损失：¥%d" % value


## 按钮淡入并启用
func _show_buttons() -> void:
    var t := create_tween().set_parallel(true)
    t.tween_property(retry_btn, "modulate:a", 1.0, 0.3)
    t.tween_property(menu_btn, "modulate:a", 1.0, 0.3)
    t.chain().tween_callback(func():
        retry_btn.disabled = false
        menu_btn.disabled = false
    )


## 创建单条资源条目
func _create_resource_item(res: Dictionary) -> HBoxContainer:
    var hbox := HBoxContainer.new()
    hbox.name = "ResourceItem"
    hbox.add_theme_constant_override("separation", 12)

    var icon_label := Label.new()
    icon_label.name = "IconLabel"
    icon_label.text = res.get("icon", "📦")
    hbox.add_child(icon_label)

    var name_label := Label.new()
    name_label.name = "NameLabel"
    name_label.text = res.get("name", "未知资源")
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(name_label)

    var cost_label := Label.new()
    cost_label.name = "CostLabel"
    cost_label.text = "¥%d" % res.get("cost", 0)
    hbox.add_child(cost_label)

    var loss_mark := Label.new()
    loss_mark.name = "LossMarkLabel"
    loss_mark.text = ""  # 初始为空，动画中填入
    loss_mark.pivot_offset = loss_mark.size / 2.0  # 放大动画以中心为锚点
    hbox.add_child(loss_mark)

    return hbox
```

---

### Step 5：成功结算场景 + 逐条 Tween 动画（1.5h）

**依赖：** Step 1（PlayerWallet）、Step 2（计算结果）、Step 4（复用 `_fade_slide_in` 等工具方法，可抽到基类或 utility）

**场景树 `success_settlement.tscn`：**

```
Control "SuccessSettlement" (全屏，锚点 full_rect)
├── ColorRect "DimBackground"
└── CenterContainer
    └── PanelContainer "MainPanel"
        └── MarginContainer
            └── VBoxContainer "ContentVBox"
                ├── Label "Title"               # "✅ 《游戏名》上线成功！"
                ├── Label "Subtitle"            # "📊 收益明细："
                ├── VBoxContainer "BreakdownList" # 动态填充收益条目
                ├── HSeparator
                ├── Label "TotalRevenueLabel"   # "本局总收入：¥XXX"
                ├── Label "CurrentMoneyLabel"   # "💰 当前金钱：¥XXX"
                └── HBoxContainer "ButtonRow"
                    ├── Button "RetryBtn"       # "再来一局"
                    └── Button "MenuBtn"        # "返回主菜单"
```

**动画时间线：**

```
0.0s    — 遮罩淡入
0.3s    — 标题淡入："✅ 《xxx》上线成功！"
1.0s    — "📊 收益明细："
1.8s    — 空窗期用户收入（滑入 + 数字滚动）
2.6s    — 品质竞争收入（滑入 + 数字滚动）
3.4s    — 热度加成（滑入）
4.2s    — 分割线 + 本局总收入（数字从0滚动到最终值）
5.4s    — 💰 当前金钱
6.2s    — 按钮淡入
```

```gdscript
# success_settlement.gd
extends Control

signal action_chosen(action: String)

@onready var dim_bg: ColorRect = %DimBackground
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var breakdown_list: VBoxContainer = %BreakdownList
@onready var total_revenue_label: Label = %TotalRevenueLabel
@onready var current_money_label: Label = %CurrentMoneyLabel
@onready var retry_btn: Button = %RetryBtn
@onready var menu_btn: Button = %MenuBtn

const ITEM_INTERVAL := 0.8
const NUMBER_ROLL_DURATION := 0.8

var _total_revenue: int = 0


func _ready() -> void:
    retry_btn.pressed.connect(func(): action_chosen.emit("retry"))
    menu_btn.pressed.connect(func(): action_chosen.emit("menu"))
    _hide_all()


## 外部调用
## data 结构：
##   game_name: String
##   breakdown: Array[Dictionary]  — [{ label, value, detail }]
##   total_revenue: int
##   current_money: int
func setup(data: Dictionary) -> void:
    var game_name: String = data.get("game_name", "未命名")
    var breakdown: Array = data.get("breakdown", [])
    _total_revenue = data.get("total_revenue", 0)
    var current_money: int = data.get("current_money", 0)

    title_label.text = "✅ 《%s》上线成功！" % game_name
    subtitle_label.text = "📊 收益明细："
    current_money_label.text = "💰 当前金钱：¥%d" % current_money

    # 预创建收益条目
    var item_nodes: Array[HBoxContainer] = []
    for entry in breakdown:
        var item := _create_breakdown_item(entry)
        breakdown_list.add_child(item)
        item.modulate.a = 0.0
        item_nodes.append(item)

    # --- Tween 动画编排 ---
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

    # 遮罩
    tween.tween_property(dim_bg, "color:a", 0.6, 0.3).from(0.0)

    # 标题
    tween.tween_interval(0.3)
    tween.tween_callback(func(): _fade_slide_in(title_label, Vector2(0, -20)))

    # 副标题
    tween.tween_interval(0.7)
    tween.tween_callback(func(): _fade_slide_in(subtitle_label, Vector2(0, -10)))

    # 逐条收益滑入
    tween.tween_interval(0.8)
    for i in item_nodes.size():
        tween.tween_callback(func(): _fade_slide_in(item_nodes[i], Vector2(-30, 0)))
        if i < item_nodes.size() - 1:
            tween.tween_interval(ITEM_INTERVAL)

    # 总收入数字滚动
    tween.tween_interval(ITEM_INTERVAL)
    tween.tween_callback(func(): total_revenue_label.modulate.a = 1.0)
    tween.tween_method(_update_revenue_text, 0, _total_revenue, NUMBER_ROLL_DURATION) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

    # 当前金钱
    tween.tween_interval(0.6)
    tween.tween_callback(func(): _fade_slide_in(current_money_label, Vector2(0, 10)))

    # 按钮
    tween.tween_interval(0.6)
    tween.tween_callback(_show_buttons)


func _hide_all() -> void:
    dim_bg.color.a = 0.0
    for node in [title_label, subtitle_label, total_revenue_label,
                 current_money_label, retry_btn, menu_btn]:
        node.modulate.a = 0.0
    retry_btn.disabled = true
    menu_btn.disabled = true


func _fade_slide_in(node: Control, offset: Vector2) -> void:
    node.position += offset
    node.modulate.a = 0.0
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(node, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
    t.tween_property(node, "position", node.position - offset, 0.35) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _update_revenue_text(value: int) -> void:
    total_revenue_label.text = "本局总收入：¥%d" % value


func _show_buttons() -> void:
    var t := create_tween().set_parallel(true)
    t.tween_property(retry_btn, "modulate:a", 1.0, 0.3)
    t.tween_property(menu_btn, "modulate:a", 1.0, 0.3)
    t.chain().tween_callback(func():
        retry_btn.disabled = false
        menu_btn.disabled = false
    )


func _create_breakdown_item(entry: Dictionary) -> HBoxContainer:
    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 16)

    var label := Label.new()
    label.text = entry.get("label", "")
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(label)

    var value_label := Label.new()
    var val: int = entry.get("value", 0)
    if val >= 0:
        value_label.text = "+¥%d" % val
        value_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
    else:
        # 热度加成等非金额行
        value_label.text = entry.get("detail", "")
        value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    hbox.add_child(value_label)

    return hbox
```

---

### Step 6：流程串联与集成（1.5h）

**依赖：** Step 1-5 全部完成，模块02/03/04 接口就绪

**实现内容：**
- 研发界面"上线"按钮 → 实例化确认弹窗 → 信号处理
- 确认 → 调用 SettlementCalculator → PlayerWallet.add_money → 加载成功结算场景
- 时间耗尽 → 直接加载失败结算场景
- 结算场景 `action_chosen` → 跳转入场选购或主菜单

```gdscript
# 主流程串联示例（在研发场景或 GameManager 中）

## 预加载场景
const LaunchConfirmScene := preload("res://scenes/ui/launch_confirm_dialog.tscn")
const SuccessScene := preload("res://scenes/settlement/success_settlement.tscn")
const FailureScene := preload("res://scenes/settlement/failure_settlement.tscn")


## 玩家点击上线按钮
func _on_launch_button_pressed() -> void:
    var dialog := LaunchConfirmScene.instantiate()
    add_child(dialog)

    dialog.setup(_build_game_state_summary())

    dialog.confirmed.connect(_on_launch_confirmed)
    dialog.cancelled.connect(func(): pass)  # 弹窗自行 queue_free


## 确认上线 → 计算收益 → 进入成功结算
func _on_launch_confirmed() -> void:
    var result := SettlementCalculator.calculate({
        "total_users": current_genre.user_pool,
        "pay_ability": current_genre.pay_ability,
        "window_ratio": _calc_window_ratio(),
        "heat": current_heat,
        "player_quality": quality_score,
        "competitor_qualities": competitors.map(func(c): return c.quality),
    })

    PlayerWallet.add_money(result.total_revenue)

    var scene := SuccessScene.instantiate()
    get_tree().current_scene.add_child(scene)
    scene.setup({
        "game_name": game_name,
        "breakdown": result.breakdown,
        "total_revenue": result.total_revenue,
        "current_money": PlayerWallet.get_money(),
    })
    scene.action_chosen.connect(_on_post_settlement)


## 时间耗尽 → 强制失败结算
func _on_time_expired() -> void:
    var scene := FailureScene.instantiate()
    get_tree().current_scene.add_child(scene)
    scene.setup({
        "resources": entry_resources,  # [{ icon, name, cost }]
        "total_loss": entry_resources.reduce(
            func(acc, r): return acc + r.cost, 0
        ),
        "remaining_money": PlayerWallet.get_money(),
    })
    scene.action_chosen.connect(_on_post_settlement)


## 结算后路由
func _on_post_settlement(action: String) -> void:
    match action:
        "retry":
            get_tree().change_scene_to_file("res://scenes/entry_shop.tscn")
        "menu":
            get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

---

## 四、依赖关系图

```
模块02（入场资源）──→ entry_resources 数据 ──→ 失败结算展示
模块03（市场热度）──→ 热度值/竞品数据/用户池 ──→ 收益计算
模块04（研发流程）──→ 品质分/剩余时间 ──→ 上线确认 + 收益计算
                 ──→ time_expired 信号 ──→ 触发失败结算

本模块 ──→ PlayerWallet 金钱更新 ──→ 模块02（下一局入场选购）
本模块 ──→ action_chosen 信号   ──→ 场景路由（入场选购/主菜单）
```

**开发顺序：** Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6

- Step 1（PlayerWallet 单例）零依赖，5分钟搞定，后续都要用
- Step 2（计算公式）纯函数，可以写个测试场景直接 `print()` 验证
- Step 3（确认弹窗）可 mock game_state 独立开发
- Step 4（失败动画）是核心体验，留足 Tween 调试时间
- Step 5 复用 Step 4 的 Tween 编排模式，较快
- Step 6 串联全部，需要其他模块接口就绪（可先用 mock）

---

## 五、工时汇总

| 步骤 | 内容 | 工时 |
|------|------|------|
| Step 1 | 金钱持久化 Autoload 单例 | 0.5h |
| Step 2 | 收益计算纯函数 | 1.5h |
| Step 3 | 上线确认弹窗 | 1h |
| Step 4 | 失败结算 + 逐条 Tween 动画 ⭐ | 2h |
| Step 5 | 成功结算 + 逐条 Tween 动画 | 1.5h |
| Step 6 | 流程串联与集成测试 | 1.5h |
| **总计** | | **8h** |

---

## 六、风险与降级策略

| 风险 | 降级方案 |
|------|---------|
| Tween 动画调试耗时（节奏/缓动/回弹反复调参） | 砍掉 `scale` 回弹和颜色闪烁，只保留 `modulate:a` 淡入 + `position` 滑入。逐条延迟是底线，绝不能砍 |
| 数字滚动效果卡顿或不自然 | 改为直接设置最终数字 + 淡入，省掉 `tween_method` 插值 |
| 模块03/04 接口未就绪 | Step 2 `SettlementCalculator.calculate()` 是纯函数，用硬编码 mock 数据跑通全流程 |
| 音效来不及 | 纯视觉可交付。音效标记为 P1 后续加（`AudioStreamPlayer` 在 Tween callback 中 `play()` 即可） |
| 总工时超 8h | 优先级：失败逐条动画 > 收益计算 > 成功动画 > 确认弹窗美化 > 数字滚动特效 |
| `pivot_offset` 未正确设置导致 scale 动画偏移 | 在 `_create_resource_item` 中对 LossMarkLabel 设置 `pivot_offset = size / 2`；若仍有问题，放弃 scale 只用 alpha |

---

## 七、Godot 特有注意事项

1. **Tween 生命周期**：`create_tween()` 创建的 Tween 绑定到调用节点，节点 `queue_free()` 时自动清理，无需手动管理
2. **暂停兼容**：确认弹窗设置 `get_tree().paused = true`，Tween 用 `set_pause_mode(TWEEN_PAUSE_PROCESS)` 确保弹窗内动画不受暂停影响
3. **unique_name 引用**：场景树中用 `%NodeName`（unique name）引用节点，比 `$Path/To/Node` 更抗重构
4. **Autoload 访问**：`PlayerWallet` 注册为 Autoload 后，任意脚本可直接 `PlayerWallet.get_money()` 访问，无需 `get_node("/root/PlayerWallet")`
5. **信号解耦**：结算场景只发 `action_chosen` 信号，不直接调用场景切换，由上层（GameManager 或研发场景）决定路由目标
