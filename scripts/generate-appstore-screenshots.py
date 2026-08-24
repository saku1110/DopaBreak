#!/usr/bin/env python3
"""Build localized App Store screenshot sets from real simulator captures."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "output" / "app-store-screenshots"
FINAL_ROOT = ASSET_ROOT / "final"
REVIEW_ROOT = ASSET_ROOT / "review"

COLORS = {
    "background": (10, 11, 13),
    "background_2": (16, 18, 21),
    "card": (23, 25, 29),
    "card_edge": (49, 53, 60),
    "white": (248, 248, 245),
    "muted": (132, 138, 151),
    "lime": (199, 249, 77),
    "lime_soft": (154, 201, 49),
    "ember": (255, 138, 31),
}

FONTS = {
    "ja": {
        "regular": Path("/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"),
        "bold": Path("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"),
    },
    "ko": {
        "regular": Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"),
        "bold": Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"),
    },
    "en-US": {
        "regular": Path("/System/Library/Fonts/SFNS.ttf"),
        "bold": Path("/System/Library/Fonts/SFNS.ttf"),
    },
}

CANVASES = {
    "iphone-69": (1320, 2868),
    "iphone-65": (1284, 2778),
    "ipad-13": (2064, 2752),
}

PANEL_DAYS = {
    "ja": {"iphone-69": 35, "iphone-65": 35, "ipad-13": 35},
    "en-US": {"iphone-69": 35, "iphone-65": 35, "ipad-13": 35},
    "ko": {"iphone-69": 35, "iphone-65": 35, "ipad-13": 35},
}

COPY = {
    "ja": [
        {
            "eyebrow": "SNS時間を見える化",
            "headline": ["「あと5分だけ」が", "1年で{days}日になる"],
            "sub": "回答から、無意識スクロールの時間を推計",
        },
        {
            "eyebrow": "禁止しないアプリ制限",
            "headline": ["SNSをブロックしない", "開く前に、ひと呼吸"],
            "sub": "反射で開く瞬間にだけ、短いブレーキ",
        },
        {
            "eyebrow": "理由と時間を選ぶ",
            "headline": ["何のために開く？", "必要な時間だけ使う"],
            "sub": "目的を言葉にして、5〜30分から選べます",
        },
        {
            "eyebrow": "目標と実績をひとつの画面に",
            "headline": ["我慢できた回数が", "数字で増える"],
            "sub": "今日と今週の合計をホームでいつでも確認",
        },
        {
            "eyebrow": "ロック画面・通知・ウィジェット",
            "headline": ["大切な目標を", "いつも目に入る場所へ"],
            "sub": "SNSを開く前に、やりたいことを思い出す",
        },
        {
            "eyebrow": "振り返りと統計",
            "headline": ["SNSのあと、本音を記録", "開くのをやめた回数も記録"],
            "sub": "満足感と開こうとした回数を見える化",
        },
        {
            "eyebrow": "オンデバイスで安心",
            "headline": ["記録は端末の中だけ", "無料で始められます"],
            "sub": "対象アプリ・呼吸時間・通知をいつでも調整",
        },
    ],
    "en-US": [
        {
            "eyebrow": "SEE THE COST OF DOOMSCROLLING",
            "headline": ["“Five more minutes”", "can become {days} days a year"],
            "sub": "Answer a few questions to see how much time your phone takes.",
        },
        {
            "eyebrow": "NOT ANOTHER APP BLOCKER",
            "headline": ["Don’t block social media", "Pause before you open"],
            "sub": "A short break interrupts the reflex. You still choose.",
        },
        {
            "eyebrow": "CHOOSE A REASON AND A TIME",
            "headline": ["Know why you’re opening", "Use only what you need"],
            "sub": "Name your purpose, then pick 5 to 30 minutes",
        },
        {
            "eyebrow": "A DETOX YOU CAN ACTUALLY KEEP",
            "headline": ["Dopamine detox,", "one skipped open at a time"],
            "sub": "Every open you skip gets counted, so the number keeps climbing.",
        },
        {
            "eyebrow": "LOCK SCREEN · NOTIFICATIONS · WIDGETS",
            "headline": ["Keep your goal", "where you’ll see it"],
            "sub": "Remember what matters before you open social media",
        },
        {
            "eyebrow": "HABIT TRACKER AND CHECK-INS",
            "headline": ["Check in after you scroll", "Count every time you didn’t open"],
            "sub": "Log how you felt, then see your attempts and skipped opens",
        },
        {
            "eyebrow": "PRIVATE BY DESIGN",
            "headline": ["Your records stay on device", "Start free"],
            "sub": "Adjust paused apps, breath length, and reminders anytime",
        },
    ],
    "ko": [
        {
            "eyebrow": "숏폼·SNS 시간 셀프 체크",
            "headline": ["‘5분만 더’가", "1년에 {days}일이 돼요"],
            "sub": "답변을 바탕으로 무심코 스크롤한 시간을 추정해요",
        },
        {
            "eyebrow": "차단이 아니라 브레이크",
            "headline": ["SNS를 막지 않아요", "열기 전에 숨 고르기"],
            "sub": "반사적으로 여는 순간에만 잠깐 브레이크를 걸어요",
        },
        {
            "eyebrow": "이유와 시간 선택",
            "headline": ["왜 여는지 먼저 확인", "필요한 만큼만 사용해요"],
            "sub": "목적을 고르고 5~30분 중 필요한 시간만 선택해요",
        },
        {
            "eyebrow": "목표와 기록을 한 화면에",
            "headline": ["참아낸 횟수가", "숫자로 늘어나요"],
            "sub": "오늘과 이번 주 합계를 홈에서 바로 확인해요",
        },
        {
            "eyebrow": "잠금 화면·알림·위젯",
            "headline": ["목표를", "늘 보이는 곳에"],
            "sub": "SNS를 열기 전에 내가 하려던 일을 떠올려요",
        },
        {
            "eyebrow": "사용 후 돌아보기와 루틴 통계",
            "headline": ["SNS를 본 뒤 기분을 기록", "열지 않은 횟수도 쌓여요"],
            "sub": "만족감·시도·열지 않은 횟수를 한눈에 봐요",
        },
        {
            "eyebrow": "기기 안에 안전하게",
            "headline": ["기록은 기기 안에만", "무료로 시작해요"],
            "sub": "대상 앱·숨 고르기 시간·알림을 언제든 조절해요",
        },
    ],
}

UI_COPY = {
    "ja": {
        "intent_title": "何のために\n開きますか？",
        "intent_desc": "目的が明確なら、ひと呼吸を省いてすぐ進めます",
        "reasons": ["仕事で使う", "調べもの", "連絡を確認", "投稿する", "暇つぶし", "なんとなく"],
        "time_title": "何分だけ開きますか？",
        "breath": "ひと呼吸おきましょう",
        "breath_sub": "ドーパと一緒にひと呼吸",
        "goal": "英語で話す",
        "goal_full": "英語で商談できる自分になる",
        "lock_summary": "今日は12回 開くのをやめた",
        "reflection": "SNSを見て\nどうだった？",
        "reflection_options": ["満足感があった", "楽しかった", "何も得られなかった", "時間を失った"],
        "stats_title": "今日の記録",
        "stats_main": "開くのをやめた 12回",
        "stats_sub": "開こうとした 18回",
        "sample": "サンプルデータ",
    },
    "en-US": {
        "intent_title": "What are you\nopening for?",
        "intent_desc": "If your purpose is clear, skip the breath and go straight in",
        "reasons": ["For work", "Look something up", "Check messages", "Post something", "Killing time", "Just because"],
        "time_title": "How many minutes do you need?",
        "breath": "Take a breath first",
        "breath_sub": "Take a breath with Dopa",
        "goal": "Speak English",
        "goal_full": "Speak English confidently",
        "lock_summary": "Chose not to open 12× today",
        "reflection": "How did it feel\nafter scrolling?",
        "reflection_options": ["Felt satisfied", "It was fun", "Got nothing out of it", "Lost time"],
        "stats_title": "Today’s record",
        "stats_main": "Chose not to open 12 times",
        "stats_sub": "18 attempts to open",
        "sample": "SAMPLE DATA",
    },
    "ko": {
        "intent_title": "무엇을 위해\n여나요?",
        "intent_desc": "목적이 분명하면 숨 고르기를 건너뛰고 바로 진행해요",
        "reasons": ["업무용", "찾아보기", "연락 확인", "게시물 올리기", "심심풀이", "그냥"],
        "time_title": "몇 분만 열까요?",
        "breath": "숨 한 번 고르고 가요",
        "breath_sub": "도파와 함께 한 호흡",
        "goal": "영어로 말하기",
        "goal_full": "영어로 자신 있게 말하기",
        "lock_summary": "오늘은 12번 열지 않기로 함",
        "reflection": "SNS를 보고 나서\n어땠나요?",
        "reflection_options": ["만족스러웠어요", "즐거웠어요", "얻은 게 없었어요", "시간을 허비했어요"],
        "stats_title": "오늘의 기록",
        "stats_main": "열지 않기로 함 12회",
        "stats_sub": "열려고 한 횟수 18회",
        "sample": "예시 데이터",
    },
}


def font(locale: str, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS[locale]["bold" if bold else "regular"]), size=size)


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    strip = Image.new("RGB", (1, h))
    colors = []
    for y in range(h):
        t = y / max(h - 1, 1)
        colors.append(tuple(lerp(top[i], bottom[i], t) for i in range(3)))
    strip.putdata(colors)
    return strip.resize((w, h))


def cover(image: Image.Image, size: tuple[int, int], focus_y: float = 0.5) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, round((resized.height - target_h) * focus_y))
    return resized.crop((left, top, left + target_w, top + target_h)).convert("RGB")


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = image.copy().convert("RGB")
    result.thumbnail(size, Image.Resampling.LANCZOS)
    return result


def rounded_paste(base: Image.Image, source: Image.Image, box: tuple[int, int, int, int], radius: int, border: int = 2) -> None:
    x, y, w, h = box
    fitted = cover(source.convert("RGB"), (w, h), focus_y=0.18)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x - 14, y + 18, x + w + 14, y + h + 46), radius=radius + 10, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(18, radius // 3)))
    base.paste(shadow.convert("RGB"), (0, 0), shadow.getchannel("A"))
    base.paste(fitted, (x, y), mask)
    ImageDraw.Draw(base).rounded_rectangle((x, y, x + w - 1, y + h - 1), radius=radius, outline=COLORS["card_edge"], width=border)


def sanitize_ipad_status(image: Image.Image, locale: str) -> Image.Image:
    if image.width < 1800:
        return image
    result = image.copy().convert("RGB")
    draw = ImageDraw.Draw(result)
    bar_h = 60
    draw.rectangle((0, 0, result.width, bar_h), fill=COLORS["background"])
    draw.text((50, 14), "9:41", font=font(locale, 28, True), fill=COLORS["white"])
    right = "Wi-Fi   100%"
    bbox = draw.textbbox((0, 0), right, font=font(locale, 25, True))
    draw.text((result.width - (bbox[2] - bbox[0]) - 54, 16), right, font=font(locale, 25, True), fill=COLORS["white"])
    return result


def draw_centered_lines(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    locale: str,
    y: int,
    max_width: int,
    size: int,
    fill: tuple[int, int, int],
    spacing: int,
) -> int:
    selected = size
    while selected > max(36, size // 2):
        f = font(locale, selected, True)
        if all(draw.textbbox((0, 0), line, font=f)[2] <= max_width for line in lines):
            break
        selected -= 2
    f = font(locale, selected, True)
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=f)
        draw.text(((draw._image.width - (bbox[2] - bbox[0])) // 2, y), line, font=f, fill=fill)
        y += (bbox[3] - bbox[1]) + spacing
    return y


def draw_status(draw: ImageDraw.ImageDraw, size: tuple[int, int], locale: str) -> None:
    w, _ = size
    draw.text((56, 44), "9:41", font=font(locale, max(24, w // 34), True), fill=COLORS["white"])
    if w < 1700:
        draw.rounded_rectangle((w // 2 - 125, 30, w // 2 + 125, 108), radius=42, fill=(0, 0, 0))
    right = "Wi-Fi   100%"
    bbox = draw.textbbox((0, 0), right, font=font(locale, max(22, w // 38), True))
    draw.text((w - (bbox[2] - bbox[0]) - 56, 46), right, font=font(locale, max(22, w // 38), True), fill=COLORS["white"])


def mock_intent(size: tuple[int, int], locale: str) -> Image.Image:
    w, h = size
    s = w / 1320
    ui = UI_COPY[locale]
    image = Image.new("RGB", size, COLORS["background"])
    draw = ImageDraw.Draw(image)
    draw_status(draw, size, locale)
    margin = round(70 * s)
    y = round(220 * s)
    draw.text((margin, y), "INTENT", font=font(locale, round(34 * s), True), fill=COLORS["muted"])
    y += round(85 * s)
    title_size = round((78 if w < 1700 else 64) * s)
    for line in ui["intent_title"].splitlines():
        draw.text((margin, y), line, font=font(locale, title_size, True), fill=COLORS["white"])
        y += round(100 * s)
    draw.text((margin, y + round(16 * s)), ui["intent_desc"], font=font(locale, round(31 * s)), fill=COLORS["muted"])
    y += round(120 * s)

    gap = round(22 * s)
    card_w = (w - margin * 2 - gap) // 2
    card_h = round(170 * s)
    for idx, label in enumerate(ui["reasons"][:4]):
        row, col = divmod(idx, 2)
        x = margin + col * (card_w + gap)
        cy = y + row * (card_h + gap)
        draw.rounded_rectangle((x, cy, x + card_w, cy + card_h), radius=round(34 * s), fill=COLORS["card"], outline=COLORS["card_edge"], width=max(2, round(2 * s)))
        symbol = f"{idx + 1:02d}"
        draw.text((x + round(34 * s), cy + round(24 * s)), symbol, font=font(locale, round(45 * s), True), fill=COLORS["white"])
        draw.text((x + round(34 * s), cy + round(100 * s)), label, font=font(locale, round(31 * s), True), fill=COLORS["white"])
    y += 2 * (card_h + gap) + round(42 * s)
    draw.text((margin, y), ui["time_title"], font=font(locale, round(40 * s), True), fill=COLORS["white"])
    y += round(78 * s)
    chip_gap = round(16 * s)
    chip_w = (w - margin * 2 - chip_gap * 3) // 4
    for idx, minutes in enumerate((5, 10, 15, 30)):
        x = margin + idx * (chip_w + chip_gap)
        fill = COLORS["lime"] if minutes == 10 else COLORS["card"]
        text_fill = COLORS["background"] if minutes == 10 else COLORS["white"]
        draw.rounded_rectangle((x, y, x + chip_w, y + round(95 * s)), radius=round(48 * s), fill=fill, outline=COLORS["card_edge"])
        label = f"{minutes}分" if locale == "ja" else (f"{minutes}분" if locale == "ko" else f"{minutes} min")
        bbox = draw.textbbox((0, 0), label, font=font(locale, round(28 * s), True))
        draw.text((x + (chip_w - (bbox[2] - bbox[0])) // 2, y + round(27 * s)), label, font=font(locale, round(28 * s), True), fill=text_fill)
    return image


def mock_breath(size: tuple[int, int], locale: str) -> Image.Image:
    w, h = size
    s = w / 1320
    ui = UI_COPY[locale]
    image = Image.new("RGB", size, COLORS["background"])
    character_source = Image.open(
        ROOT / "ios/DopaBreak/Assets.xcassets/Character/doom.imageset/doom.png"
    ).convert("RGBA")
    character_side = round(w * (0.20 if w >= 1700 else 0.46))
    character = character_source.copy()
    character.thumbnail((character_side, character_side), Image.Resampling.LANCZOS)
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gx = (w - character.width) // 2
    gy = (h - character.height) // 2
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (
            gx + character.width * 0.08,
            gy + character.height * 0.16,
            gx + character.width * 0.92,
            gy + character.height * 0.92,
        ),
        fill=(*COLORS["lime"], 55),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(round(110 * s)))
    image.paste(glow.convert("RGB"), (0, 0), glow.getchannel("A"))
    image.paste(character, (gx, gy), character.getchannel("A"))
    draw = ImageDraw.Draw(image)
    draw_status(draw, size, locale)
    eyebrow = "PAUSE"
    eb = draw.textbbox((0, 0), eyebrow, font=font(locale, round(32 * s), True))
    draw.text(((w - (eb[2] - eb[0])) // 2, round(210 * s)), eyebrow, font=font(locale, round(32 * s), True), fill=COLORS["muted"])
    title_y = round(285 * s)
    tb = draw.textbbox((0, 0), ui["breath"], font=font(locale, round(62 * s), True))
    draw.text(((w - (tb[2] - tb[0])) // 2, title_y), ui["breath"], font=font(locale, round(62 * s), True), fill=COLORS["white"])
    sb = draw.textbbox((0, 0), ui["breath_sub"], font=font(locale, round(30 * s)))
    draw.text(((w - (sb[2] - sb[0])) // 2, title_y + round(102 * s)), ui["breath_sub"], font=font(locale, round(30 * s)), fill=COLORS["muted"])
    return image


def mock_lock(size: tuple[int, int], locale: str) -> Image.Image:
    w, h = size
    s = w / 1320
    ui = UI_COPY[locale]
    background = Image.open(ROOT / "ios/DopaBreak/Resources/morning-horizon.png").convert("RGB")
    image = cover(background, size, focus_y=0.45)
    overlay = Image.new("RGBA", size, (0, 0, 0, 85))
    image.paste(overlay.convert("RGB"), (0, 0), overlay.getchannel("A"))
    draw = ImageDraw.Draw(image)
    draw_status(draw, size, locale)
    time_font = font(locale, round(160 * s), False)
    time = "7:00"
    tb = draw.textbbox((0, 0), time, font=time_font)
    draw.text(((w - (tb[2] - tb[0])) // 2, round(170 * s)), time, font=time_font, fill=COLORS["white"])

    card_x = round(70 * s)
    card_w = w - card_x * 2
    card_y = round(h * 0.51)
    card_h = round(360 * s)
    glass = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    gd.rounded_rectangle((card_x, card_y, card_x + card_w, card_y + card_h), radius=round(48 * s), fill=(17, 19, 22, 225), outline=(255, 255, 255, 45), width=max(2, round(2 * s)))
    image.paste(glass.convert("RGB"), (0, 0), glass.getchannel("A"))
    draw = ImageDraw.Draw(image)
    draw.text((card_x + round(48 * s), card_y + round(42 * s)), "DOPABREAK · LIVE", font=font(locale, round(28 * s), True), fill=COLORS["lime"])
    draw.text((card_x + round(48 * s), card_y + round(100 * s)), ui["goal_full"], font=font(locale, round(47 * s), True), fill=COLORS["white"])
    draw.line((card_x + round(48 * s), card_y + round(190 * s), card_x + card_w - round(48 * s), card_y + round(190 * s)), fill=COLORS["card_edge"], width=max(2, round(2 * s)))
    draw.text((card_x + round(48 * s), card_y + round(230 * s)), ui["lock_summary"], font=font(locale, round(39 * s), True), fill=COLORS["white"])
    draw.ellipse((card_x + card_w - round(140 * s), card_y + round(235 * s), card_x + card_w - round(78 * s), card_y + round(297 * s)), fill=COLORS["lime"])
    return image


def mock_reflection(size: tuple[int, int], locale: str) -> Image.Image:
    w, h = size
    s = w / 1320
    ui = UI_COPY[locale]
    image = Image.new("RGB", size, COLORS["background"])
    draw = ImageDraw.Draw(image)
    draw_status(draw, size, locale)
    margin = round(70 * s)
    y = round(210 * s)
    draw.text((margin, y), "REFLECTION", font=font(locale, round(30 * s), True), fill=COLORS["lime"])
    y += round(70 * s)
    for line in ui["reflection"].splitlines():
        draw.text((margin, y), line, font=font(locale, round(66 * s), True), fill=COLORS["white"])
        y += round(90 * s)
    y += round(32 * s)
    option_h = round(105 * s)
    for idx, label in enumerate(ui["reflection_options"]):
        fill = (35, 42, 28) if idx == 2 else COLORS["card"]
        outline = COLORS["lime_soft"] if idx == 2 else COLORS["card_edge"]
        draw.rounded_rectangle((margin, y, w - margin, y + option_h), radius=round(30 * s), fill=fill, outline=outline, width=max(2, round(2 * s)))
        draw.text((margin + round(34 * s), y + round(30 * s)), label, font=font(locale, round(31 * s), True), fill=COLORS["white"])
        y += option_h + round(18 * s)

    y += round(45 * s)
    stats_h = round(330 * s)
    draw.rounded_rectangle((margin, y, w - margin, y + stats_h), radius=round(42 * s), fill=COLORS["card"], outline=COLORS["card_edge"], width=max(2, round(2 * s)))
    draw.text((margin + round(42 * s), y + round(38 * s)), ui["sample"], font=font(locale, round(24 * s), True), fill=COLORS["muted"])
    draw.text((margin + round(42 * s), y + round(88 * s)), ui["stats_title"], font=font(locale, round(38 * s), True), fill=COLORS["white"])
    draw.text((margin + round(42 * s), y + round(158 * s)), ui["stats_main"], font=font(locale, round(51 * s), True), fill=COLORS["lime"])
    draw.text((margin + round(42 * s), y + round(240 * s)), ui["stats_sub"], font=font(locale, round(31 * s)), fill=COLORS["muted"])
    return image


def source_for(panel: int, locale: str, device: str) -> Image.Image:
    is_ipad = device == "ipad-13"
    raw_root = ASSET_ROOT / ("raw-ipad" if is_ipad else "raw") / locale
    if panel == 1:
        image = Image.open(raw_root / "onboarding/03-quiz-result.png").convert("RGB")
    elif panel == 2:
        image = mock_breath(CANVASES[device], locale)
    elif panel == 3:
        image = mock_intent(CANVASES[device], locale)
    elif panel == 4:
        image = Image.open(raw_root / "onboarding/04-choose-mode.png").convert("RGB")
    elif panel == 5:
        image = mock_lock(CANVASES[device], locale)
    elif panel == 6:
        image = mock_reflection(CANVASES[device], locale)
    elif panel == 7:
        image = Image.open(raw_root / "native/chrome-settings-default.png").convert("RGB")
    else:
        raise ValueError(panel)
    return sanitize_ipad_status(image, locale)


def app_icon(size: int) -> Image.Image:
    source = Image.open(ROOT / "ios/DopaBreak/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").convert("RGB")
    source = source.resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=round(size * 0.22), fill=255)
    result = Image.new("RGB", (size, size), COLORS["background"])
    result.paste(source, (0, 0), mask)
    return result


def compose(locale: str, device: str, panel: int) -> Image.Image:
    w, h = CANVASES[device]
    is_ipad = device == "ipad-13"
    raw_info = COPY[locale][panel - 1]
    info = {
        "eyebrow": raw_info["eyebrow"],
        "headline": [line.format(days=PANEL_DAYS[locale][device]) for line in raw_info["headline"]],
        "sub": raw_info["sub"],
    }
    if panel == 2:
        canvas = gradient((w, h), (206, 255, 86), (159, 213, 47))
        primary = COLORS["background"]
        secondary = (45, 58, 29)
        pill_fill = (14, 16, 17)
        pill_text = COLORS["lime"]
    else:
        canvas = gradient((w, h), (18, 20, 23), COLORS["background"])
        primary = COLORS["white"]
        secondary = COLORS["muted"]
        pill_fill = (35, 42, 28)
        pill_text = COLORS["lime"]

    draw = ImageDraw.Draw(canvas)
    margin = round(w * (0.07 if is_ipad else 0.075))
    icon_size = round(w * (0.055 if is_ipad else 0.09))
    icon = app_icon(icon_size)
    canvas.paste(icon, (margin, margin))
    brand_font = font(locale, round(w * (0.025 if is_ipad else 0.033)), True)
    draw.text((margin + icon_size + round(w * 0.018), margin + round(icon_size * 0.22)), "DopaBreak", font=brand_font, fill=primary)
    counter = f"{panel:02d} / 07"
    cb = draw.textbbox((0, 0), counter, font=font(locale, round(w * 0.022), True))
    draw.text((w - margin - (cb[2] - cb[0]), margin + round(icon_size * 0.24)), counter, font=font(locale, round(w * 0.022), True), fill=secondary)

    eyebrow_y = margin + icon_size + round(h * 0.035)
    eyebrow_font = font(locale, round(w * (0.021 if is_ipad else 0.026)), True)
    eb = draw.textbbox((0, 0), info["eyebrow"], font=eyebrow_font)
    pad_x = round(w * 0.022)
    pad_y = round(h * 0.008)
    pill_w = eb[2] - eb[0] + pad_x * 2
    pill_h = eb[3] - eb[1] + pad_y * 2
    pill_x = (w - pill_w) // 2
    draw.rounded_rectangle((pill_x, eyebrow_y, pill_x + pill_w, eyebrow_y + pill_h), radius=pill_h // 2, fill=pill_fill)
    draw.text((pill_x + pad_x, eyebrow_y + pad_y - eb[1]), info["eyebrow"], font=eyebrow_font, fill=pill_text)

    headline_y = eyebrow_y + pill_h + round(h * 0.028)
    headline_size = round(w * (0.055 if is_ipad else 0.065))
    headline_y = draw_centered_lines(draw, info["headline"], locale, headline_y, w - margin * 2, headline_size, primary, round(h * 0.007))
    sub_font = font(locale, round(w * (0.024 if is_ipad else 0.029)), False)
    sb = draw.textbbox((0, 0), info["sub"], font=sub_font)
    if sb[2] - sb[0] > w - margin * 2:
        sub_font = font(locale, round(w * (0.020 if is_ipad else 0.025)), False)
        sb = draw.textbbox((0, 0), info["sub"], font=sub_font)
    draw.text(((w - (sb[2] - sb[0])) // 2, headline_y + round(h * 0.018)), info["sub"], font=sub_font, fill=secondary)

    source = source_for(panel, locale, device)
    if is_ipad:
        frame_y = round(h * 0.34)
        frame_w = round(w * 0.83)
        frame_h = round(h * 0.76)
        radius = round(w * 0.028)
    else:
        frame_y = round(h * 0.34)
        frame_w = round(w * 0.78)
        frame_h = round(frame_w * CANVASES["iphone-69"][1] / CANVASES["iphone-69"][0])
        radius = round(w * 0.055)
    frame_x = (w - frame_w) // 2
    rounded_paste(canvas, source, (frame_x, frame_y, frame_w, frame_h), radius=radius, border=max(2, round(w * 0.002)))
    return canvas.convert("RGB")


def make_contact_sheet(locale: str, device: str, files: list[Path]) -> None:
    thumb_w = 320 if device == "ipad-13" else 240
    thumbs = []
    for path in files:
        image = Image.open(path).convert("RGB")
        thumb_h = round(thumb_w * image.height / image.width)
        thumbs.append(image.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS))
    cols = 4
    rows = math.ceil(len(thumbs) / cols)
    gap = 24
    label_h = 54
    cell_h = max(image.height for image in thumbs) + label_h
    sheet = Image.new("RGB", (cols * thumb_w + (cols + 1) * gap, rows * cell_h + (rows + 1) * gap), (230, 232, 226))
    draw = ImageDraw.Draw(sheet)
    for idx, image in enumerate(thumbs):
        col = idx % cols
        row = idx // cols
        x = gap + col * (thumb_w + gap)
        y = gap + row * (cell_h + gap)
        sheet.paste(image, (x, y))
        draw.text((x, y + image.height + 10), f"{idx + 1:02d}", font=font("en-US", 28, True), fill=(25, 26, 28))
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    sheet.save(REVIEW_ROOT / f"{locale}-{device}-contact-sheet.jpg", quality=92, subsampling=0)


def main() -> None:
    for locale in COPY:
        for device in CANVASES:
            output_dir = FINAL_ROOT / locale / device
            output_dir.mkdir(parents=True, exist_ok=True)
            files: list[Path] = []
            slugs = ("hook", "pause", "intent-time", "modes", "goal-lockscreen", "reflection-stats", "privacy-settings")
            for panel, slug in enumerate(slugs, start=1):
                image = compose(locale, device, panel)
                path = output_dir / f"{panel:02d}-{slug}.png"
                image.save(path, format="PNG", compress_level=7)
                files.append(path)
            make_contact_sheet(locale, device, files)
            print(f"Generated {locale}/{device}: {len(files)} screenshots")


if __name__ == "__main__":
    main()
