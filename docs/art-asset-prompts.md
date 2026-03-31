# 《开发商》美术素材生成清单

> **总计：41张素材**
> 统一风格：**像素风 / 32-bit retro / 深色背景 / 游戏行业主题**
> 建议工具：Midjourney / Stable Diffusion / DALL·E 3
> 生成后统一放到 `game/assets/sprites/` 对应子目录，修改 `asset_registry.gd` 即可替换占位图

---

## 风格统一约束（所有素材通用前缀）

```
Style Prefix: pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark
```

所有下方提示词已包含此前缀，可直接复制使用。

---

## 一、角色头像 — `game/assets/sprites/portraits/`

> 用途：入场阶段（资源选购）的人物卡片头像
> 优先级：**P0**（玩家第一印象）
> 尺寸：**128×128 px**

### 1.1 主创（Creator）— 决定品质上限

| # | 文件名 | 角色名 | 角色描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|------|-----------|
| 1 | `creator_low.png` | 独立游戏愤青 | 有理想没预算更没经验的独立开发者，简历上写着"拒绝商业化"，作品集全是Game Jam作品 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a young indie game developer, messy unkempt hair, wearing a worn-out hoodie with coffee stains, passionate burning eyes behind thick glasses, surrounded by scattered post-it notes, determined but broke expression, icon style, centered composition` |
| 2 | `creator_mid.png` | 鹅皇互娱主创 | 大厂镀金五年，PPT能力MAX，擅长"生态""闭环"等行业黑话 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a corporate game producer, slicked-back hair, sharp business suit with name badge, confident smirk, holding a presentation clicker in one hand, subtle arrogance, polished appearance, icon style, centered composition` |
| 3 | `creator_high.png` | 天命堂制作人 | 传说级制作人"X神"，上一款全球年度最佳，脾气也是传说级 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a legendary game director, intense piercing stare, crossed arms, wearing a black turtleneck, aura of absolute authority, slight golden glow behind head like a halo, intimidating but brilliant, icon style, centered composition` |

### 1.2 外包（Outsource）— 决定开发速度

| # | 文件名 | 角色名 | 角色描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|------|-----------|
| 4 | `outsource_low.png` | 大学生兼职组 | 便宜是真便宜慢也是真的慢，五人群永远只有两人在线 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a group of sleepy college students, three faces cramped together, one yawning, one looking at phone, one barely awake with laptop, messy dorm-room energy, cheap headphones, icon style, centered composition` |
| 5 | `outsource_mid.png` | 外包铁军 | 准时交付质量稳定不问为什么，需求改八百遍脸上依然挂职业微笑 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a disciplined outsource team leader, neat uniform appearance, professional forced smile, headset on, multiple monitor reflections in glasses, calm and reliable expression, military-like precision vibe, icon style, centered composition` |
| 6 | `outsource_high.png` | 越南闪电队 | 又快又便宜，东南亚卷王之巅，凌晨三点还在回消息 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of an elite developer with lightning-fast energy, wearing a cap backwards, energy drink cans around, multiple screens glowing, typing at superhuman speed with motion blur on hands, electric blue accent lighting, icon style, centered composition` |

### 1.3 商务（Business）— 决定事件应对能力

| # | 文件名 | 角色名 | 角色描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|------|-----------|
| 7 | `business_low.png` | 实习商务 | 刚毕业，签过的最大合同是帮公司续企业邮箱 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a nervous young intern, oversized suit that doesn't fit, holding an oversized business card with shaking hands, sweating slightly, eager but inexperienced expression, fresh graduate energy, icon style, centered composition` |
| 8 | `business_mid.png` | 万能商务 | 行业老油条，手机3000联系人，解决问题靠"请他吃个饭" | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of a smooth-talking businessman, holding two phones simultaneously, sly knowing grin, loosened tie with rolled-up sleeves, surrounded by floating contact icons and chat bubbles, street-smart and connected, icon style, centered composition` |
| 9 | `business_high.png` | 前渠道教父 | 行业元老，一个电话能叫停一场公关危机，半退休 | 128×128 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, portrait of an old-school industry godfather, sitting in a luxurious leather chair, silver hair slicked back, cigar in hand, calm all-knowing expression, dim golden lighting, rings on fingers, exudes power and experience, icon style, centered composition` |

