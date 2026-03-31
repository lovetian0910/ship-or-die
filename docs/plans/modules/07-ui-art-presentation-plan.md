# 模块07：UI/美术表现 — 实施方案

> 对应规格：`docs/specs/modules/07-ui-art-presentation.md`
> 技术栈：**Godot 4.6.1 + GDScript**
> 美术总预算：**2.5小时（150分钟）**
> 原则：降级方案先行（ColorRect + Label），美术是增量覆盖，不是前置依赖

---

## 一、技术选型：Godot Theme 系统

### 为什么用 Theme

Godot 的 Theme 资源（`.tres`）是全局换肤利器：**做好一套 Theme，所有 Control 节点自动继承统一风格**——字体、颜色、按钮样式、面板样式一次定义，全局生效，无需逐节点手调。

| 决策项 | 选择 | 理由 |
|-------|------|------|
| UI 框架 | Godot Control 节点树 | 原生 UI 系统，布局/主题/信号一体化 |
| 全局风格 | **Theme 资源 (`pixel_theme.tres`)** | 一处定义，所有 UI 自动统一；改一个 Theme 等于改全局 |
| 像素风核心 | **项目设置 Nearest Filter** | 一行设置，所有纹理自动像素锐利 |
| 字体方案 | `.ttf` → `FontFile` → 嵌入 Theme | Godot 4.x 直接导入 TTF，设为 Theme default_font |
| 降级方案 | `ColorRect` + `Label` + `StyleBoxFlat` | 零美术即可运行，后续替换为图片只需改节点属性 |

### 像素风关键项目设置

**必须在开发第一步就配置，否则所有纹理都会模糊：**

```
Project Settings → Rendering → Textures → Canvas Textures:
  default_texture_filter = Nearest

Project Settings → Display → Window:
  size/viewport_width = 1280
  size/viewport_height = 720
  stretch/mode = canvas_items
  stretch/aspect = keep
```

> **原理：** `Nearest` 过滤器禁止双线性插值，保持像素点锐利边缘。`canvas_items` 拉伸模式让 UI 在不同分辨率下等比缩放而不变形。

---

## 二、美术资源清单

### A. 需要准备的资源总表

| 类型 | 数量 | 格式 | 用途 | 来源 | 导入方式 |
|------|------|------|------|------|---------|
| **Theme 资源** | 1 | `.tres` | 全局像素风主题 | 手工创建 | Godot Theme Editor |
| **字体** | 2 | `.ttf` | 中文主字体 + 像素英文字体 | GitHub 开源 | 拖入 → FontFile → 设入 Theme |
| **角色头像** | 9 | `.png` 256×256 | 入场选购界面（3类×3级） | AI 生图 | 拖入 → TextureRect，Filter 已全局 Nearest |
| **场景氛围图** | 5 | `.png` 512×384 | 主菜单/研发背景/上线/结算×2 | AI 生图 | TextureRect 或 Sprite2D |
| **事件配图** | 6-8 | `.png` 256×256 | 事件弹窗配图（⚠️可降级） | AI 生图 | TextureRect |
| **UI 素材包** | 1套 | `.png` | 按钮/面板/进度条九宫格 | itch.io | 切片 → StyleBoxTexture 或 NinePatchRect |
| **题材图标** | 3-4 | `.png` 64×64 | 选题界面 | itch.io 图标包 | TextureRect |
| **HUD 小图标** | 若干 | `.png` 16-32px | 金币/时钟/星级 | itch.io | TextureRect |

### B. 项目目录结构

