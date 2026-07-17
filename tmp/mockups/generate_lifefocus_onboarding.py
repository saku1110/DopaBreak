from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter


OUT_DIR = Path("output/mockups/lifefocus_onboarding")
OUT_DIR.mkdir(parents=True, exist_ok=True)

SCALE = 3
W, H = 390, 844
FONT_CJK = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_LATIN = "/System/Library/Fonts/HelveticaNeue.ttc"

VOID = "#05070D"
NIGHT = "#0B1020"
PANEL = "#101827"
PANEL_2 = "#151F35"
STROKE = "#2A3858"
TEXT = "#F7FAFF"
MIST = "#9AA8C7"
AURA = "#8B5CF6"
AURA_2 = "#C4B5FD"
BREATH = "#70E1FF"
GOLD = "#F8D477"
INK = TEXT
MUTED = MIST
SUBTLE = STROKE
SURFACE = VOID
CARD = PANEL
NAVY = VOID
BLUE = AURA
BLUE_DARK = AURA_2
GREEN = "#55D6A0"
RED = "#FF6B6B"
CYAN = BREATH
YELLOW = GOLD


def sc(v):
    return int(round(v * SCALE))


def box(rect):
    return tuple(sc(v) for v in rect)


def font(size, latin=False):
    path = FONT_LATIN if latin else FONT_CJK
    return ImageFont.truetype(path, sc(size))


def text_size(draw, content, f):
    bbox = draw.textbbox((0, 0), content, font=f)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap_text(draw, content, f, max_width):
    lines = []
    for para in content.split("\n"):
        if not para:
            lines.append("")
            continue
        current = ""
        for ch in para:
            trial = current + ch
            if draw.textlength(trial, font=f) <= sc(max_width):
                current = trial
            else:
                if current:
                    lines.append(current)
                current = ch
        if current:
            lines.append(current)
    return lines


def draw_text(draw, xy, content, size, fill=INK, max_width=None, line_height=1.28, align="left", anchor=None, latin=False):
    f = font(size, latin=latin)
    x, y = xy
    if max_width:
        lines = wrap_text(draw, content, f, max_width)
    else:
        lines = content.split("\n")
    if anchor == "center":
        total_h = len(lines) * size * line_height
        y = y - total_h / 2
    for line in lines:
        sx, sy = sc(x), sc(y)
        if align == "center":
            w, _ = text_size(draw, line, f)
            sx = sc(x) - w // 2
        elif align == "right":
            w, _ = text_size(draw, line, f)
            sx = sc(x) - w
        draw.text((sx, sy), line, font=f, fill=fill)
        y += size * line_height


def rr(draw, rect, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box(rect), radius=sc(radius), fill=fill, outline=outline, width=sc(width))


def line(draw, points, fill, width=1):
    draw.line([(sc(x), sc(y)) for x, y in points], fill=fill, width=sc(width))


def circle(draw, center, radius, fill, outline=None, width=1):
    x, y = center
    draw.ellipse(box((x - radius, y - radius, x + radius, y + radius)), fill=fill, outline=outline, width=sc(width))


def focus_field(draw, center=(195, 250), radius=230, intensity=18, spokes=True):
    cx, cy = center
    rings = [72, 124, 178, radius]
    for idx, r in enumerate(rings):
        alpha = max(5, intensity - idx * 4)
        draw.ellipse(box((cx - r, cy - r, cx + r, cy + r)), outline=(112, 225, 255, alpha), width=sc(1))
    if spokes:
        for angle in range(0, 180, 30):
            # Thin crossing lines create a restrained focus/ritual mark without adding decorative blobs.
            rad = math.radians(angle)
            dx = math.cos(rad) * radius
            dy = math.sin(rad) * radius
            draw.line((sc(cx - dx), sc(cy - dy), sc(cx + dx), sc(cy + dy)), fill=(196, 181, 253, 6), width=sc(1))
    draw.ellipse(box((cx - 12, cy - 12, cx + 12, cy + 12)), outline=(248, 212, 119, 54), width=sc(1))


def check_mark(draw, center, size=42, fill="#FFFFFF", width=6):
    x, y = center
    line(
        draw,
        [
            (x - size * 0.42, y + size * 0.03),
            (x - size * 0.12, y + size * 0.34),
            (x + size * 0.46, y - size * 0.34),
        ],
        fill,
        width,
    )


