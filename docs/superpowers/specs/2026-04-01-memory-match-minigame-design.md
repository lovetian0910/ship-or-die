# 素材归档（记忆翻牌小游戏）设计规格

> 状态：已确认
> 日期：2026-04-01
> 涉及系统：小游戏框架、fight_event_popup、Config

---

## 一、概述

新增第三种小游戏类型"素材归档"（记忆翻牌），作为打类危机事件的可选小游戏。

**叙事包装**：美术素材库索引损坏，大量文件名丢失，玩家需在限时内通过翻牌配对找回素材。

**与现有小游戏的差异化**：

| | Code Rescue | Bug Survivor | 素材归档 |
|--|------------|-------------|---------|
| 核心能力 | 优先级判断 | 操作反应 | 记忆力 |
| 操作 | 点格子修复 | WASD移动 | 点格子翻牌 |
| 节奏 | 被动应对 | 持续高压 | 主动节奏 |
| 紧张来源 | bug在蔓延 | 被虫子包围 | 时间在流逝 |

---

## 二、核心玩法

### 2.1 基本规则

- 4×3 网格，12张牌 = 6对
- 牌面朝下显示 `?` 图标
- 玩家每次点击翻开一张牌，翻开第二张后判断是否配对：
  - **配对成功** → 两张牌消除（变绿 + 缩小消失）
  - **配对失败** → 停留0.5秒让玩家记住内容，然后翻回去
- 限时15秒，时间到自动结算
- 全部6对配完则提前结束（大成功）

### 2.2 操作流

```
点击牌A → 翻牌动画(0.3s) → 显示内容
  ↓
点击牌B → 翻牌动画(0.3s) → 显示内容
  ↓
判断A==B？
  ├─ 是 → 配对成功动画(0.3s) → 两牌消除 → 可继续翻
  └─ 否 → 停留(0.5s) → 翻回动画(0.3s) → 可继续翻
```

**操作锁定**：翻牌动画播放中、配对判定中，禁止点击其他牌。

### 2.3 卡面素材

从两组混合池中每局随机抽6张，生成6对共12张，打乱分布到网格：

**Emoji Icons 池**（通过 AssetRegistry 加载）：
- `icon_money`、`icon_warning`、`icon_success`、`icon_fail`
- `icon_search`、`icon_treasure`、`icon_launch`、`icon_polish`
- `icon_time`、`icon_info`、`icon_gamepad`、`icon_team`

**角色立绘池**（通过 AssetRegistry 加载）：
- `creator_low`、`creator_mid`、`creator_high`
- `outsource_low`、`outsource_mid`、`outsource_high`
- `business_low`、`business_mid`、`business_high`

总池约21张，每局随机取6张，保证每局体验不同。

---

## 三、视觉表现

### 3.1 卡牌样式

- **背面（未翻开）**：深灰色块 `Color(0.25, 0.25, 0.30)` + `?` 图标，跟迷雾地图 FOGGY 格子同风格
- **正面（翻开）**：浅色底 `Color(0.35, 0.35, 0.40)` + 居中显示素材图标
- **已消除**：绿色底 `Color(0.2, 0.6, 0.2, 0.3)` + 透明，不可再点击

### 3.2 翻牌动画（3D 模拟）

使用 Tween 压缩 `scale.x` 模拟翻转：
1. `scale.x` 从 1.0 → 0.0（0.15秒，`EASE_IN` + `TRANS_SINE`）
2. 在 `scale.x == 0.0` 瞬间切换内容（背面→正面，或正面→背面）
3. `scale.x` 从 0.0 → 1.0（0.15秒，`EASE_OUT` + `TRANS_SINE`）

总翻牌时长：0.3秒

### 3.3 配对结果动画

- **配对成功**：两张牌背景闪绿（0.2秒），然后 `scale` 整体从 1.0→0.0 缩小消失（0.3秒）
- **配对失败**：两张牌背景短暂闪红（0.15秒），然后执行翻回动画（0.3秒）

### 3.4 背景与布局

- 背景深色 `Color(0.12, 0.12, 0.16)`，跟 Code Rescue 终端风一致
- 网格居中，卡牌间距8px
- 顶部显示：剩余时间（倒计时）+ 已配对数 `X/6`
- 卡牌尺寸：根据游戏区域自适应，约 80×100px

---

## 四、结算映射

与现有小游戏一致的三档结算：

| 配对数 | completion_rate | 结果等级 | 说明 |
|--------|----------------|---------|------|
| 6/6 | 1.0 | risky（大成功） | 素材全部归档 |
| 4-5/6 | 0.67-0.83 | steady（稳妥） | 抢救了大部分 |
| 0-3/6 | 0.0-0.50 | conservative（保守） | 大量素材丢失 |