```
assets/
├── fonts/
│   ├── SmileySans-Oblique.ttf    # 得意黑（中文主字体，OFL协议）
│   └── fusion-pixel.ttf          # Fusion Pixel（像素英文/数字，OFL协议）
├── images/
│   ├── portraits/                # 9张角色头像
│   │   ├── creator_low.png       # 独立游戏愤青
│   │   ├── creator_mid.png       # 鹅皇互娱主创
│   │   ├── creator_high.png      # 天命堂制作人
│   │   ├── outsource_low.png     # 大学生兼职组
│   │   ├── outsource_mid.png     # 外包铁军
│   │   ├── outsource_high.png    # 越南闪电队
│   │   ├── business_low.png      # 实习商务
│   │   ├── business_mid.png      # 万能商务
│   │   └── business_high.png     # 前渠道教父
│   ├── scenes/                   # 场景氛围图
│   │   ├── menu_bg.png           # 主菜单
│   │   ├── dev_bg.png            # 研发界面背景
│   │   ├── launch_bg.png         # 上线确认
│   │   ├── settle_win.png        # 结算-成功
│   │   └── settle_fail.png       # 结算-失败
│   └── events/                   # 事件配图（P2可砍）
│       ├── event_bug.png
│       ├── event_conflict.png
│       ├── event_copycat.png
│       ├── event_treasure.png
│       ├── event_recruit.png
│       ├── event_intel.png
│       ├── event_playtest.png
│       └── event_polish.png
├── ui/                           # itch.io UI素材包
│   ├── btn_normal.png
│   ├── btn_hover.png
│   ├── btn_pressed.png
│   ├── panel_bg.png              # 九宫格面板底图
│   ├── progress_bg.png
│   ├── progress_fill.png
│   └── icons/                    # 小图标
│       ├── icon_coin.png
│       ├── icon_clock.png
│       └── icon_star.png
└── themes/
    └── pixel_theme.tres          # 全局像素风Theme
```

### C. 字体资源

| 字体 | 用途 | 来源 | 协议 |
|------|------|------|------|
| 得意黑 (Smiley Sans) | 中文主字体——标题、正文、按钮 | GitHub: `atelier-anchor/smiley-sans` | OFL |
| Fusion Pixel Font | 像素风英文/数字——数值显示、倒计时 | GitHub: `TakWolf/fusion-pixel-font` | OFL |
| 系统等宽字体 | 代码急救小游戏 | Godot 内置 `res://` 或系统 monospace | 零成本 |

**字体导入流程：**
1. 将 `.ttf` 文件放入 `assets/fonts/`
2. Godot 自动识别为 `FontFile` 资源
3. 在 Theme Editor 中：`Default Font` → 拖入得意黑 FontFile
4. 设置 `Default Font Size` = 20（正文）；标题用 Theme Type Override 设 28-32
5. 如需像素字体：对特定 Label 节点 Override `theme_override_fonts/font` 为 Fusion Pixel

---

## 三、Godot Theme 资源设计 (`pixel_theme.tres`)

### 配色 Token

```
# 对应 Theme 中的 Color 常量，通过 GDScript 或 Theme Editor 设置

深蓝黑底     #1a1a2e    ← 全局背景 / Panel 底色
次级底色     #16213e    ← 大面板 / 次级区域
面板色       #0f3460    ← 卡片 / 弹窗 / 按钮底色
主文字       #e8e8e8    ← Label font_color
次级文字     #a0a0b0    ← 弱化文字
金色强调     #f5c842    ← 金钱/收益/高亮
绿色强调     #4ecca3    ← 正面/成功/安全/进度
红色强调     #e74c3c    ← 危险/损失/bug/时间警告
蓝色强调     #3498db    ← 信息/中性/中级资源
紫色强调     #9b59b6    ← 稀有/高级资源
```

### Theme 核心类型覆写

以下是 `pixel_theme.tres` 需要配置的关键 Control 类型：

#### Panel

```
StyleBoxFlat:
  bg_color = #16213e
  border_width_all = 2
  border_color = #e8e8e8
  corner_radius_all = 0          ← 像素风直角！
  content_margin_all = 8
  shadow_color = #00000080
  shadow_offset = Vector2(4, 4)
  shadow_size = 0
```

#### Button

```
# Normal
StyleBoxFlat:
  bg_color = #0f3460
  border_width_all = 2
  border_color = #e8e8e8
  corner_radius_all = 0
  shadow_color = #00000080
  shadow_offset = Vector2(4, 4)

# Hover
StyleBoxFlat:
  bg_color = #1a4a7a            ← 略亮
  border_color = #f5c842        ← 金色边框高亮
  shadow_offset = Vector2(2, 2) ← 阴影缩小=按钮上浮感

# Pressed
StyleBoxFlat:
  bg_color = #0a2a4a            ← 略暗
  border_color = #f5c842
  shadow_offset = Vector2(0, 0) ← 阴影消失=按下感

# Font Colors
font_color = #e8e8e8
font_hover_color = #f5c842
font_pressed_color = #f5c842
```