---

## 二、题材图标 — `game/assets/sprites/topics/`

> 用途：选题阶段的赛道选择卡片
> 优先级：**P1**
> 尺寸：**96×96 px**

| # | 文件名 | 题材名 | 影射品类 | 一句话描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|-----------|------|-----------|
| 10 | `topic_phantom_realm.png` | 抽象大陆 | 开放世界RPG | 超大地图让玩家跑酷捡东西 | 96×96 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, icon of a vast fantasy open world, floating islands connected by bridges, tiny adventurer silhouette standing on a cliff edge looking at endless horizon, swords and magic crystals scattered, epic scale feeling compressed into small icon, warm orange and cool blue contrast, icon style` |
| 11 | `topic_mecha_royale.png` | 枪枪枪 | FPS/射击 | 对着屏幕开枪，区别只是用什么枪 | 96×96 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, icon of an intense mecha battle royale, a giant robot in dynamic shooting pose, bullet casings flying, explosion effects in background, crosshair overlay, aggressive red and orange tones, action-packed composition, icon style` |
| 12 | `topic_waifu_collection.png` | 二次元觉醒 | 二次元手游/抽卡 | 美少女+抽卡+剧情 | 96×96 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, icon of an anime gacha game concept, sparkling golden card being pulled from a deck, cute character silhouette visible on the card, star and sparkle effects radiating outward, pink and purple magical aura, dreamy pastel accents on dark background, icon style` |
| 13 | `topic_star_ranch.png` | 像素怀旧谷 | 独立/像素/Roguelike | 用最少的像素讲最深的故事 | 96×96 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, icon of a cozy pixel farming game in space, small pixelated cow on a tiny asteroid, little crops growing around it, stars twinkling in background, nostalgic warm color palette, peaceful and quirky atmosphere, retro 8-bit charm, icon style` |

---

## 三、背景图 — `game/assets/sprites/backgrounds/`

> 用途：各游戏阶段的全屏背景
> 优先级：**P2**（降级方案：渐变色）
> 尺寸：**1280×720 px**

| # | 文件名 | 用途 | 场景描述 | 尺寸 | AI Prompt |
|---|--------|------|---------|------|-----------|
| 14 | `bg_menu.png` | 主菜单背景 | 游戏首屏，需要传达"游戏行业黑色幽默"的基调 | 1280×720 | `pixel art, 32-bit retro style, wide landscape, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a chaotic game development studio at night seen from outside through large windows, multiple floors visible, some windows lit with blue monitor glow, some dark, a neon sign flickering on top, scattered coffee cups and energy drinks on windowsills, city skyline in far background, moody dark purple and blue atmosphere with warm window lights, cinematic composition, 16:9 aspect ratio` |
| 15 | `bg_office.png` | 研发主界面背景 | 研发阶段持续显示，需要不干扰前景UI | 1280×720 | `pixel art, 32-bit retro style, wide landscape, game industry theme, clean pixel lines, muted colors, no text, no watermark, interior of a game development office, rows of desks with glowing monitors, whiteboard with scribbled game designs, empty energy drink cans and takeout boxes, dim overhead lighting, a window showing night sky, subtle and calm atmosphere, slightly desaturated to not distract from UI overlay, dark tones with soft blue ambient light, 16:9 aspect ratio` |
| 16 | `bg_success.png` | 成功结算底图 | 游戏成功上线的庆祝氛围 | 1280×720 | `pixel art, 32-bit retro style, wide landscape, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, celebration scene in a game studio, confetti falling, team members cheering with arms raised, monitors showing upward-trending charts and five-star reviews, golden warm lighting, champagne bottle popping, trophy on desk, triumphant and joyful atmosphere, warm gold and orange tones, 16:9 aspect ratio` |
| 17 | `bg_failure.png` | 失败结算底图 | 项目失败的凄凉氛围 | 1280×720 | `pixel art, 32-bit retro style, wide landscape, game industry theme, clean pixel lines, muted colors, no text, no watermark, abandoned game studio in the rain, seen through a rain-streaked window, empty desks with powered-off monitors, a single desk lamp still on illuminating scattered papers, moving boxes stacked near the door, a wilted plant on a desk, melancholy blue and grey tones, lonely and somber atmosphere, rain drops on glass, 16:9 aspect ratio` |

