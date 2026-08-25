#!/usr/bin/env python3
"""Generate localized DopaBreak App Store screenshots v2 for iPhone and iPad.

The composition is defined by:
  .claude/specs/appstore-screenshots-v2-diagonal.md

The legacy generator remains the source of truth for gradients and the
approved en-US / ko copy used by panels 01-04 and 06-07. This module owns the
locale-specific typography and v2 lock-screen mock. Core app screens come
from the real-window XCTest captures in output/app-store-screenshots/raw-core/.
The legacy filename contains hyphens, so it is loaded with importlib without
invoking main().
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import shutil
from dataclasses import dataclass, replace
from functools import lru_cache
from pathlib import Path
from types import ModuleType
from typing import Any, Callable, Sequence

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
LEGACY_PATH = ROOT / "scripts" / "generate-appstore-screenshots.py"
WIDGET_LOCALIZABLE_PATH = ROOT / "ios" / "WidgetsExtension" / "Localizable.xcstrings"
OUTPUT_ROOT = ROOT / "output" / "app-store-screenshots" / "v2"
SCREENSHOT_ROOT = OUTPUT_ROOT / "ja" / "iphone-69"
CONTACT_SHEET_PATH = OUTPUT_ROOT / "contact-sheet-ja.png"
SLOTS_PATH = OUTPUT_ROOT / "slots-ja.json"
RAW_CORE_ROOT = ROOT / "output" / "app-store-screenshots" / "raw-core" / "ja"

CANVAS_SIZE = (1320, 2868)
CANVAS_WIDTH, CANVAS_HEIGHT = CANVAS_SIZE
IPHONE_CANVAS_SIZE = (1320, 2868)
IPAD_CANVAS_SIZE = (2064, 2752)
SCREEN_ASPECT = (1320, 2868)
SUPPORTED_LOCALES = ("ja", "en-US", "ko")
SUPPORTED_DEVICES = ("iphone-69", "ipad-13")
LOCALE = "ja"
DEVICE = "iphone-69"
AA_SCALE = 4

IPAD_COPY_MAX_WIDTH = round(IPAD_CANVAS_SIZE[0] * 0.78)
IPAD_COPY_EYEBROW_Y = 145
IPAD_COPY_HEADLINE_Y = 245
IPAD_COPY_SUB_Y = 610
IPAD_PHONE_VISUAL_TOP = 760
IPAD_BREATH_PHONE_VISUAL_TOP = 670
IPAD_LOCK_PHONE_VISUAL_TOP = 720
IPAD_STRAIGHT_PHONE_WIDTH = 1480
# At 8 degrees, 1607px is the largest integer chassis width whose rotated
# exterior remains fully inside the 2064px canvas.  The extra height of the
# 1320:2868 phone, rather than the unrotated width, is the limiting dimension.
IPAD_ROTATED_PHONE_WIDTH = 1607
# With visual_top=720, 1224px is the largest integer chassis width whose real
# y=2280 Live Activity lower edge remains inside the 2752px canvas.
IPAD_LOCK_PHONE_WIDTH = 1224
IPAD_LOCK_CALLOUT_WIDTH = 1500
IPAD_LOCK_CLOCK_SOURCE_BOX = (298, 350, 1023, 617)

COPY_EYEBROW_Y = 240
COPY_HEADLINE_Y = 340
COPY_SUB_Y = 680
PANEL_01_LIME_POLYGON = ((0, 200), (1320, 80), (1320, 1080), (0, 1420))
PANEL_08_LIME_POLYGON = ((0, 80), (1320, 200), (1320, 1420), (0, 1080))
PHONE_VISUAL_TOP = 820
MAX_STRAIGHT_PHONE_WIDTH = 1396
MAX_SEVEN_DEGREE_PHONE_WIDTH = 1111
MAX_EIGHT_DEGREE_PHONE_WIDTH = 1081
LOCK_PHONE_VISUAL_TOP = 800
# Largest integer outer width whose source y=2280 Live Activity edge lands at
# or above canvas y=2800 with the upright phone held at visual top y=800.
LOCK_PHONE_WIDTH = 1204
LOCK_LIME_CIRCLE_CENTER = (CANVAS_WIDTH // 2, 1830)
LOCK_LIME_CIRCLE_RADIUS = 640
LOCK_CHARACTER_WIDTH = 300
LOCK_CHARACTER_CENTER_X = 230
LOCK_CHARACTER_BOTTOM_Y = LOCK_PHONE_VISUAL_TOP + 260


def lock_pt_to_px(points: float, screen_width: int = CANVAS_WIDTH) -> int:
    """Convert SwiftUI points to pixels for the 3x lock-screen source."""
    return round(points * 3 * screen_width / 1320)

CHARACTER_GROUND_SHADOW_WIDTH_RATIO = 0.70
CHARACTER_GROUND_SHADOW_HEIGHT = 90
CHARACTER_GROUND_SHADOW_OPACITY = 0.30
CHARACTER_GROUND_SHADOW_BLUR = 30

COLORS = {
    "background": (11, 13, 15),  # #0B0D0F
    "raised": (18, 20, 23),
    "lime": (199, 249, 77),  # #C7F94D
    "lime_deep": (159, 213, 47),  # #9FD52F
    "ink": (10, 12, 14),  # #0A0C0E
    "off_white": (244, 245, 242),  # #F4F5F2
    "muted": (126, 134, 148),  # #7E8694
    "lime_sub": (45, 58, 29),
    "dark_pill": (35, 42, 28),
    "titanium_top": (58, 63, 69),  # #3A3F45
    "titanium_bottom": (27, 30, 34),  # #1B1E22
    "titanium_rim": (90, 97, 105),  # #5A6169
}

LOCK_THEME_E1 = {
    "card": (20, 23, 27),
    "accent": (184, 255, 61),
    "primary_text": (244, 242, 236),
    "secondary_text": (139, 146, 158),
}
LOCK_ACTIVITY_CARD_MARGIN = lock_pt_to_px(14)
LOCK_ACTIVITY_CARD_BOX = (
    LOCK_ACTIVITY_CARD_MARGIN,
    1860,
    CANVAS_WIDTH - LOCK_ACTIVITY_CARD_MARGIN,
    2280,
)
LOCK_ACTIVITY_CARD_RADIUS = lock_pt_to_px(18)
LOCK_CALLOUT_WIDTH = round(CANVAS_WIDTH * 0.894)
LOCK_CALLOUT_TOP = 1410
LOCK_CALLOUT_VERTICAL_CLEARANCE = 40
LOCK_ACTIVITY_CANVAS_BOTTOM_LIMIT = 2800
LOCK_CALLOUT_MAX_ACTUAL_WIDTH_RATIO = 1.35
LOCK_CALLOUT_BORDER_WIDTH = 3
LOCK_SOURCE_OUTLINE_WIDTH = 2
LOCK_CONNECTOR_WIDTH = 2
LOCK_CONNECTOR_OPACITY = 0.60
LOCK_CALLOUT_SHADOW_OPACITY = 0.45
LOCK_CALLOUT_SHADOW_BLUR = 50
LOCK_CALLOUT_SHADOW_OFFSET = (0, 24)

PANEL_IDS = (1, 2, 3, 4, 5, 6, 8, 9, 10)
SLUGS = (
    "breath",
    "home",
    "lockscreen",
    "night",
    "stats",
    "deepfocus",
    "intent",
    "reflection",
    "grayscale-home",
)
UPLOAD_ORDER = (
    (1, "breath"),
    (3, "lockscreen"),
    (6, "deepfocus"),
    (2, "home"),
    (4, "night"),
    (8, "intent"),
    (9, "reflection"),
    (10, "grayscale-home"),
)

# Layout IDs stay attached to upload positions. Only their screen/copy content moves.
CONTENT_PANEL_BY_LAYOUT = {
    1: 2,   # breath
    2: 1,   # home
    3: 5,   # lock screen
    4: 4,   # night mode
    5: 3,   # stats
    6: 6,   # deep focus
    8: 8,   # intent
    9: 9,   # reflection
    10: 10, # grayscale home
}
LAYOUT_SURFACES = {
    1: "lime",
    2: "lime",
    3: "dark",
    4: "dark",
    5: "dark",
    6: "dark",
    8: "lime",
    9: "dark",
    10: "dark",
}

SOURCE_PATHS: tuple[Path | None, ...] = (
    RAW_CORE_ROOT / "home.png",
    RAW_CORE_ROOT / "breath.png",
    RAW_CORE_ROOT / "stats.png",
    RAW_CORE_ROOT / "nightmode.png",
    None,
    RAW_CORE_ROOT / "deepfocus.png",
    RAW_CORE_ROOT / "intent.png",
    RAW_CORE_ROOT / "reflection.png",
    None,
)

# Panels whose screen is drawn by this module instead of an XCTest capture.
MOCK_SOURCE_NAMES = {5: "mock_lock", 10: "mock_home_grayscale"}


def source_labels(paths: Sequence[Path | None], locale: str) -> tuple[str, ...]:
    labels: list[str] = []
    for panel, path in zip(PANEL_IDS, paths):
        if path is None:
            labels.append(f"{MOCK_SOURCE_NAMES[panel]}((1320, 2868), {locale!r})")
        else:
            labels.append(path.relative_to(ROOT).as_posix())
    return tuple(labels)


SOURCE_LABELS = source_labels(SOURCE_PATHS, LOCALE)

# rawを原寸で目視した個体数。statsの気持ちカードは5体が正しい。
SCREEN_CHARACTER_COUNTS = (
    1,  # home
    1,  # breath
    5,  # stats（見たあとの気持ちカード）
    0,  # night-only settings
    0,  # lock mock
    0,  # deep focus settings
    0,  # intent
    1,  # reflection（1問目・未選択）
    0,  # grayscale home mock
)

# 最終コンポジットに見える画面内キャラ数。statsだけは配置後の可視領域から算出する。
VISIBLE_SCREEN_CHARACTER_COUNTS: tuple[int | None, ...] = (
    1, 1, None, 0, 0, 0, 0, 1, 0
)
STATS_PHONE_WIDTH = MAX_STRAIGHT_PHONE_WIDTH
STATS_PHONE_VISUAL_TOP = 930
STATS_DOOM_WIDTH = 300
STATS_DOOM_CENTER_X = 1130
STATS_DOOM_BOTTOM_Y = 1260
STATS_CARD_TOPS = {
    "ja": {"percentage": 661, "app": 1245, "mood": 1915},
    "en-US": {"percentage": 661, "app": 1284, "mood": 1954},
    "ko": {"percentage": 661, "app": 1245, "mood": 1915},
}
NIGHT_PHONE_WIDTH = MAX_EIGHT_DEGREE_PHONE_WIDTH
NIGHT_PHONE_VISUAL_TOP = PHONE_VISUAL_TOP
NIGHT_PHONE_ROTATION = 8
CORNER_CHARACTER_WIDTH = 470
DEEPFOCUS_CHARACTER_CENTER_X = 1085
DEEPFOCUS_CHARACTER_BOTTOM_Y = 1160
NIGHT_CHARACTER_CENTER_X = 240
NIGHT_CHARACTER_BOTTOM_Y = 1160
INTENT_PHONE_WIDTH = MAX_STRAIGHT_PHONE_WIDTH
INTENT_PHONE_VISUAL_TOP = 800
INTENT_CHARACTER_CENTER_X = 1080
INTENT_CHARACTER_BOTTOM_Y = 1150
REFLECTION_PHONE_WIDTH = MAX_STRAIGHT_PHONE_WIDTH
REFLECTION_PHONE_VISUAL_TOP = 800
REFLECTION_LIME_RIBBON = ((0, 770), (1320, 810), (1320, 890), (0, 850))
GRAYSCALE_PHONE_VISUAL_TOP = 805
GRAYSCALE_CHARACTER_CENTER_X = 1080
GRAYSCALE_CHARACTER_BOTTOM_Y = 1160
BREATH_SOURCE_OFFSET_Y = 400


@dataclass(frozen=True)
class CopySpec:
    eyebrow: str
    headline: tuple[str, str]
    sub: str
    eyebrow_y: int
    headline_y: int
    sub_y: int
    surface: str


def _copy_spec(
    eyebrow: str,
    headline_1: str,
    headline_2: str,
    sub: str,
    surface: str,
) -> CopySpec:
    return CopySpec(
        eyebrow=eyebrow,
        headline=(headline_1, headline_2),
        sub=sub,
        eyebrow_y=COPY_EYEBROW_Y,
        headline_y=COPY_HEADLINE_Y,
        sub_y=COPY_SUB_Y,
        surface=surface,
    )


COPY: dict[str, tuple[CopySpec, ...]] = {
    "ja": (
        _copy_spec(
            "SNSに消えるはずだった時間",
            "「溶けた時間」が",
            "人生の時間に変わる",
            "積み上がった時間が何日分かまでホームに",
            "lime",
        ),
        _copy_spec(
            "禁止しないアプリ制限",
            "SNSをブロックしない",
            "開く前にひと呼吸",
            "反射で開く瞬間にだけ短いブレーキ",
            "dark",
        ),
        _copy_spec(
            "今日の記録",
            "開こうとした15回のうち",
            "12回はやめられた",
            "どのアプリを何回やめたか まで残る",
            "dark",
        ),
        _copy_spec(
            "夜だけ強化",
            "就寝中は自動で",
            "完全ブロック",
            "夜ふかしスクロールを就寝・起床の時刻で断つ",
            "lime",
        ),
        _copy_spec(
            "ロック画面の目標",
            "SNSを開くたびに",
            "目標を確認",
            "ロック画面に目標と開くのをやめた回数を表示",
            "dark",
        ),
        _copy_spec(
            "集中タイマーで完全ブロック",
            "集中したい時間だけ",
            "選んだアプリを止める",
            "30分から解除するまで 曜日と時間帯の予約も",
            "dark",
        ),
        _copy_spec(
            "理由を選ぶ",
            "何のために開く？",
            "理由を決めてから使う",
            "目的を言葉にして反射で開くのを止める",
            "lime",
        ),
        _copy_spec(
            "見たあとの本音",
            "SNSを見たあと",
            "本音を一つ選ぶだけ",
            "5つの気持ちから選ぶ 次に開く前の材料になる",
            "dark",
        ),
        _copy_spec(
            "白黒フィルタ連携",
            "色を消して",
            "SNSをつまらなくする",
            "SNSを開くと自動で白黒に サイドボタン3回の手動切替も",
            "dark",
        ),
    ),
    "en-US": (
        _copy_spec(
            "DOPAMINE DETOX, COUNTED IN HOURS",
            "Hours you would have lost to scrolling",
            "are yours again",
            "See how many days it adds up to, right on the home screen.",
            "lime",
        ),
        _copy_spec(
            "NOT ANOTHER APP BLOCKER",
            "Don’t block social media",
            "Pause before you open",
            "A short break interrupts the reflex. You still choose.",
            "dark",
        ),
        _copy_spec(
            "TODAY'S RECORD",
            "Reached for it 15 times",
            "stopped 12 of them",
            "Which app, and how many times. It all stays.",
            "dark",
        ),
        _copy_spec(
            "STRONGER AT NIGHT",
            "Your bedtime hours",
            "block themselves",
            "Late-night scrolling stops at the bedtime and wake times you set",
            "lime",
        ),
        _copy_spec(
            "LOCK SCREEN GOALS",
            "Your goals, every time",
            "you reach for social media",
            "Your goals and skipped opens sit on the lock screen",
            "dark",
        ),
        _copy_spec(
            "BLOCK ON YOUR SCHEDULE",
            "Pick the hours you need to focus",
            "and those apps stay shut",
            "From 30 minutes to until you lift it, plus weekly time slots",
            "dark",
        ),
        _copy_spec(
            "CHOOSE A REASON",
            "Know why you're opening",
            "then decide to use it",
            "Put the purpose into words and the reflex loses its grip",
            "lime",
        ),
        _copy_spec(
            "HONEST CHECK-IN",
            "After you scroll",
            "pick one honest feeling",
            "Five moods to choose from. It shapes your next decision.",
            "dark",
        ),
        _copy_spec(
            "GRAYSCALE SHORTCUT",
            "Strip the color",
            "and social media gets boring",
            "Goes gray the moment you open social media. Or triple-click the side button.",
            "dark",
        ),
    ),
    "ko": (
        _copy_spec(
            "SNS에 뺏기지 않은 시간",
            "녹아 없어질 뻔한 시간이",
            "내 인생의 시간으로 돌아와요",
            "쌓인 시간이 며칠치인지까지 홈에서 봐요",
            "lime",
        ),
        _copy_spec(
            "차단이 아니라 브레이크",
            "SNS를 막지 않아요",
            "열기 전에 숨 고르기",
            "반사적으로 여는 순간에만 잠깐 브레이크를 걸어요",
            "dark",
        ),
        _copy_spec(
            "오늘의 기록",
            "열려고 한 15번 중",
            "12번은 참았어요",
            "어떤 앱을 몇 번 참았는지까지 남아요",
            "dark",
        ),
        _copy_spec(
            "밤에만 강하게",
            "잠든 사이엔 자동으로",
            "완전 차단",
            "늦은 밤 스크롤을 취침 기상 시각으로 끊어요",
            "lime",
        ),
        _copy_spec(
            "잠금 화면 목표",
            "SNS를 열 때마다",
            "목표를 확인해요",
            "잠금 화면에 목표와 열지 않은 횟수가 보여요",
            "dark",
        ),
        _copy_spec(
            "공부·업무 시간 완전 차단",
            "집중할 시간만 골라서",
            "앱을 멈춰요",
            "30분부터 해제할 때까지 요일과 시간대 예약도 돼요",
            "dark",
        ),
        _copy_spec(
            "이유 선택",
            "왜 여는지 먼저 확인",
            "이유를 정하고 써요",
            "목적을 말로 정하면 무심코 여는 손이 멈춰요",
            "lime",
        ),
        _copy_spec(
            "본 뒤의 솔직한 기분",
            "SNS를 본 뒤",
            "솔직한 기분 하나만 골라요",
            "다섯 가지 기분에서 하나를 고르면 다음에 열기 전 판단 재료가 돼요",
            "dark",
        ),
        _copy_spec(
            "흑백 필터 연동",
            "색을 없애면",
            "SNS가 시시해져요",
            "SNS를 열면 자동으로 흑백 측면 버튼 세 번으로 직접 전환도 돼요",
            "dark",
        ),
    ),
}

COPY_SPECS = COPY[LOCALE]


@dataclass(frozen=True)
class PreparedDevice:
    image: Image.Image
    outer_width: int
    outer_height: int
    bezel: int
    outer_radius: int
    screen_width: int
    screen_height: int
    screen_radius: int


def load_legacy() -> ModuleType:
    if not LEGACY_PATH.is_file():
        raise FileNotFoundError(f"Legacy generator not found: {LEGACY_PATH}")
    spec = importlib.util.spec_from_file_location("dopabreak_legacy_screenshots", LEGACY_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load legacy generator: {LEGACY_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


LEGACY = load_legacy()


@dataclass(frozen=True)
class FontFace:
    path: Path
    index: int
    requested_face: str
    fallback_used: bool


FONT_CANDIDATES: dict[str, dict[str, tuple[tuple[Path, int, str], ...]]] = {
    "ja": {
        "regular": (
            (Path("/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"), 0, "Hiragino Sans W4"),
            (Path("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"), 0, "Hiragino Sans W3"),
        ),
        "bold": (
            (Path("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"), 0, "Hiragino Sans W8"),
            (Path("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"), 0, "Hiragino Sans W6"),
        ),
    },
    "en-US": {
        "regular": (
            (Path("/System/Library/Fonts/SFNS.ttf"), 0, "SFNS Regular"),
            (Path("/System/Library/Fonts/Helvetica.ttc"), 0, "Helvetica Regular"),
        ),
        "bold": (
            (Path("/System/Library/Fonts/SFNS.ttf"), 0, "SFNS Bold"),
            (Path("/System/Library/Fonts/Helvetica.ttc"), 1, "Helvetica Bold"),
        ),
    },
    "ko": {
        "regular": (
            (Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"), 0, "Apple SD Gothic Neo Regular"),
            (Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"), 2, "Apple SD Gothic Neo Medium"),
        ),
        "bold": (
            (Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"), 6, "Apple SD Gothic Neo Bold"),
            (Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"), 4, "Apple SD Gothic Neo SemiBold"),
        ),
    },
}

LOCK_DATES = {
    "ja": "8月20日 木曜日",
    "en-US": "Thursday, August 20",
    "ko": "8월 20일 목요일",
}

LOCK_GOALS = {
    "ja": (
        "英語で商談できる自分になる",
        "朝のランニングを続ける",
        "読書を30分する",
    ),
    "en-US": (
        "Hold my own in English meetings",
        "Keep up my morning run",
        "Read for 30 minutes",
    ),
    "ko": (
        "영어로 상담할 수 있는 나 되기",
        "아침 러닝 계속하기",
        "30분 독서하기",
    ),
}

WIDGET_CATALOG_LOCALES = {"ja": "ja", "en-US": "en", "ko": "ko"}

# Panel 10 home-screen mock. Tiles reuse the brand colours and glyph meanings of
# ios/DopaBreak/AppIconView.swift catalogTile so the grid still reads as "those
# apps" once the whole screen is converted to grayscale.
HOME_TILE_SIZE = 196
HOME_TILE_RADIUS = round(HOME_TILE_SIZE * 0.225)
HOME_COLUMN_CENTERS = (258, 526, 794, 1062)
HOME_ROW_TOPS = (330, 640, 950, 1260)
HOME_LABEL_GAP = 14
HOME_LABEL_SIZE = 34
HOME_LABEL_FILL = (235, 237, 239)
HOME_SEARCH_PILL_BOX = (495, 2434, 825, 2506)
HOME_DOCK_BOX = (40, 2528, 1280, 2772)
HOME_DOCK_RADIUS = 80
HOME_DOCK_TILE_TOP = 2552
HOME_INDICATOR_BOX = (500, 2784, 820, 2800)

HOME_SNS_TILES = (
    ("instagram", "Instagram"),
    ("x", "X"),
    ("tiktok", "TikTok"),
    ("youtube", "YouTube"),
    ("facebook", "Facebook"),
    ("threads", "Threads"),
    ("line", "LINE"),
    ("safari", "Safari"),
)
HOME_GENERIC_TILES = (
    "photos",
    "notes",
    "calendar",
    "weather",
    "maps",
    "music",
    "mail",
    "settings",
)
HOME_GENERIC_LABELS = {
    "ja": ("写真", "メモ", "カレンダー", "天気", "マップ", "ミュージック", "メール", "設定"),
    "en-US": (
        "Photos",
        "Notes",
        "Calendar",
        "Weather",
        "Maps",
        "Music",
        "Mail",
        "Settings",
    ),
    "ko": ("사진", "메모", "캘린더", "날씨", "지도", "음악", "메일", "설정"),
}
HOME_DOCK_TILES = ("instagram", "tiktok", "youtube", "line")
HOME_SEARCH_LABELS = {"ja": "検索", "en-US": "Search", "ko": "검색"}
HOME_TILE_BACKGROUNDS = {
    "x": (0, 0, 0),
    "tiktok": (0, 0, 0),
    "threads": (0, 0, 0),
    "youtube": (255, 0, 51),
    "facebook": (24, 119, 242),
    "line": (6, 199, 85),
    "photos": (250, 250, 252),
    "notes": (252, 252, 250),
    "calendar": (255, 255, 255),
    "weather": (64, 156, 255),
    "maps": (232, 240, 226),
    "music": (250, 45, 85),
    "mail": (0, 122, 255),
    "settings": (142, 142, 147),
}
HOME_INSTAGRAM_STOPS = ((249, 206, 52), (238, 42, 123), (98, 40, 215))
HOME_SAFARI_STOPS = ((47, 180, 255), (10, 132, 255))
HOME_GLYPH_WHITE = (255, 255, 255, 255)


@lru_cache(maxsize=None)
def resolve_font_face(locale: str, bold: bool) -> FontFace:
    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported font locale: {locale}")
    weight = "bold" if bold else "regular"
    candidates = FONT_CANDIDATES[locale][weight]
    failures = []
    for candidate_index, (path, face_index, requested_face) in enumerate(candidates):
        if not path.is_file():
            failures.append(f"missing {path}")
            continue
        try:
            ImageFont.truetype(str(path), size=16, index=face_index)
        except OSError as error:
            failures.append(f"unreadable {path} index={face_index}: {error}")
            continue
        return FontFace(
            path=path,
            index=face_index,
            requested_face=requested_face,
            fallback_used=candidate_index > 0,
        )
    raise FileNotFoundError(
        f"No usable {locale} {weight} font. " + "; ".join(failures)
    )


def _load_font(
    locale: str,
    size: int,
    *,
    bold: bool,
    sf_weight: int | None = None,
) -> ImageFont.FreeTypeFont:
    face = resolve_font_face(locale, bold)
    selected_font = ImageFont.truetype(str(face.path), size=size, index=face.index)
    if face.path.name == "SFNS.ttf":
        requested_weight = sf_weight if sf_weight is not None else (700 if bold else 400)
        try:
            selected_font.set_variation_by_axes(
                [100, min(96, max(17, size)), 400, min(1000, max(1, requested_weight))]
            )
        except (AttributeError, OSError, ValueError):
            # SFNS remains the selected system font on Pillow builds that do not
            # expose variable-font axes; the path is still reported below.
            pass
    return selected_font


def font(locale: str, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Return the approved locale-specific face without glyph image scaling."""
    return _load_font(locale, size, bold=bold)