#### Label

```
font_color = #e8e8e8
font_shadow_color = #00000080
font_shadow_offset = Vector2(2, 2)   ← 像素风文字投影
```

#### ProgressBar

```
# Background
StyleBoxFlat:
  bg_color = #0a0a1a
  border_width_all = 2
  border_color = #e8e8e8
  corner_radius_all = 0

# Fill
StyleBoxFlat:
  bg_color = #4ecca3             ← 绿色默认，代码中按状态切换红色
  corner_radius_all = 0
```

#### PopupPanel（事件弹窗）

```
StyleBoxFlat:
  bg_color = #1a1a2eE6          ← 半透明深底（E6 = 90%不透明）
  border_width_all = 3
  border_color = #f5c842         ← 金色边框突出弹窗
  corner_radius_all = 0
  shadow_color = #000000C0
  shadow_offset = Vector2(6, 6)
```

### Theme 创建步骤（Theme Editor）

1. **新建 Theme 资源：** `FileSystem` → 右键 `assets/themes/` → `New Resource` → `Theme` → 保存为 `pixel_theme.tres`
2. **设置默认字体：** Theme Editor 顶栏 → `Default Font` → 拖入得意黑 FontFile → `Default Font Size` = 20
3. **逐类型配置：** 左侧添加 Type（`Button`, `Panel`, `Label`, `ProgressBar`, `PopupPanel`）→ 按上表设置各项 StyleBox 和 Color
4. **挂载到根节点：** 场景树根 Control 节点 → Inspector → `Theme` 属性 → 拖入 `pixel_theme.tres`
5. **所有子节点自动继承**——无需逐个设置

> **关键：** Godot Theme 是级联继承的，根节点设了 Theme，所有子 Control 自动生效。只有需要特殊样式的节点才用 `theme_override_*` 覆盖。

---

## 四、AI 生图 Prompt 列表

> 工具推荐：DALL-E 3 / Stable Diffusion（SDXL + pixel art LoRA）
> 统一风格前缀：`pixel art, 32-bit style, dark background, game industry theme, clean lines, icon style`

### 角色头像（9张）

| # | 角色 | Prompt |
|---|------|--------|
| 1 | 独立游戏愤青 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a young indie game developer with messy hair, hoodie, passionate eyes, holding a coffee cup, pixel art icon style, clean lines, 256x256` |
| 2 | 鹅皇互娱主创 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a confident corporate game producer, neat suit, smug smile, company badge on chest, pixel art icon style, clean lines, 256x256` |
| 3 | 天命堂制作人 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a legendary game designer, wise old master with glasses, iconic mustache, glowing aura, pixel art icon style, clean lines, 256x256` |
| 4 | 大学生兼职组 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a young college student with backpack, nervous expression, holding laptop, pixel art icon style, clean lines, 256x256` |
| 5 | 外包铁军 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a disciplined outsourcing team leader, military-style beret, serious face, multiple monitors behind, pixel art icon style, clean lines, 256x256` |
| 6 | 越南闪电队 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a lightning-fast coder, cool sunglasses, lightning bolt earring, speed lines effect, pixel art icon style, clean lines, 256x256` |
| 7 | 实习商务 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a young intern in oversized suit, eager smile, holding business cards, pixel art icon style, clean lines, 256x256` |
| 8 | 万能商务 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a smooth-talking business manager, slick hair, phone in each hand, winking, pixel art icon style, clean lines, 256x256` |
| 9 | 前渠道教父 | `pixel art, 32-bit style, dark background, game industry theme, portrait of a powerful godfather figure in gaming industry, cigar, gold rings, shadowy lighting, intimidating presence, pixel art icon style, clean lines, 256x256` |

**策略：** 每个 prompt 生成 2-3 张取最佳。9个 × ~3分钟 ≈ 27分钟，留 3分钟 buffer。

### 场景氛围图（5张）