---

## 四、随机事件配图 — `game/assets/sprites/events/`

> 用途：事件弹窗中的配图，增强叙事感
> 优先级：**P2**（降级方案：纯文字）
> 尺寸：**256×256 px**

### 4.1 搜类事件（主动探索发现的机会）

| # | 文件名 | 事件名 | 事件描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|------|-----------|
| 18 | `event_search_talent_01.png` | 野生大神出没 | 论坛发现匿名用户200行代码实现核心功能 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a mysterious hooded figure typing on a glowing laptop in a dark room, screen showing elegant code, a golden aura emanating from the screen, forum comments floating around like ghosts, legendary hacker vibes, green and gold accent colors, dramatic lighting from screen` |
| 19 | `event_search_talent_02.png` | 灵感时刻 | 凌晨三点主创在马桶上想到绝妙设计 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a game designer sitting in a bathroom at 3am having a eureka moment, lightbulb glowing brightly above head, frantically drawing on a napkin, phone showing a chat app with many voice messages sent, toilet visible, excited manic expression, yellow inspiration glow contrasting dark bathroom` |
| 20 | `event_search_tech_01.png` | 开源宝藏 | 发现三年没更新的开源项目Star数47但代码完美 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a treasure chest opening on a computer screen, inside the chest is glowing source code, cobwebs and dust around the chest suggesting it's been forgotten, a small star counter showing low numbers, golden light spilling out, sense of discovering hidden treasure in digital ruins` |
| 21 | `event_search_tech_02.png` | 外包加急通道 | 外包群有人说被甲方放鸽子这周有空档 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a chat group notification popping up urgently, a team of developers waving from inside the phone screen, a clock showing limited time, express delivery rocket symbol, opportunity knocking on a door, orange and yellow urgency colors, fast-paced energy` |
| 22 | `event_search_quality_01.png` | 反面教材研究 | 竞品发万字复盘文讲如何把月活从500万做到5万 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a long scroll document unrolling with a dramatic downward-trending graph visible, a detective with magnifying glass studying the document, skull and crossbones watermark on the failed game, taking notes eagerly, learning from others' disaster, dark humor tone, red warning colors` |
| 23 | `event_search_resource_01.png` | 友商内鬼 | 行业朋友约喝咖啡"不小心"透露竞品数据 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, two people at a coffee shop table, one leaning in whispering secrets, the other frantically taking notes under the table, coffee cups between them, floating data charts and numbers visible as thought bubbles, spy-thriller mood, dim cafe lighting with suspicious shadows` |

### 4.2 打类事件（被动遭遇的危机）

| # | 文件名 | 事件名 | 事件描述 | 尺寸 | AI Prompt |
|---|--------|--------|---------|------|-----------|
| 24 | `event_fight_team_01.png` | 核心程序员提桶跑路 | 周一早上核心程序员工位空了，只留一张纸条 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, an empty office desk with a still-warm coffee cup and a resignation note, monitor showing incomprehensible spaghetti code, a door slightly ajar with a silhouette walking away carrying a box, dramatic abandonment scene, cold blue tones with warm desk lamp contrast` |
| 25 | `event_fight_team_02.png` | 团队内战：玩法之争 | 策划组爆发史诗级争吵，有人甩数据有人甩椅子 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a meeting room in total chaos, two groups of developers on opposite sides of a table arguing passionately, papers flying everywhere, a whiteboard cracked in half with two different game designs, one person throwing a chair, intense red and orange conflict lighting, cartoon battle energy` |
| 26 | `event_fight_tech_01.png` | 引擎突然收费 | 游戏引擎突然宣布按安装量收费，技术群瞬间炸了 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a giant price tag crashing down onto a game engine logo (abstract gear symbol), developers running in panic below, money flying out of wallets, a chat window exploding with angry messages, dollar signs raining from sky, crisis and outrage atmosphere, red alarm colors` |
| 27 | `event_fight_tech_02.png` | 服务器着火了（真的着火了） | 机房空调坏了三天，测试服务器过热自燃 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a server room literally on fire, server racks with visible flames and smoke, a broken air conditioner unit dripping, a firefighter pixel character running in with extinguisher, data streams evaporating into smoke, dramatic orange fire glow against dark server room, disaster scene` |
| 28 | `event_fight_external_01.png` | 美术素材碰瓷 | 某画师在社交平台发长文说角色设计抄袭 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a social media post going viral shown on a phone screen, two character designs side by side being compared (both with blue hair), angry emoji reactions flooding in, a mob with pitchforks in the comment section, drama and controversy atmosphere, hot pink and angry red accents` |
| 29 | `event_fight_external_02.png` | 平台政策突变 | "蒸汽城"平台更新荒谬审核标准 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a giant stamp marked with an X slamming down on a game icon, absurd rule scroll unfurling with ridiculous requirements, a faceless bureaucratic building in background, developers protesting with signs, kafka-esque nightmare mood, oppressive grey and red tones` |
| 30 | `event_fight_survivor_01.png` | 代码库虫群爆发 | CI/CD流水线全线飘红，成群bug从依赖库涌出 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, swarm of pixel bugs (literal cartoon insects) crawling out of a computer screen, code lines turning red as bugs consume them, a developer wielding a keyboard like a sword fighting the bugs, CI/CD pipeline shown as tubes being invaded, green code turning to red, action scene` |
| 31 | `event_fight_survivor_02.png` | 虫族母巢入侵 | 更大规模的bug爆发，需要进入代码急救小游戏 | 256×256 | `pixel art, 32-bit retro style, dark background, game industry theme, clean pixel lines, vibrant colors, no text, no watermark, a massive bug queen monster emerging from a cracked server, smaller bugs swarming everywhere, the entire screen is under siege, a lone developer in battle stance with glowing keyboard weapon, epic boss fight energy, dark purple and toxic green colors, intense and dramatic` |

