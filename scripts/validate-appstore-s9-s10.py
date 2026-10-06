#!/usr/bin/env python3
"""Validate the complete local App Store screenshot delivery, without App Store access.

2026-09-28 rebuild: 7 screenshots. Copy and screens were checked panel by panel
(output/verify/appstore-rebuild-2026-09-28/README.md).
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'output/app-store-screenshots/v2'
ORDER = ['breathing-goals', 'deepfocus', 'lockscreen', 'night',
         'grayscale-home', 'home', 'lock-designs']
LOCK_HEADLINES = {
    'ja': ['無意識に手に取っても', 'まず目標が見える'],
    'en-US': ['Pick up your phone', 'and your goals come first'],
    'ko': ['무심코 폰을 들면', '목표부터 떠요'],
}
# Screens that must show the Screen Time block screen, not the settings screen.
# Exact source per panel. The full-block panel shows the deep focus settings captured on
# 2026-09-28 (owner: two block screens looked the same); only night shows the block screen.
REBUILD_RAW = 'output/verify/appstore-rebuild-2026-09-28/raw'
EXPECTED_SOURCES = {
    'breathing-goals': lambda locale: f'{REBUILD_RAW}/{locale}/breathing-goals.png',
    'deepfocus': lambda locale: f'{REBUILD_RAW}/{locale}/deepfocus.png',
    'night': lambda locale: f"mock_shield_night((1320, 2868), '{locale}')",
    'home': lambda locale: f'{REBUILD_RAW}/{locale}/home.png',
}
DEVICES = {'iphone-69': ((1320, 2868), 'slots-{}'),
           'iphone-65': ((1284, 2778), 'slots-iphone65-{}'),
           'ipad-13': ((2064, 2752), 'slots-ipad-{}')}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate():
    reports = []
    for locale in ('ja', 'en-US', 'ko'):
        for device, (size, manifest_name) in DEVICES.items():
            manifest = json.loads((OUTPUT / (manifest_name.format(locale) + '.json')).read_text())
            records = manifest['screenshots']
            require([r['slug'] for r in records] == ORDER, f'{locale}/{device}: order')
            require([r['upload_position'] for r in records] == list(range(1, len(ORDER) + 1)), 'positions')
            require(manifest['canvas'] == dict(zip(('width', 'height'), size)), 'manifest size')
            upload = OUTPUT / 'upload-order' / locale / device
            files = sorted(upload.glob('*.png'))
            require(len(files) == len(ORDER), f'{locale}/{device}: stale files in upload folder')
            require([p.name for p in files] == [f'{n:02d}-{s}.png' for n, s in enumerate(ORDER, 1)], 'delivery names')
            hashes = []
            for path, record in zip(files, records):
                with Image.open(path) as image:
                    require(image.size == size and image.mode == 'RGB' and image.format == 'PNG', str(path))
                    hashes.append(hashlib.sha256(image.tobytes()).hexdigest())
                require(path.read_bytes() == (OUTPUT / record['file']).read_bytes(), 'source/upload mismatch')
                require(record['character_count']['total'] == 1, f'{path}: mascot count')
                require(record['character_count']['screen'] + record['character_count']['external'] == 1, 'count sum')
                geometry = record['copy_geometry']
                width, height = (1320, 2868) if device == 'iphone-65' else size
                boxes = [geometry['pill_box'], *geometry['headline_boxes'], geometry['sub_box']]
                for x1, y1, x2, y2 in boxes:
                    require(0 <= x1 < x2 <= width and 0 <= y1 < y2 <= height, f'{path}: copy bounds')
                    require(abs((x1 + x2) / 2 - width / 2) <= 1, f'{path}: copy centering')
                if record['slug'] in ('breathing-goals', 'breath'):
                    require(len(geometry['headline_metrics']) == 1, f'{path}: headline line count')
                    texts = [geometry['eyebrow_metric']['text'], geometry['headline_metrics'][0]['text'], geometry['sub_metric']['text']]
                    require(not any(c in ''.join(texts) for c in '、。！？!?.,:;’\'／/¥$₩'), f'{path}: punctuation')
                if record['slug'] == 'breathing-goals':
                    slot = record['slots'][0]
                    headline_bottom = geometry['headline_boxes'][-1][3]
                    require(geometry['sub_box'][1] - headline_bottom == 32, 'headline/sub spacing')
                    phone_top = min(y for x, y in slot['outer_corners'].values())
                    require(abs(phone_top - geometry['sub_box'][3] - 32) <= 1, 'sub/mock spacing')
                    for x, y in slot['outer_corners'].values():
                        require(0 <= x <= width and 0 <= y <= height, 'goals screen clipped')
                if record['slug'] == 'lockscreen':
                    lines = [m['text'] for m in geometry['headline_metrics']]
                    require(lines == LOCK_HEADLINES[locale], f'{path}: lock headline {lines}')
                if record['slug'] in EXPECTED_SOURCES:
                    expected = EXPECTED_SOURCES[record['slug']](locale)
                    require(record['source'] == expected, f"{path}: source {record['source']!r} != {expected!r}")
                character = record['character']
                if character:
                    x1, y1, x2, y2 = character['visible_alpha_bbox']
                    require(0 <= x1 < x2 <= width and 0 <= y1 < y2 <= height, 'mascot clipped')
            require(len(set(hashes)) == len(ORDER), f'{locale}/{device}: duplicate pixels')
            reports.append({'locale': locale, 'device': device, 'images': len(files), 'size': size, 'result': 'PASS'})
    require((OUTPUT / 'slots.json').read_bytes() == (OUTPUT / 'slots-ja.json').read_bytes(), 'ja compatibility slots')
    print(json.dumps({'result': 'PASS', 'total_upload_images': sum(r['images'] for r in reports), 'sets': reports}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    validate()