| # | 用途 | Prompt |
|---|------|--------|
| 10 | 主菜单氛围图 | `pixel art, 32-bit style, wide shot of a game development studio at night, multiple glowing monitors, dark room, neon light leaks through windows, coffee cups scattered, indie game dev atmosphere, cinematic pixel art, 512x256` |
| 11 | 研发主界面背景 | `pixel art, 32-bit style, top-down view of a busy game studio office, desks with computers, whiteboards with game design sketches, dim overhead lighting, cozy dark atmosphere, 512x384` |
| 12 | 上线确认"发射"画面 | `pixel art, 32-bit style, dramatic rocket launch scene, a cartoonish rocket shaped like a game disc blasting off, fire and smoke, countdown display, exciting moment, vibrant against dark sky, 512x384` |
| 13 | 结算-成功底图 | `pixel art, 32-bit style, celebration scene, gold coins raining down, trophy with game controller icon, confetti, warm golden lighting, victory atmosphere, 512x384` |
| 14 | 结算-失败底图 | `pixel art, 32-bit style, dark abandoned office, overturned desk, broken monitor displaying error screen, single flickering light, rain outside window, melancholy atmosphere, 512x384` |

**策略：** 每张 5-6 分钟含挑选，共 ~25分钟，留 5分钟 buffer。

### 事件配图（6-8张，⚠️ P2 可砍）

| # | 事件 | Prompt |
|---|------|--------|
| 15 | 技术事故 | `pixel art, 32-bit style, dark background, computer screen showing red error codes, sparks flying from server rack, panicking pixel characters, alarm lights, game industry theme, 256x256` |
| 16 | 团队内讧 | `pixel art, 32-bit style, dark background, two pixel game developers arguing across desk, papers flying, angry speech bubbles, tense office atmosphere, game industry theme, 256x256` |
| 17 | 竞品抄袭 | `pixel art, 32-bit style, dark background, shadowy figure copying game design documents, magnifying glass, stolen code scrolling on screen, spy thriller vibe, game industry theme, 256x256` |
| 18 | 发现宝藏资源 | `pixel art, 32-bit style, dark background, pixel character opening a glowing treasure chest filled with code scrolls and game assets, excited expression, game industry theme, 256x256` |
| 19 | 招募人才 | `pixel art, 32-bit style, dark background, pixel recruiter shaking hands with star developer, sparkle effects, resume papers floating, game industry theme, 256x256` |
| 20 | 市场情报 | `pixel art, 32-bit style, dark background, pixel spy character looking at holographic market data charts, binoculars, classified folder, game industry theme, 256x256` |
| 21 | 内测验证 | `pixel art, 32-bit style, dark background, pixel testers playing game on multiple devices, feedback forms floating, magnifying glass over game screen, QA theme, 256x256` |
| 22 | 临上线打磨 | `pixel art, 32-bit style, dark background, pixel craftsman polishing a glowing game disc with tools, sparkle effects, workbench with instruments, perfectionist theme, 256x256` |

**策略：** 每张 5分钟，8张 = 40分钟。如果时间不够，全部砍掉用降级方案。

---

## 五、素材导入流程

### 5.1 图片导入（PNG → TextureRect / Sprite2D）

**步骤：**
1. 将 `.png` 文件拖入对应 `assets/` 子目录
2. Godot 自动生成 `.import` 文件
3. **验证 Filter 设置：** 由于项目设置已全局设为 `Nearest`，无需逐图配置。如果个别图片需要平滑（不太可能），可在 Import Dock 单独改为 `Linear`
4. 在场景中使用：
   - **UI 内：** 用 `TextureRect` 节点 → Inspector → `Texture` 拖入 png
   - **非 UI：** 用 `Sprite2D` 节点 → `Texture` 拖入 png

**TextureRect 常用配置：**
```
stretch_mode = STRETCH_KEEP_ASPECT_CENTERED  ← 保持比例居中
expand_mode = EXPAND_IGNORE_SIZE             ← 允许 TextureRect 大于/小于原图
```

### 5.2 九宫格素材（itch.io UI 包 → NinePatchRect / StyleBoxTexture）

itch.io 的像素 UI 素材包通常是 spritesheet 或单图。用于 Theme 的 StyleBox 有两种方式：