---

## 五、UI 图标 — `game/assets/sprites/ui/`

> 用途：HUD 资源栏的小图标
> 优先级：**P3**（降级方案：emoji 文字）
> 尺寸：**32×32 px** / **48×48 px**

| # | 文件名 | 用途 | 尺寸 | AI Prompt |
|---|--------|------|------|-----------|
| 32 | `icon_money.png` | 金钱/预算图标 | 32×32 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, a golden coin with a dollar sign, slight shine effect, simple and readable at small size, game UI icon style, centered` |
| 33 | `icon_time.png` | 时间/月份图标 | 32×32 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, an hourglass with blue sand flowing, slight glow effect, simple and readable at small size, game UI icon style, centered` |
| 34 | `icon_quality.png` | 品质分数图标 | 32×32 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, a sparkling diamond or gem with quality star, purple and white shimmer, simple and readable at small size, game UI icon style, centered` |
| 35 | `icon_launch.png` | 上线按钮图标 | 48×48 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, a rocket launching upward with flame trail, dynamic upward motion, exciting energy, orange and red flames, simple and readable, game UI icon style, centered` |
| 36 | `icon_energy.png` | 精力/体力图标 | 32×32 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, a lightning bolt with electric glow, yellow and white energy, simple and readable at small size, game UI icon style, centered` |
| 37 | `icon_speed.png` | 开发速度图标 | 32×32 | `pixel art, 32-bit retro style, dark background, clean pixel lines, vibrant colors, no text, no watermark, a fast-forward arrow with speed lines, dynamic motion feel, cyan and white colors, simple and readable at small size, game UI icon style, centered` |

---

## 六、小游戏素材 — `game/assets/sprites/minigame/`

> 用途：代码急救小游戏（Bug Survivor）中的视觉元素
> 优先级：**P2**
> 尺寸：各异

| # | 文件名 | 用途 | 尺寸 | AI Prompt |
|---|--------|------|------|-----------|
| 38 | `minigame_bg.png` | 小游戏背景（代码编辑器界面） | 1280×720 | `pixel art, 32-bit retro style, game industry theme, clean pixel lines, muted colors, no text, no watermark, a zoomed-in view of a code editor screen, dark IDE theme with syntax-highlighted code lines scrolling in background, subtle grid pattern, matrix-like digital rain effect, very dark and atmospheric, meant as game background so low contrast, dark green and dark blue tones, 16:9 aspect ratio` |
| 39 | `minigame_bug.png` | Bug 敌人精灵（虫子） | 32×32 | `pixel art, 32-bit retro style, transparent background, clean pixel lines, vibrant colors, no watermark, a cute but menacing cartoon bug insect, red eyes, small wings, pixel game enemy sprite, side view, retro arcade enemy style, bright red and dark purple colors, animated-ready design` |
| 40 | `minigame_player.png` | 玩家角色（程序员/光标） | 32×48 | `pixel art, 32-bit retro style, transparent background, clean pixel lines, vibrant colors, no watermark, a small pixel programmer character holding a glowing keyboard as weapon, determined expression, ready for battle stance, retro game protagonist style, blue and white color scheme, animated-ready sprite design` |
| 41 | `minigame_powerup.png` | 能量道具（咖啡/能量饮料） | 24×24 | `pixel art, 32-bit retro style, transparent background, clean pixel lines, vibrant colors, no watermark, a glowing energy drink can with sparkle effect, power-up item for pixel game, bright cyan glow, collectible item style, simple and recognizable at small size` |

---

## 素材总览

| 类别 | 数量 | 尺寸 | 优先级 | 目录 |
|------|------|------|--------|------|
| 角色头像 | 9 张 | 128×128 | **P0** | `portraits/` |
| 题材图标 | 4 张 | 96×96 | **P1** | `topics/` |
| 背景图 | 4 张 | 1280×720 | **P2** | `backgrounds/` |
| 事件配图 | 14 张 | 256×256 | **P2** | `events/` |
| UI 图标 | 6 张 | 32×32 ~ 48×48 | **P3** | `ui/` |
| 小游戏素材 | 4 张 | 各异 | **P2** | `minigame/` |
| **总计** | **41 张** | | | |

---

## 替换步骤

### 1. 生成素材
使用上方提示词在 AI 绘图工具中生成 PNG 图片。

### 2. 放到对应目录
```
game/assets/sprites/
├── portraits/       ← 9张头像
├── topics/          ← 4张题材图标
├── backgrounds/     ← 4张背景
├── events/          ← 14张事件配图
├── ui/              ← 6张UI图标
└── minigame/        ← 4张小游戏素材
```

### 3. 修改 AssetRegistry
打开 `game/scripts/autoload/asset_registry.gd`，将对应条目从 `""` 改为实际路径：

```gdscript
# 示例：替换主创头像
var portraits: Dictionary = {
    "creator_low": "res://assets/sprites/portraits/creator_low.png",
    "creator_mid": "res://assets/sprites/portraits/creator_mid.png",
    # ...
}
```

### 4. 事件配图扩展
当前 `asset_registry.gd` 的事件配图只有 6 个通用分类。如需按事件单独配图（14张），需要扩展 `event_images` 字典：

```gdscript
var event_images: Dictionary = {
    "search_talent_01": "",     # 野生大神出没
    "search_talent_02": "",     # 灵感时刻
    "search_tech_01": "",       # 开源宝藏
    "search_tech_02": "",       # 外包加急通道
    "search_quality_01": "",    # 反面教材研究
    "search_resource_01": "",   # 友商内鬼
    "fight_team_01": "",        # 核心程序员提桶跑路
    "fight_team_02": "",        # 团队内战
    "fight_tech_01": "",        # 引擎突然收费
    "fight_tech_02": "",        # 服务器着火了
    "fight_external_01": "",    # 美术素材碰瓷
    "fight_external_02": "",    # 平台政策突变
    "fight_survivor_01": "",    # 代码库虫群爆发
    "fight_survivor_02": "",    # 虫族母巢入侵
}
```

### 5. 运行测试
```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path game res://tests/test_main.tscn 2>&1
```

---

## 生成建议

1. **批量生成**：同一类别素材（如9张头像）建议在同一个会话中连续生成，保持风格一致
2. **后处理**：生成后统一用图片工具裁剪到精确尺寸，确保像素对齐
3. **透明背景**：小游戏精灵（bug、player、powerup）需要透明背景，生成后需要去背景处理
4. **背景图**：因为上面会叠加 UI，建议整体偏暗、对比度不要太高
5. **优先级执行**：按 P0→P1→P2→P3 顺序生成，时间紧张时可跳过 P3