def font_manifest(locale: str) -> dict[str, dict[str, Any]]:
    manifest: dict[str, dict[str, Any]] = {}
    for bold, weight in ((False, "regular"), (True, "bold")):
        face = resolve_font_face(locale, bold)
        loaded = font(locale, 40, bold)
        manifest[weight] = {
            "path": str(face.path),
            "face_index": face.index,
            "requested_face": face.requested_face,
            "requested_weight": 700 if bold else 400,
            "loaded_family": loaded.getname()[0],
            "loaded_style": loaded.getname()[1],
            "fallback_used": face.fallback_used,
        }
    return manifest


@lru_cache(maxsize=None)
def live_activity_copy(locale: str) -> dict[str, str]:
    if not WIDGET_LOCALIZABLE_PATH.is_file():
        raise FileNotFoundError(WIDGET_LOCALIZABLE_PATH)
    catalog = json.loads(WIDGET_LOCALIZABLE_PATH.read_text(encoding="utf-8"))
    catalog_locale = WIDGET_CATALOG_LOCALES[locale]

    def value(key: str) -> str:
        try:
            return catalog["strings"][key]["localizations"][catalog_locale]["stringUnit"]["value"]
        except KeyError as error:
            raise KeyError(f"Missing {key}/{catalog_locale} in {WIDGET_LOCALIZABLE_PATH}") from error

    def with_count(template: str, count: int) -> str:
        if template.count("%lld") != 1:
            raise ValueError(f"Expected one %lld placeholder: {template}")
        return template.replace("%lld", str(count))

    eyebrow_source = value("live_activity.goal.eyebrow")
    return {
        "eyebrow_source": eyebrow_source,
        "eyebrow_rendered": eyebrow_source.upper(),
        "cancelled": with_count(value("live_activity.summary.cancelled"), 12),
        "attempted": with_count(value("live_activity.summary.attempted"), 15),
    }


def validate_legacy_copy_reuse(locale: str) -> None:
    if locale not in ("en-US", "ko"):
        return
    days = LEGACY.PANEL_DAYS[locale][DEVICE]
    for panel_id in (1, 2, 3, 4, 6):
        legacy = LEGACY.COPY[locale][panel_id - 1]
        expected = (
            legacy["eyebrow"],
            tuple(line.format(days=days) for line in legacy["headline"]),
            legacy["sub"],
        )
        actual_spec = COPY[locale][PANEL_IDS.index(panel_id)]
        actual = (actual_spec.eyebrow, actual_spec.headline, actual_spec.sub)
        if actual != expected:
            raise ValueError(
                f"Panel {panel_id:02d} {locale} copy differs from legacy: "
                f"expected={expected!r}, actual={actual!r}"
            )


def configure_locale(locale: str) -> None:
    global LOCALE
    global SCREENSHOT_ROOT, CONTACT_SHEET_PATH, SLOTS_PATH, RAW_CORE_ROOT
    global SOURCE_PATHS, SOURCE_LABELS
    global SCREEN_CHARACTER_COUNTS, VISIBLE_SCREEN_CHARACTER_COUNTS, COPY_SPECS

    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported locale: {locale}")

    LOCALE = locale
    SCREENSHOT_ROOT = OUTPUT_ROOT / locale / DEVICE
    CONTACT_SHEET_PATH = OUTPUT_ROOT / f"contact-sheet-{locale}.png"
    SLOTS_PATH = OUTPUT_ROOT / f"slots-{locale}.json"
    RAW_CORE_ROOT = ROOT / "output" / "app-store-screenshots" / "raw-core" / locale
    SOURCE_PATHS = (
        RAW_CORE_ROOT / "home.png",
        RAW_CORE_ROOT / "breath.png",
        RAW_CORE_ROOT / "stats.png",
        RAW_CORE_ROOT / "nightmode.png",
        None,
        RAW_CORE_ROOT / "deepfocus.png",
        RAW_CORE_ROOT / "intent.png",
        RAW_CORE_ROOT / "reflection.png",
        None,
    )
    SOURCE_LABELS = source_labels(SOURCE_PATHS, locale)
    SCREEN_CHARACTER_COUNTS = (
        1,
        1,
        5,
        0,
        0,
        0,
        0,
        1,
        0,
    )
    VISIBLE_SCREEN_CHARACTER_COUNTS = (1, 1, None, 0, 0, 0, 0, 1, 0)
    COPY_SPECS = COPY[locale]

    validate_legacy_copy_reuse(locale)
    font_manifest(locale)
    live_activity_copy(locale)