**方式 A：NinePatchRect 节点（推荐用于独立面板）**
1. 创建 `NinePatchRect` 节点 → 拖入切好的 panel 图片
2. Inspector → `Patch Margin`：设置上下左右不拉伸区域（像素值）
3. 中间区域自动拉伸填充

**方式 B：StyleBoxTexture（推荐用于 Theme 统一配置）**
1. 在 Theme Editor 中，对 Panel/Button 的 StyleBox 选 `StyleBoxTexture`
2. 拖入切好的图片 → 设置 `texture_margin_*`（九宫格边距）
3. 所有使用该 Theme 类型的节点自动套用

**切图方法：** 如果素材是 spritesheet，用 Godot 内置的 `AtlasTexture`：
1. 新建 `AtlasTexture` 资源 → `Atlas` 指向 spritesheet 图片
2. `Region` 设置裁切矩形（像素坐标）
3. 导出为单独 `.tres` 或直接在节点引用

### 5.3 字体导入（.ttf → FontFile → Theme）

1. 将 `.ttf` 放入 `assets/fonts/`
2. Godot 自动导入为 `FontFile` 资源
3. 打开 `pixel_theme.tres` → Theme Editor → 顶部 `Default Font` → 拖入得意黑
4. `Default Font Size` = 20
5. 如需标题大字：在具体 Label 节点 → `theme_override_font_sizes/font_size` = 32
6. 像素字体用于数值显示：特定 Label → `theme_override_fonts/font` = Fusion Pixel FontFile

> **注意：** 得意黑是斜体设计字体（Smiley Sans Oblique），如果觉得标题斜体不合适，可改用「站酷快乐体」或「思源黑体」作备选，同为 OFL 协议。

---

## 六、降级方案（ColorRect + Label，零美术）

### 原则：降级方案 = 默认实现方案，美术是增量替换

先做 Level 0 可玩，再逐步替换为美术素材。**所有场景必须先以降级方案实现，确保功能闭环。**

### Level 0：纯功能版（零美术，约 60 分钟 Godot 工作）

#### 全局背景

```gdscript
# 任何场景根节点下加 ColorRect 作为背景
var bg = ColorRect.new()
bg.color = Color("#1a1a2e")
bg.set_anchors_preset(Control.PRESET_FULL_RECT)  # 铺满
bg.z_index = -1  # 确保在最底层
add_child(bg)
```

> 实际开发中直接在场景编辑器中放 ColorRect 即可，无需代码。

#### 角色头像降级 → 色块 + 首字

```
场景结构：
MarginContainer
├── ColorRect (背景色，按等级着色)
└── Label (首字缩写，居中)

低级 → bg_color = #a0a0b0 (灰)
中级 → bg_color = #3498db (蓝)
高级 → bg_color = #9b59b6 (紫)
```

```gdscript
# avatar_fallback.gd
extends MarginContainer

@export var character_name: String = "愤"
@export var tier: int = 0  # 0=低, 1=中, 2=高

const TIER_COLORS = [
    Color("#a0a0b0"),  # 低级-灰
    Color("#3498db"),  # 中级-蓝
    Color("#9b59b6"),  # 高级-紫
]

func _ready():
    $ColorRect.color = TIER_COLORS[tier]
    $Label.text = character_name
```

**示例：** 独立游戏愤青 → 灰底色块 + "愤" 字

#### 背景降级 → 渐变 ColorRect

Godot 没有 CSS `linear-gradient`，但可以用 `GradientTexture2D`：

```gdscript
# 创建渐变背景
var tex_rect = TextureRect.new()
var gradient = GradientTexture2D.new()
var grad = Gradient.new()
grad.colors = [Color("#1a1a2e"), Color("#16213e")]
gradient.gradient = grad
gradient.fill_from = Vector2(0.5, 0.0)
gradient.fill_to = Vector2(0.5, 1.0)
tex_rect.texture = gradient
tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
```

> 实际开发中建议直接在场景编辑器中创建 TextureRect + GradientTexture2D，可视化调色，无需代码。

#### 按钮降级 → Theme StyleBoxFlat（已由 Theme 覆盖）

Theme 配好后按钮自动生效，无需额外降级代码。这是 Theme 系统的核心优势。