def shadow_layer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def add_shadow(img, rect, radius=22, blur=18, alpha=80, dy=8):
    layer = shadow_layer(img.size)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box((rect[0], rect[1] + dy, rect[2], rect[3] + dy)), radius=sc(radius), fill=(0, 0, 0, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(sc(blur)))
    img.alpha_composite(layer)


def gradient_bg(c1, c2):
    img = Image.new("RGBA", (sc(W), sc(H)), c1)
    draw = ImageDraw.Draw(img)
    for y in range(sc(H)):
        t = y / max(1, sc(H) - 1)
        r1, g1, b1 = Image.new("RGB", (1, 1), c1).getpixel((0, 0))
        r2, g2, b2 = Image.new("RGB", (1, 1), c2).getpixel((0, 0))
        col = (
            int(r1 + (r2 - r1) * t),
            int(g1 + (g2 - g1) * t),
            int(b1 + (b2 - b1) * t),
            255,
        )
        draw.line((0, y, sc(W), y), fill=col)
    return img


def base(bg=SURFACE, dark=True):
    img = gradient_bg(bg, "#0A0F1F") if dark else Image.new("RGBA", (sc(W), sc(H)), bg)
    draw = ImageDraw.Draw(img)
    if dark:
        focus_field(draw, center=(195, 520), radius=230, intensity=10, spokes=False)
    status(draw, dark=dark)
    home_indicator(draw, dark=dark)
    return img, draw


def status(draw, dark=False):
    fill = "#FFFFFF" if dark else INK
    draw_text(draw, (24, 17), "9:41", 15, fill, latin=True)
    line(draw, [(318, 27), (320, 23), (322, 27), (324, 21), (326, 27)], fill, 2)
    circle(draw, (342, 25), 4, fill)
    rr(draw, (357, 19, 382, 31), 4, None, fill, 1.4)
    rr(draw, (360, 22, 376, 28), 2, fill)


def home_indicator(draw, dark=False):
    fill = "#FFFFFF" if dark else "#111827"
    rr(draw, (135, 824, 255, 829), 3, fill)


def cta(draw, label, y=742, fill=VOID, bg=GOLD, outline=None):
    rr(draw, (26, y - 2, 364, y + 60), 20, "#15111F", outline="#2B2542")
    rr(draw, (28, y, 362, y + 58), 18, bg, outline=outline)
    draw_text(draw, (195, y + 18), label, 17, fill, align="center")


def back_chevron(draw, dark=True):
    col = "#FFFFFF" if dark else INK
    line(draw, [(26, 54), (16, 64), (26, 74)], col, 3)


def small_step(draw, index, label, active=True):
    total = 7
    start = 104
    gap = 8
    w = 20
    for i in range(total):
        col = GOLD if i == index else ("#303B58" if active else "#D1D5DB")
        rr(draw, (start + i * (w + gap), 54, start + i * (w + gap) + w, 58), 2, col)
    draw_text(draw, (195, 67), label, 11, "#AEB9D3" if active else MUTED, align="center")


def screen_welcome():
    img = gradient_bg(VOID, "#0B1020")
    draw = ImageDraw.Draw(img)
    focus_field(draw, center=(195, 398), radius=250, intensity=20)
    status(draw, dark=True)
    home_indicator(draw, dark=True)
    draw_text(draw, (28, 72), "LifeFocus", 14, BREATH)
    rr(draw, (274, 64, 362, 92), 14, "#151F35", outline="#3E2F68")
    draw_text(draw, (318, 70), "Deep Focus", 10, GOLD, align="center", latin=True)
    draw_text(draw, (30, 210), "SNSを断つ 人生に戻る", 31, "#FFFFFF")
    draw_text(draw, (32, 344), "無意識スクロールを止めて深い集中へ", 16, "#D6E4FF")
    line(draw, [(30, 474), (330, 474)], "#3E2F68", 1.2)
    draw_text(draw, (32, 506), "開く前に止まる", 18, "#D8E7F6")
    cta(draw, "はじめる", y=742, fill=VOID, bg=GOLD)
    return img