def _scaled_box(box: tuple[int, int, int, int], scale: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = box
    return left * scale, top * scale, right * scale - 1, bottom * scale - 1


def rounded_mask(
    size: tuple[int, int],
    box: tuple[int, int, int, int],
    radius: int,
    *,
    aa_scale: int = AA_SCALE,
) -> Image.Image:
    width, height = size
    mask = Image.new("L", (width * aa_scale, height * aa_scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        _scaled_box(box, aa_scale),
        radius=max(0, radius * aa_scale),
        fill=255,
    )
    return mask.resize(size, Image.Resampling.LANCZOS)


def polygon_mask(points: Sequence[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", (CANVAS_WIDTH * AA_SCALE, CANVAS_HEIGHT * AA_SCALE), 0)
    ImageDraw.Draw(mask).polygon(
        [(x * AA_SCALE, y * AA_SCALE) for x, y in points],
        fill=255,
    )
    return mask.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)


def ellipse_mask(box: tuple[int, int, int, int]) -> Image.Image:
    mask = Image.new("L", (CANVAS_WIDTH * AA_SCALE, CANVAS_HEIGHT * AA_SCALE), 0)
    ImageDraw.Draw(mask).ellipse(_scaled_box(box, AA_SCALE), fill=255)
    return mask.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)


def dark_background() -> Image.Image:
    return LEGACY.gradient(CANVAS_SIZE, COLORS["raised"], COLORS["background"])


def paste_lime_gradient(
    canvas: Image.Image,
    mask: Image.Image,
    top_y: int,
    bottom_y: int,
) -> None:
    if not (0 <= top_y < bottom_y <= CANVAS_HEIGHT):
        raise ValueError((top_y, bottom_y))
    region_height = bottom_y - top_y
    gradient = LEGACY.gradient(
        (CANVAS_WIDTH, region_height),
        COLORS["lime"],
        COLORS["lime_deep"],
    )
    canvas.paste(gradient, (0, top_y), mask.crop((0, top_y, CANVAS_WIDTH, bottom_y)))


def draw_lime_polygon(canvas: Image.Image, points: Sequence[tuple[int, int]]) -> Image.Image:
    ys = [point[1] for point in points]
    mask = polygon_mask(points)
    paste_lime_gradient(canvas, mask, max(0, min(ys)), min(CANVAS_HEIGHT, max(ys)))
    return mask


def draw_lime_circle(canvas: Image.Image, center: tuple[int, int], radius: int) -> None:
    cx, cy = center
    box = (cx - radius, cy - radius, cx + radius, cy + radius)
    paste_lime_gradient(canvas, ellipse_mask(box), box[1], box[3])


def sf_font(size: int, weight: int = 400) -> ImageFont.FreeTypeFont:
    return _load_font(
        "en-US",
        size,
        bold=weight >= 600,
        sf_weight=weight,
    )


def text_image_with_font(
    text: str,
    selected_font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
) -> Image.Image:
    bbox = selected_font.getbbox(text)
    width = max(1, bbox[2] - bbox[0])
    height = max(1, bbox[3] - bbox[1])
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(result).text(
        (-bbox[0], -bbox[1]),
        text,
        font=selected_font,
        fill=(*fill, 255),
    )
    return result


def sf_text_fitted_to_width(
    text: str,
    target_width: int,
    *,
    weight: int,
    maximum_size: int,
    fill: tuple[int, int, int],
) -> tuple[Image.Image, int]:
    low = 1
    high = maximum_size
    best_size = 1
    best_image = text_image_with_font(text, sf_font(1, weight), fill)
    while low <= high:
        candidate_size = (low + high) // 2
        candidate = text_image_with_font(text, sf_font(candidate_size, weight), fill)
        if candidate.width <= target_width:
            best_size = candidate_size
            best_image = candidate
            low = candidate_size + 1
        else:
            high = candidate_size - 1
    return best_image, best_size


def paste_centered_image(canvas: Image.Image, image: Image.Image, y: int) -> tuple[int, int, int, int]:
    x = round((canvas.width - image.width) / 2)
    canvas.paste(image, (x, y), image.getchannel("A"))
    return x, y, x + image.width, y + image.height


def lock_wallpaper(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = LEGACY.gradient(size, (18, 21, 25), (5, 7, 9)).convert("RGBA")

    atmosphere = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(atmosphere, "RGBA")
    draw.ellipse(
        (-round(width * 0.42), round(height * 0.04), round(width * 0.78), round(height * 0.54)),
        fill=(45, 60, 67, 105),
    )
    draw.ellipse(
        (round(width * 0.36), round(height * 0.17), round(width * 1.35), round(height * 0.73)),
        fill=(41, 31, 52, 85),
    )
    draw.ellipse(
        (-round(width * 0.08), round(height * 0.54), round(width * 1.08), round(height * 1.10)),
        fill=(22, 49, 42, 70),
    )
    atmosphere = atmosphere.filter(ImageFilter.GaussianBlur(round(width * 0.14)))
    image = Image.alpha_composite(image, atmosphere)

    sweep = Image.new("RGBA", size, (0, 0, 0, 0))
    sweep_draw = ImageDraw.Draw(sweep, "RGBA")
    sweep_draw.polygon(
        (
            (-round(width * 0.30), round(height * 0.42)),
            (round(width * 0.92), round(height * 0.18)),
            (round(width * 1.20), round(height * 0.33)),
            (-round(width * 0.15), round(height * 0.57)),
        ),
        fill=(255, 255, 255, 12),
    )
    sweep = sweep.filter(ImageFilter.GaussianBlur(round(width * 0.09)))
    return Image.alpha_composite(image, sweep).convert("RGB")


def tracked_text_image(
    text: str,
    selected_font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    tracking: int,
) -> Image.Image:
    glyphs = [text_image_with_font(character, selected_font, fill) for character in text]
    width = sum(glyph.width for glyph in glyphs) + tracking * max(0, len(glyphs) - 1)
    height = max((glyph.height for glyph in glyphs), default=1)
    image = Image.new("RGBA", (max(1, width), height), (0, 0, 0, 0))
    x = 0
    for glyph in glyphs:
        y = round((height - glyph.height) / 2)
        image.paste(glyph, (x, y), glyph.getchannel("A"))
        x += glyph.width + tracking
    return image


def draw_live_activity_card(canvas: Image.Image, locale: str) -> dict[str, Any]:
    """Draw the lock-screen Live Activity from liveActivityView()."""
    localized_copy = live_activity_copy(locale)
    left, top, right, bottom = LOCK_ACTIVITY_CARD_BOX
    radius = LOCK_ACTIVITY_CARD_RADIUS
    padding = lock_pt_to_px(16)
    vstack_spacing = lock_pt_to_px(10)
    goal_spacing = lock_pt_to_px(5)
    goal_hstack_spacing = lock_pt_to_px(8)
    summary_spacing = lock_pt_to_px(14)
    accent_width = lock_pt_to_px(3)
    goal_bar_width = lock_pt_to_px(10)
    goal_bar_height = lock_pt_to_px(2)

    card_mask = rounded_mask(CANVAS_SIZE, LOCK_ACTIVITY_CARD_BOX, radius)
    canvas.paste(
        LOCK_THEME_E1["card"],
        LOCK_ACTIVITY_CARD_BOX,
        card_mask.crop(LOCK_ACTIVITY_CARD_BOX),
    )

    accent_mask = Image.new("L", CANVAS_SIZE, 0)
    ImageDraw.Draw(accent_mask).rectangle(
        (left, top, left + accent_width - 1, bottom - 1),
        fill=255,
    )
    accent_mask = ImageChops.multiply(accent_mask, card_mask)
    canvas.paste(
        LOCK_THEME_E1["accent"],
        (0, 0, CANVAS_WIDTH, CANVAS_HEIGHT),
        accent_mask,
    )

    content_left = left + padding
    content_right = right - padding
    content_y = top + padding

    eyebrow = tracked_text_image(
        localized_copy["eyebrow_rendered"],
        font(locale, lock_pt_to_px(10), True),
        LOCK_THEME_E1["secondary_text"],
        tracking=lock_pt_to_px(1.4),
    )
    canvas.paste(eyebrow, (content_left, content_y), eyebrow.getchannel("A"))
    content_y += eyebrow.height + vstack_spacing

    goal_font = font(locale, lock_pt_to_px(15), True)
    goal_titles = LOCK_GOALS[locale]
    goal_boxes = []
    for index, title in enumerate(goal_titles):
        title_image = text_image_with_font(title, goal_font, LOCK_THEME_E1["primary_text"])
        title_x = content_left + goal_bar_width + goal_hstack_spacing
        bar_y = content_y + round((title_image.height - goal_bar_height) / 2)
        ImageDraw.Draw(canvas).rectangle(
            (
                content_left,
                bar_y,
                content_left + goal_bar_width - 1,
                bar_y + goal_bar_height - 1,
            ),
            fill=LOCK_THEME_E1["accent"],
        )
        canvas.paste(title_image, (title_x, content_y), title_image.getchannel("A"))
        goal_boxes.append(
            [
                content_left,
                content_y,
                title_x + title_image.width,
                content_y + title_image.height,
            ]
        )
        content_y += title_image.height
        if index < len(goal_titles) - 1:
            content_y += goal_spacing

    content_y += vstack_spacing
    divider_y = content_y
    ImageDraw.Draw(canvas, "RGBA").line(
        (content_left, divider_y, content_right - 1, divider_y),
        fill=(*LOCK_THEME_E1["secondary_text"], round(255 * 0.25)),
        width=1,
    )
    content_y += 1 + vstack_spacing

    summary_font = font(locale, lock_pt_to_px(12), True)
    cancelled = text_image_with_font(
        localized_copy["cancelled"],
        summary_font,
        LOCK_THEME_E1["accent"],
    )
    attempted = text_image_with_font(
        localized_copy["attempted"],
        summary_font,
        LOCK_THEME_E1["secondary_text"],
    )
    attempted_x = content_left + cancelled.width + summary_spacing
    canvas.paste(cancelled, (content_left, content_y), cancelled.getchannel("A"))
    canvas.paste(attempted, (attempted_x, content_y), attempted.getchannel("A"))
    summary_bottom = content_y + max(cancelled.height, attempted.height)

    if attempted_x + attempted.width > content_right:
        raise ValueError("Live Activity summary exceeds the 16pt horizontal padding")
    if summary_bottom + padding > bottom:
        raise ValueError("Live Activity content exceeds the 16pt vertical padding")

    return {
        "locale": locale,
        "copy": {
            **localized_copy,
            "goals": list(goal_titles),
        },
        "source_box": list(LOCK_ACTIVITY_CARD_BOX),
        "corner_radius_px": radius,
        "horizontal_margin_px": LOCK_ACTIVITY_CARD_MARGIN,
        "padding_px": padding,
        "vstack_spacing_px": vstack_spacing,
        "goal_spacing_px": goal_spacing,
        "accent_bar_width_px": accent_width,
        "goal_bar_size_px": [goal_bar_width, goal_bar_height],
        "divider_height_px": 1,
        "goal_boxes": goal_boxes,
        "summary_box": [content_left, content_y, attempted_x + attempted.width, summary_bottom],
    }


def draw_lock_status_icons(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")

    # Centered lock. The left status area intentionally remains empty.
    draw.arc((635, 164, 685, 222), start=180, end=360, fill=(255, 255, 255, 235), width=6)
    draw.rounded_rectangle((630, 197, 690, 250), radius=12, fill=(255, 255, 255, 235))
    draw.ellipse((657, 215, 663, 221), fill=(11, 13, 15, 220))
    draw.rounded_rectangle((658, 220, 662, 233), radius=2, fill=(11, 13, 15, 220))

    # Wi-Fi and battery indicators on the right.
    draw.arc((1054, 49, 1124, 111), start=215, end=325, fill=(255, 255, 255, 245), width=6)
    draw.arc((1067, 65, 1111, 105), start=215, end=325, fill=(255, 255, 255, 245), width=6)
    draw.ellipse((1085, 91, 1095, 101), fill=(255, 255, 255, 245))
    draw.rounded_rectangle(
        (1152, 59, 1234, 102),
        radius=10,
        outline=(255, 255, 255, 245),
        width=5,
    )
    draw.rounded_rectangle((1238, 72, 1245, 90), radius=3, fill=(255, 255, 255, 210))
    draw.rounded_rectangle((1159, 66, 1218, 95), radius=6, fill=(255, 255, 255, 245))


def draw_lock_bottom_controls(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    button_radius = 72
    button_y = 2600
    for button_x in (170, 1150):
        draw.ellipse(
            (
                button_x - button_radius,
                button_y - button_radius,
                button_x + button_radius,
                button_y + button_radius,
            ),
            fill=(3, 5, 7, 158),
            outline=(255, 255, 255, 34),
            width=3,
        )

    # Flashlight.
    draw.polygon(((142, 2561), (198, 2561), (187, 2595), (153, 2595)), fill=(255, 255, 255, 245))
    draw.rounded_rectangle((156, 2588, 184, 2640), radius=9, fill=(255, 255, 255, 245))
    draw.rounded_rectangle((161, 2603, 179, 2632), radius=6, fill=(20, 22, 24, 180))

    # Camera.
    draw.rounded_rectangle((1105, 2572, 1195, 2632), radius=15, fill=(255, 255, 255, 245))
    draw.polygon(((1126, 2572), (1138, 2558), (1162, 2558), (1174, 2572)), fill=(255, 255, 255, 245))
    draw.ellipse((1126, 2580, 1174, 2628), fill=(16, 18, 21, 255))
    draw.ellipse((1135, 2589, 1165, 2619), outline=(255, 255, 255, 230), width=5)

    draw.rounded_rectangle((500, 2784, 820, 2800), radius=8, fill=(255, 255, 255, 245))


def lock_clock_image() -> Image.Image:
    clock_target_width = round(CANVAS_WIDTH * 0.55)
    image, _ = sf_text_fitted_to_width(
        "9:41",
        clock_target_width,
        weight=620,
        maximum_size=430,
        fill=(248, 249, 247),
    )
    return image


def lock_clock_source_box() -> tuple[int, int, int, int]:
    image = lock_clock_image()
    left = round((CANVAS_WIDTH - image.width) / 2)
    top = 350
    return left, top, left + image.width, top + image.height


def mock_lock(size: tuple[int, int], locale: str) -> Image.Image:
    if size != CANVAS_SIZE:
        raise ValueError(f"The v2 lock mock is fixed to {CANVAS_SIZE}, got {size}")
    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported lock mock locale: {locale}")

    image = lock_wallpaper(size)
    draw_lock_status_icons(image)

    date_image = text_image_with_font(
        LOCK_DATES[locale],
        font(locale, 48, False),
        (224, 227, 229),
    )
    paste_centered_image(image, date_image, 278)

    paste_centered_image(image, lock_clock_image(), lock_clock_source_box()[1])

    draw_live_activity_card(image, locale)

    draw_lock_bottom_controls(image)
    return image


def home_points(points: Sequence[tuple[float, float]], scale: int) -> list[tuple[int, int]]:
    return [(round(x * scale), round(y * scale)) for x, y in points]


def home_box(values: Sequence[float], scale: int) -> tuple[int, ...]:
    return tuple(round(value * scale) for value in values)


def glyph_instagram(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rounded_rectangle(
        home_box((46, 46, 150, 150), scale),
        radius=round(30 * scale),
        outline=HOME_GLYPH_WHITE,
        width=round(12 * scale),
    )
    draw.ellipse(
        home_box((72, 72, 124, 124), scale),
        outline=HOME_GLYPH_WHITE,
        width=round(12 * scale),
    )
    draw.ellipse(home_box((123, 57, 141, 75), scale), fill=HOME_GLYPH_WHITE)


def glyph_x(draw: ImageDraw.ImageDraw, scale: int) -> None:
    width = round(22 * scale)
    draw.line(home_points(((56, 56), (140, 140)), scale), fill=HOME_GLYPH_WHITE, width=width)
    draw.line(home_points(((140, 56), (56, 140)), scale), fill=HOME_GLYPH_WHITE, width=width)


def glyph_music_note(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.ellipse(home_box((64, 108, 118, 152), scale), fill=HOME_GLYPH_WHITE)
    draw.rounded_rectangle(
        home_box((104, 46, 120, 134), scale),
        radius=round(8 * scale),
        fill=HOME_GLYPH_WHITE,
    )
    draw.polygon(
        home_points(((118, 46), (152, 62), (152, 90), (118, 74)), scale),
        fill=HOME_GLYPH_WHITE,
    )


def glyph_youtube(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rounded_rectangle(
        home_box((34, 56, 162, 140), scale),
        radius=round(28 * scale),
        fill=HOME_GLYPH_WHITE,
    )
    draw.polygon(
        home_points(((84, 76), (84, 120), (122, 98)), scale),
        fill=(*HOME_TILE_BACKGROUNDS["youtube"], 255),
    )


def glyph_facebook(draw: ImageDraw.ImageDraw, scale: int) -> None:
    behind = (255, 255, 255, 175)
    draw.ellipse(home_box((112, 56, 150, 94), scale), fill=behind)
    draw.pieslice(home_box((100, 94, 168, 156), scale), start=180, end=360, fill=behind)
    draw.ellipse(home_box((54, 50, 100, 96), scale), fill=HOME_GLYPH_WHITE)
    draw.pieslice(
        home_box((34, 98, 120, 162), scale),
        start=180,
        end=360,
        fill=HOME_GLYPH_WHITE,
    )


def glyph_line(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rounded_rectangle(
        home_box((32, 42, 164, 134), scale),
        radius=round(34 * scale),
        fill=HOME_GLYPH_WHITE,
    )
    draw.polygon(
        home_points(((68, 124), (112, 124), (72, 166)), scale),
        fill=HOME_GLYPH_WHITE,
    )


def glyph_safari(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.ellipse(
        home_box((32, 32, 164, 164), scale),
        outline=HOME_GLYPH_WHITE,
        width=round(11 * scale),
    )
    draw.polygon(
        home_points(((138, 58), (110, 110), (58, 138), (86, 86)), scale),
        fill=HOME_GLYPH_WHITE,
    )


def glyph_photos(draw: ImageDraw.ImageDraw, scale: int) -> None:
    petals = (
        (98, 52, (255, 204, 0)),
        (140, 82, (255, 59, 48)),
        (124, 132, (175, 82, 222)),
        (72, 132, (0, 122, 255)),
        (56, 82, (52, 199, 89)),
    )
    for center_x, center_y, color in petals:
        draw.ellipse(
            home_box(
                (center_x - 31, center_y - 31, center_x + 31, center_y + 31),
                scale,
            ),
            fill=(*color, 200),
        )


def glyph_notes(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rectangle(home_box((0, 0, 196, 52), scale), fill=(255, 204, 0, 255))
    for index in range(3):
        top = 86 + index * 28
        draw.rounded_rectangle(
            home_box((40, top, 156 - index * 30, top + 12), scale),
            radius=round(6 * scale),
            fill=(158, 158, 163, 255),
        )


def glyph_calendar(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rectangle(home_box((0, 0, 196, 48), scale), fill=(255, 59, 48, 255))
    for row in range(3):
        for column in range(4):
            left = 30 + column * 38
            top = 78 + row * 32
            draw.ellipse(
                home_box((left, top, left + 16, top + 16), scale),
                fill=(172, 174, 180, 255),
            )


def glyph_weather(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.ellipse(home_box((50, 38, 118, 106), scale), fill=(255, 214, 10, 255))
    draw.ellipse(home_box((58, 100, 116, 150), scale), fill=HOME_GLYPH_WHITE)
    draw.ellipse(home_box((94, 84, 152, 142), scale), fill=HOME_GLYPH_WHITE)
    draw.rounded_rectangle(
        home_box((54, 118, 154, 150), scale),
        radius=round(16 * scale),
        fill=HOME_GLYPH_WHITE,
    )


def glyph_maps(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.polygon(
        home_points(((0, 40), (196, 8), (196, 54), (0, 86)), scale),
        fill=(118, 178, 240, 255),
    )
    draw.polygon(
        home_points(((0, 152), (88, 116), (196, 170), (196, 196), (0, 196)), scale),
        fill=(150, 200, 140, 255),
    )
    road = home_points(((52, 196), (70, 138), (124, 104), (196, 88)), scale)
    draw.line(road, fill=HOME_GLYPH_WHITE, width=round(22 * scale), joint="curve")
    draw.line(road, fill=(255, 190, 70, 255), width=round(9 * scale), joint="curve")


def glyph_mail(draw: ImageDraw.ImageDraw, scale: int) -> None:
    draw.rounded_rectangle(
        home_box((32, 58, 164, 142), scale),
        radius=round(16 * scale),
        fill=HOME_GLYPH_WHITE,
    )
    draw.line(
        home_points(((44, 72), (98, 116), (152, 72)), scale),
        fill=(*HOME_TILE_BACKGROUNDS["mail"], 255),
        width=round(11 * scale),
        joint="curve",
    )


def glyph_settings(draw: ImageDraw.ImageDraw, scale: int) -> None:
    for index in range(8):
        angle = math.radians(index * 45)
        center_x = 98 + math.cos(angle) * 62
        center_y = 98 + math.sin(angle) * 62
        draw.ellipse(
            home_box(
                (center_x - 15, center_y - 15, center_x + 15, center_y + 15),
                scale,
            ),
            fill=HOME_GLYPH_WHITE,
        )
    draw.ellipse(
        home_box((42, 42, 154, 154), scale),
        outline=HOME_GLYPH_WHITE,
        width=round(16 * scale),
    )


HOME_TILE_GLYPHS: dict[str, Callable[[ImageDraw.ImageDraw, int], None]] = {
    "instagram": glyph_instagram,
    "x": glyph_x,
    "tiktok": glyph_music_note,
    "youtube": glyph_youtube,
    "facebook": glyph_facebook,
    "line": glyph_line,
    "safari": glyph_safari,
    "photos": glyph_photos,
    "notes": glyph_notes,
    "calendar": glyph_calendar,
    "weather": glyph_weather,
    "maps": glyph_maps,
    "music": glyph_music_note,
    "mail": glyph_mail,
    "settings": glyph_settings,
}


def diagonal_gradient(
    size: tuple[int, int],
    stops: Sequence[tuple[int, int, int]],
) -> Image.Image:
    """Bottom-leading to top-trailing multi-stop ramp (Instagram tile)."""
    steps = 96
    last = len(stops) - 1
    pixels: list[tuple[int, int, int]] = []
    for y in range(steps):
        for x in range(steps):
            ratio = (x / (steps - 1) + (1 - y / (steps - 1))) / 2
            position = ratio * last
            index = min(last - 1, int(position))
            local = position - index
            start, end = stops[index], stops[index + 1]
            pixels.append(
                tuple(round(start[i] + (end[i] - start[i]) * local) for i in range(3))
            )
    ramp = Image.new("RGB", (steps, steps))
    ramp.putdata(pixels)
    return ramp.resize(size, Image.Resampling.BICUBIC)


def home_tile_background(kind: str, span: int) -> Image.Image:
    if kind == "instagram":
        return diagonal_gradient((span, span), HOME_INSTAGRAM_STOPS)
    if kind == "safari":
        return LEGACY.gradient((span, span), *HOME_SAFARI_STOPS)
    return Image.new("RGB", (span, span), HOME_TILE_BACKGROUNDS[kind])


@lru_cache(maxsize=None)
def home_app_tile(kind: str) -> Image.Image:
    """Supersampled iOS-style app tile with the AppIconView inner ring."""
    scale = AA_SCALE
    span = HOME_TILE_SIZE * scale
    tile = home_tile_background(kind, span).convert("RGB")
    if kind == "threads":
        glyph = text_image_with_font("@", sf_font(round(112 * scale), 600), (255, 255, 255))
        tile.paste(
            glyph,
            (round((span - glyph.width) / 2), round((span - glyph.height) / 2)),
            glyph.getchannel("A"),
        )
    else:
        HOME_TILE_GLYPHS[kind](ImageDraw.Draw(tile, "RGBA"), scale)
    ImageDraw.Draw(tile, "RGBA").rounded_rectangle(
        (scale, scale, span - 1 - scale, span - 1 - scale),
        radius=HOME_TILE_RADIUS * scale - scale,
        outline=(255, 255, 255, 40),
        width=2 * scale,
    )
    shape = Image.new("L", (span, span), 0)
    ImageDraw.Draw(shape).rounded_rectangle(
        (0, 0, span - 1, span - 1),
        radius=HOME_TILE_RADIUS * scale,
        fill=255,
    )
    tile = tile.convert("RGBA")
    tile.putalpha(shape)
    return tile.resize((HOME_TILE_SIZE, HOME_TILE_SIZE), Image.Resampling.LANCZOS)


def paste_home_tile(canvas: Image.Image, kind: str, center_x: int, top: int) -> None:
    tile = home_app_tile(kind)
    canvas.paste(tile, (center_x - HOME_TILE_SIZE // 2, top), tile.getchannel("A"))


def baseline_text_image(
    text: str,
    selected_font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
) -> Image.Image:
    """Render on a shared baseline so neighbouring app labels line up."""
    ascent, descent = selected_font.getmetrics()
    width = max(1, math.ceil(selected_font.getlength(text)))
    image = Image.new("RGBA", (width, ascent + descent), (0, 0, 0, 0))
    ImageDraw.Draw(image).text((0, 0), text, font=selected_font, fill=(*fill, 255))
    return image


def draw_home_status_bar(canvas: Image.Image) -> None:
    clock = text_image_with_font("9:41", sf_font(56, 600), (248, 249, 247))
    canvas.paste(clock, (150, 70), clock.getchannel("A"))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.arc((1054, 49, 1124, 111), start=215, end=325, fill=(255, 255, 255, 245), width=6)
    draw.arc((1067, 65, 1111, 105), start=215, end=325, fill=(255, 255, 255, 245), width=6)
    draw.ellipse((1085, 91, 1095, 101), fill=(255, 255, 255, 245))
    draw.rounded_rectangle(
        (1152, 59, 1234, 102),
        radius=10,
        outline=(255, 255, 255, 245),
        width=5,
    )
    draw.rounded_rectangle((1238, 72, 1245, 90), radius=3, fill=(255, 255, 255, 210))
    draw.rounded_rectangle((1159, 66, 1218, 95), radius=6, fill=(255, 255, 255, 245))


def draw_home_app_grid(canvas: Image.Image, locale: str) -> None:
    generic_labels = HOME_GENERIC_LABELS[locale]
    rows = (
        HOME_SNS_TILES[0:4],
        HOME_SNS_TILES[4:8],
        tuple(zip(HOME_GENERIC_TILES[0:4], generic_labels[0:4])),
        tuple(zip(HOME_GENERIC_TILES[4:8], generic_labels[4:8])),
    )
    label_font = font(locale, HOME_LABEL_SIZE, False)
    for top, row in zip(HOME_ROW_TOPS, rows):
        for center_x, (kind, label) in zip(HOME_COLUMN_CENTERS, row):
            paste_home_tile(canvas, kind, center_x, top)
            label_image = baseline_text_image(label, label_font, HOME_LABEL_FILL)
            canvas.paste(
                label_image,
                (
                    center_x - label_image.width // 2,
                    top + HOME_TILE_SIZE + HOME_LABEL_GAP,
                ),
                label_image.getchannel("A"),
            )


def paste_translucent_rounded_rect(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    color: tuple[int, int, int],
    alpha: int,
) -> None:
    mask = rounded_mask(canvas.size, box, radius)
    canvas.paste(color, (0, 0, canvas.width, canvas.height), mask.point(lambda v: v * alpha // 255))


def draw_home_search_pill(canvas: Image.Image, locale: str) -> None:
    left, top, right, bottom = HOME_SEARCH_PILL_BOX
    paste_translucent_rounded_rect(
        canvas,
        HOME_SEARCH_PILL_BOX,
        (bottom - top) // 2,
        (255, 255, 255),
        60,
    )
    label = baseline_text_image(
        HOME_SEARCH_LABELS[locale],
        font(locale, 30, False),
        (245, 246, 248),
    )
    glyph_span = 34
    gap = 14
    start_x = round((left + right) / 2 - (glyph_span + gap + label.width) / 2)
    center_y = (top + bottom) // 2
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.ellipse(
        (start_x, center_y - 17, start_x + 27, center_y + 10),
        outline=(245, 246, 248, 235),
        width=4,
    )
    draw.line(
        (start_x + 22, center_y + 5, start_x + 32, center_y + 15),
        fill=(245, 246, 248, 235),
        width=4,
    )
    canvas.paste(
        label,
        (start_x + glyph_span + gap, center_y - label.height // 2),
        label.getchannel("A"),
    )


def draw_home_dock(canvas: Image.Image) -> None:
    paste_translucent_rounded_rect(
        canvas,
        HOME_DOCK_BOX,
        HOME_DOCK_RADIUS,
        (255, 255, 255),
        45,
    )
    for center_x, kind in zip(HOME_COLUMN_CENTERS, HOME_DOCK_TILES):
        paste_home_tile(canvas, kind, center_x, HOME_DOCK_TILE_TOP)


def mock_home_grayscale(size: tuple[int, int], locale: str) -> Image.Image:
    """iOS home screen with the SNS grid, converted to grayscale as a whole."""
    if size != CANVAS_SIZE:
        raise ValueError(f"The v2 home mock is fixed to {CANVAS_SIZE}, got {size}")
    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported home mock locale: {locale}")

    image = lock_wallpaper(size)
    draw_home_status_bar(image)
    draw_home_app_grid(image, locale)
    draw_home_search_pill(image, locale)
    draw_home_dock(image)
    ImageDraw.Draw(image, "RGBA").rounded_rectangle(
        HOME_INDICATOR_BOX,
        radius=8,
        fill=(255, 255, 255, 245),
    )
    return ImageOps.grayscale(image).convert("RGB")


def tight_text_image(text: str, size: int, fill: tuple[int, int, int], *, bold: bool) -> Image.Image:
    selected_font = font(LOCALE, size, bold)
    bbox = selected_font.getbbox(text)
    width = max(1, bbox[2] - bbox[0])
    height = max(1, bbox[3] - bbox[1])
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(image).text(
        (-bbox[0], -bbox[1]),
        text,
        font=selected_font,
        fill=(*fill, 255),
    )
    return image


def paste_centered_text(
    canvas: Image.Image,
    text: str,
    y: int,
    size: int,
    fill: tuple[int, int, int],
    *,
    bold: bool,
    max_width: int | None = None,
) -> tuple[tuple[int, int, int, int], dict[str, Any]]:
    text_image = tight_text_image(text, size, fill, bold=bold)
    natural_width = text_image.width
    rendered_font_size = size
    if max_width is not None and text_image.width > max_width:
        rendered_font_size = max(1, math.floor(size * max_width / natural_width))
        text_image = tight_text_image(text, rendered_font_size, fill, bold=bold)
        # Font hinting can round the proportional estimate up by a pixel or two.
        # Re-render at the next native size instead of distorting glyphs.
        while text_image.width > max_width and rendered_font_size > 1:
            rendered_font_size -= 1
            text_image = tight_text_image(text, rendered_font_size, fill, bold=bold)
    x = round((CANVAS_WIDTH - text_image.width) / 2)
    canvas.paste(text_image, (x, y), text_image.getchannel("A"))
    box = (x, y, x + text_image.width, y + text_image.height)
    return box, {
        "text": text,
        "requested_font_size": size,
        "rendered_font_size": rendered_font_size,
        "natural_width": natural_width,
        "rendered_width": text_image.width,
        "max_width": max_width,
        "horizontal_scale_ratio": 1.0,
        "uniform_font_scale_ratio": round(rendered_font_size / size, 6),
    }


def paste_solid_rounded_rect(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int],
) -> None:
    mask = rounded_mask(canvas.size, box, radius)
    canvas.paste(fill, box, mask.crop(box))


def draw_copy_block(canvas: Image.Image, spec: CopySpec) -> dict[str, Any]:
    if spec.surface == "lime":
        pill_fill = COLORS["ink"]
        pill_text = COLORS["lime"]
        headline_fill = COLORS["ink"]
        sub_fill = COLORS["lime_sub"]
    else:
        pill_fill = COLORS["dark_pill"]
        pill_text = COLORS["lime"]
        headline_fill = COLORS["off_white"]
        sub_fill = COLORS["muted"]

    eyebrow_image = tight_text_image(spec.eyebrow, 40, pill_text, bold=True)
    pill_width = eyebrow_image.width + 68
    pill_height = eyebrow_image.height + 32
    pill_x = round((CANVAS_WIDTH - pill_width) / 2)
    pill_box = (pill_x, spec.eyebrow_y, pill_x + pill_width, spec.eyebrow_y + pill_height)
    paste_solid_rounded_rect(canvas, pill_box, pill_height // 2, pill_fill)
    eyebrow_x = round((CANVAS_WIDTH - eyebrow_image.width) / 2)
    eyebrow_text_y = spec.eyebrow_y + 16
    canvas.paste(eyebrow_image, (eyebrow_x, eyebrow_text_y), eyebrow_image.getchannel("A"))

    headline_boxes = []
    headline_metrics = []
    for line_index, line in enumerate(spec.headline):
        line_y = spec.headline_y + line_index * (112 + 26)
        headline_box, headline_metric = paste_centered_text(
            canvas,
            line,
            line_y,
            112,
            headline_fill,
            bold=True,
            max_width=1240,
        )
        headline_boxes.append(headline_box)
        headline_metrics.append(headline_metric)

    sub_box, sub_metric = paste_centered_text(
        canvas,
        spec.sub,
        spec.sub_y,
        44,
        sub_fill,
        bold=False,
        max_width=1240,
    )
    return {
        "pill_box": list(pill_box),
        "eyebrow_metric": {
            "text": spec.eyebrow,
            "requested_font_size": 40,
            "rendered_font_size": 40,
            "rendered_width": eyebrow_image.width,
            "horizontal_scale_ratio": 1.0,
            "uniform_font_scale_ratio": 1.0,
        },
        "headline_boxes": [list(box) for box in headline_boxes],
        "headline_metrics": headline_metrics,
        "sub_box": list(sub_box),
        "sub_metric": sub_metric,
    }


def validate_copy_inside_lime_pixels(
    lime_mask: Image.Image,
    copy_geometry: dict[str, Any],
    *,
    panel: int,
    polygon: Sequence[tuple[int, int]],
) -> dict[str, Any]:
    """Require every copy box on a lime headline surface to sit on solid lime."""
    labeled_boxes = [
        ("eyebrow_pill", copy_geometry["pill_box"]),
        *(
            (f"headline_{line_index}", box)
            for line_index, box in enumerate(copy_geometry["headline_boxes"], start=1)
        ),
        ("sub", copy_geometry["sub_box"]),
    ]
    box_checks = []
    for label, raw_box in labeled_boxes:
        box = tuple(raw_box)
        minimum, maximum = lime_mask.crop(box).getextrema()
        fully_inside = minimum == maximum == 255
        box_checks.append(
            {
                "label": label,
                "box": list(box),
                "lime_mask_min": minimum,
                "lime_mask_max": maximum,
                "fully_inside": fully_inside,
            }
        )

    pill_left, pill_top, pill_right, _ = copy_geometry["pill_box"]
    mask_pixels = lime_mask.load()
    upper_boundary_pixels = []
    for x in range(pill_left, pill_right):
        first_solid_lime_y = next(
            (y for y in range(pill_top + 1) if mask_pixels[x, y] == 255),
            None,
        )
        if first_solid_lime_y is None:
            raise ValueError(
                f"Panel {panel:02d} has no solid lime above eyebrow pill at x={x}"
            )
        upper_boundary_pixels.append(first_solid_lime_y)

    boundary_max_y = max(upper_boundary_pixels)
    pill_clearance = pill_top - boundary_max_y
    if not all(check["fully_inside"] for check in box_checks) or pill_clearance <= 0:
        raise ValueError(
            f"Panel {panel:02d} copy must be fully inside the solid lime pixels: "
            f"checks={box_checks}, pill_clearance={pill_clearance}"
        )

    return {
        "polygon": [list(point) for point in polygon],
        "all_copy_boxes_fully_inside": True,
        "box_checks": box_checks,
        "eyebrow_pill_top_y": pill_top,
        "lime_upper_boundary_max_y_under_pill": boundary_max_y,
        "eyebrow_pill_clearance_px": pill_clearance,
    }


def prepare_device(
    source: Image.Image,
    outer_width: int,
    *,
    expected_source_size: tuple[int, int] | None = None,
) -> PreparedDevice:
    bezel = round(outer_width * 0.0275)
    outer_radius = round(outer_width * 0.148)
    screen_width = outer_width - bezel * 2
    screen_height = round(screen_width * SCREEN_ASPECT[1] / SCREEN_ASPECT[0])
    outer_height = screen_height + bezel * 2
    screen_radius = outer_radius - bezel

    source_size = CANVAS_SIZE if expected_source_size is None else expected_source_size
    if source.size != source_size:
        raise ValueError(f"Device source must be {source_size}, got {source.size}")
    if source.mode not in {"RGB", "RGBA"}:
        raise ValueError(f"Device source must be RGB/RGBA, got {source.mode}")
    if bezel <= 0 or screen_radius <= 0:
        raise ValueError((bezel, screen_radius))
    if abs(screen_width / screen_height - SCREEN_ASPECT[0] / SCREEN_ASPECT[1]) >= 0.001:
        raise ValueError((screen_width, screen_height, SCREEN_ASPECT))

    device = Image.new("RGBA", (outer_width, outer_height), (0, 0, 0, 0))
    outer_mask = rounded_mask(
        device.size,
        (0, 0, outer_width, outer_height),
        outer_radius,
    )
    titanium = LEGACY.gradient(
        device.size,
        COLORS["titanium_top"],
        COLORS["titanium_bottom"],
    ).convert("RGBA")
    device.paste(titanium, (0, 0), outer_mask)

    # The specified bezel is the total outer-edge-to-screen distance.  Its
    # inner half is black, with the titanium chassis remaining visible outside.
    inner_bezel_inset = max(1, round(bezel * 0.45))
    inner_bezel_box = (
        inner_bezel_inset,
        inner_bezel_inset,
        outer_width - inner_bezel_inset,
        outer_height - inner_bezel_inset,
    )
    inner_bezel_mask = rounded_mask(
        device.size,
        inner_bezel_box,
        outer_radius - inner_bezel_inset,
    )
    device.paste((0, 0, 0, 255), (0, 0, outer_width, outer_height), inner_bezel_mask)

    screen = source.convert("RGB").resize((screen_width, screen_height), Image.Resampling.LANCZOS)
    screen_mask = rounded_mask(
        (screen_width, screen_height),
        (0, 0, screen_width, screen_height),
        screen_radius,
    )
    device.paste(screen.convert("RGBA"), (bezel, bezel), screen_mask)

    island_width = round(screen_width * 0.30)
    island_height = round(screen_height * 0.031)
    island_top = bezel + round(screen_height * 0.021)
    island_left = bezel + round((screen_width - island_width) / 2)
    island_box = (
        island_left,
        island_top,
        island_left + island_width,
        island_top + island_height,
    )
    island_mask = rounded_mask(device.size, island_box, island_height // 2)
    device.paste((0, 0, 0, 255), (0, 0, outer_width, outer_height), island_mask)

    # One-pixel #5A6169 outer highlight ring.
    inner_rim_mask = rounded_mask(
        device.size,
        (1, 1, outer_width - 1, outer_height - 1),
        max(0, outer_radius - 1),
    )
    rim_mask = ImageChops.subtract(outer_mask, inner_rim_mask)
    device.paste((*COLORS["titanium_rim"], 255), (0, 0, outer_width, outer_height), rim_mask)

    return PreparedDevice(
        image=device,
        outer_width=outer_width,
        outer_height=outer_height,
        bezel=bezel,
        outer_radius=outer_radius,
        screen_width=screen_width,
        screen_height=screen_height,
        screen_radius=screen_radius,
    )


def transform_point(
    local_point: tuple[float, float],
    local_size: tuple[int, int],
    center: tuple[float, float],
    rotation_deg: float,
) -> tuple[float, float]:
    local_x, local_y = local_point
    width, height = local_size
    delta_x = local_x - width / 2
    delta_y = local_y - height / 2
    theta = math.radians(rotation_deg)
    cosine = math.cos(theta)
    sine = math.sin(theta)
    # This is Pillow Image.rotate()'s visual-angle convention in y-down image
    # coordinates: positive angles rotate counter-clockwise on the canvas.
    return (
        center[0] + cosine * delta_x + sine * delta_y,
        center[1] - sine * delta_x + cosine * delta_y,
    )


def rounded_point(point: tuple[float, float]) -> list[float]:
    return [round(point[0], 2), round(point[1], 2)]


def source_box_canvas_geometry(
    prepared: PreparedDevice,
    *,
    source_box: tuple[int, int, int, int],
    center: tuple[float, float],
    rotation_deg: float,
) -> dict[str, Any]:
    left, top, right, bottom = source_box
    scale_x = prepared.screen_width / CANVAS_WIDTH
    scale_y = prepared.screen_height / CANVAS_HEIGHT
    local_corners = (
        (prepared.bezel + left * scale_x, prepared.bezel + top * scale_y),
        (prepared.bezel + right * scale_x, prepared.bezel + top * scale_y),
        (prepared.bezel + right * scale_x, prepared.bezel + bottom * scale_y),
        (prepared.bezel + left * scale_x, prepared.bezel + bottom * scale_y),
    )
    canvas_corners = [
        transform_point(point, prepared.image.size, center, rotation_deg)
        for point in local_corners
    ]
    xs = [point[0] for point in canvas_corners]
    ys = [point[1] for point in canvas_corners]
    bounds = [min(xs), min(ys), max(xs), max(ys)]
    fully_visible = (
        bounds[0] >= 0
        and bounds[1] >= 0
        and bounds[2] <= CANVAS_WIDTH
        and bounds[3] <= CANVAS_HEIGHT
    )
    return {
        "source_box": list(source_box),
        "canvas_corners": {
            "top_left": rounded_point(canvas_corners[0]),
            "top_right": rounded_point(canvas_corners[1]),
            "bottom_right": rounded_point(canvas_corners[2]),
            "bottom_left": rounded_point(canvas_corners[3]),
        },
        "canvas_bounds": [round(value, 2) for value in bounds],
        "fully_visible": fully_visible,
    }


def paste_black_shadow(canvas: Image.Image, alpha: Image.Image, blur: int, opacity: int) -> None:
    blurred = alpha.filter(ImageFilter.GaussianBlur(blur))
    scaled = blurred.point(lambda value: round(value * opacity / 255))
    canvas.paste((0, 0, 0), (0, 0, CANVAS_WIDTH, CANVAS_HEIGHT), scaled)


def rounded_outline_mask(
    size: tuple[int, int],
    radius: int,
    width: int,
) -> Image.Image:
    image_width, image_height = size
    if width <= 0 or width * 2 >= min(size):
        raise ValueError((size, radius, width))
    outer = rounded_mask(
        size,
        (0, 0, image_width, image_height),
        radius,
    )
    inner = rounded_mask(
        size,
        (width, width, image_width - width, image_height - width),
        max(0, radius - width),
    )
    return ImageChops.subtract(outer, inner)


def paste_rounded_outline(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    *,
    radius: int,
    width: int,
    fill: tuple[int, int, int],
) -> None:
    left, top, right, bottom = box
    outline = rounded_outline_mask((right - left, bottom - top), radius, width)
    canvas.paste(fill, box, outline)


def paste_antialiased_lines(
    canvas: Image.Image,
    lines: Sequence[tuple[tuple[float, float], tuple[float, float]]],
    *,
    fill: tuple[int, int, int, int],
    width: int,
) -> None:
    if not lines or width <= 0:
        raise ValueError((lines, width))
    points = [point for line in lines for point in line]
    padding = width * 2 + 2
    left = max(0, math.floor(min(point[0] for point in points)) - padding)
    top = max(0, math.floor(min(point[1] for point in points)) - padding)
    right = min(CANVAS_WIDTH, math.ceil(max(point[0] for point in points)) + padding + 1)
    bottom = min(CANVAS_HEIGHT, math.ceil(max(point[1] for point in points)) + padding + 1)
    region_size = (right - left, bottom - top)
    high_resolution = Image.new(
        "RGBA",
        (region_size[0] * AA_SCALE, region_size[1] * AA_SCALE),
        (0, 0, 0, 0),
    )
    high_draw = ImageDraw.Draw(high_resolution, "RGBA")
    for start, end in lines:
        high_draw.line(
            (
                (
                    round((start[0] - left) * AA_SCALE),
                    round((start[1] - top) * AA_SCALE),
                ),
                (
                    round((end[0] - left) * AA_SCALE),
                    round((end[1] - top) * AA_SCALE),
                ),
            ),
            fill=fill,
            width=width * AA_SCALE,
        )
    antialiased = high_resolution.resize(region_size, Image.Resampling.LANCZOS)
    canvas.paste(antialiased, (left, top), antialiased.getchannel("A"))


def draw_lock_live_activity_callout(
    canvas: Image.Image,
    source: Image.Image,
    live_activity_geometry: dict[str, Any],
    clock_geometry: dict[str, Any],
    character_geometry: dict[str, Any],
) -> dict[str, Any]:
    """Magnify the full-resolution lock-screen card above its in-phone source."""
    if source.size != CANVAS_SIZE:
        raise ValueError(f"Lock-screen callout source must be {CANVAS_SIZE}, got {source.size}")

    source_crop = source.crop(LOCK_ACTIVITY_CARD_BOX)
    source_width, source_height = source_crop.size
    target_width = LOCK_CALLOUT_WIDTH
    target_height = round(source_height * target_width / source_width)
    if target_width >= source_width or target_height >= source_height:
        raise ValueError(
            "Lock-screen Live Activity callout must be a LANCZOS downscale "
            f"from the full-resolution crop: source={source_crop.size}, "
            f"target={(target_width, target_height)}"
        )

    target_size = (target_width, target_height)
    scaled_card = source_crop.resize(target_size, Image.Resampling.LANCZOS).convert("RGBA")
    target_radius = round(LOCK_ACTIVITY_CARD_RADIUS * target_width / source_width)
    card_mask = rounded_mask(
        target_size,
        (0, 0, target_width, target_height),
        target_radius,
    )
    scaled_card.putalpha(card_mask)

    callout_left = round((CANVAS_WIDTH - target_width) / 2)
    callout_top = LOCK_CALLOUT_TOP
    callout_right = callout_left + target_width
    callout_bottom = callout_top + target_height
    callout_box = (callout_left, callout_top, callout_right, callout_bottom)
    clock_bounds = clock_geometry["canvas_bounds"]
    actual_bounds = live_activity_geometry["canvas_bounds"]
    clock_clearance = callout_top - clock_bounds[3]
    activity_clearance = actual_bounds[1] - callout_bottom
    if (
        clock_clearance < LOCK_CALLOUT_VERTICAL_CLEARANCE
        or activity_clearance < LOCK_CALLOUT_VERTICAL_CLEARANCE
    ):
        raise ValueError(
            "Lock-screen callout must stay in the wallpaper gap with at least "
            f"{LOCK_CALLOUT_VERTICAL_CLEARANCE}px vertical clearance: "
            f"clock={clock_bounds}, callout={callout_box}, activity={actual_bounds}"
        )
    if actual_bounds[3] > LOCK_ACTIVITY_CANVAS_BOTTOM_LIMIT:
        raise ValueError(
            "Lock-screen Live Activity must be fully inside the approved canvas "
            f"limit y={LOCK_ACTIVITY_CANVAS_BOTTOM_LIMIT}: {actual_bounds}"
        )
    if not live_activity_geometry["fully_visible"]:
        raise ValueError(
            f"Lock-screen Live Activity must be fully visible: {actual_bounds}"
        )

    actual_box = (
        math.floor(actual_bounds[0]),
        math.floor(actual_bounds[1]),
        math.ceil(actual_bounds[2]),
        math.ceil(actual_bounds[3]),
    )
    actual_radius = round(
        LOCK_ACTIVITY_CARD_RADIUS
        * (actual_bounds[2] - actual_bounds[0])
        / source_width
    )
    actual_display_width = actual_bounds[2] - actual_bounds[0]
    if target_width > actual_display_width * LOCK_CALLOUT_MAX_ACTUAL_WIDTH_RATIO:
        raise ValueError(
            "Lock-screen callout exceeds the 1.35x actual-card width cap: "
            f"callout={target_width}, actual={actual_display_width:.2f}"
        )
    paste_rounded_outline(
        canvas,
        actual_box,
        radius=actual_radius,
        width=LOCK_SOURCE_OUTLINE_WIDTH,
        fill=COLORS["lime"],
    )

    actual_corners = live_activity_geometry["canvas_corners"]
    callout_corners = {
        "top_left": [callout_left, callout_top],
        "top_right": [callout_right, callout_top],
        "bottom_right": [callout_right, callout_bottom],
        "bottom_left": [callout_left, callout_bottom],
    }
    # A rounded rectangle has no painted pixel at its mathematical bounding-box
    # corner.  Use the adjacent edge tangency points so the straight connector
    # endpoints visibly meet both rounded outlines without a gap.
    source_connector_anchors = {
        "top_left": [actual_box[0] + actual_radius, actual_box[1]],
        "top_right": [actual_box[2] - actual_radius, actual_box[1]],
    }
    callout_connector_anchors = {
        "bottom_left": [callout_left + target_radius, callout_bottom],
        "bottom_right": [callout_right - target_radius, callout_bottom],
    }
    connector_lines = (
        (
            tuple(source_connector_anchors["top_left"]),
            tuple(callout_connector_anchors["bottom_left"]),
        ),
        (
            tuple(source_connector_anchors["top_right"]),
            tuple(callout_connector_anchors["bottom_right"]),
        ),
    )
    character_bounds = character_geometry["visible_alpha_bbox"]
    if boxes_overlap(clock_bounds, character_bounds):
        raise ValueError(
            "Lock-screen character must not overlap the clock: "
            f"clock={clock_bounds}, character={character_bounds}"
        )
    connector_top = min(point[1] for line in connector_lines for point in line)
    if connector_top < callout_bottom:
        raise ValueError(
            "Lock-screen connectors must start at the callout bottom edge: "
            f"top={connector_top}, callout_bottom={callout_bottom}"
        )
    if connector_top <= max(clock_bounds[3], character_bounds[3]):
        raise ValueError(
            "Lock-screen connectors must not cross the clock or character: "
            f"connector_top={connector_top}, clock={clock_bounds}, "
            f"character={character_bounds}"
        )
    paste_antialiased_lines(
        canvas,
        connector_lines,
        fill=(
            *COLORS["lime"],
            round(255 * LOCK_CONNECTOR_OPACITY),
        ),
        width=LOCK_CONNECTOR_WIDTH,
    )

    shadow_alpha = Image.new("L", CANVAS_SIZE, 0)
    shadow_alpha.paste(
        card_mask,
        (
            callout_left + LOCK_CALLOUT_SHADOW_OFFSET[0],
            callout_top + LOCK_CALLOUT_SHADOW_OFFSET[1],
        ),
    )
    paste_black_shadow(
        canvas,
        shadow_alpha,
        blur=LOCK_CALLOUT_SHADOW_BLUR,
        opacity=round(255 * LOCK_CALLOUT_SHADOW_OPACITY),
    )
    canvas.paste(scaled_card, (callout_left, callout_top), scaled_card.getchannel("A"))
    paste_rounded_outline(
        canvas,
        callout_box,
        radius=target_radius,
        width=LOCK_CALLOUT_BORDER_WIDTH,
        fill=COLORS["lime"],
    )

    return {
        "source_image_size": list(source.size),
        "source_box": list(LOCK_ACTIVITY_CARD_BOX),
        "source_crop_size": [source_width, source_height],
        "resampling": "LANCZOS",
        "downscale_only": True,
        "width": target_width,
        "height": target_height,
        "scale_from_source": round(target_width / source_width, 6),
        "scale_vs_in_phone_display": round(target_width / actual_display_width, 6),
        "corner_radius": target_radius,
        "canvas_bounds": list(callout_box),
        "canvas_corners": callout_corners,
        "connector_anchors": callout_connector_anchors,
        "vertical_clearance": {
            "minimum": LOCK_CALLOUT_VERTICAL_CLEARANCE,
            "below_clock": round(clock_clearance, 2),
            "above_live_activity": round(activity_clearance, 2),
        },
        "border": {
            "color": "#C7F94D",
            "width": LOCK_CALLOUT_BORDER_WIDTH,
        },
        "shadow": {
            "color": "#000000",
            "opacity": LOCK_CALLOUT_SHADOW_OPACITY,
            "blur": LOCK_CALLOUT_SHADOW_BLUR,
            "offset": list(LOCK_CALLOUT_SHADOW_OFFSET),
        },
        "source_outline": {
            "canvas_bounds": [round(value, 2) for value in actual_bounds],
            "canvas_corners": actual_corners,
            "connector_anchors": source_connector_anchors,
            "corner_radius": actual_radius,
            "border": {
                "color": "#C7F94D",
                "width": LOCK_SOURCE_OUTLINE_WIDTH,
            },
        },
        "connector_lines": [
            {
                "from": list(start),
                "to": list(end),
                "color": "#C7F94D",
                "width": LOCK_CONNECTOR_WIDTH,
                "opacity": LOCK_CONNECTOR_OPACITY,
            }
            for start, end in connector_lines
        ],
        "layer_order": [
            "phone",
            "character",
            "source_outline_and_connector_lines",
            "callout_shadow",
            "callout_card_and_border",
        ],
    }


def boxes_overlap(
    first: Sequence[float],
    second: Sequence[float],
) -> bool:
    return (
        first[0] < second[2]
        and first[2] > second[0]
        and first[1] < second[3]
        and first[3] > second[1]
    )


def validate_corner_character_geometry(
    *,
    panel: int,
    character_geometry: dict[str, Any] | None,
    device_geometry: dict[str, Any],
    copy_geometry: dict[str, Any],
    expected_asset: str,
    expected_side: str,
) -> dict[str, Any]:
    """Verify that one large mascot visibly hooks over a phone's upper corner."""
    if character_geometry is None:
        raise ValueError(f"Panel {panel:02d} requires an external mascot")
    if character_geometry["asset"] != expected_asset:
        raise ValueError(
            f"Panel {panel:02d} requires {expected_asset}, "
            f"got {character_geometry['asset']}"
        )
    if expected_side not in {"left", "right"}:
        raise ValueError(expected_side)

    char_box = character_geometry["visible_alpha_bbox"]
    char_width = char_box[2] - char_box[0]
    if char_width < 440:
        raise ValueError(
            f"Panel {panel:02d} mascot alpha width must be at least 440px: "
            f"{char_width}"
        )

    copy_boxes = [
        copy_geometry["pill_box"],
        *copy_geometry["headline_boxes"],
        copy_geometry["sub_box"],
    ]
    copy_intersections = sum(boxes_overlap(char_box, box) for box in copy_boxes)
    if copy_intersections:
        raise ValueError(
            f"Panel {panel:02d} mascot overlaps {copy_intersections} copy boxes"
        )

    outer_points = list(device_geometry["outer_corners"].values())
    outer_box = [
        min(point[0] for point in outer_points),
        min(point[1] for point in outer_points),
        max(point[0] for point in outer_points),
        max(point[1] for point in outer_points),
    ]
    intersection_box = [
        max(char_box[0], outer_box[0]),
        max(char_box[1], outer_box[1]),
        min(char_box[2], outer_box[2]),
        min(char_box[3], outer_box[3]),
    ]
    intersection_width = max(0, intersection_box[2] - intersection_box[0])
    intersection_height = max(0, intersection_box[3] - intersection_box[1])
    if intersection_width <= 0 or intersection_height <= 0:
        raise ValueError(f"Panel {panel:02d} mascot does not intersect phone exterior")

    corner_name = "top_left" if expected_side == "left" else "top_right"
    corner = device_geometry["outer_corners"][corner_name]
    if not char_box[1] < corner[1] < char_box[3]:
        raise ValueError(
            f"Panel {panel:02d} mascot must straddle the phone's {corner_name}: "
            f"character={char_box}, corner={corner}"
        )
    visible_center_x = character_geometry["visible_center_x"]
    if expected_side == "left" and visible_center_x >= CANVAS_WIDTH / 2:
        raise ValueError(f"Panel {panel:02d} mascot must use the left corner")
    if expected_side == "right" and visible_center_x <= CANVAS_WIDTH / 2:
        raise ValueError(f"Panel {panel:02d} mascot must use the right corner")

    return {
        "side": expected_side,
        "phone_corner": corner,
        "alpha_bbox_width": char_width,
        "phone_bbox_intersection": [round(value, 2) for value in intersection_box],
        "phone_bbox_intersection_size": [
            round(intersection_width, 2),
            round(intersection_height, 2),
        ],
        "copy_box_intersections": copy_intersections,
        "copy_vertical_clearance": round(
            char_box[1] - max(box[3] for box in copy_boxes),
            2,
        ),
        "straddles_phone_corner": True,
    }


def place_device(
    canvas: Image.Image,
    prepared: PreparedDevice,
    *,
    center: tuple[float, float],
    rotation_deg: float,
) -> dict[str, Any]:
    if rotation_deg:
        rendered = prepared.image.rotate(
            rotation_deg,
            resample=Image.Resampling.BICUBIC,
            expand=True,
        )
    else:
        rendered = prepared.image

    paste_x = round(center[0] - rendered.width / 2)
    paste_y = round(center[1] - rendered.height / 2)

    shadow_alpha = Image.new("L", CANVAS_SIZE, 0)
    shadow_offset = round(prepared.outer_height * 0.03)
    shadow_alpha.paste(rendered.getchannel("A"), (paste_x, paste_y + shadow_offset))
    paste_black_shadow(
        canvas,
        shadow_alpha,
        blur=round(prepared.screen_width * 0.12),
        opacity=150,
    )
    canvas.paste(rendered, (paste_x, paste_y), rendered.getchannel("A"))

    screen_local = (
        (prepared.bezel, prepared.bezel),
        (prepared.bezel + prepared.screen_width, prepared.bezel),
        (
            prepared.bezel + prepared.screen_width,
            prepared.bezel + prepared.screen_height,
        ),
        (prepared.bezel, prepared.bezel + prepared.screen_height),
    )
    outer_local = (
        (0, 0),
        (prepared.outer_width, 0),
        (prepared.outer_width, prepared.outer_height),
        (0, prepared.outer_height),
    )
    screen_canvas = [
        transform_point(point, prepared.image.size, center, rotation_deg)
        for point in screen_local
    ]
    outer_canvas = [
        transform_point(point, prepared.image.size, center, rotation_deg)
        for point in outer_local
    ]
    screen_xs = [point[0] for point in screen_canvas]
    screen_ys = [point[1] for point in screen_canvas]

    return {
        "name": "main",
        "x": prepared.bezel,
        "y": prepared.bezel,
        "width": prepared.screen_width,
        "height": prepared.screen_height,
        "corner_radius": prepared.screen_radius,
        "outer_width": prepared.outer_width,
        "outer_height": prepared.outer_height,
        "outer_corner_radius": prepared.outer_radius,
        "bezel": prepared.bezel,
        "rotation_deg": rotation_deg,
        "rotation_center": [round(center[0], 2), round(center[1], 2)],
        "rendered_paste_box": [
            paste_x,
            paste_y,
            paste_x + rendered.width,
            paste_y + rendered.height,
        ],
        "screen_corners": {
            "top_left": rounded_point(screen_canvas[0]),
            "top_right": rounded_point(screen_canvas[1]),
            "bottom_right": rounded_point(screen_canvas[2]),
            "bottom_left": rounded_point(screen_canvas[3]),
        },
        "screen_canvas_bounds": [
            round(min(screen_xs), 2),
            round(min(screen_ys), 2),
            round(max(screen_xs), 2),
            round(max(screen_ys), 2),
        ],
        "outer_corners": {
            "top_left": rounded_point(outer_canvas[0]),
            "top_right": rounded_point(outer_canvas[1]),
            "bottom_right": rounded_point(outer_canvas[2]),
            "bottom_left": rounded_point(outer_canvas[3]),
        },
        "shadow": {
            "blur": round(prepared.screen_width * 0.12),
            "opacity": 150,
            "offset": [0, shadow_offset],
        },
        "ground_shadow": None,
        "note": (
            "x/y/width/height are pre-rotation device-local screen coordinates; "
            "screen_corners are the four post-rotation canvas points"
        ),
    }


def center_for_visual_top(
    prepared: PreparedDevice,
    *,
    rotation_deg: float,
    visual_top: float = PHONE_VISUAL_TOP,
    center_x: float = CANVAS_WIDTH / 2,
) -> tuple[float, float]:
    """Center a rotated phone so its outer silhouette starts at visual_top."""
    theta = math.radians(abs(rotation_deg))
    rotated_height = (
        prepared.outer_height * math.cos(theta)
        + prepared.outer_width * math.sin(theta)
    )
    return center_x, visual_top + rotated_height / 2


def character_source(name: str) -> Image.Image:
    path = ROOT / f"ios/DopaBreak/Assets.xcassets/Character/{name}.imageset/{name}.png"
    with Image.open(path) as source_file:
        image = source_file.convert("RGBA")
    if image.size != (1024, 1024):
        raise ValueError((path, image.size))
    return image


def ground_shadow(
    canvas: Image.Image,
    *,
    center_x: float,
    contact_y: float,
    width: int,
    height: int,
    opacity: float,
    blur: int,
) -> dict[str, Any]:
    if width <= 0 or height <= 0 or blur < 0 or not 0 <= opacity <= 1:
        raise ValueError((width, height, opacity, blur))

    # Keep the full ellipse below the visible object's bottom edge. The blur
    # alone feathers upward into the contact point, so the shadow remains
    # visible instead of being half-covered by the character or device.
    left = round(center_x - width / 2)
    top = round(contact_y)
    box = (
        left,
        top,
        left + width,
        top + height,
    )
    alpha = Image.new("L", CANVAS_SIZE, 0)
    ImageDraw.Draw(alpha).ellipse(box, fill=255)
    paste_black_shadow(canvas, alpha, blur=blur, opacity=round(255 * opacity))
    return {
        "box": list(box),
        "contact_y": round(contact_y, 2),
        "width": width,
        "height": height,
        "opacity": opacity,
        "blur": blur,
    }


def place_character(
    canvas: Image.Image,
    *,
    name: str,
    width: int,
    center_x: float,
    bottom_y: float,
    rotation_deg: float = 0,
    flip_horizontal: bool = False,
    has_ground_shadow: bool = False,
    after_ground_shadow: Callable[[], None] | None = None,
) -> dict[str, Any]:
    character = character_source(name).resize((width, width), Image.Resampling.LANCZOS)
    if flip_horizontal:
        character = ImageOps.mirror(character)
    if rotation_deg:
        character = character.rotate(
            rotation_deg,
            resample=Image.Resampling.BICUBIC,
            expand=True,
        )

    alpha_bbox = character.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError(f"Character has no visible pixels: {name}")
    alpha_center_x = (alpha_bbox[0] + alpha_bbox[2]) / 2
    paste_x = round(center_x - alpha_center_x)
    paste_y = round(bottom_y - alpha_bbox[3])

    ground_shadow_geometry: dict[str, Any] | None = None
    if has_ground_shadow:
        ground_shadow_geometry = ground_shadow(
            canvas,
            center_x=center_x,
            contact_y=bottom_y,
            width=round(width * CHARACTER_GROUND_SHADOW_WIDTH_RATIO),
            height=CHARACTER_GROUND_SHADOW_HEIGHT,
            opacity=CHARACTER_GROUND_SHADOW_OPACITY,
            blur=CHARACTER_GROUND_SHADOW_BLUR,
        )
    if after_ground_shadow is not None:
        after_ground_shadow()

    shadow_alpha = Image.new("L", CANVAS_SIZE, 0)
    shadow_alpha.paste(character.getchannel("A"), (paste_x, paste_y + 30))
    paste_black_shadow(canvas, shadow_alpha, blur=40, opacity=round(255 * 0.35))
    canvas.paste(character, (paste_x, paste_y), character.getchannel("A"))

    canvas_alpha_bbox = [
        paste_x + alpha_bbox[0],
        paste_y + alpha_bbox[1],
        paste_x + alpha_bbox[2],
        paste_y + alpha_bbox[3],
    ]
    return {
        "asset": name,
        "nominal_width": width,
        "rotation_deg": rotation_deg,
        "flip_horizontal": flip_horizontal,
        "requested_visible_center_x": round(center_x, 2),
        "requested_visible_bottom_y": round(bottom_y, 2),
        "rendered_paste_box": [
            paste_x,
            paste_y,
            paste_x + character.width,
            paste_y + character.height,
        ],
        "visible_alpha_bbox": canvas_alpha_bbox,
        "visible_center_x": round((canvas_alpha_bbox[0] + canvas_alpha_bbox[2]) / 2, 2),
        "visible_bottom_y": canvas_alpha_bbox[3],
        "drop_shadow": {"opacity": 0.35, "blur": 40, "offset": [0, 30]},
        "ground_shadow_box": (
            ground_shadow_geometry["box"] if ground_shadow_geometry is not None else None
        ),
        "ground_shadow": ground_shadow_geometry,
    }


def source_for(panel: int) -> Image.Image:
    if panel not in PANEL_IDS:
        raise ValueError(panel)
    source_path = SOURCE_PATHS[PANEL_IDS.index(panel)]
    if panel == 5:
        source = mock_lock(CANVAS_SIZE, LOCALE).convert("RGB")
    elif panel == 10:
        source = mock_home_grayscale(CANVAS_SIZE, LOCALE).convert("RGB")
    else:
        if source_path is None:
            raise ValueError(f"Panel {panel:02d} has no capture and no mock")
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        with Image.open(source_path) as raw_source:
            source = raw_source.convert("RGB")
    if source.size != CANVAS_SIZE:
        raise ValueError((panel, source.size))
    if panel == 2:
        source = breath_countdown_source(source)
    return source


def breath_countdown_source(source: Image.Image) -> Image.Image:
    """Shift the live breath stage up so the remaining-second numeral stays visible."""
    image = Image.new("RGB", CANVAS_SIZE, COLORS["background"])
    image.paste(
        source.crop((0, BREATH_SOURCE_OFFSET_Y, CANVAS_WIDTH, CANVAS_HEIGHT)),
        (0, 0),
    )
    return image


def source_box_is_visible(
    prepared: PreparedDevice,
    *,
    source_box: tuple[int, int, int, int],
    center: tuple[float, float],
    rotation_deg: float,
) -> tuple[bool, dict[str, Any]]:
    """Count source characters only when their source region meets the canvas."""
    geometry = source_box_canvas_geometry(
        prepared,
        source_box=source_box,
        center=center,
        rotation_deg=rotation_deg,
    )
    left, top, right, bottom = geometry["canvas_bounds"]
    visible = left < CANVAS_WIDTH and top < CANVAS_HEIGHT and right > 0 and bottom > 0
    geometry["intersects_canvas"] = visible
    return visible, geometry


def render_panel(panel: int) -> tuple[Image.Image, dict[str, Any]]:
    if panel not in PANEL_IDS:
        raise ValueError(panel)
    content_panel = CONTENT_PANEL_BY_LAYOUT[panel]

    canvas = dark_background()

    copy_lime_mask = None
    copy_lime_polygon: Sequence[tuple[int, int]] | None = None
    if panel == 1:
        copy_lime_polygon = PANEL_01_LIME_POLYGON
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 2:
        copy_lime_polygon = ((0, 0), (1320, 0), (1320, 1450), (0, 1170))
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 3:
        draw_lime_circle(canvas, LOCK_LIME_CIRCLE_CENTER, LOCK_LIME_CIRCLE_RADIUS)
    elif panel == 4:
        draw_lime_polygon(canvas, ((0, 2100), (1320, 1520), (1320, 2868), (0, 2868)))
    elif panel == 5:
        draw_lime_circle(canvas, (660, 1800), 680)
    elif panel == 6:
        draw_lime_polygon(canvas, ((0, 1520), (1320, 2100), (1320, 2868), (0, 2868)))
    elif panel == 8:
        copy_lime_polygon = ((0, 0), (1320, 0), (1320, 1450), (0, 1170))
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 9:
        draw_lime_polygon(canvas, REFLECTION_LIME_RIBBON)
    elif panel == 10:
        draw_lime_polygon(canvas, ((0, 1450), (1320, 1170), (1320, 2868), (0, 2868)))

    content_index = PANEL_IDS.index(content_panel)
    copy_spec = replace(COPY_SPECS[content_index], surface=LAYOUT_SURFACES[panel])
    copy_geometry = draw_copy_block(canvas, copy_spec)
    if copy_lime_mask is not None:
        if copy_lime_polygon is None:
            raise RuntimeError(f"Panel {panel:02d} lime polygon was not recorded")
        copy_geometry["lime_surface_validation"] = validate_copy_inside_lime_pixels(
            copy_lime_mask,
            copy_geometry,
            panel=panel,
            polygon=copy_lime_polygon,
        )
    source = source_for(content_panel)
    source_screen_character_count = SCREEN_CHARACTER_COUNTS[content_index]
    visible_screen_character_count = VISIBLE_SCREEN_CHARACTER_COUNTS[content_index]

    if panel == 1:
        device = prepare_device(source, MAX_STRAIGHT_PHONE_WIDTH)
        device_geometry = place_device(
            canvas,
            device,
            center=center_for_visual_top(device, rotation_deg=0),
            rotation_deg=0,
        )
        # breath.png contains the breathing mascot; no external character is added.
        character_geometry = None
    elif panel == 2:
        device = prepare_device(source, MAX_STRAIGHT_PHONE_WIDTH)
        device_rotation = 0
        device_center = center_for_visual_top(device, rotation_deg=device_rotation)
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=device_rotation,
        )
        character_geometry = None
    elif panel == 3:
        device = prepare_device(source, LOCK_PHONE_WIDTH)
        device_rotation = 0
        device_center = center_for_visual_top(
            device,
            rotation_deg=device_rotation,
            visual_top=LOCK_PHONE_VISUAL_TOP,
        )
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=device_rotation,
        )
        device_geometry["live_activity_card"] = source_box_canvas_geometry(
            device,
            source_box=LOCK_ACTIVITY_CARD_BOX,
            center=device_center,
            rotation_deg=device_rotation,
        )
        wider_device = prepare_device(source, LOCK_PHONE_WIDTH + 1)
        wider_center = center_for_visual_top(
            wider_device,
            rotation_deg=device_rotation,
            visual_top=LOCK_PHONE_VISUAL_TOP,
        )
        wider_activity = source_box_canvas_geometry(
            wider_device,
            source_box=LOCK_ACTIVITY_CARD_BOX,
            center=wider_center,
            rotation_deg=device_rotation,
        )
        if wider_activity["canvas_bounds"][3] <= LOCK_ACTIVITY_CANVAS_BOTTOM_LIMIT:
            raise ValueError(
                "LOCK_PHONE_WIDTH must be the maximum integer width satisfying "
                f"the Live Activity y={LOCK_ACTIVITY_CANVAS_BOTTOM_LIMIT} limit"
            )
        device_geometry["clock"] = source_box_canvas_geometry(
            device,
            source_box=lock_clock_source_box(),
            center=device_center,
            rotation_deg=device_rotation,
        )
        device_geometry["live_activity_localization"] = {
            "date": LOCK_DATES[LOCALE],
            **live_activity_copy(LOCALE),
            "goals": list(LOCK_GOALS[LOCALE]),
        }
        character_geometry = place_character(
            canvas,
            name="awake",
            width=LOCK_CHARACTER_WIDTH,
            rotation_deg=-12,
            flip_horizontal=True,
            center_x=LOCK_CHARACTER_CENTER_X,
            bottom_y=LOCK_CHARACTER_BOTTOM_Y,
        )
    elif panel == 4:
        # Keep nightmode.png pixel-for-pixel aligned to the device screen. The
        # relief mascot hooks over the upper-left chassis corner, above the
        # wake/bed timeline and away from its labels.
        device = prepare_device(source, NIGHT_PHONE_WIDTH)
        device_center = center_for_visual_top(
            device,
            rotation_deg=NIGHT_PHONE_ROTATION,
            visual_top=NIGHT_PHONE_VISUAL_TOP,
        )
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=NIGHT_PHONE_ROTATION,
        )
        character_geometry = place_character(
            canvas,
            name="relief",
            width=CORNER_CHARACTER_WIDTH,
            rotation_deg=NIGHT_PHONE_ROTATION,
            center_x=NIGHT_CHARACTER_CENTER_X,
            bottom_y=NIGHT_CHARACTER_BOTTOM_Y,
        )
    elif panel == 5:
        device = prepare_device(source, STATS_PHONE_WIDTH)
        device_center = center_for_visual_top(
            device,
            rotation_deg=0,
            visual_top=STATS_PHONE_VISUAL_TOP,
        )
        device_rotation = 0
        device_geometry = {}

        def place_panel_5_device() -> None:
            device_geometry.update(
                place_device(
                    canvas,
                    device,
                    center=device_center,
                    rotation_deg=device_rotation,
                )
            )

        character_geometry = place_character(
            canvas,
            name="doom",
            width=STATS_DOOM_WIDTH,
            center_x=STATS_DOOM_CENTER_X,
            bottom_y=STATS_DOOM_BOTTOM_Y,
            has_ground_shadow=True,
            after_ground_shadow=place_panel_5_device,
        )
    elif panel == 6:
        device = prepare_device(source, MAX_EIGHT_DEGREE_PHONE_WIDTH)
        device_rotation = -8
        device_center = center_for_visual_top(device, rotation_deg=device_rotation)
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=device_rotation,
        )
        character_geometry = place_character(
            canvas,
            name="blink",
            width=CORNER_CHARACTER_WIDTH,
            rotation_deg=device_rotation,
            center_x=DEEPFOCUS_CHARACTER_CENTER_X,
            bottom_y=DEEPFOCUS_CHARACTER_BOTTOM_Y,
        )
    elif panel == 8:
        device = prepare_device(source, INTENT_PHONE_WIDTH)
        device_rotation = 0
        device_center = center_for_visual_top(
            device,
            rotation_deg=device_rotation,
            visual_top=INTENT_PHONE_VISUAL_TOP,
        )
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=device_rotation,
        )
        character_geometry = place_character(
            canvas,
            name="awake",
            width=CORNER_CHARACTER_WIDTH,
            center_x=INTENT_CHARACTER_CENTER_X,
            bottom_y=INTENT_CHARACTER_BOTTOM_Y,
        )
    elif panel == 9:
        device = prepare_device(source, REFLECTION_PHONE_WIDTH)
        device_rotation = 0
        device_geometry = place_device(
            canvas,
            device,
            center=center_for_visual_top(
                device,
                rotation_deg=device_rotation,
                visual_top=REFLECTION_PHONE_VISUAL_TOP,
            ),
            rotation_deg=device_rotation,
        )
        # reflection.png already contains its one mascot.
        character_geometry = None
    else:
        device = prepare_device(source, MAX_STRAIGHT_PHONE_WIDTH)
        device_geometry = place_device(
            canvas,
            device,
            center=center_for_visual_top(
                device,
                rotation_deg=0,
                visual_top=GRAYSCALE_PHONE_VISUAL_TOP,
            ),
            rotation_deg=0,
        )

        character_geometry = place_character(
            canvas,
            name="worse",
            width=CORNER_CHARACTER_WIDTH,
            center_x=GRAYSCALE_CHARACTER_CENTER_X,
            bottom_y=GRAYSCALE_CHARACTER_BOTTOM_Y,
        )

    if content_panel == 5:
        callout_geometry = draw_lock_live_activity_callout(
            canvas,
            source,
            device_geometry["live_activity_card"],
            device_geometry["clock"],
            character_geometry,
        )
        callout_box = callout_geometry["canvas_bounds"]
        copy_boxes = [
            copy_geometry["pill_box"],
            *copy_geometry["headline_boxes"],
            copy_geometry["sub_box"],
        ]
        if any(boxes_overlap(callout_box, box) for box in copy_boxes):
            raise ValueError(
                f"Lock-screen callout must not overlap the copy block: {callout_box}"
            )
        if character_geometry is not None and boxes_overlap(
            callout_box,
            character_geometry["visible_alpha_bbox"],
        ):
            raise ValueError(
                "Lock-screen callout must not overlap the character: "
                f"{callout_box} vs {character_geometry['visible_alpha_bbox']}"
            )
        callout_geometry["overlap_checks"] = {
            "copy": False,
            "character": False,
        }
        device_geometry["callout"] = callout_geometry

    screen_corner_xs = [
        point[0] for point in device_geometry["screen_corners"].values()
    ]
    if min(screen_corner_xs) < 0 or max(screen_corner_xs) > CANVAS_WIDTH:
        raise ValueError(
            f"Panel {panel:02d} screen x coordinates must stay inside the canvas: "
            f"{screen_corner_xs}"
        )

    if content_panel == 3:
        card_tops = STATS_CARD_TOPS[LOCALE]
        percentage_marker = source_box_canvas_geometry(
            device,
            source_box=(0, card_tops["percentage"], CANVAS_WIDTH, card_tops["percentage"] + 1),
            center=device_center,
            rotation_deg=device_rotation,
        )
        app_marker = source_box_canvas_geometry(
            device,
            source_box=(0, card_tops["app"], CANVAS_WIDTH, card_tops["app"] + 1),
            center=device_center,
            rotation_deg=device_rotation,
        )
        mood_visible, mood_geometry = source_box_is_visible(
            device,
            source_box=(0, card_tops["mood"], CANVAS_WIDTH, CANVAS_HEIGHT),
            center=device_center,
            rotation_deg=device_rotation,
        )
        visible_screen_character_count = 5 if mood_visible else 0
        device_geometry["stats_source_crop"] = {
            "raw_card_top_y": card_tops,
            "percentage_card_canvas_top_y": percentage_marker["canvas_bounds"][1],
            "app_card_canvas_top_y": app_marker["canvas_bounds"][1],
            "mood_card": mood_geometry,
            "percentage_card_included": True,
            "app_card_included": True,
            "mood_card_included": mood_visible,
        }
        if mood_geometry["canvas_bounds"][1] < 2880:
            raise ValueError(
                "Stats mood-card top must stay below the App Store canvas: "
                f"{mood_geometry['canvas_bounds'][1]}"
            )
        if source_screen_character_count != 5 or visible_screen_character_count != 0:
            raise ValueError(
                "Stats character accounting must derive raw=5 and visible=0 "
                "from the mood-card canvas intersection"
            )

    if visible_screen_character_count is None:
        raise ValueError(
            f"Panel {panel:02d} visible screen character count was not resolved"
        )
    if visible_screen_character_count > source_screen_character_count:
        raise ValueError(
            f"Panel {panel:02d} visible screen character count exceeds raw count: "
            f"{visible_screen_character_count}>{source_screen_character_count}"
        )

    external_character_count = 0 if character_geometry is None else 1
    total_character_count = visible_screen_character_count + external_character_count
    if total_character_count > 1:
        raise ValueError((panel, total_character_count))
    if canvas.size != CANVAS_SIZE:
        raise ValueError((panel, canvas.size))
    if canvas.mode != "RGB":
        raise ValueError((panel, canvas.mode))
    if character_geometry is not None:
        char_left, char_top, char_right, char_bottom = character_geometry["visible_alpha_bbox"]
        if (
            char_left < 0
            or char_top < 0
            or char_right > CANVAS_WIDTH
            or char_bottom > CANVAS_HEIGHT
        ):
            raise ValueError(
                f"Panel {panel:02d} external character must be fully visible: "
                f"{character_geometry['visible_alpha_bbox']}"
            )
    corner_attachment = None
    corner_requirements = {
        4: ("relief", "left"),
        6: ("blink", "right"),
        8: ("awake", "right"),
        10: ("worse", "right"),
    }
    if panel in corner_requirements:
        expected_asset, expected_side = corner_requirements[panel]
        corner_attachment = validate_corner_character_geometry(
            panel=panel,
            character_geometry=character_geometry,
            device_geometry=device_geometry,
            copy_geometry=copy_geometry,
            expected_asset=expected_asset,
            expected_side=expected_side,
        )
    return canvas, {
        "copy_geometry": copy_geometry,
        "slot": device_geometry,
        "character": character_geometry,
        "corner_attachment": corner_attachment,
        "character_count": {
            "source_screen": source_screen_character_count,
            "screen": visible_screen_character_count,
            "external": external_character_count,
            "total": total_character_count,
        },
    }


def configure_device_context(device: str, locale: str) -> None:
    """Select output geometry without changing any locale content source."""
    global CANVAS_SIZE, CANVAS_WIDTH, CANVAS_HEIGHT, DEVICE
    global SCREENSHOT_ROOT, CONTACT_SHEET_PATH, SLOTS_PATH

    if device not in SUPPORTED_DEVICES:
        raise ValueError(f"Unsupported device: {device}")
    DEVICE = device
    if device == "iphone-69":
        CANVAS_SIZE = IPHONE_CANVAS_SIZE
        CONTACT_SHEET_PATH = OUTPUT_ROOT / f"contact-sheet-{locale}.png"
        SLOTS_PATH = OUTPUT_ROOT / f"slots-{locale}.json"
    else:
        CANVAS_SIZE = IPAD_CANVAS_SIZE
        CONTACT_SHEET_PATH = OUTPUT_ROOT / f"contact-sheet-ipad-{locale}.png"
        SLOTS_PATH = OUTPUT_ROOT / f"slots-ipad-{locale}.json"
    CANVAS_WIDTH, CANVAS_HEIGHT = CANVAS_SIZE
    SCREENSHOT_ROOT = OUTPUT_ROOT / locale / device


def draw_ipad_copy_block(canvas: Image.Image, spec: CopySpec) -> dict[str, Any]:
    """Draw centered iPad copy at native font widths, capped at 1.25x iPhone."""
    if spec.surface == "lime":
        pill_fill = COLORS["ink"]
        pill_text = COLORS["lime"]
        headline_fill = COLORS["ink"]
        sub_fill = COLORS["lime_sub"]
    else:
        pill_fill = COLORS["dark_pill"]
        pill_text = COLORS["lime"]
        headline_fill = COLORS["off_white"]
        sub_fill = COLORS["muted"]

    eyebrow_size = 50
    eyebrow_image = tight_text_image(spec.eyebrow, eyebrow_size, pill_text, bold=True)
    eyebrow_natural_width = eyebrow_image.width
    while eyebrow_image.width > IPAD_COPY_MAX_WIDTH - 84 and eyebrow_size > 1:
        eyebrow_size -= 1
        eyebrow_image = tight_text_image(spec.eyebrow, eyebrow_size, pill_text, bold=True)
    eyebrow_x = round((CANVAS_WIDTH - eyebrow_image.width) / 2)
    eyebrow_y = IPAD_COPY_EYEBROW_Y + 20
    eyebrow_box = (
        eyebrow_x,
        eyebrow_y,
        eyebrow_x + eyebrow_image.width,
        eyebrow_y + eyebrow_image.height,
    )
    eyebrow_metric = {
        "text": spec.eyebrow,
        "requested_font_size": 50,
        "rendered_font_size": eyebrow_size,
        "natural_width": eyebrow_natural_width,
        "rendered_width": eyebrow_image.width,
        "max_width": IPAD_COPY_MAX_WIDTH - 84,
        "horizontal_scale_ratio": 1.0,
        "uniform_font_scale_ratio": round(eyebrow_size / 50, 6),
    }
    pill_box = (
        eyebrow_box[0] - 42,
        IPAD_COPY_EYEBROW_Y,
        eyebrow_box[2] + 42,
        eyebrow_box[3] + 20,
    )
    paste_solid_rounded_rect(
        canvas,
        pill_box,
        (pill_box[3] - pill_box[1]) // 2,
        pill_fill,
    )
    canvas.paste(
        eyebrow_image,
        (eyebrow_box[0], eyebrow_box[1]),
        eyebrow_image.getchannel("A"),
    )

    headline_boxes: list[tuple[int, int, int, int]] = []
    headline_metrics: list[dict[str, Any]] = []
    for line_index, line in enumerate(spec.headline):
        line_box, line_metric = paste_centered_text(
            canvas,
            line,
            IPAD_COPY_HEADLINE_Y + line_index * (140 + 28),
            140,
            headline_fill,
            bold=True,
            max_width=IPAD_COPY_MAX_WIDTH,
        )
        headline_boxes.append(line_box)
        headline_metrics.append(line_metric)
    sub_box, sub_metric = paste_centered_text(
        canvas,
        spec.sub,
        IPAD_COPY_SUB_Y,
        55,
        sub_fill,
        bold=False,
        max_width=IPAD_COPY_MAX_WIDTH,
    )
    geometry = {
        "pill_box": list(pill_box),
        "eyebrow_metric": eyebrow_metric,
        "headline_boxes": [list(box) for box in headline_boxes],
        "headline_metrics": headline_metrics,
        "sub_box": list(sub_box),
        "sub_metric": sub_metric,
        "max_width": IPAD_COPY_MAX_WIDTH,
    }
    boxes = [pill_box, *headline_boxes, sub_box]
    if any(box[0] < 0 or box[2] > CANVAS_WIDTH for box in boxes):
        raise ValueError(f"iPad copy exceeds canvas: {boxes}")
    metrics = [eyebrow_metric, *headline_metrics, sub_metric]
    if any(metric["horizontal_scale_ratio"] != 1.0 for metric in metrics):
        raise ValueError("iPad copy must never be resized horizontally")
    return geometry


def source_box_canvas_geometry_ipad(
    prepared: PreparedDevice,
    *,
    source_box: tuple[int, int, int, int],
    center: tuple[float, float],
    rotation_deg: float,
) -> dict[str, Any]:
    """Map a 1320x2868 raw/mock source box into the iPad marketing canvas."""
    left, top, right, bottom = source_box
    source_width, source_height = IPHONE_CANVAS_SIZE
    scale_x = prepared.screen_width / source_width
    scale_y = prepared.screen_height / source_height
    local_corners = (
        (prepared.bezel + left * scale_x, prepared.bezel + top * scale_y),
        (prepared.bezel + right * scale_x, prepared.bezel + top * scale_y),
        (prepared.bezel + right * scale_x, prepared.bezel + bottom * scale_y),
        (prepared.bezel + left * scale_x, prepared.bezel + bottom * scale_y),
    )
    canvas_corners = [
        transform_point(point, prepared.image.size, center, rotation_deg)
        for point in local_corners
    ]
    xs = [point[0] for point in canvas_corners]
    ys = [point[1] for point in canvas_corners]
    bounds = [min(xs), min(ys), max(xs), max(ys)]
    return {
        "source_box": list(source_box),
        "canvas_corners": {
            "top_left": rounded_point(canvas_corners[0]),
            "top_right": rounded_point(canvas_corners[1]),
            "bottom_right": rounded_point(canvas_corners[2]),
            "bottom_left": rounded_point(canvas_corners[3]),
        },
        "canvas_bounds": [round(value, 2) for value in bounds],
        "fully_visible": (
            bounds[0] >= 0
            and bounds[1] >= 0
            and bounds[2] <= CANVAS_WIDTH
            and bounds[3] <= CANVAS_HEIGHT
        ),
    }


def draw_ipad_lock_callout(
    canvas: Image.Image,
    source: Image.Image,
    live_activity_geometry: dict[str, Any],
    clock_geometry: dict[str, Any],
    character_geometry: dict[str, Any],
) -> dict[str, Any]:
    """Center the enlarged card in the wallpaper gap, as on iPhone."""
    source_crop = source.crop(LOCK_ACTIVITY_CARD_BOX)
    source_width, source_height = source_crop.size
    target_width = IPAD_LOCK_CALLOUT_WIDTH
    target_height = round(source_height * target_width / source_width)
    target_size = (target_width, target_height)
    card = source_crop.resize(target_size, Image.Resampling.LANCZOS).convert("RGBA")
    target_radius = round(LOCK_ACTIVITY_CARD_RADIUS * target_width / source_width)
    card_mask = rounded_mask(target_size, (0, 0, *target_size), target_radius)
    card.putalpha(card_mask)
    left = round((CANVAS_WIDTH - target_width) / 2)
    clock_bounds = clock_geometry["canvas_bounds"]
    actual_bounds = live_activity_geometry["canvas_bounds"]
    top = round((clock_bounds[3] + actual_bounds[1] - target_height) / 2)
    box = (left, top, left + target_width, top + target_height)
    clock_clearance = top - clock_bounds[3]
    activity_clearance = actual_bounds[1] - box[3]
    if min(clock_clearance, activity_clearance) < 80:
        raise ValueError(
            "iPad lock callout must sit between the clock and Live Activity: "
            f"clock={clock_bounds}, callout={box}, activity={actual_bounds}"
        )
    if boxes_overlap(box, character_geometry["visible_alpha_bbox"]):
        raise ValueError("iPad lock callout overlaps the character")
    if boxes_overlap(clock_bounds, character_geometry["visible_alpha_bbox"]):
        raise ValueError("iPad lock character overlaps the clock")

    actual_box = tuple(
        round(value)
        for value in actual_bounds
    )
    actual_radius = round(
        LOCK_ACTIVITY_CARD_RADIUS
        * (actual_bounds[2] - actual_bounds[0])
        / source_width
    )
    paste_rounded_outline(
        canvas,
        actual_box,
        radius=actual_radius,
        width=3,
        fill=COLORS["lime"],
    )
    connector_lines = (
        (
            (actual_box[0] + actual_radius, actual_box[1]),
            (box[0] + target_radius, box[3]),
        ),
        (
            (actual_box[2] - actual_radius, actual_box[1]),
            (box[2] - target_radius, box[3]),
        ),
    )
    paste_antialiased_lines(
        canvas,
        connector_lines,
        fill=(*COLORS["lime"], round(255 * 0.60)),
        width=3,
    )
    shadow_alpha = Image.new("L", CANVAS_SIZE, 0)
    shadow_alpha.paste(card_mask, (left, top + 24))
    paste_black_shadow(canvas, shadow_alpha, blur=50, opacity=round(255 * 0.45))
    canvas.paste(card, (left, top), card.getchannel("A"))
    paste_rounded_outline(
        canvas,
        box,
        radius=target_radius,
        width=4,
        fill=COLORS["lime"],
    )
    return {
        "source_image_size": list(source.size),
        "source_box": list(LOCK_ACTIVITY_CARD_BOX),
        "source_crop_size": [source_width, source_height],
        "resampling": "LANCZOS",
        "width": target_width,
        "height": target_height,
        "scale_from_source": round(target_width / source_width, 6),
        "canvas_bounds": list(box),
        "corner_radius": target_radius,
        "vertical_clearance": {
            "below_clock": round(clock_clearance, 2),
            "above_live_activity": round(activity_clearance, 2),
        },
        "connector_lines": [
            {"from": list(start), "to": list(end)}
            for start, end in connector_lines
        ],
        "layer_order": [
            "phone",
            "character",
            "source_outline_and_connector_lines",
            "callout_shadow",
            "callout_card_and_border",
        ],
    }


def render_ipad_panel(
    panel: int,
    sources: dict[int, Image.Image],
) -> tuple[Image.Image, dict[str, Any]]:
    """Render one iPad 13-inch asset using an iPhone phone mock as the hero."""
    content_panel = CONTENT_PANEL_BY_LAYOUT[panel]
    canvas = dark_background()
    copy_lime_mask: Image.Image | None = None
    copy_lime_polygon: Sequence[tuple[int, int]] | None = None
    if panel == 1:
        copy_lime_polygon = ((0, 170), (2064, 65), (2064, 1110), (0, 1450))
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel in (2, 8):
        copy_lime_polygon = ((0, 0), (2064, 0), (2064, 1460), (0, 1180))
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 3:
        draw_lime_circle(canvas, (1032, 1870), 880)
    elif panel == 4:
        draw_lime_polygon(canvas, ((0, 2070), (2064, 1370), (2064, 2752), (0, 2752)))
    elif panel == 6:
        draw_lime_polygon(canvas, ((0, 1370), (2064, 2070), (2064, 2752), (0, 2752)))
    elif panel == 9:
        draw_lime_polygon(canvas, ((0, 725), (2064, 785), (2064, 915), (0, 855)))
    elif panel == 10:
        draw_lime_polygon(canvas, ((0, 1500), (2064, 1110), (2064, 2752), (0, 2752)))

    content_index = PANEL_IDS.index(content_panel)
    copy_spec = replace(COPY_SPECS[content_index], surface=LAYOUT_SURFACES[panel])
    copy_geometry = draw_ipad_copy_block(canvas, copy_spec)
    if copy_lime_mask is not None:
        if copy_lime_polygon is None:
            raise RuntimeError(f"Panel {panel:02d} iPad lime polygon missing")
        copy_geometry["lime_surface_validation"] = validate_copy_inside_lime_pixels(
            copy_lime_mask,
            copy_geometry,
            panel=panel,
            polygon=copy_lime_polygon,
        )

    source = sources[content_panel]
    straight = IPAD_STRAIGHT_PHONE_WIDTH
    rotated = IPAD_ROTATED_PHONE_WIDTH
    phone_width = rotated if panel in (4, 6) else straight
    rotation = 8 if panel == 4 else (-8 if panel == 6 else 0)
    if panel == 1:
        visual_top = IPAD_BREATH_PHONE_VISUAL_TOP
    elif panel == 3:
        visual_top = IPAD_LOCK_PHONE_VISUAL_TOP
    else:
        visual_top = IPAD_PHONE_VISUAL_TOP
    if panel == 3:
        phone_width = IPAD_LOCK_PHONE_WIDTH
    device = prepare_device(
        source,
        phone_width,
        expected_source_size=IPHONE_CANVAS_SIZE,
    )
    device_center = center_for_visual_top(
        device,
        rotation_deg=rotation,
        visual_top=visual_top,
        center_x=CANVAS_WIDTH / 2,
    )
    device_geometry = place_device(
        canvas,
        device,
        center=device_center,
        rotation_deg=rotation,
    )
    character_geometry: dict[str, Any] | None = None
    if panel == 3:
        character_geometry = place_character(
            canvas,
            name="awake",
            width=round(phone_width / 3),
            rotation_deg=-12,
            flip_horizontal=True,
            center_x=470,
            bottom_y=1060,
        )
        activity_geometry = source_box_canvas_geometry_ipad(
            device,
            source_box=LOCK_ACTIVITY_CARD_BOX,
            center=device_center,
            rotation_deg=rotation,
        )
        device_geometry["live_activity_card"] = activity_geometry
        wider_device = prepare_device(
            source,
            phone_width + 1,
            expected_source_size=IPHONE_CANVAS_SIZE,
        )
        wider_center = center_for_visual_top(
            wider_device,
            rotation_deg=rotation,
            visual_top=visual_top,
            center_x=CANVAS_WIDTH / 2,
        )
        wider_activity = source_box_canvas_geometry_ipad(
            wider_device,
            source_box=LOCK_ACTIVITY_CARD_BOX,
            center=wider_center,
            rotation_deg=rotation,
        )
        if wider_activity["canvas_bounds"][3] <= CANVAS_HEIGHT:
            raise ValueError(
                "IPAD_LOCK_PHONE_WIDTH must be the maximum integer width with "
                "the real Live Activity fully inside the canvas"
            )
        if not activity_geometry["fully_visible"]:
            raise ValueError(f"iPad real Live Activity is clipped: {activity_geometry}")
        clock_geometry = source_box_canvas_geometry_ipad(
            device,
            source_box=IPAD_LOCK_CLOCK_SOURCE_BOX,
            center=device_center,
            rotation_deg=rotation,
        )
        device_geometry["clock"] = clock_geometry
        device_geometry["live_activity_localization"] = {
            "date": LOCK_DATES[LOCALE],
            **live_activity_copy(LOCALE),
            "goals": list(LOCK_GOALS[LOCALE]),
        }
        device_geometry["callout"] = draw_ipad_lock_callout(
            canvas,
            source,
            activity_geometry,
            clock_geometry,
            character_geometry,
        )
    elif panel == 4:
        character_geometry = place_character(
            canvas,
            name="relief",
            width=round(phone_width / 3),
            rotation_deg=rotation,
            center_x=270,
            bottom_y=1170,
        )
    elif panel == 6:
        character_geometry = place_character(
            canvas,
            name="blink",
            width=round(phone_width / 3),
            rotation_deg=rotation,
            center_x=1790,
            bottom_y=1170,
        )
    elif panel == 8:
        character_geometry = place_character(
            canvas,
            name="awake",
            width=round(phone_width / 3),
            center_x=1740,
            bottom_y=1120,
        )
    elif panel == 10:
        character_geometry = place_character(
            canvas,
            name="worse",
            width=round(phone_width / 3),
            center_x=1740,
            bottom_y=1120,
        )

    visible_screen_count = VISIBLE_SCREEN_CHARACTER_COUNTS[content_index]
    if visible_screen_count is None:
        raise ValueError("Stats is intentionally excluded from the iPad upload set")
    external_count = int(character_geometry is not None)
    total_count = visible_screen_count + external_count
    if total_count != 1:
        raise ValueError(f"Panel {panel:02d} must contain exactly one mascot: {total_count}")

    screen_xs = [point[0] for point in device_geometry["screen_corners"].values()]
    outer_xs = [point[0] for point in device_geometry["outer_corners"].values()]
    if min(screen_xs) < 0 or max(screen_xs) > CANVAS_WIDTH:
        raise ValueError(f"Panel {panel:02d} iPad screen exceeds horizontal canvas")
    if min(outer_xs) < 0 or max(outer_xs) > CANVAS_WIDTH:
        raise ValueError(f"Panel {panel:02d} iPad chassis is clipped horizontally")
    width_ratio = phone_width / CANVAS_WIDTH
    if panel in (4, 6):
        wider_device = prepare_device(
            source,
            phone_width + 1,
            expected_source_size=IPHONE_CANVAS_SIZE,
        )
        wider_center = center_for_visual_top(
            wider_device,
            rotation_deg=rotation,
            visual_top=visual_top,
            center_x=CANVAS_WIDTH / 2,
        )
        wider_outer = [
            transform_point(point, wider_device.image.size, wider_center, rotation)
            for point in (
                (0, 0),
                (wider_device.outer_width, 0),
                (wider_device.outer_width, wider_device.outer_height),
                (0, wider_device.outer_height),
            )
        ]
        wider_xs = [point[0] for point in wider_outer]
        if min(wider_xs) >= 0 and max(wider_xs) <= CANVAS_WIDTH:
            raise ValueError(
                "IPAD_ROTATED_PHONE_WIDTH must be the maximum integer width "
                "whose rotated chassis fits horizontally"
            )
    elif panel != 3 and not 0.70 <= width_ratio <= 0.74:
        raise ValueError(f"Panel {panel:02d} phone width ratio out of range: {width_ratio}")
    if character_geometry is not None:
        char_box = character_geometry["visible_alpha_bbox"]
        if char_box[0] < 0 or char_box[1] < 0 or char_box[2] > CANVAS_WIDTH or char_box[3] > CANVAS_HEIGHT:
            raise ValueError(f"Panel {panel:02d} iPad character is clipped: {char_box}")
        copy_boxes = [
            copy_geometry["pill_box"],
            *copy_geometry["headline_boxes"],
            copy_geometry["sub_box"],
        ]
        if any(boxes_overlap(char_box, copy_box) for copy_box in copy_boxes):
            raise ValueError(f"Panel {panel:02d} character overlaps marketing copy")
    corner_attachment = None
    corner_requirements = {
        4: ("relief", "left"),
        6: ("blink", "right"),
        8: ("awake", "right"),
        10: ("worse", "right"),
    }
    if panel in corner_requirements:
        expected_asset, expected_side = corner_requirements[panel]
        corner_attachment = validate_corner_character_geometry(
            panel=panel,
            character_geometry=character_geometry,
            device_geometry=device_geometry,
            copy_geometry=copy_geometry,
            expected_asset=expected_asset,
            expected_side=expected_side,
        )
    if panel == 3:
        if character_geometry is None:
            raise ValueError("iPad lock panel requires the awake mascot")
        char_box = character_geometry["visible_alpha_bbox"]
        phone_corner = device_geometry["outer_corners"]["top_left"]
        if not (
            character_geometry["visible_center_x"] < CANVAS_WIDTH / 2
            and char_box[1] < phone_corner[1] < char_box[3]
            and boxes_overlap(
                char_box,
                (
                    min(outer_xs),
                    min(point[1] for point in device_geometry["outer_corners"].values()),
                    max(outer_xs),
                    max(point[1] for point in device_geometry["outer_corners"].values()),
                ),
            )
        ):
            raise ValueError(
                f"iPad lock mascot must hook over the upper-left phone corner: "
                f"character={char_box}, corner={phone_corner}"
            )
    if canvas.mode != "RGB" or canvas.size != IPAD_CANVAS_SIZE:
        raise ValueError((canvas.mode, canvas.size))
    return canvas, {
        "copy_geometry": copy_geometry,
        "slot": device_geometry,
        "character": character_geometry,
        "corner_attachment": corner_attachment,
        "character_count": {
            "source_screen": SCREEN_CHARACTER_COUNTS[content_index],
            "screen": visible_screen_count,
            "external": external_count,
            "total": total_count,
        },
        "phone_width_ratio": round(width_ratio, 6),
        "horizontal_screen_containment": True,
        "horizontal_chassis_containment": True,
    }


def write_ipad_slots(panel_records: Sequence[dict[str, Any]]) -> None:
    payload = {
        "version": 2,
        "canvas": {"width": 2064, "height": 2752},
        "screen_aspect": "1320:2868",
        "locale": LOCALE,
        "device": "ipad-13",
        "app_store_device_type": "IPAD_PRO_3GEN_129",
        "fonts": font_manifest(LOCALE),
        "screenshots": panel_records,
    }
    SLOTS_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    loaded = json.loads(SLOTS_PATH.read_text(encoding="utf-8"))
    if loaded["canvas"] != {"width": 2064, "height": 2752}:
        raise ValueError(loaded["canvas"])
    if len(loaded["screenshots"]) != 8:
        raise ValueError("iPad slots must contain exactly eight screenshots")


def sync_ipad_upload_order(files_by_panel: dict[int, Path]) -> None:
    upload_root = OUTPUT_ROOT / "upload-order" / LOCALE / "ipad-13"
    upload_root.mkdir(parents=True, exist_ok=True)
    expected_names = {
        f"{position:02d}-{slug}.png"
        for position, (_, slug) in enumerate(UPLOAD_ORDER, start=1)
    }
    for stale_path in upload_root.glob("*.png"):
        if stale_path.name not in expected_names:
            stale_path.unlink()
    for position, (panel, slug) in enumerate(UPLOAD_ORDER, start=1):
        source_path = files_by_panel[panel]
        target_path = upload_root / f"{position:02d}-{slug}.png"
        shutil.copyfile(source_path, target_path)
        validate_png(target_path, IPAD_CANVAS_SIZE)
        if source_path.read_bytes() != target_path.read_bytes():
            raise ValueError(f"iPad upload copy differs from source: {target_path}")
    if len(tuple(upload_root.glob("*.png"))) != 8:
        raise ValueError(f"iPad upload-order must contain exactly eight PNGs: {upload_root}")


def generate_ipad_locale(locale: str) -> None:
    """Generate the eight iPad assets without writing any iPhone artifact."""
    configure_device_context("iphone-69", locale)
    configure_locale(locale)
    sources = {
        content_panel: source_for(content_panel)
        for content_panel in dict.fromkeys(
            CONTENT_PANEL_BY_LAYOUT[panel] for panel, _ in UPLOAD_ORDER
        )
    }
    configure_device_context("ipad-13", locale)
    SCREENSHOT_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    expected_names = {
        f"{panel:02d}-{slug}.png" for panel, slug in UPLOAD_ORDER
    }
    for stale_path in SCREENSHOT_ROOT.glob("*.png"):
        if stale_path.name not in expected_names:
            stale_path.unlink()

    generated: dict[int, tuple[Path, dict[str, Any]]] = {}
    for panel, slug in UPLOAD_ORDER:
        output_path = SCREENSHOT_ROOT / f"{panel:02d}-{slug}.png"
        image, geometry = render_ipad_panel(panel, sources)
        image.save(output_path, format="PNG", compress_level=7)
        validate_png(output_path, IPAD_CANVAS_SIZE)
        generated[panel] = (output_path, geometry)

    files = [generated[panel][0] for panel, _ in UPLOAD_ORDER]
    records = []
    for position, (panel, slug) in enumerate(UPLOAD_ORDER, start=1):
        content_panel = CONTENT_PANEL_BY_LAYOUT[panel]
        output_path, geometry = generated[panel]
        records.append(
            {
                "id": f"{panel:02d}",
                "slug": slug,
                "file": str(output_path.relative_to(OUTPUT_ROOT)),
                "source": SOURCE_LABELS[PANEL_IDS.index(content_panel)],
                "content_panel": content_panel,
                "upload_position": position,
                "slots": [geometry["slot"]],
                "character": geometry["character"],
                "corner_attachment": geometry["corner_attachment"],
                "character_count": geometry["character_count"],
                "copy_geometry": geometry["copy_geometry"],
                "phone_width_ratio": geometry["phone_width_ratio"],
                "horizontal_screen_containment": geometry["horizontal_screen_containment"],
                "horizontal_chassis_containment": geometry["horizontal_chassis_containment"],
            }
        )
    contact_sheet = make_contact_sheet(files)
    expected_contact_size = (400 * len(files), round(400 * 2752 / 2064))
    contact_sheet.save(CONTACT_SHEET_PATH, format="PNG", compress_level=7)
    validate_png(CONTACT_SHEET_PATH, expected_contact_size)
    write_ipad_slots(records)
    sync_ipad_upload_order({panel: generated[panel][0] for panel, _ in UPLOAD_ORDER})
    print(f"Generated 8 iPad screenshots in {SCREENSHOT_ROOT}")
    print(f"Contact sheet: {CONTACT_SHEET_PATH} ({expected_contact_size[0]}x{expected_contact_size[1]} RGB)")
    print(f"Slots: {SLOTS_PATH} (8 entries)")
    configure_device_context("iphone-69", locale)


def make_contact_sheet(files: Sequence[Path]) -> Image.Image:
    thumbnail_width = 400
    thumbnail_height = round(thumbnail_width * CANVAS_HEIGHT / CANVAS_WIDTH)
    expected_size = (thumbnail_width * len(files), thumbnail_height)
    sheet = Image.new("RGB", expected_size, COLORS["background"])
    for index, path in enumerate(files):
        with Image.open(path) as source:
            if source.size != CANVAS_SIZE:
                raise ValueError((path, source.size))
            if source.mode != "RGB":
                raise ValueError((path, source.mode))
            thumbnail = source.resize((thumbnail_width, thumbnail_height), Image.Resampling.LANCZOS)
        sheet.paste(thumbnail, (index * thumbnail_width, 0))
    if sheet.size != expected_size:
        raise ValueError(sheet.size)
    if sheet.mode != "RGB":
        raise ValueError(sheet.mode)
    return sheet


def validate_png(path: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(path) as image:
        if image.format != "PNG":
            raise ValueError((path, image.format))
        if image.size != expected_size:
            raise ValueError((path, image.size))
        if image.mode != "RGB":
            raise ValueError((path, image.mode))


def sync_upload_order(files_by_panel: dict[int, Path]) -> None:
    upload_root = OUTPUT_ROOT / "upload-order" / LOCALE / DEVICE
    upload_root.mkdir(parents=True, exist_ok=True)
    expected_names = {
        f"{position:02d}-{upload_slug}.png"
        for position, (_, upload_slug) in enumerate(UPLOAD_ORDER, start=1)
    }
    for stale_path in upload_root.glob("*.png"):
        if stale_path.name not in expected_names:
            stale_path.unlink()
    for position, (panel, upload_slug) in enumerate(UPLOAD_ORDER, start=1):
        source_path = files_by_panel[panel]
        upload_path = upload_root / f"{position:02d}-{upload_slug}.png"
        shutil.copyfile(source_path, upload_path)
        validate_png(upload_path, CANVAS_SIZE)
        if source_path.read_bytes() != upload_path.read_bytes():
            raise ValueError(f"Upload-order copy differs from source: {upload_path}")
    expected_count = len(UPLOAD_ORDER)
    if len(tuple(upload_root.glob("*.png"))) != expected_count:
        raise ValueError(
            f"Upload-order must contain exactly {expected_count} PNGs: {upload_root}"
        )


def write_slots(panel_records: Sequence[dict[str, Any]]) -> None:
    payload = {
        "version": 2,
        "canvas": {"width": CANVAS_WIDTH, "height": CANVAS_HEIGHT},
        "screen_aspect": "1320:2868",
        "locale": LOCALE,
        "device": DEVICE,
        "fonts": font_manifest(LOCALE),
        "screenshots": panel_records,
    }
    serialized = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    SLOTS_PATH.write_text(serialized, encoding="utf-8")
    if LOCALE == "ja":
        # Preserve the original v2 path while also emitting slots-ja.json like
        # every other locale-specific artifact.
        (OUTPUT_ROOT / "slots.json").write_text(serialized, encoding="utf-8")
    loaded = json.loads(SLOTS_PATH.read_text(encoding="utf-8"))
    if loaded["canvas"] != {"width": 1320, "height": 2868}:
        raise ValueError(loaded["canvas"])
    if loaded["screen_aspect"] != "1320:2868":
        raise ValueError(loaded["screen_aspect"])
    if len(loaded["screenshots"]) != len(UPLOAD_ORDER):
        raise ValueError(len(loaded["screenshots"]))
    if not all(len(item["slots"]) == 1 for item in loaded["screenshots"]):
        raise ValueError("Every screenshot must contain exactly one screen slot")
    if not all("ground_shadow" in item["slots"][0] for item in loaded["screenshots"]):
        raise ValueError("Every slot must include ground_shadow (null when absent)")


def generate_locale(locale: str) -> None:
    configure_locale(locale)
    if not (
        len(COPY_SPECS)
        == len(PANEL_IDS)
        == len(SLUGS)
        == len(SOURCE_PATHS)
        == len(SOURCE_LABELS)
        == len(SCREEN_CHARACTER_COUNTS)
        == len(VISIBLE_SCREEN_CHARACTER_COUNTS)
        == 9
    ):
        raise ValueError("Expected exactly nine aligned panel specifications")
    expected_copy_positions = (COPY_EYEBROW_Y, COPY_HEADLINE_Y, COPY_SUB_Y)
    if any(
        (spec.eyebrow_y, spec.headline_y, spec.sub_y) != expected_copy_positions
        for spec in COPY_SPECS
    ):
        raise ValueError("Every panel must use the shared 240/340/680 copy positions")
    SCREENSHOT_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    expected_panel_names = {
        f"{panel:02d}-{slug}.png" for panel, slug in zip(PANEL_IDS, SLUGS)
    }
    for stale_panel in SCREENSHOT_ROOT.glob("*.png"):
        if stale_panel.name not in expected_panel_names:
            stale_panel.unlink()

    for weight, details in font_manifest(LOCALE).items():
        fallback = " fallback" if details["fallback_used"] else ""
        print(
            f"Font {LOCALE} {weight}:{fallback} {details['path']} "
            f"index={details['face_index']} "
            f"loaded={details['loaded_family']} {details['loaded_style']}"
        )

    generated: dict[int, tuple[Path, dict[str, Any]]] = {}
    render_order = tuple(panel for panel in PANEL_IDS if panel != 4) + (4,)
    for panel in render_order:
        slug = SLUGS[PANEL_IDS.index(panel)]
        output_path = SCREENSHOT_ROOT / f"{panel:02d}-{slug}.png"
        image, geometry = render_panel(panel)
        image.save(output_path, format="PNG", compress_level=7)
        validate_png(output_path, CANVAS_SIZE)
        content_panel = CONTENT_PANEL_BY_LAYOUT[panel]
        generated[panel] = (output_path, geometry)

    files: list[Path] = []
    panel_records: list[dict[str, Any]] = []
    for panel, slug in UPLOAD_ORDER:
        output_path, geometry = generated[panel]
        content_panel = CONTENT_PANEL_BY_LAYOUT[panel]
        files.append(output_path)
        panel_records.append(
            {
                "id": f"{panel:02d}",
                "slug": slug,
                "file": str(output_path.relative_to(OUTPUT_ROOT)),
                "source": SOURCE_LABELS[PANEL_IDS.index(content_panel)],
                "content_panel": content_panel,
                "upload_position": len(panel_records) + 1,
                "slots": [geometry["slot"]],
                "character": geometry["character"],
                "corner_attachment": geometry["corner_attachment"],
                "character_count": geometry["character_count"],
                "copy_geometry": geometry["copy_geometry"],
            }
        )

    contact_sheet = make_contact_sheet(files)
    contact_sheet.save(CONTACT_SHEET_PATH, format="PNG", compress_level=7)
    validate_png(CONTACT_SHEET_PATH, (400 * len(UPLOAD_ORDER), 869))
    write_slots(panel_records)
    sync_upload_order({panel: generated[panel][0] for panel in PANEL_IDS})

    if len(files) != len(UPLOAD_ORDER):
        raise RuntimeError(
            f"Expected {len(UPLOAD_ORDER)} upload screenshots, generated {len(files)}"
        )
    missing_files = [path for path in files if not path.is_file()]
    if missing_files:
        raise FileNotFoundError(missing_files)
    if not CONTACT_SHEET_PATH.is_file():
        raise FileNotFoundError(CONTACT_SHEET_PATH)
    if not SLOTS_PATH.is_file():
        raise FileNotFoundError(SLOTS_PATH)

    print(f"Generated {len(files)} screenshots in {SCREENSHOT_ROOT}")
    for record in panel_records:
        character = record["character"]
        counts = record["character_count"]
        external_description = (
            "none"
            if character is None
            else (
                f"{character['asset']} visible_alpha_bbox="
                f"{tuple(character['visible_alpha_bbox'])} "
                f"center_x={character['visible_center_x']} "
                f"bottom_y={character['visible_bottom_y']}"
            )
        )
        print(
            f"{record['id']}-{record['slug']}.png: 1320x2868 RGB; "
            f"characters raw_screen={counts['source_screen']} "
            f"visible_screen={counts['screen']} external={counts['external']} "
            f"total={counts['total']}; external_asset={external_description}"
        )
    print(
        f"Contact sheet: {CONTACT_SHEET_PATH} "
        f"({400 * len(UPLOAD_ORDER)}x869 RGB)"
    )
    print(f"Slots: {SLOTS_PATH} ({len(panel_records)} entries)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate DopaBreak App Store screenshots v2 by locale."
    )
    parser.add_argument(
        "--locale",
        dest="locales",
        action="append",
        choices=SUPPORTED_LOCALES,
        help="Generate only this locale. Repeat to generate more than one; omit for all.",
    )
    parser.add_argument(
        "--device",
        choices=SUPPORTED_DEVICES,
        default="iphone-69",
        help="Generate iPhone 6.9-inch (default) or iPad 13-inch marketing assets.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    locales = tuple(dict.fromkeys(args.locales or SUPPORTED_LOCALES))
    for locale in locales:
        if args.device == "ipad-13":
            generate_ipad_locale(locale)
        else:
            configure_device_context("iphone-69", locale)
            generate_locale(locale)


if __name__ == "__main__":
    main()
