#!/usr/bin/env python3
"""Compose the ten real Live Activity themes using the existing store design.

Capture inputs with LockThemeDensitySnapshotCapture.testCaptureAppStoreThemeGallery.
This is a standalone additional panel; the existing upload sets are not rewritten.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output/app-store-screenshots/theme-gallery"
THEMES = (
    "e1", "gaming", "asagiri", "monochrome", "liquidGlassV3",
    "kpop", "kawaiiPink", "note", "blueprint", "spiderWeb",
)
COPY = {
    "ja": {
        "eyebrow": "選べるロック画面",
        "headline": ("あなたの目標を", "好きなデザインで"),
        "sub": "10種類から選べる 目標カードのデザイン",
        "free": "無料",
        "footer": "黒とライムは無料 ほか9種類はPro",
    },
    "en-US": {
        "eyebrow": "LOCK SCREEN STYLES",
        "headline": ("Keep your goals", "in a style you love"),
        "sub": "Choose from 10 lock screen designs",
        "free": "Free",
        "footer": "Black & Lime is free · 9 more designs with Pro",
    },
    "ko": {
        "eyebrow": "골라 쓰는 잠금 화면",
        "headline": ("내 목표를", "좋아하는 디자인으로"),
        "sub": "잠금 화면 목표 카드 10종 중에서 골라보세요",
        "free": "무료",
        "footer": "블랙 & 라임은 무료 · 나머지 9종은 Pro",
    },
}


def theme_labels(locale: str) -> dict[str, str]:
    catalog = json.loads((ROOT / "ios/DopaBreak/Localizable.xcstrings").read_text())
    language = "en" if locale == "en-US" else locale
    return {
        theme: catalog["strings"][f"lock_surface.theme.{'liquidGlass' if theme == 'liquidGlassV3' else theme}"]["localizations"][language]["stringUnit"]["value"]
        for theme in THEMES
    }


def load_design():
    spec = importlib.util.spec_from_file_location(
        "store_v2", ROOT / "scripts/generate-appstore-screenshots-v2.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load the existing screenshot design")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(locale: str, device: str = "iphone-69", *, store_set: bool = False):
    capture = json.loads((OUTPUT / "raw" / locale / "capture.json").read_text())
    if capture.get("themes") != list(THEMES):
        raise ValueError(f"Capture theme list differs from the gallery: {locale}; recapture the current app")
    design = load_design()
    design.LOCALE = locale
    ipad = device == "ipad-13"
    if ipad:
        design.CANVAS_SIZE = (2064, 2752)
        design.CANVAS_WIDTH, design.CANVAS_HEIGHT = design.CANVAS_SIZE
    localized_copy = COPY[locale]
    labels = theme_labels(locale)
    canvas = design.dark_background()
    if store_set:
        design.draw_lime_polygon(canvas, ((0, 700), (design.CANVAS_WIDTH, 780),
                                         (design.CANVAS_WIDTH, 860), (0, 780)))
    copy = design._copy_spec(
        localized_copy["eyebrow"],
        *localized_copy["headline"],
        localized_copy["sub"],
        "dark",
    )
    copy_geometry = (design.draw_ipad_copy_block if ipad else design.draw_copy_block)(canvas, copy)
    width = 700 if ipad else 582
    height = round(width * 160 / 393)
    first_y = 760 if ipad else 880
    stride = 370 if ipad else 354
    items = []

    for index, identifier in enumerate(THEMES):
        label = labels[identifier]
        path = OUTPUT / "raw" / locale / f"{identifier}.png"
        with Image.open(path) as source:
            if source.size != (1179, 480):
                raise ValueError(f"Unexpected capture size: {path}: {source.size}")
            if max(high - low for low, high in source.convert("RGB").getextrema()) < 30:
                raise ValueError(f"Blank or unreadable capture: {path}")
            card = source.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
        x = (1320 - width) // 2 if len(THEMES) % 2 and index == len(THEMES) - 1 else 48 + (index % 2) * 642
        if ipad:
            x = 282 + (index % 2) * 800
        y = first_y + (index // 2) * stride
        # Match the canonical 22pt continuous preview radius while removing only
        # the capture window's background outside the card.
        mask_scale = 4
        mask = Image.new("L", (width * mask_scale, height * mask_scale), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, width * mask_scale - 1, height * mask_scale - 1),
            radius=round(22 * width / 393 * mask_scale),
            fill=255,
        )
        mask = mask.resize((width, height), Image.Resampling.LANCZOS)
        canvas.paste(card, (x, y), mask)

        caption = design.tight_text_image(label, 38 if ipad else 34, design.COLORS["off_white"], bold=True)
        label_y = y + height + 24
        canvas.paste(caption, (x + 10, label_y), caption.getchannel("A"))
        badge_box = None
        if not store_set:
            badge_text = localized_copy["free"] if identifier == "e1" else "Pro"
            badge_ink = design.COLORS["lime"] if identifier == "e1" else (187, 193, 203)
            badge_fill = design.COLORS["dark_pill"] if identifier == "e1" else (29, 33, 39)
            badge = design.tight_text_image(badge_text, 26, badge_ink, bold=True)
            badge_width, badge_height = badge.width + 30, 44
            badge_x = x + width - badge_width - 8
            badge_y = label_y - 7
            badge_box = (badge_x, badge_y, badge_x + badge_width, badge_y + badge_height)
            design.paste_solid_rounded_rect(canvas, badge_box, badge_height // 2, badge_fill)
            canvas.paste(
                badge,
                (badge_x + 15, badge_y + (badge_height - badge.height) // 2),
                badge.getchannel("A"),
            )
            if x + 10 + caption.width + 16 > badge_x:
                raise ValueError(f"Label overlaps badge: {identifier}")
        items.append({
            "theme": identifier,
            "label": label,
            "tier": "free" if identifier == "e1" else "pro",
            "source": str(path.relative_to(ROOT)),
            "sha256": sha256(path),
            "card_box": [x, y, x + width, y + height],
            "label_box": [x + 10, label_y, x + 10 + caption.width, label_y + caption.height],
            "badge_box": list(badge_box) if badge_box else None,
        })

    footer_box = None
    character = None
    if store_set:
        character = design.place_character(
            canvas, name="awake", width=250, rotation_deg=0,
            center_x=150 if ipad else design.CANVAS_WIDTH // 2, bottom_y=design.CANVAS_HEIGHT - 18,
        )
        character_box = character["visible_alpha_bbox"]
        occupied = [copy_geometry["pill_box"], *copy_geometry["headline_boxes"], copy_geometry["sub_box"]]
        occupied.extend(box for item in items for box in (item["card_box"], item["label_box"]))
        if any(design.boxes_overlap(character_box, box) for box in occupied):
            raise ValueError("Gallery mascot overlaps text or theme cards")
        if not (0 <= character_box[0] < character_box[2] <= design.CANVAS_WIDTH
                and 0 <= character_box[1] < character_box[3] <= design.CANVAS_HEIGHT):
            raise ValueError("Gallery mascot is clipped")
    else:
        footer_box, _ = design.paste_centered_text(
            canvas, localized_copy["footer"], 2660 if ipad else 2695, 42 if ipad else 34,
            (154, 161, 173), bold=False, max_width=1640 if ipad else 1180,
        )
    assert len(items) == len({item["theme"] for item in items}) == 10
    assert all(0 <= x <= design.CANVAS_WIDTH and 0 <= y <= design.CANVAS_HEIGHT for item in items for x, y in (
        (item["card_box"][0], item["card_box"][1]),
        (item["card_box"][2], item["card_box"][3]),
    ))
    final = (design.OUTPUT_ROOT if store_set else OUTPUT) / locale / device / "11-lock-designs.png"
    final.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(final, optimize=True)
    manifest = {
        "size": list(canvas.size),
        "mode": "RGB",
        "file": str(final.relative_to(ROOT)),
        "sha256": sha256(final),
        "locale": locale,
        "device": device,
        "copy": {"eyebrow": copy.eyebrow, "headline": copy.headline, "sub": copy.sub,
                 "free": localized_copy["free"], "footer": localized_copy["footer"]},
        "copy_geometry": copy_geometry,
        "fonts": design.font_manifest(locale),
        "layout": "2 columns by 5 rows; no phone mockup",
        "footer_box": list(footer_box) if footer_box else None,
        "character": character,
        "themes": items,
        "suggested_upload_position": 4,
        "existing_upload_sets_modified": False,
    }
    if store_set:
        manifest["copy"].pop("free")
        manifest["copy"].pop("footer")
        return canvas.convert("RGB"), manifest
    (OUTPUT / (f"manifest-ipad-{locale}.json" if ipad else f"manifest-{locale}.json")).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(final)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", nargs="+", choices=tuple(COPY), default=["ja"])
    parser.add_argument("--device", choices=("iphone-69", "ipad-13"), default="iphone-69")
    args = parser.parse_args()
    for requested_locale in args.locales:
        generate(requested_locale, args.device)