def screen_self_check():
    img, draw = base(SURFACE)
    back_chevron(draw)
    small_step(draw, 1, "01 / 意志のせいにしない")
    draw_text(draw, (28, 122), "意志の問題ではありません", 27)
    draw_text(draw, (28, 184), "SNSは反射で開けるように作られています。まず開きやすい時間を見つけます", 15, MUTED, max_width=325)
    draw_text(draw, (28, 252), "1日にSNSをどれくらい使っていますか", 16)
    choices = ["1時間未満", "1-2時間", "2-4時間", "4時間以上"]
    y = 288
    for i, label in enumerate(choices):
        selected = i == 2
        rr(draw, (28, y, 362, y + 48), 12, PANEL_2 if selected else CARD, outline=GOLD if selected else SUBTLE, width=1.4)
        draw_text(draw, (50, y + 13), label, 16, GOLD if selected else INK)
        if selected:
            circle(draw, (333, y + 24), 10, GOLD)
            check_mark(draw, (333, y + 24), size=14, fill=VOID, width=2.6)
        y += 58
    draw_text(draw, (28, 542), "特に開きやすい時間帯は", 16)
    chips = [("朝", 28), ("昼", 88), ("夕方", 148), ("夜", 228), ("寝る前", 288)]
    for label, x in chips:
        selected = label == "夜"
        rr(draw, (x, 576, x + (52 if len(label) == 1 else 66), 616), 20, "#211C32" if selected else CARD, outline=GOLD if selected else SUBTLE)
        draw_text(draw, (x + (26 if len(label) == 1 else 33), 587), label, 14, GOLD if selected else INK, align="center")
    cta(draw, "次へ", y=742, fill="#FFFFFF", bg=AURA)
    return img


def generic_app_icon(draw, rect, label, fill):
    rr(draw, rect, 11, fill)
    draw_text(draw, ((rect[0] + rect[2]) / 2, rect[1] + 11), label, 15, "#FFFFFF", align="center", latin=True)


def screen_choose_apps():
    img, draw = base(SURFACE)
    back_chevron(draw)
    small_step(draw, 2, "02 / まず1つ変える")
    draw_text(draw, (28, 122), "一番開くSNSから始める", 29)
    draw_text(draw, (28, 184), "全部を一気に止める必要はありません。まず1つだけ開く前に止まる仕組みを入れます", 15, MUTED, max_width=320)
    apps = [("X", "X", "#0F172A", True), ("Instagram", "IG", "#C24180", True), ("TikTok", "TT", "#111827", False), ("YouTube", "YT", "#DC2626", True)]
    y = 246
    for name, abbrev, col, selected in apps:
        add_shadow(img, (28, y, 362, y + 64), 14, 8, 12, 3)
        rr(draw, (28, y, 362, y + 64), 14, CARD, outline=BREATH if selected else SUBTLE, width=1.2)
        generic_app_icon(draw, (46, y + 14, 82, y + 50), abbrev, col)
        draw_text(draw, (98, y + 21), name, 17)
        if selected:
            circle(draw, (334, y + 32), 12, BREATH)
            check_mark(draw, (334, y + 32), size=16, fill=VOID, width=2.8)
        else:
            circle(draw, (334, y + 32), 12, CARD, outline=SUBTLE)
        y += 78
    rr(draw, (28, y + 8, 362, y + 62), 14, "#111B2D", outline="#344766")
    draw_text(draw, (58, y + 25), "その他のアプリを選ぶ", 16, BREATH)
    draw_text(draw, (334, y + 21), "+", 22, BREATH, align="center")
    cta(draw, "次へ", y=742, fill="#FFFFFF", bg=AURA)
    return img


def screen_choose_mode():
    img, draw = base(SURFACE)
    back_chevron(draw)
    small_step(draw, 3, "03 / 止め方")
    draw_text(draw, (28, 122), "SNSを開く前の止め方", 28)
    draw_text(draw, (28, 184), "開く前の確認の強さを選びます", 15, MUTED, max_width=320)
    cards = [
        ("Deep Focus", "作業中はSNSを開く前に強く止める", "Recommended", True, GOLD),
        ("通常モード", "SNSを開く前にひと呼吸と理由確認", "", False, BREATH),
        ("夜だけ強める", "夜は確認を強くして開きすぎを防ぐ", "", False, "#7280A5"),
    ]
    y = 246
    for title, desc, pill, selected, color in cards:
        add_shadow(img, (28, y, 362, y + 112), 18, 12, 18, 5)
        rr(draw, (28, y, 362, y + 112), 18, "#171A2A" if selected else CARD, outline=GOLD if selected else SUBTLE, width=1.4)
        rr(draw, (46, y + 26, 58, y + 70), 6, color)
        draw_text(draw, (78, y + 24), title, 20, INK)
        draw_text(draw, (78, y + 56), desc, 14, MUTED, max_width=230)
        if pill:
            rr(draw, (238, y + 24, 342, y + 50), 13, "#2C2340", outline="#5E4B7F")
            draw_text(draw, (290, y + 30), pill, 10, GOLD, align="center", latin=True)
        y += 130
    cta(draw, "次へ", y=742, fill=VOID, bg=GOLD)
    return img


