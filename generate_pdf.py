from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# ── 字体注册（使用系统中文字体）──────────────────────────────────────────
FONT_PATHS = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/Library/Fonts/Arial Unicode MS.ttf",
]
CN_FONT = "Helvetica"  # fallback
for fp in FONT_PATHS:
    if os.path.exists(fp):
        try:
            pdfmetrics.registerFont(TTFont("CNFont", fp))
            pdfmetrics.registerFont(TTFont("CNFontB", fp, subfontIndex=1))
            CN_FONT = "CNFont"
            CN_FONT_B = "CNFontB"
            break
        except Exception:
            continue
CN_FONT_B = CN_FONT

# ── 调色板 ────────────────────────────────────────────────────────────────
C_BG        = colors.HexColor("#0D0D0D")   # 深黑背景
C_ACCENT    = colors.HexColor("#E8C84A")   # 金色强调
C_ACCENT2   = colors.HexColor("#C0392B")   # 红色警示
C_TEXT      = colors.HexColor("#EEEEEE")   # 主文字
C_MUTED     = colors.HexColor("#888888")   # 次要文字
C_CARD      = colors.HexColor("#1A1A1A")   # 卡片背景
C_BORDER    = colors.HexColor("#2E2E2E")   # 边框
C_HIGHLIGHT = colors.HexColor("#1E3A5F")   # 高亮行背景

W, H = A4

# ── 样式 ─────────────────────────────────────────────────────────────────
def s(name, **kw):
    base = dict(
        fontName=CN_FONT, fontSize=11, textColor=C_TEXT,
        leading=18, spaceAfter=4,
    )
    base.update(kw)
    return ParagraphStyle(name, **base)

ST_COVER_TITLE = s("ct", fontName=CN_FONT_B, fontSize=34, textColor=C_ACCENT,
                   leading=42, alignment=TA_CENTER, spaceAfter=6)
ST_COVER_SUB   = s("cs", fontSize=14, textColor=C_MUTED, alignment=TA_CENTER,
                   spaceAfter=2)
ST_COVER_TAG   = s("ctag", fontSize=11, textColor=C_ACCENT2, alignment=TA_CENTER,
                   spaceAfter=2)
ST_SECTION     = s("sec", fontName=CN_FONT_B, fontSize=16, textColor=C_ACCENT,
                   leading=22, spaceBefore=14, spaceAfter=6)
ST_BODY        = s("body", fontSize=11, leading=20, spaceAfter=4)
ST_BODY_BOLD   = s("bb", fontName=CN_FONT_B, fontSize=11, leading=20, spaceAfter=4)
ST_SMALL       = s("sm", fontSize=9, textColor=C_MUTED, leading=14)
ST_QUOTE       = s("qt", fontName=CN_FONT_B, fontSize=13, textColor=C_ACCENT,
                   leading=22, alignment=TA_CENTER, spaceBefore=10, spaceAfter=10)
ST_TABLE_H     = s("th", fontName=CN_FONT_B, fontSize=10, textColor=C_ACCENT,
                   alignment=TA_CENTER, leading=16)
ST_TABLE_B     = s("tb", fontSize=10, textColor=C_TEXT,
                   alignment=TA_LEFT, leading=16)
ST_TABLE_BC    = s("tbc", fontSize=10, textColor=C_TEXT,
                   alignment=TA_CENTER, leading=16)

def P(text, style=ST_BODY):
    return Paragraph(text, style)

def divider(color=C_BORDER, thickness=0.5):
    return HRFlowable(width="100%", thickness=thickness,
                      color=color, spaceAfter=8, spaceBefore=4)

def section_title(text):
    # 带左侧色块装饰的标题
    label = f'<font color="#E8C84A">&#9612;</font> {text}'
    return Paragraph(label, ST_SECTION)

