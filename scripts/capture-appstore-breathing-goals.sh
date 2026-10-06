#!/bin/bash
# Run on a dedicated iPhone 17 Pro Max Simulator (440 x 956 pt at 3x).
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <dedicated-simulator-udid>" >&2
  exit 64
fi
simulator_udid="$1"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
artifact_dir="$project_root/output/verify/appstore-s9-s10-2026-09-20"
derived_data="${TMPDIR:-/tmp}/dopabreak-store-breathing-capture"
mkdir -p "$artifact_dir"
xcodebuild build-for-testing \
  -project "$project_root/ios/DopaBreak.xcodeproj" -scheme DopaBreak \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO \
  > "$artifact_dir/build-capture.log" 2>&1
for locale in ja en-US ko; do
  python3 - "$derived_data/Build/Products" "$locale" <<'PY'
import plistlib
import sys
from pathlib import Path
products = Path(sys.argv[1])
locale = sys.argv[2]
language, region = {"ja": ("ja", "JP"), "en-US": ("en", "US"), "ko": ("ko", "KR")}[locale]
source = max((p for p in products.glob("*.xctestrun") if not p.name.startswith("StoreCapture")),
             key=lambda p: p.stat().st_mtime)
data = plistlib.loads(source.read_bytes())
patched = 0

def patch(node):
    global patched
    if isinstance(node, dict):
        if "TestBundlePath" in node and "DopaBreakTests" in node["TestBundlePath"]:
            node["CommandLineArguments"] = ["-AppleLanguages", f"({language})", "-AppleLocale", f"{language}_{region}"]
            node["TestLanguage"] = language
            node["TestRegion"] = region
            patched += 1
        for value in node.values():
            patch(value)
    elif isinstance(node, list):
        for value in node:
            patch(value)

patch(data)
if patched != 1:
    raise ValueError(f"Expected one capture test target, got {patched}")
(products / f"StoreCapture-{locale}.xctestrun").write_bytes(plistlib.dumps(data))
PY
  xcodebuild test-without-building \
    -xctestrun "$derived_data/Build/Products/StoreCapture-$locale.xctestrun" \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -only-testing:DopaBreakTests/MeasurementFoundationTests/testCaptureASABreathingScreens \
    -parallel-testing-enabled NO \
    > "$artifact_dir/capture-$locale.log" 2>&1
done