def screen_intervention_preview():
    img, draw = base(SURFACE)
    back_chevron(draw)
    small_step(draw, 4, "04 / 確認画面")
    draw_text(draw, (28, 126), "SNSを開くと確認が出ます", 27)
    draw_text(draw, (28, 180), "SNSを開く前にこの流れを表示します", 15, MUTED, max_width=320)
    add_shadow(img, (42, 246, 348, 590), 26, 18, 100, 8)
    rr(draw, (42, 246, 348, 590), 26, "#0C1324", outline="#2B3B5D")
    focus_field(draw, center=(195, 418), radius=132, intensity=14, spokes=False)
    rr(draw, (76, 276, 314, 340), 20, VOID, outline="#30415F")
    draw_text(draw, (195, 297), "ひと呼吸", 22, "#FFFFFF", align="center")
    line(draw, [(195, 348), (195, 378)], GOLD, 3)
    rr(draw, (76, 386, 314, 454), 20, "#1B1B33", outline="#4A3D70")
    draw_text(draw, (195, 399), "今日 18回目", 20, GOLD, align="center")
    draw_text(draw, (195, 428), "無意識を数字で見る", 12, "#B8C7EA", align="center")
    line(draw, [(195, 462), (195, 492)], GOLD, 3)
    rr(draw, (76, 500, 314, 562), 20, "#111827", outline="#5D6D90")
    draw_text(draw, (195, 515), "何のために開く？", 18, INK, align="center")
    draw_text(draw, (195, 539), "理由を選んでから続ける", 12, MUTED, align="center")
    cta(draw, "表示を確認する", y=742, fill=VOID, bg=GOLD)
    return img


def screen_permission():
    img, draw = base(SURFACE)
    back_chevron(draw)
    small_step(draw, 5, "05 / 権限")
    circle(draw, (195, 162), 58, None, outline="#3E2F68", width=1.2)
    circle(draw, (195, 162), 44, "#171A2A", outline=GOLD)
    rr(draw, (162, 134, 228, 190), 18, "#211C32", outline="#5E4B7F")
    draw_text(draw, (195, 151), "ST", 23, GOLD, align="center", latin=True)
    draw_text(draw, (195, 268), "SNSの前で止める許可", 28, align="center")
    draw_text(draw, (195, 338), "iOSのScreen Timeを使います", 15, MUTED, max_width=310, align="center")
    rr(draw, (34, 430, 356, 558), 18, CARD, outline=SUBTLE)
    circle(draw, (64, 462), 10, GREEN)
    draw_text(draw, (88, 452), "選んだSNSの前に表示", 15)
    circle(draw, (64, 504), 10, GREEN)
    draw_text(draw, (88, 494), "使用データは端末内に保存", 15)
    circle(draw, (64, 546), 10, GREEN)
    draw_text(draw, (88, 536), "通知やタスク管理はしない", 15)
    cta(draw, "許可して始める", y=720, fill=VOID, bg=GOLD)
    draw_text(draw, (195, 795), "あとで", 15, MUTED, align="center")
    return img


def screen_ready():
    img = gradient_bg(VOID, "#0B1020")
    draw = ImageDraw.Draw(img)
    focus_field(draw, center=(195, 330), radius=230, intensity=13, spokes=False)
    status(draw, dark=True)
    home_indicator(draw, dark=True)
    small_step(draw, 6, "06 / 開始")
    circle(draw, (195, 160), 62, "#0E241E", outline=GREEN, width=1.2)
    circle(draw, (195, 160), 48, GREEN)
    check_mark(draw, (195, 160), size=58, fill=VOID, width=7)
    draw_text(draw, (195, 278), "次から開く前に止まります", 27, align="center")
    draw_text(draw, (195, 334), "SNSを開く前に確認が入ります", 17, MUTED, max_width=298, align="center", line_height=1.55)
    rr(draw, (34, 414, 356, 566), 20, CARD, outline=SUBTLE)
    draw_text(draw, (58, 442), "有効な設定", 13, MUTED)
    draw_text(draw, (58, 474), "対象SNS", 14, MUTED)
    draw_text(draw, (332, 474), "3個", 16, INK, align="right")
    line(draw, [(58, 508), (332, 508)], "#25324E", 1)
    draw_text(draw, (58, 526), "モード", 14, MUTED)
    draw_text(draw, (332, 526), "Deep Focus", 16, GOLD, align="right", latin=True)
    draw_text(draw, (195, 604), "開く前に選べる状態を作ります", 16, INK, max_width=274, align="center")
    cta(draw, "始める", y=742, fill=VOID, bg=GOLD)
    return img