#### 进度条降级 → ProgressBar（已由 Theme 覆盖）

```gdscript
# 时间条 / 品质条
var bar = ProgressBar.new()
bar.min_value = 0
bar.max_value = 100
bar.value = 75
bar.show_percentage = false  # 不显示百分比文字
# 样式由 Theme 自动控制

# 动态切换颜色（时间不足时变红）
func _on_time_warning():
    var fill_style = bar.get_theme_stylebox("fill").duplicate()
    fill_style.bg_color = Color("#e74c3c")
    bar.add_theme_stylebox_override("fill", fill_style)
```

#### 事件配图降级 → 类型色块 + Emoji Label

```
PanelContainer
├── VBoxContainer
│   ├── Label (大字emoji："🐛" / "💢" / "⚡" / "💎" / "🤝" / "📊")
│   └── Label (事件名称)
```

事件类型 → emoji 映射：
- 技术事故 → 🐛
- 团队内讧 → 💢
- 外部冲击 → ⚡
- 发现资源 → 💎
- 招募人才 → 🤝
- 市场情报 → 📊

### Level 1：基础美术版（+字体 + UI素材包，额外 20 分钟）

在 Level 0 基础上：
- Theme 中 `default_font` 替换为得意黑
- itch.io 素材包切图后替换 Theme 中的 StyleBoxFlat → StyleBoxTexture
- 角色头像仍用色块

### Level 2：完整美术版（+AI生图全部素材，额外 ~75 分钟）

在 Level 1 基础上：
- 角色色块替换为 TextureRect + AI 生图头像
- ColorRect/Gradient 背景替换为 TextureRect + AI 场景图
- 事件 emoji 替换为 TextureRect + AI 事件配图
- 添加上线确认/结算氛围底图

**替换方式：** 每个降级节点旁预留一个 TextureRect（初始隐藏），有图后 `texture = load("res://assets/images/xxx.png")`，隐藏降级节点、显示图片节点。或者更简洁——直接在 TextureRect 上设 texture，没图时 texture 为 null 则 fallback 到背后的 ColorRect。

---

## 七、各画面配色映射

| 画面 | 主色调 | 强调色 | 情绪 |
|------|--------|--------|------|
| 主菜单 | 深蓝黑 `#1a1a2e` | 金色 `#f5c842` | 神秘、期待 |
| 入场选购 | 次级蓝 `#16213e` | 金色(价格) + 三色等级 | 选择、权衡 |
| 选题界面 | 深蓝黑 | 各题材独立色 | 多样、诱惑 |
| 研发主界面 | 深灰蓝 `#16213e` | 绿色(进度) + 红色(警告) | 紧张、忙碌 |
| 事件弹窗 | 半透明黑遮罩 `#1a1a2eE6` | 红=危机 / 蓝=探索 | 突发、紧迫 |
| 代码急救 | 纯黑 `#1e1e1e` | 绿/红/黑三态 | IDE 冷硬风 |
| 上线确认 | 深黑 → 金色渐变 | 金色 `#f5c842` | 仪式感、决断 |
| 结算-成功 | 暖黑底 | 金色+绿色 | 喜悦、丰收 |
| 结算-失败 | 冷黑底 | 红色为主 | 痛苦、后悔 |

### 资源等级色彩编码

| 等级 | 色彩 | 边框/光效 |
|------|------|----------|
| 低级 | 灰白 `#a0a0b0` | 普通 2px 边框 |
| 中级 | 蓝色 `#3498db` | 蓝色微光边框（`border_color` = 蓝，可加 Glow shader） |
| 高级 | 紫金 `#9b59b6` + `#f5c842` | 紫色边框 + 金色角标 Label |

---

## 八、实施步骤与工时

### 步骤总览

