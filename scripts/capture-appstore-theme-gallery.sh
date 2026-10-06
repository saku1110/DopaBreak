#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <dedicated-simulator-udid> [ja en-US ko]" >&2
  exit 64
fi
simulator_udid="$1"
shift
if [ "$#" -eq 0 ]; then set -- ja; fi
for locale in "$@"; do
  case "$locale" in
    ja|en-US|ko) ;;
    *) echo "Unsupported locale: $locale" >&2; exit 64 ;;
  esac
done

project_root="$(cd "$(dirname "$0")/.." && pwd)"
artifact_dir="$project_root/output/app-store-screenshots/theme-gallery"
derived_data="$artifact_dir/derived-data"
mkdir -p "$artifact_dir"

xcodebuild build-for-testing \
  -project "$project_root/ios/DopaBreak.xcodeproj" \
  -scheme DopaBreak \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" \
  -testLanguage ja -testRegion JP \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY= \
  > "$artifact_dir/build-capture.log" 2>&1

# xcodebuild does not forward arbitrary shell environment variables into XCTest.
# Set the opt-in flag on its explicit test target, preserving __TESTROOT__ paths.
for locale in "$@"; do
python3 - "$derived_data/Build/Products" "$project_root" "$locale" <<'PY'
import json
import plistlib
import runpy
import sys
from pathlib import Path

products = Path(sys.argv[1])
project_root = Path(sys.argv[2])
locale = sys.argv[3]
language, region = {"ja": ("ja", "JP"), "en-US": ("en", "US"), "ko": ("ko", "KR")}[locale]
design = runpy.run_path(str(project_root / 'scripts/generate-appstore-theme-gallery.py'))['load_design']()
sources = sorted(
    (p for p in products.glob('*.xctestrun') if not p.name.startswith('ThemeGallery')),
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
if not sources:
    raise SystemExit('No xctestrun file produced by build-for-testing')
data = plistlib.loads(sources[0].read_bytes())
patched = 0

def patch(node):
    global patched
    if isinstance(node, dict):
        if 'TestBundlePath' in node and 'DopaBreakTests' in node['TestBundlePath']:
            node.setdefault('EnvironmentVariables', {}).update({
                'DOPABREAK_CAPTURE_THEME_GALLERY': '1',
                'DOPABREAK_THEME_GALLERY_LOCALE': locale,
                'DOPABREAK_THEME_GALLERY_GOALS': json.dumps(design.LOCK_GOALS[locale], ensure_ascii=False),
            })
            arguments = node.get('CommandLineArguments', [])
            for key, value in (('-AppleLanguages', f'({language})'), ('-AppleLocale', f'{language}_{region}')):
                if key in arguments:
                    arguments[arguments.index(key) + 1] = value
                else:
                    arguments.extend([key, value])
            node['CommandLineArguments'] = arguments
            node['TestLanguage'] = language
            node['TestRegion'] = region
            patched += 1
        for value in node.values():
            patch(value)
    elif isinstance(node, list):
        for value in node:
            patch(value)

patch(data)
if patched != 1:
    raise SystemExit(f'Expected one capture target, got {patched}')
(products / f'ThemeGallery-{locale}.xctestrun').write_bytes(plistlib.dumps(data))
PY

xcodebuild test-without-building \
  -xctestrun "$derived_data/Build/Products/ThemeGallery-$locale.xctestrun" \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -only-testing:DopaBreakTests/LockThemeDensitySnapshotCapture/testCaptureAppStoreThemeGallery \
  -parallel-testing-enabled NO \
  > "$artifact_dir/capture-run-$locale.log" 2>&1

python3 "$project_root/scripts/generate-appstore-theme-gallery.py" --locales "$locale"
done
