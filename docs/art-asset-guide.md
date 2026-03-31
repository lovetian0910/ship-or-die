# 美术素材清单与替换指南

> 所有美术素材统一放在 `game/assets/` 目录下
> 当前全部使用代码生成的占位图（ColorRect/Label）
> 替换时只需把 PNG 放到对应目录，修改 `asset_registry.gd` 中的路径即可

---

## 替换步骤（3步完成）

1. **准备 PNG 文件**，按下面清单命名，放到对应目录
2. **打开 `scripts/autoload/asset_registry.gd`**，把对应条目从 `""` 改为 `"res://assets/xxx/文件名.png"`
3. **运行游戏**，AssetRegistry 会自动加载图片替换占位

---

## 素材清单

### 角色头像 — `assets/sprites/portraits/`

| 文件名 | 用途 | 建议尺寸 | AI Prompt |
|--------|------|---------|-----------|
| `creator_low.png` | 独立游戏愤青 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, young indie developer with messy hair and hoodie, passionate eyes, clean lines, icon style |
| `creator_mid.png` | 鹅皇互娱主创 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, corporate game producer in suit with confident smile, clean lines, icon style |
| `creator_high.png` | 天命堂制作人 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, legendary game director with intense stare and crossed arms, clean lines, icon style |
| `outsource_low.png` | 大学生兼职组 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, group of sleepy college students with laptops, clean lines, icon style |
| `outsource_mid.png` | 外包铁军 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, disciplined outsource team in uniform, clean lines, icon style |
| `outsource_high.png` | 越南闪电队 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, lightning-fast coding team with energy drinks, clean lines, icon style |
| `business_low.png` | 实习商务 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, nervous intern with oversized business card, clean lines, icon style |
| `business_mid.png` | 万能商务 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, smooth-talking businessman with phone in each hand, clean lines, icon style |
| `business_high.png` | 前渠道教父 | 128×128 | pixel art, 32-bit style, dark background, game industry theme, legendary old man in luxury chair smoking cigar, godfather vibes, clean lines, icon style |

### 题材图标 — `assets/sprites/topics/`

| 文件名 | 用途 | 建议尺寸 | AI Prompt |
|--------|------|---------|-----------|
| `topic_phantom_realm.png` | 抽象大陆 | 96×96 | pixel art, 32-bit, dark bg, fantasy open world icon, floating islands and swords, icon style |
| `topic_mecha_royale.png` | 枪枪枪 | 96×96 | pixel art, 32-bit, dark bg, battle royale icon, mecha with guns, explosion, icon style |
| `topic_waifu_collection.png` | 二次元觉醒 | 96×96 | pixel art, 32-bit, dark bg, anime gacha icon, sparkle card with cute character silhouette, icon style |
| `topic_star_ranch.png` | 像素怀旧谷 | 96×96 | pixel art, 32-bit, dark bg, space farming icon, pixel cow on asteroid with crops, icon style |

### 背景图 — `assets/sprites/backgrounds/`

| 文件名 | 用途 | 建议尺寸 |
|--------|------|---------|
| `bg_menu.png` | 主菜单背景 | 1280×720 |
| `bg_office.png` | 研发主界面背景 | 1280×720 |
| `bg_success.png` | 成功结算底图 | 1280×720 |
| `bg_failure.png` | 失败结算底图 | 1280×720 |

### 事件配图 — `assets/sprites/events/`

| 文件名 | 用途 | 建议尺寸 |
|--------|------|---------|
| `event_talent.png` | 人才发现类事件 | 256×256 |
| `event_tech.png` | 技术方案类事件 | 256×256 |
| `event_crisis_team.png` | 团队危机 | 256×256 |
| `event_crisis_tech.png` | 技术事故 | 256×256 |
| `event_crisis_external.png` | 外部冲击 | 256×256 |
| `event_crisis_resource.png` | 资源意外 | 256×256 |

### UI 图标 — `assets/sprites/ui/`

| 文件名 | 用途 | 建议尺寸 |
|--------|------|---------|
| `icon_money.png` | 金钱图标 | 32×32 |
| `icon_time.png` | 时间图标 | 32×32 |
| `icon_quality.png` | 品质图标 | 32×32 |
| `icon_launch.png` | 上线按钮图标 | 48×48 |

---

## 总计

| 类别 | 数量 | 优先级 |
|------|------|--------|
| 角色头像 | 9张 | P0（入场选购第一印象）|
| 题材图标 | 4张 | P1 |
| 背景图 | 4张 | P2（降级方案：渐变色） |
| 事件配图 | 6张 | P2（降级方案：纯文字） |
| UI图标 | 4张 | P3（降级方案：emoji） |
| **总计** | **27张** | |
