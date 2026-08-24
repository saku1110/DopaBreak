#!/usr/bin/env python3
"""Generate localized DopaBreak App Store screenshots v2 for iPhone 6.9-inch.

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
from dataclasses import dataclass
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
SCREEN_ASPECT = (1320, 2868)
SUPPORTED_LOCALES = ("ja", "en-US", "ko")
LOCALE = "ja"
DEVICE = "iphone-69"
AA_SCALE = 4

COPY_EYEBROW_Y = 240
COPY_HEADLINE_Y = 340
COPY_SUB_Y = 680
PANEL_01_LIME_POLYGON = ((0, 200), (1320, 80), (1320, 1080), (0, 1420))
PANEL_08_LIME_POLYGON = ((0, 80), (1320, 200), (1320, 1420), (0, 1080))


def lock_pt_to_px(points: float, screen_width: int = CANVAS_WIDTH) -> int:
    """Convert SwiftUI points to pixels for the 3x lock-screen source."""
    return round(points * 3 * screen_width / 1320)

CHARACTER_GROUND_SHADOW_WIDTH_RATIO = 0.70
CHARACTER_GROUND_SHADOW_HEIGHT = 90
CHARACTER_GROUND_SHADOW_OPACITY = 0.30
CHARACTER_GROUND_SHADOW_BLUR = 30
PHONE_GROUND_SHADOW_WIDTH_RATIO = 0.85
PHONE_GROUND_SHADOW_HEIGHT = 110
PHONE_GROUND_SHADOW_OPACITY = 0.35
PHONE_GROUND_SHADOW_BLUR = 40

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
PANEL_05_CALLOUT_WIDTH = 1180
PANEL_05_CALLOUT_TOP = 1390
PANEL_05_CALLOUT_BORDER_WIDTH = 3
PANEL_05_SOURCE_OUTLINE_WIDTH = 2
PANEL_05_CONNECTOR_WIDTH = 2
PANEL_05_CONNECTOR_OPACITY = 0.60
PANEL_05_CALLOUT_SHADOW_OPACITY = 0.45
PANEL_05_CALLOUT_SHADOW_BLUR = 50
PANEL_05_CALLOUT_SHADOW_OFFSET = (0, 24)

SLUGS = (
    "hook",
    "pause",
    "intent-time",
    "modes",
    "goal-lockscreen",
    "reflection-stats",
    "privacy-settings",
    "deep-focus",
    "night-block",
    "grayscale-guide",
)

MODES_SOURCE_PATH = (
    RAW_CORE_ROOT / "modes.png"
    if (RAW_CORE_ROOT / "modes.png").is_file()
    else RAW_CORE_ROOT / "home.png"
)
SOURCE_PATHS: tuple[Path | None, ...] = (
    RAW_CORE_ROOT / "stats.png",
    RAW_CORE_ROOT / "breath.png",
    RAW_CORE_ROOT / "intent.png",
    MODES_SOURCE_PATH,
    None,
    RAW_CORE_ROOT / "reflection.png",
    RAW_CORE_ROOT / "goals.png",
    RAW_CORE_ROOT / "deepfocus.png",
    RAW_CORE_ROOT / "nightmode.png",
    RAW_CORE_ROOT / "grayscale.png",
)
SOURCE_LABELS = tuple(
    "mock_lock((1320, 2868), 'ja')"
    if path is None
    else path.relative_to(ROOT).as_posix()
    for path in SOURCE_PATHS
)

# 実画面を原寸で目視した個体数。外乗せと合算し、各枚1体以下を検証する。
SCREEN_CHARACTER_COUNTS = (
    0,  # stats
    1,  # breath
    0,  # intent
    0 if MODES_SOURCE_PATH.name == "modes.png" else 1,  # modes / home fallback
    0,  # lock mock
    1,  # reflection（1問目・未選択）
    0,  # goals
    0,  # deep focus settings
    0,  # night-only settings
    0,  # grayscale automation guide
)


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
            "SNS時間を見える化",
            "「あと5分だけ」が",
            "1年で35日になる",
            "回答から無意識スクロールの時間を推計",
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
            "理由と時間を選ぶ",
            "何のために開く？",
            "必要な時間だけ使う",
            "目的を言葉にして5〜30分から選べます",
            "dark",
        ),
        _copy_spec(
            "目標と実績をひとつの画面に",
            "我慢できた回数が",
            "数字で増える",
            "今日と今週の合計をホームでいつでも確認",
            "lime",
        ),
        _copy_spec(
            "ロック画面・通知・ウィジェット",
            "SNSを開くたびに",
            "目標を確認",
            "ロック画面に目標と開くのをやめた回数を表示",
            "dark",
        ),
        _copy_spec(
            "振り返りと統計",
            "SNSのあと本音を記録",
            "開くのをやめた回数も記録",
            "満足感と開こうとした回数を見える化",
            "dark",
        ),
        _copy_spec(
            "オンデバイスで安心",
            "記録は端末の中だけ",
            "無料で始められます",
            "対象アプリ・呼吸時間・通知をいつでも調整",
            "dark",
        ),
        _copy_spec(
            "集中タイマーで完全ブロック",
            "集中したい時間だけ",
            "選んだアプリを止める",
            "勉強や仕事の30分〜2時間 曜日と時間帯の予約も",
            "lime",
        ),
        _copy_spec(
            "夜だけ強化",
            "就寝中は自動で",
            "完全ブロック",
            "夜ふかしスクロールを就寝・起床の時刻で断つ",
            "dark",
        ),
        _copy_spec(
            "白黒フィルタ連携",
            "SNSを開くと",
            "画面が白黒になる",
            "閉じると色は戻る ガイドどおり設定するだけ",
            "dark",
        ),
    ),
    "en-US": (
        _copy_spec(
            "SEE THE COST OF DOOMSCROLLING",
            "“Five more minutes”",
            "can become 35 days a year",
            "Answer a few questions to see how much time your phone takes.",
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
            "CHOOSE A REASON AND A TIME",
            "Know why you’re opening",
            "Use only what you need",
            "Name your purpose, then pick 5 to 30 minutes",
            "dark",
        ),
        _copy_spec(
            "A DETOX YOU CAN ACTUALLY KEEP",
            "Dopamine detox,",
            "one skipped open at a time",
            "Every open you skip gets counted, so the number keeps climbing.",
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
            "HABIT TRACKER AND CHECK-INS",
            "Check in after you scroll",
            "Count every time you didn’t open",
            "Log how you felt, then see your attempts and skipped opens",
            "dark",
        ),
        _copy_spec(
            "PRIVATE BY DESIGN",
            "Your records stay on device",
            "Start free",
            "Adjust paused apps, breath length, and reminders anytime",
            "dark",
        ),
        _copy_spec(
            "BLOCK ON YOUR SCHEDULE",
            "Pick the hours you need to focus",
            "and those apps stay shut",
            "Start 30 minutes to 2 hours now, or set weekly time slots",
            "lime",
        ),
        _copy_spec(
            "STRONGER AT NIGHT",
            "Your bedtime hours",
            "block themselves",
            "Late-night scrolling stops at the bedtime and wake times you set",
            "dark",
        ),
        _copy_spec(
            "GRAYSCALE SHORTCUT",
            "Open social media",
            "and your screen turns gray",
            "Color returns when you close it. Just follow the guide.",
            "dark",
        ),
    ),
    "ko": (
        _copy_spec(
            "숏폼·SNS 시간 셀프 체크",
            "‘5분만 더’가",
            "1년에 35일이 돼요",
            "답변을 바탕으로 무심코 스크롤한 시간을 추정해요",
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
            "이유와 시간 선택",
            "왜 여는지 먼저 확인",
            "필요한 만큼만 사용해요",
            "목적을 고르고 5~30분 중 필요한 시간만 선택해요",
            "dark",
        ),
        _copy_spec(
            "목표와 기록을 한 화면에",
            "참아낸 횟수가",
            "숫자로 늘어나요",
            "오늘과 이번 주 합계를 홈에서 바로 확인해요",
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
            "사용 후 돌아보기와 루틴 통계",
            "SNS를 본 뒤 기분을 기록",
            "열지 않은 횟수도 쌓여요",
            "만족감·시도·열지 않은 횟수를 한눈에 봐요",
            "dark",
        ),
        _copy_spec(
            "기기 안에 안전하게",
            "기록은 기기 안에만",
            "무료로 시작해요",
            "대상 앱·숨 고르기 시간·알림을 언제든 조절해요",
            "dark",
        ),
        _copy_spec(
            "공부·업무 시간 완전 차단",
            "집중할 시간만 골라서",
            "앱을 멈춰요",
            "지금 30분에서 2시간 요일과 시간대 예약도 돼요",
            "lime",
        ),
        _copy_spec(
            "밤에만 강하게",
            "잠든 사이엔 자동으로",
            "완전 차단",
            "늦은 밤 스크롤을 취침 기상 시각으로 끊어요",
            "dark",
        ),
        _copy_spec(
            "흑백 필터 연동",
            "SNS를 열면",
            "화면이 흑백이 돼요",
            "닫으면 색이 돌아와요 안내대로 설정만 하면 끝",
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
    for panel_index in (0, 1, 2, 3, 5, 6):
        legacy = LEGACY.COPY[locale][panel_index]
        expected = (
            legacy["eyebrow"],
            tuple(line.format(days=days) for line in legacy["headline"]),
            legacy["sub"],
        )
        actual_spec = COPY[locale][panel_index]
        actual = (actual_spec.eyebrow, actual_spec.headline, actual_spec.sub)
        if actual != expected:
            raise ValueError(
                f"Panel {panel_index + 1:02d} {locale} copy differs from legacy: "
                f"expected={expected!r}, actual={actual!r}"
            )


def configure_locale(locale: str) -> None:
    global LOCALE
    global SCREENSHOT_ROOT, CONTACT_SHEET_PATH, SLOTS_PATH, RAW_CORE_ROOT
    global MODES_SOURCE_PATH, SOURCE_PATHS, SOURCE_LABELS
    global SCREEN_CHARACTER_COUNTS, COPY_SPECS

    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported locale: {locale}")

    LOCALE = locale
    SCREENSHOT_ROOT = OUTPUT_ROOT / locale / DEVICE
    CONTACT_SHEET_PATH = OUTPUT_ROOT / f"contact-sheet-{locale}.png"
    SLOTS_PATH = OUTPUT_ROOT / f"slots-{locale}.json"
    RAW_CORE_ROOT = ROOT / "output" / "app-store-screenshots" / "raw-core" / locale
    MODES_SOURCE_PATH = (
        RAW_CORE_ROOT / "modes.png"
        if (RAW_CORE_ROOT / "modes.png").is_file()
        else RAW_CORE_ROOT / "home.png"
    )
    SOURCE_PATHS = (
        RAW_CORE_ROOT / "stats.png",
        RAW_CORE_ROOT / "breath.png",
        RAW_CORE_ROOT / "intent.png",
        MODES_SOURCE_PATH,
        None,
        RAW_CORE_ROOT / "reflection.png",
        RAW_CORE_ROOT / "goals.png",
        RAW_CORE_ROOT / "deepfocus.png",
        RAW_CORE_ROOT / "nightmode.png",
        RAW_CORE_ROOT / "grayscale.png",
    )
    SOURCE_LABELS = tuple(
        f"mock_lock((1320, 2868), {locale!r})"
        if path is None
        else path.relative_to(ROOT).as_posix()
        for path in SOURCE_PATHS
    )
    SCREEN_CHARACTER_COUNTS = (
        0,
        1,
        0,
        0 if MODES_SOURCE_PATH.name == "modes.png" else 1,
        0,
        1,
        0,
        0,
        0,
        0,
    )
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

    clock_target_width = round(size[0] * 0.55)
    clock_image, _ = sf_text_fitted_to_width(
        "9:41",
        clock_target_width,
        weight=620,
        maximum_size=430,
        fill=(248, 249, 247),
    )
    paste_centered_image(image, clock_image, 350)

    draw_live_activity_card(image, locale)

    draw_lock_bottom_controls(image)
    return image


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


def prepare_device(source: Image.Image, outer_width: int) -> PreparedDevice:
    bezel = round(outer_width * 0.0275)
    outer_radius = round(outer_width * 0.148)
    screen_width = outer_width - bezel * 2
    screen_height = round(screen_width * SCREEN_ASPECT[1] / SCREEN_ASPECT[0])
    outer_height = screen_height + bezel * 2
    screen_radius = outer_radius - bezel

    if source.size != CANVAS_SIZE:
        raise ValueError(f"Device source must be {CANVAS_SIZE}, got {source.size}")
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


def draw_panel_05_live_activity_callout(
    canvas: Image.Image,
    source: Image.Image,
    live_activity_geometry: dict[str, Any],
) -> dict[str, Any]:
    """Magnify the full-resolution lock-screen card above its in-phone source."""
    if source.size != CANVAS_SIZE:
        raise ValueError(f"Panel 05 callout source must be {CANVAS_SIZE}, got {source.size}")

    source_crop = source.crop(LOCK_ACTIVITY_CARD_BOX)
    source_width, source_height = source_crop.size
    target_width = PANEL_05_CALLOUT_WIDTH
    target_height = round(source_height * target_width / source_width)
    if target_width >= source_width or target_height >= source_height:
        raise ValueError(
            "Panel 05 Live Activity callout must be a LANCZOS downscale "
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
    callout_top = PANEL_05_CALLOUT_TOP
    callout_right = callout_left + target_width
    callout_bottom = callout_top + target_height
    callout_box = (callout_left, callout_top, callout_right, callout_bottom)
    if callout_top < 1250 or callout_bottom > 1800:
        raise ValueError(f"Panel 05 callout must stay inside the y≈1250–1800 band: {callout_box}")

    actual_bounds = live_activity_geometry["canvas_bounds"]
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
    paste_rounded_outline(
        canvas,
        actual_box,
        radius=actual_radius,
        width=PANEL_05_SOURCE_OUTLINE_WIDTH,
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
    paste_antialiased_lines(
        canvas,
        connector_lines,
        fill=(
            *COLORS["lime"],
            round(255 * PANEL_05_CONNECTOR_OPACITY),
        ),
        width=PANEL_05_CONNECTOR_WIDTH,
    )

    shadow_alpha = Image.new("L", CANVAS_SIZE, 0)
    shadow_alpha.paste(
        card_mask,
        (
            callout_left + PANEL_05_CALLOUT_SHADOW_OFFSET[0],
            callout_top + PANEL_05_CALLOUT_SHADOW_OFFSET[1],
        ),
    )
    paste_black_shadow(
        canvas,
        shadow_alpha,
        blur=PANEL_05_CALLOUT_SHADOW_BLUR,
        opacity=round(255 * PANEL_05_CALLOUT_SHADOW_OPACITY),
    )
    canvas.paste(scaled_card, (callout_left, callout_top), scaled_card.getchannel("A"))
    paste_rounded_outline(
        canvas,
        callout_box,
        radius=target_radius,
        width=PANEL_05_CALLOUT_BORDER_WIDTH,
        fill=COLORS["lime"],
    )

    actual_display_width = actual_bounds[2] - actual_bounds[0]
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
        "border": {
            "color": "#C7F94D",
            "width": PANEL_05_CALLOUT_BORDER_WIDTH,
        },
        "shadow": {
            "color": "#000000",
            "opacity": PANEL_05_CALLOUT_SHADOW_OPACITY,
            "blur": PANEL_05_CALLOUT_SHADOW_BLUR,
            "offset": list(PANEL_05_CALLOUT_SHADOW_OFFSET),
        },
        "source_outline": {
            "canvas_bounds": [round(value, 2) for value in actual_bounds],
            "canvas_corners": actual_corners,
            "connector_anchors": source_connector_anchors,
            "corner_radius": actual_radius,
            "border": {
                "color": "#C7F94D",
                "width": PANEL_05_SOURCE_OUTLINE_WIDTH,
            },
        },
        "connector_lines": [
            {
                "from": list(start),
                "to": list(end),
                "color": "#C7F94D",
                "width": PANEL_05_CONNECTOR_WIDTH,
                "opacity": PANEL_05_CONNECTOR_OPACITY,
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
    if panel not in range(1, 11):
        raise ValueError(panel)
    source_path = SOURCE_PATHS[panel - 1]
    if source_path is None:
        source = mock_lock(CANVAS_SIZE, LOCALE).convert("RGB")
    else:
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        with Image.open(source_path) as raw_source:
            source = raw_source.convert("RGB")
    if source.size != CANVAS_SIZE:
        raise ValueError((panel, source.size))
    return source


def render_panel(panel: int) -> tuple[Image.Image, dict[str, Any]]:
    if panel not in range(1, 11):
        raise ValueError(panel)

    canvas = dark_background()

    copy_lime_mask = None
    copy_lime_polygon: Sequence[tuple[int, int]] | None = None
    if panel == 1:
        copy_lime_polygon = PANEL_01_LIME_POLYGON
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 2:
        draw_lime_polygon(canvas, ((0, 1720), (1320, 1400), (1320, 1560), (0, 1880)))
    elif panel == 3:
        draw_lime_polygon(canvas, ((0, 2100), (1320, 1520), (1320, 2868), (0, 2868)))
    elif panel == 4:
        draw_lime_polygon(canvas, ((0, 0), (1320, 0), (1320, 1450), (0, 1170)))
    elif panel == 5:
        draw_lime_circle(canvas, (660, 1800), 680)
    elif panel == 6:
        draw_lime_polygon(canvas, ((0, 1520), (1320, 2100), (1320, 2868), (0, 2868)))
    elif panel == 7:
        draw_lime_polygon(canvas, ((0, 2320), (1320, 2240), (1320, 2868), (0, 2868)))
    elif panel == 8:
        copy_lime_polygon = PANEL_08_LIME_POLYGON
        copy_lime_mask = draw_lime_polygon(canvas, copy_lime_polygon)
    elif panel == 9:
        draw_lime_polygon(canvas, ((0, 1400), (1320, 1720), (1320, 1880), (0, 1560)))
    elif panel == 10:
        draw_lime_polygon(canvas, ((0, 1450), (1320, 1170), (1320, 2868), (0, 2868)))

    copy_geometry = draw_copy_block(canvas, COPY_SPECS[panel - 1])
    if copy_lime_mask is not None:
        if copy_lime_polygon is None:
            raise RuntimeError(f"Panel {panel:02d} lime polygon was not recorded")
        copy_geometry["lime_surface_validation"] = validate_copy_inside_lime_pixels(
            copy_lime_mask,
            copy_geometry,
            panel=panel,
            polygon=copy_lime_polygon,
        )
    source = source_for(panel)
    screen_character_count = SCREEN_CHARACTER_COUNTS[panel - 1]

    if panel == 1:
        device = prepare_device(source, 1060)
        device_geometry = place_device(
            canvas,
            device,
            center=(660, 1050 + device.outer_height / 2),
            rotation_deg=0,
        )
        character_geometry = place_character(
            canvas,
            name="doom",
            width=440,
            rotation_deg=-6,
            center_x=1030,
            bottom_y=1330,
        )
    elif panel == 2:
        device = prepare_device(source, 1000)
        device_center = (660, 2100)
        device_rotation = -7
        device_geometry = place_device(
            canvas,
            device,
            center=device_center,
            rotation_deg=device_rotation,
        )
        character_geometry = None
    elif panel == 3:
        device = prepare_device(source, 980)
        device_geometry = {}

        def place_panel_3_device() -> None:
            device_geometry.update(
                place_device(
                    canvas,
                    device,
                    center=(560, 2050),
                    rotation_deg=8,
                )
            )

        character_geometry = place_character(
            canvas,
            name="awake",
            width=400,
            center_x=1080,
            bottom_y=2350,
            has_ground_shadow=True,
            after_ground_shadow=place_panel_3_device,
        )
    elif panel == 4:
        device = prepare_device(source, 1060)
        device_geometry = place_device(
            canvas,
            device,
            center=(660, 1000 + device.outer_height / 2),
            rotation_deg=0,
        )
        character_geometry = None
    elif panel == 5:
        device = prepare_device(source, 1000)
        device_center = (660, 830 + device.outer_height / 2)
        device_rotation = 0
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
        device_geometry["live_activity_localization"] = {
            "date": LOCK_DATES[LOCALE],
            **live_activity_copy(LOCALE),
            "goals": list(LOCK_GOALS[LOCALE]),
        }
        character_geometry = place_character(
            canvas,
            name="awake",
            width=300,
            rotation_deg=-12,
            flip_horizontal=True,
            center_x=230,
            bottom_y=1050,
        )
    elif panel == 6:
        device = prepare_device(source, 980)
        device_geometry = place_device(
            canvas,
            device,
            center=(760, 2050),
            rotation_deg=-8,
        )
        character_geometry = None
    elif panel == 7:
        device = prepare_device(source, 780)
        device_ground_shadow_geometry = ground_shadow(
            canvas,
            center_x=660,
            contact_y=2620,
            width=round(device.outer_width * PHONE_GROUND_SHADOW_WIDTH_RATIO),
            height=PHONE_GROUND_SHADOW_HEIGHT,
            opacity=PHONE_GROUND_SHADOW_OPACITY,
            blur=PHONE_GROUND_SHADOW_BLUR,
        )
        device_geometry = {}

        def place_panel_7_device() -> None:
            device_geometry.update(
                place_device(
                    canvas,
                    device,
                    center=(660, 2620 - device.outer_height / 2),
                    rotation_deg=0,
                )
            )
            device_geometry["ground_shadow"] = device_ground_shadow_geometry

        character_geometry = place_character(
            canvas,
            name="relief",
            width=340,
            center_x=1140,
            bottom_y=2620,
            has_ground_shadow=True,
            after_ground_shadow=place_panel_7_device,
        )
    elif panel == 8:
        device = prepare_device(source, 1060)
        device_geometry = place_device(
            canvas,
            device,
            center=(660, 1050 + device.outer_height / 2),
            rotation_deg=0,
        )
        character_geometry = place_character(
            canvas,
            name="blink",
            width=440,
            rotation_deg=6,
            center_x=290,
            bottom_y=1330,
        )
    elif panel == 9:
        device = prepare_device(source, 1000)
        device_geometry = place_device(
            canvas,
            device,
            center=(660, 2100),
            rotation_deg=7,
        )
        character_geometry = place_character(
            canvas,
            name="relief",
            width=400,
            rotation_deg=7,
            center_x=1050,
            bottom_y=1300,
        )
    else:
        device = prepare_device(source, 1060)
        device_geometry = {}

        def place_panel_10_device() -> None:
            device_geometry.update(
                place_device(
                    canvas,
                    device,
                    center=(660, 1000 + device.outer_height / 2),
                    rotation_deg=0,
                )
            )

        character_geometry = place_character(
            canvas,
            name="worse",
            width=340,
            center_x=220,
            bottom_y=2500,
            has_ground_shadow=True,
            after_ground_shadow=place_panel_10_device,
        )

    if panel == 5:
        callout_geometry = draw_panel_05_live_activity_callout(
            canvas,
            source,
            device_geometry["live_activity_card"],
        )
        callout_box = callout_geometry["canvas_bounds"]
        copy_boxes = [
            copy_geometry["pill_box"],
            *copy_geometry["headline_boxes"],
            copy_geometry["sub_box"],
        ]
        if any(boxes_overlap(callout_box, box) for box in copy_boxes):
            raise ValueError(
                f"Panel 05 callout must not overlap the copy block: {callout_box}"
            )
        if character_geometry is not None and boxes_overlap(
            callout_box,
            character_geometry["visible_alpha_bbox"],
        ):
            raise ValueError(
                "Panel 05 callout must not overlap the character: "
                f"{callout_box} vs {character_geometry['visible_alpha_bbox']}"
            )
        callout_geometry["overlap_checks"] = {
            "copy": False,
            "character": False,
        }
        device_geometry["callout"] = callout_geometry

    external_character_count = 0 if character_geometry is None else 1
    total_character_count = screen_character_count + external_character_count
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
    if panel == 5:
        if not device_geometry["live_activity_card"]["fully_visible"]:
            raise ValueError(
                "Panel 05 Live Activity card must be fully visible: "
                f"{device_geometry['live_activity_card']['canvas_bounds']}"
            )
    return canvas, {
        "copy_geometry": copy_geometry,
        "slot": device_geometry,
        "character": character_geometry,
        "character_count": {
            "screen": screen_character_count,
            "external": external_character_count,
            "total": total_character_count,
        },
    }


def make_contact_sheet(files: Sequence[Path]) -> Image.Image:
    thumbnail_width = 400
    thumbnail_height = round(thumbnail_width * CANVAS_HEIGHT / CANVAS_WIDTH)
    sheet = Image.new("RGB", (thumbnail_width * len(files), thumbnail_height), COLORS["background"])
    for index, path in enumerate(files):
        with Image.open(path) as source:
            if source.size != CANVAS_SIZE:
                raise ValueError((path, source.size))
            if source.mode != "RGB":
                raise ValueError((path, source.mode))
            thumbnail = source.resize((thumbnail_width, thumbnail_height), Image.Resampling.LANCZOS)
        sheet.paste(thumbnail, (index * thumbnail_width, 0))
    if sheet.size != (4000, 869):
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
    if len(loaded["screenshots"]) != 10:
        raise ValueError(len(loaded["screenshots"]))
    if not all(len(item["slots"]) == 1 for item in loaded["screenshots"]):
        raise ValueError("Every screenshot must contain exactly one screen slot")
    if not all("ground_shadow" in item["slots"][0] for item in loaded["screenshots"]):
        raise ValueError("Every slot must include ground_shadow (null when absent)")


def generate_locale(locale: str) -> None:
    configure_locale(locale)
    if not (
        len(COPY_SPECS)
        == len(SLUGS)
        == len(SOURCE_PATHS)
        == len(SOURCE_LABELS)
        == len(SCREEN_CHARACTER_COUNTS)
        == 10
    ):
        raise ValueError("Expected exactly ten aligned panel specifications")
    expected_copy_positions = (COPY_EYEBROW_Y, COPY_HEADLINE_Y, COPY_SUB_Y)
    if any(
        (spec.eyebrow_y, spec.headline_y, spec.sub_y) != expected_copy_positions
        for spec in COPY_SPECS
    ):
        raise ValueError("Every panel must use the shared 240/340/680 copy positions")
    SCREENSHOT_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

    for weight, details in font_manifest(LOCALE).items():
        fallback = " fallback" if details["fallback_used"] else ""
        print(
            f"Font {LOCALE} {weight}:{fallback} {details['path']} "
            f"index={details['face_index']} "
            f"loaded={details['loaded_family']} {details['loaded_style']}"
        )

    files: list[Path] = []
    panel_records: list[dict[str, Any]] = []
    for panel, slug in enumerate(SLUGS, start=1):
        image, geometry = render_panel(panel)
        output_path = SCREENSHOT_ROOT / f"{panel:02d}-{slug}.png"
        image.save(output_path, format="PNG", compress_level=7)
        validate_png(output_path, CANVAS_SIZE)
        files.append(output_path)
        panel_records.append(
            {
                "id": f"{panel:02d}",
                "slug": slug,
                "file": str(output_path.relative_to(OUTPUT_ROOT)),
                "source": SOURCE_LABELS[panel - 1],
                "slots": [geometry["slot"]],
                "character": geometry["character"],
                "character_count": geometry["character_count"],
                "copy_geometry": geometry["copy_geometry"],
            }
        )

    contact_sheet = make_contact_sheet(files)
    contact_sheet.save(CONTACT_SHEET_PATH, format="PNG", compress_level=7)
    validate_png(CONTACT_SHEET_PATH, (4000, 869))
    write_slots(panel_records)

    if len(files) != 10:
        raise RuntimeError(f"Expected ten screenshots, generated {len(files)}")
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
            f"characters screen={counts['screen']} external={counts['external']} "
            f"total={counts['total']}; external_asset={external_description}"
        )
    print(f"Contact sheet: {CONTACT_SHEET_PATH} (4000x869 RGB)")
    print(f"Slots: {SLOTS_PATH} (10 entries)")


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
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    locales = tuple(dict.fromkeys(args.locales or SUPPORTED_LOCALES))
    for locale in locales:
        generate_locale(locale)


if __name__ == "__main__":
    main()