| # | 步骤 | 内容 | 工时 | 依赖 | 优先级 |
|---|------|------|------|------|--------|
| 1 | 项目像素风设置 | `default_texture_filter = Nearest`、窗口分辨率、拉伸模式 | 5min | 无，最先做 | **P0** |
| 2 | 创建 Theme 资源 | `pixel_theme.tres`：配色、StyleBox、字体槽位 | 30min | 步骤1 | **P0** |
| 3 | 下载+导入字体 | 得意黑 + Fusion Pixel → `assets/fonts/` → 设入 Theme | 10min | 步骤2 | **P0** |
| 4 | 各画面降级布局 | ColorRect + Label + ProgressBar 搭建所有场景骨架 | 50min | 步骤2 + 各模块场景节点树 | **P0** |
| 5 | 搜索+下载 itch.io 素材包 | UI包 + 图标包 → `assets/ui/` | 10min | 无，可与步骤2并行 | **P1** |
| 6 | 切图+集成 itch.io 素材 | 替换 Theme StyleBoxFlat → StyleBoxTexture / NinePatchRect | 15min | 步骤5 + 步骤2 | **P1** |
| 7 | AI生图-角色头像（9张） | 批量生成，挑选，放入 `assets/images/portraits/` | 30min | 无，可与代码开发并行 | **P1** |
| 8 | AI生图-场景氛围图（5张） | 批量生成，挑选，放入 `assets/images/scenes/` | 30min | 无，可与代码开发并行 | **P1** |
| 9 | AI生图-事件配图（6-8张） | 批量生成 → `assets/images/events/` | 40min | 模块05事件列表确定后 | **P2 可砍** |
| 10 | 素材接入替换 | TextureRect 挂图替换降级色块/渐变 | 15min | 步骤7/8 + 步骤4 | **P1** |
| 11 | 最终视觉调整 | 间距/对齐/一致性/响应式检查 | 10min | 所有步骤 | **P1** |

### 详细工时分解

```
P0 必做（降级方案 + Theme，确保可玩）：
  步骤1  项目像素风设置                 5min
  步骤2  创建 Theme 资源               30min
  步骤3  字体下载导入                   10min
  步骤4  各画面降级布局                 50min
  ─────────────────────────────────────
  P0 小计                              95min（约 1.6h）

P1 应做（基础美术，提升观感）：
  步骤5   itch.io 素材搜索下载          10min
  步骤6   切图集成替换 Theme            15min
  步骤7   AI生图-角色头像               30min
  步骤8   AI生图-场景图                 30min
  步骤10  素材接入替换                  15min
  步骤11  视觉微调                      10min
  ─────────────────────────────────────
  P1 小计                             110min（约 1.8h）

P2 可砍（锦上添花）：
  步骤9   AI生图-事件配图               40min
  ─────────────────────────────────────
  P2 小计                              40min

总计：P0(95min) + P1(110min) = 205min ≈ 3.4h
预算：150min = 2.5h
```

### 预算裁剪策略

| 方案 | 做什么 | 砍什么 | 总时长 |
|------|--------|--------|--------|
| **方案A（推荐）** | P0全部 + 字体 + itch.io素材 + 角色头像 | 场景图用渐变降级、事件配图降级 | 95 + 25 + 30 = **150min** ✅ |
| 方案B（保守） | P0全部 + 字体 + itch.io素材 | 所有AI生图降级 | 95 + 25 = **120min** ✅ |
| 方案C（激进） | P0全部 + 全部P1 | 事件配图降级 | 95 + 110 = **205min** ❌ 超预算 |

**推荐方案A：** 角色头像是入场选购界面第一印象，投入产出比最高。场景背景用 `GradientTexture2D` 完全够用。事件配图用 emoji + Label 反而更清爽。

---

## 九、依赖关系图

```
可立即开始（无依赖）：
├── 步骤1：项目像素风设置      ← 最先做，1分钟级操作
├── 步骤5：itch.io素材搜索     ← 可以先搜好备用
├── 步骤7：AI生图-角色头像     ← 可与代码开发完全并行
└── 步骤8：AI生图-场景图       ← 可与代码开发完全并行

步骤1完成后：
├── 步骤2：创建 Theme 资源     ← 依赖：步骤1（Nearest设置先行）
└── 步骤3：字体下载导入         ← 依赖：步骤2（需要Theme来挂载字体）

等功能模块场景骨架完成后：
├── 步骤4：各画面降级布局       ← 依赖：步骤2 + 模块02-06的场景节点树
├── 步骤6：itch.io素材集成     ← 依赖：步骤5 + 步骤2
└── 步骤10：AI素材接入替换     ← 依赖：步骤4 + 步骤7/8

等事件系统设计确定后：
└── 步骤9：AI生图-事件配图     ← 依赖：模块05事件列表确定

最后：
└── 步骤11：视觉微调           ← 依赖：所有上述步骤
```