SCREENS = [
    ("01_welcome.png", "Welcome", screen_welcome),
    ("02_self_check.png", "Self Check", screen_self_check),
    ("03_choose_apps.png", "Choose Apps", screen_choose_apps),
    ("04_choose_mode.png", "Choose Mode", screen_choose_mode),
    ("05_intervention_preview.png", "Intervention Preview", screen_intervention_preview),
    ("06_permission.png", "Permission", screen_permission),
    ("07_ready.png", "Ready", screen_ready),
]


def save_individuals():
    paths = []
    for filename, _label, fn in SCREENS:
        img = fn()
        path = OUT_DIR / filename
        img.convert("RGB").save(path, quality=95)
        paths.append(path)
    return paths


def make_board(paths):
    board_w, board_h = 2500, 1660
    board = Image.new("RGBA", (board_w, board_h), VOID)
    d = ImageDraw.Draw(board)
    d.rounded_rectangle((0, 0, board_w, 210), radius=0, fill="#090E1C")
    d.rounded_rectangle((90, 115, board_w - 90, 126), radius=5, fill=GOLD)
    for r in (90, 150, 220):
        d.ellipse((40 - r, 105 - r, 40 + r, 105 + r), outline=(112, 225, 255, 22), width=2)
    title_font = ImageFont.truetype(FONT_CJK, 56)
    sub_font = ImageFont.truetype(FONT_CJK, 28)
    d.text((92, 42), "LifeFocus Onboarding Mockups", font=title_font, fill="#FFFFFF")
    d.text((94, 112), "深く集中する  SNSを開く前に止める  必要な時間だけ開く", font=sub_font, fill="#D6E4FF")
    thumb_w = 286
    thumb_h = int(844 / 390 * thumb_w)
    gap_x = 44
    gap_y = 84
    start_x = 92
    start_y = 244
    label_font = ImageFont.truetype(FONT_LATIN, 25)
    jp_font = ImageFont.truetype(FONT_CJK, 21)
    labels_jp = ["Welcome", "Self Check", "Choose Apps", "Choose Mode", "Preview", "Permission", "Ready"]
    for idx, path in enumerate(paths):
        row = idx // 4
        col = idx % 4
        x = start_x + col * (thumb_w + gap_x)
        y = start_y + row * (thumb_h + gap_y + 52)
        if row == 1:
            x += 165
        shadow = Image.new("RGBA", board.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle((x + 10, y + 18, x + thumb_w + 10, y + thumb_h + 18), radius=34, fill=(0, 0, 0, 85))
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        board.alpha_composite(shadow)
        phone = Image.open(path).convert("RGBA").resize((thumb_w, thumb_h), Image.LANCZOS)
        mask = Image.new("L", (thumb_w, thumb_h), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle((0, 0, thumb_w, thumb_h), radius=34, fill=255)
        frame = Image.new("RGBA", (thumb_w + 18, thumb_h + 18), (0, 0, 0, 0))
        fd = ImageDraw.Draw(frame)
        fd.rounded_rectangle((0, 0, thumb_w + 18, thumb_h + 18), radius=44, fill="#0C1324", outline="#3E2F68", width=3)
        board.alpha_composite(frame, (x - 9, y - 9))
        board.paste(phone, (x, y), mask)
        d.text((x, y + thumb_h + 24), f"{idx + 1:02d}", font=label_font, fill=GOLD)
        d.text((x + 48, y + thumb_h + 24), labels_jp[idx], font=jp_font, fill="#FFFFFF")
    path = OUT_DIR / "00_onboarding_board.png"
    board.convert("RGB").save(path, quality=95)
    return path


def write_readme(paths, board):
    lines = [
        "# LifeFocus Onboarding Mockups",
        "",
        "作成日: 2026-06-27",
        "",
        "SNS依存改善に絞ったオンボーディングモック。黒背景、集中リング、金色アクセントでDeep Focus感を出す。アファメーション、今日の一歩、複数タスク、期限、チェックリスト、リマインダー、プロジェクト管理は入れていない。",
        "",
        "## Files",
        "",
        f"- `{board.name}`: 7画面の俯瞰ボード",
    ]
    for path in paths:
        lines.append(f"- `{path.name}`")
    (OUT_DIR / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    paths = save_individuals()
    board = make_board(paths)
    write_readme(paths, board)
    print(board)
    for path in paths:
        print(path)