def tag_table(tags):
    """横排标签条"""
    cells = [[P(t, ParagraphStyle("tag", fontName=CN_FONT_B, fontSize=9,
                                   textColor=C_BG, leading=14, alignment=TA_CENTER))
              for t in tags]]
    ts = TableStyle([
        ("BACKGROUND", (i, 0), (i, 0),
         [C_ACCENT, C_ACCENT2, colors.HexColor("#2E86AB"),
          colors.HexColor("#27AE60"), C_ACCENT][i % 5])
        for i in range(len(tags))
    ] + [
        ("ROUNDEDCORNERS", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ])
    col_w = (W - 60*mm) / len(tags)
    return Table(cells, colWidths=[col_w]*len(tags), style=ts)

# ── 页面背景 ──────────────────────────────────────────────────────────────
def on_page(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(C_BG)
    canvas.rect(0, 0, W, H, fill=1, stroke=0)

    # 底部页码
    page_num = doc.page
    canvas.setFont(CN_FONT, 9)
    canvas.setFillColor(C_MUTED)
    canvas.drawCentredString(W/2, 18*mm, f"{page_num}")

    # 顶部极细装饰线
    canvas.setStrokeColor(C_ACCENT)
    canvas.setLineWidth(1.5)
    canvas.line(30*mm, H - 14*mm, W - 30*mm, H - 14*mm)

    canvas.restoreState()

# ── 内容构建 ──────────────────────────────────────────────────────────────
def build_story():
    story = []
    sp = lambda n=6: Spacer(1, n*mm)

    # ── 封面区 ────────────────────────────────────────────────────────────
    story.append(sp(18))
    story.append(P("《制作人》", ST_COVER_TITLE))
    story.append(sp(2))
    story.append(P("游戏策划概要 · 初稿", ST_COVER_SUB))
    story.append(sp(4))
    story.append(tag_table(["搜打撤", "单机 Demo", "PvE", "约10分钟/局", "独立游戏题材"]))
    story.append(sp(10))
    story.append(divider(C_ACCENT, 1))
    story.append(sp(4))

    # ── 一句话定位 ────────────────────────────────────────────────────────
    story.append(section_title("一句话定位"))
    story.append(sp(1))
    story.append(P(
        "一款以<b>独立游戏开发</b>为背景的搜打撤风格策略游戏。"
        "玩家扮演独立制作人，在不确定的市场中押注创意、与时间赛跑，"
        "最终决定何时上线——体验贪婪与恐惧的持续拉扯。", ST_BODY))
    story.append(sp(4))

    # ── 核心体验 ──────────────────────────────────────────────────────────
    story.append(section_title("核心体验"))
    story.append(sp(1))
    story.append(P(
        "搜打撤的本质是：<b>在不确定性中做风险决策，用资源押注收益，"
        "失败则全部损失</b>。这款游戏将这一体验完整映射到游戏开发行业：",
        ST_BODY))
    story.append(sp(3))

    mapping_data = [
        [P("原型", ST_TABLE_H), P("在本游戏中的映射", ST_TABLE_H)],
        [P("搜", ST_TABLE_BC), P("探索研发节点，寻找能提升品质或效率的机会", ST_TABLE_B)],
        [P("打", ST_TABLE_BC), P("应对研发途中的随机突发事件，需要策略抉择", ST_TABLE_B)],
        [P("撤", ST_TABLE_BC), P("主动决定何时上线——这是整局的核心博弈时刻", ST_TABLE_B)],
    ]
    ts = TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_HIGHLIGHT),
        ("BACKGROUND", (0, 1), (-1, 1), C_CARD),
        ("BACKGROUND", (0, 2), (-1, 2), C_BG),
        ("BACKGROUND", (0, 3), (-1, 3), C_CARD),
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [C_HIGHLIGHT, C_CARD, C_BG, C_CARD]),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ])
    story.append(Table(mapping_data,
                       colWidths=[25*mm, W - 60*mm - 25*mm],
                       style=ts))
    story.append(sp(6))

    # ── 一局流程 ──────────────────────────────────────────────────────────
    story.append(section_title("一局游戏是什么样的"))
    story.append(sp(1))

    steps = [
        ("01  入场", "带着资源进入，选择这局要做哪个题材"),
        ("02  研发", "在时间压力下推进开发，途中遭遇随机事件，可选探索节点"),
        ("03  上线决策", "市场热度在变化，AI竞品在抢市场——何时上线，由你判断"),
        ("04  结算", "收益由品质 × 市场热度 × 上线时机共同决定，带钱离场或失败清零"),
    ]
    step_data = [[P(n, ST_TABLE_H), P(d, ST_TABLE_B)] for n, d in steps]
    ts2 = TableStyle([
        ("BACKGROUND", (0, i), (0, i), [C_ACCENT, C_ACCENT, C_ACCENT, C_ACCENT2][i])
        for i in range(4)
    ] + [
        ("BACKGROUND", (1, i), (1, i), C_CARD if i % 2 == 0 else C_BG)
        for i in range(4)
    ] + [
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TEXTCOLOR", (0, 0), (0, -1), C_BG),
    ])
    story.append(Table(step_data,
                       colWidths=[32*mm, W - 60*mm - 32*mm],
                       style=ts2))
    story.append(sp(3))
    story.append(P("单局目标时长：约 <b>10 分钟</b>", ST_BODY))
    story.append(sp(6))

    # ── 核心张力 ──────────────────────────────────────────────────────────
    story.append(section_title("三组核心张力"))
    story.append(sp(1))

    tensions = [
        ("时间即生命", "每局有开发时限，超时未上线则一切损失"),
        ("上线即撤离", "早上线抢市场但品质不足；继续磨品质则窗口可能关闭"),
        ("信息不完全", "看得到热度趋势，但判断不了最优时机——靠胆量与判断，不是计算"),
    ]
    for title, desc in tensions:
        row_data = [[
            P(title, ParagraphStyle("th2", fontName=CN_FONT_B, fontSize=11,
                                     textColor=C_ACCENT, leading=18, alignment=TA_LEFT)),
            P(desc, ST_TABLE_B)
        ]]
        ts3 = TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), C_HIGHLIGHT),
            ("BACKGROUND", (1, 0), (1, 0), C_CARD),
            ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ("LEFTPADDING", (0, 0), (-1, -1), 10),
            ("RIGHTPADDING", (0, 0), (-1, -1), 10),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ])
        story.append(Table(row_data,
                           colWidths=[38*mm, W - 60*mm - 38*mm],
                           style=ts3))
        story.append(sp(1))
    story.append(sp(4))

    # ── 经济循环 ──────────────────────────────────────────────────────────
    story.append(section_title("经济循环"))
    story.append(sp(1))
    eco_items = [
        "局内收益转化为金钱，用于购买下一局的入场资源",
        "失败损失资源，但不会彻底出局",
        "<b>无局外养成</b>（无天赋点等），失去的代价是真实的",
    ]
    for item in eco_items:
        story.append(P(f'<font color="#E8C84A">&#9658;</font>  {item}', ST_BODY))
    story.append(sp(6))

    # ── 核心感受 ──────────────────────────────────────────────────────────
    story.append(divider(C_ACCENT, 1))
    story.append(sp(4))
    story.append(P(
        '"玩家在每局结束时，无论成败，都应该感受到：<br/>'
        '<b>我当时应该早点/晚点上线。</b>"',
        ST_QUOTE))
    story.append(sp(2))
    story.append(P(
        "这种「后悔感」本身，就是这款游戏最核心的情绪价值。",
        ParagraphStyle("center_body", fontName=CN_FONT, fontSize=11,
                       textColor=C_MUTED, leading=18, alignment=TA_CENTER)))
    story.append(sp(6))
    story.append(divider(C_BORDER))
    story.append(sp(2))
    story.append(P("本文件为初步概要，设计细节持续迭代中。", ST_SMALL))

    return story

# ── 生成 PDF ──────────────────────────────────────────────────────────────
OUT = "/Users/kuangjianwei/AI_Discover/sdc/策划概要_制作人.pdf"

doc = SimpleDocTemplate(
    OUT,
    pagesize=A4,
    leftMargin=30*mm, rightMargin=30*mm,
    topMargin=20*mm, bottomMargin=22*mm,
)

doc.build(build_story(), onFirstPage=on_page, onLaterPages=on_page)
print(f"PDF saved: {OUT}")