`completion_rate = matched_pairs / total_pairs`

结果等级阈值复用现有逻辑：≥0.9 = risky，0.6-0.9 = steady，<0.6 = conservative

---

## 五、叙事文本

### 事件定义

- **event_id**: `fight_memory_01`
- **title**: "素材库崩溃"
- **description**: "美术素材库索引损坏，大量文件名丢失！紧急配对归档，找回越多越好。"
- **minigame_type**: `"memory_match"`

### 结果文案

- **risky（大成功）**："素材全部归档完成！研发效率不降反升"
- **steady（稳妥）**："抢救了大部分素材，损失可控"
- **conservative（保守）**："大量素材丢失，美术返工严重"

---

## 六、预设系统

### MemoryMatchPreset（Resource 子类）

```
preset_id: String          # 预设ID
preset_name: String        # 预设名（UI显示）
grid_rows: int = 3         # 行数
grid_cols: int = 4         # 列数
time_limit: float = 15.0   # 时间限制（秒）
flip_duration: float = 0.3 # 翻牌动画时长（秒）
peek_duration: float = 0.5 # 配对失败后停留时长（秒）
```

### 预设变体

| 预设 | 网格 | 时限 | 叙事包装 |
|------|------|------|---------|
| memory_standard | 4×3 | 15s | 素材库崩溃 |

后续可新增变体（缩短时限、加大网格），无需改代码。

---

## 七、数据层 MemoryMatchData

纯逻辑层，不依赖场景树，可独立测试。

### 状态

```
grid: Array[Array[int]]       # 网格，值为素材ID（0~5代表6种素材）
revealed: Array[Array[bool]]  # 是否翻开
matched: Array[Array[bool]]   # 是否已配对消除
first_pick: Vector2i          # 第一张翻开的位置（-1,-1表示未选）
matched_pairs: int            # 已配对数
total_pairs: int              # 总对数（6）
elapsed: float                # 已用时间
time_limit: float             # 时间限制
is_finished: bool             # 是否结束
```

### 方法

```
setup(preset: MemoryMatchPreset) → void          # 初始化网格，随机分配素材对
pick_card(row, col) → PickResult                  # 翻牌，返回结果枚举
  → FIRST_REVEALED: 翻开第一张
  → MATCH_SUCCESS: 第二张配对成功
  → MATCH_FAIL: 第二张配对失败
  → INVALID: 无效操作（已翻开/已消除/动画中）
advance_time(delta) → void                        # 推进时间
get_completion_rate() → float                     # matched_pairs / total_pairs
get_result_tier() → String                        # "risky" / "steady" / "conservative"
```

### 素材ID分配逻辑

1. 从混合素材池（21张）中随机取6张，编号 0-5
2. 生成数组 `[0,0,1,1,2,2,3,3,4,4,5,5]`
3. 洗牌后填入 4×3 网格

---

## 八、技术接入

### 新增文件

| 文件 | 说明 |
|------|------|
| `game/scripts/resources/memory_match_preset.gd` | 预设 Resource 类 |
| `game/scripts/minigame/memory_match_data.gd` | 数据层（纯逻辑） |
| `game/scripts/minigame/memory_match_game.gd` | 游戏场景脚本 |
| `game/scenes/minigame/memory_match_game.tscn` | 游戏场景 |
| `game/resources/minigame_presets/memory_standard.tres` | 标准预设 |
| `game/resources/events/fight_memory_01.tres` | 事件数据 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `game/scripts/popups/fight_event_popup.gd` | `_on_start_rescue()` 新增 `"memory_match"` 分支 |
| `game/tests/test_runner.gd` | 新增 MemoryMatchData 单元测试 |

### Config 新增常量

```
MEMORY_MATCH_TIME_LIMIT: float = 15.0    # 时限（秒）
MEMORY_MATCH_GRID_ROWS: int = 3          # 行数
MEMORY_MATCH_GRID_COLS: int = 4          # 列数
MEMORY_MATCH_FLIP_DURATION: float = 0.3  # 翻牌动画时长
MEMORY_MATCH_PEEK_DURATION: float = 0.5  # 失败停留时长
MEMORY_MATCH_MONTH_COST: int = 2         # 小游戏消耗月数（与其他小游戏一致）
```

### 素材加载

通过 `AssetRegistry.get_texture(category, key)` 加载：
- Icons: `AssetRegistry.get_texture("icon", key)`
- Portraits: `AssetRegistry.get_texture("portrait", key)`

具体的 key 列表在 `AssetRegistry.gd` 的注册表中已有定义。