### 并行策略（关键！节省时间）

美术资源生成（AI生图）**可以与功能代码开发完全并行**：

- **Day 1：** 配置项目设置 + 创建 Theme + 导入字体（步骤1-3，45min）
- **Day 1-2：** 开发功能时，利用间隙批量生成 AI 图片（步骤7-8）
- **Day 2-3：** 功能场景骨架出来后，集中 50min 搭建降级布局（步骤4）
- **Day 3：** 把 itch.io 素材和 AI 图片替换进去（步骤5-6, 10）
- **Day 4：** 微调 + polish（步骤11）

---

## 十、总工时预估

| 类别 | 工时 | 说明 |
|------|------|------|
| Godot 项目设置 + Theme 创建 | 35min | 步骤1+2，开发人员工作 |
| 字体导入 | 10min | 步骤3 |
| 各画面降级布局 | 50min | 步骤4，开发人员工作，计入开发工时 |
| AI生图（角色头像） | 30min | 美术预算，可利用碎片时间 |
| itch.io素材下载+集成 | 25min | 步骤5+6，美术预算 |
| **美术预算合计** | **55min** | 方案A美术侧投入 |
| **开发预算合计** | **95min** | Theme + 布局侧投入 |
| **总计** | **150min = 2.5h** | ✅ 踩线达标 |

> **风险 buffer：** 如果 AI 生图不顺利（prompt 调不出效果），立即放弃该张图，用降级方案。每张图最多尝试 3 次（~5分钟），不出效果就止损。

---

## 附录A：Godot 关键操作速查

### 创建 Theme 资源

```
FileSystem 面板 → 右键 assets/themes/ → New Resource → Theme → 保存为 pixel_theme.tres
```

### Theme Editor 操作

```
双击 pixel_theme.tres → 打开 Theme Editor
  → 顶栏设置 Default Font / Default Font Size
  → 左侧 "+" 添加 Type (Button / Panel / Label / ProgressBar...)
  → 右侧编辑该 Type 的 Colors / Constants / Fonts / Styles
```

### 挂载 Theme 到场景

```
场景根节点 (Control) → Inspector → Theme 属性 → 拖入 pixel_theme.tres
→ 所有子 Control 节点自动继承
```

### 单节点覆写 Theme

```
某个特殊 Label → Inspector → Theme Overrides:
  → font_sizes/font_size = 32         (标题大字)
  → fonts/font = fusion_pixel.ttf     (像素字体)
  → colors/font_color = #f5c842       (金色高亮)
```

### 像素风设置验证检查

```
Project → Project Settings → 搜索 "texture_filter"
  → Rendering > Textures > Canvas Textures > Default Texture Filter = Nearest  ✓
运行游戏 → 所有图片边缘应该是锐利像素块，不是模糊的
```

---

## 附录B：快速检查清单

开发时逐项打勾：

- [ ] 项目设置 `default_texture_filter = Nearest`
- [ ] 项目设置窗口 1280×720 + `canvas_items` 拉伸
- [ ] `pixel_theme.tres` 创建完毕，配色/StyleBox/字体齐全
- [ ] Theme 挂载到所有场景根节点
- [ ] 得意黑字体导入并设为 Theme 默认字体
- [ ] 所有画面有降级方案可用（ColorRect + Label + emoji）
- [ ] itch.io UI 素材包下载并集成到 Theme
- [ ] 9张角色头像 AI 生图完成并接入 TextureRect
- [ ] 主菜单氛围图完成（或 GradientTexture2D 降级）
- [ ] 研发界面背景完成（或渐变降级）
- [ ] 上线确认画面完成（或渐变降级）
- [ ] 结算成功/失败底图完成（或渐变降级）
- [ ] 代码急救小游戏 IDE 风格（纯 Theme 配色，不依赖美术）
- [ ] 全局视觉一致性检查通过——每个场景切换时风格统一
