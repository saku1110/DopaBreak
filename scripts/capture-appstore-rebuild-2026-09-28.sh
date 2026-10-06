#!/bin/bash
# App Store screenshots (2026-09-28 rebuild): re-capture the current app screens in one build.
# - breathing-goals: MeasurementFoundationTests/testCaptureASABreathingScreens -> output/verify/asa-fix-2026-09-20/
# - home:            CoreScreensSnapshotCapture/testCaptureHomeScreen          -> output/app-store-screenshots/raw-core/{locale}/home.png
# - deep focus settings: CoreScreensSnapshotCapture/testCaptureAdditionalSettingsScreens -> raw-core/{locale}/deepfocus.png
# - theme cards:     LockThemeDensitySnapshotCapture/testCaptureAppStoreThemeGallery -> output/app-store-screenshots/theme-gallery/raw/{locale}/
# Run on a dedicated iPhone 17 Pro Max Simulator (440 x 956 pt at 3x).
set -euo pipefail
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <dedicated-simulator-udid> [ja en-US ko]" >&2
  exit 64
fi
simulator_udid="$1"; shift
if [ "$#" -eq 0 ]; then set -- ja en-US ko; fi
project_root="$(cd "$(dirname "$0")/.." && pwd)"
log_dir="$project_root/output/verify/appstore-rebuild-2026-09-28/capture-logs"
derived_data="${TMPDIR:-/tmp}/dopabreak-store-rebuild-0928"
mkdir -p "$log_dir"

xcodebuild build-for-testing \
  -project "$project_root/ios/DopaBreak.xcodeproj" -scheme DopaBreak \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY= \
  > "$log_dir/build.log" 2>&1

for locale in "$@"; do
  python3 - "$derived_data/Build/Products" "$project_root" "$locale" <<'PY'
import json, plistlib, runpy, sys
from pathlib import Path
products, project_root, locale = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
language, region = {"ja": ("ja", "JP"), "en-US": ("en", "US"), "ko": ("ko", "KR")}[locale]
design = runpy.run_path(str(project_root / "scripts/generate-appstore-theme-gallery.py"))["load_design"]()
source = max((p for p in products.glob("*.xctestrun") if not p.name.startswith("Rebuild0928")),
             key=lambda p: p.stat().st_mtime)
data = plistlib.loads(source.read_bytes())
patched = 0
def patch(node):
    global patched
    if isinstance(node, dict):
        if "TestBundlePath" in node and "DopaBreakTests" in node["TestBundlePath"]:
            node.setdefault("EnvironmentVariables", {}).update({
                "DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS": "1",
                "DOPABREAK_CAPTURE_THEME_GALLERY": "1",
                "DOPABREAK_THEME_GALLERY_LOCALE": locale,
                "DOPABREAK_THEME_GALLERY_GOALS": json.dumps(design.LOCK_GOALS[locale], ensure_ascii=False),
            })
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
    raise SystemExit(f"Expected one capture test target, got {patched}")
(products / f"Rebuild0928-{locale}.xctestrun").write_bytes(plistlib.dumps(data))
PY
  # CAPTURE_TESTS overrides the list, e.g. CAPTURE_TESTS="CoreScreensSnapshotCapture/testCaptureAdditionalSettingsScreens".
  tests="${CAPTURE_TESTS:-MeasurementFoundationTests/testCaptureASABreathingScreens CoreScreensSnapshotCapture/testCaptureHomeScreen CoreScreensSnapshotCapture/testCaptureAdditionalSettingsScreens LockThemeDensitySnapshotCapture/testCaptureAppStoreThemeGallery}"
  for test in $tests; do
    name="${test##*/}"
    started_at=$(date +%s)
    # The test host occasionally stalls before the suite starts (seen on the 2nd
    # launch in a row). A capture finishes in under 30 s, so kill it after 75 s
    # and retry once so one stall does not block the other captures.
    ok=0
    for attempt in 1 2; do
      xcodebuild test-without-building \
        -xctestrun "$derived_data/Build/Products/Rebuild0928-$locale.xctestrun" \
        -destination "platform=iOS Simulator,id=$simulator_udid" \
        -only-testing:"DopaBreakTests/$test" \
        -parallel-testing-enabled NO \
        > "$log_dir/$name-$locale.log" 2>&1 &
      pid=$!
      ( sleep 75; kill "$pid" 2>/dev/null ) &
      watchdog=$!
      if wait "$pid"; then ok=1; fi
      kill "$watchdog" 2>/dev/null || true
      if [ "$ok" -eq 1 ]; then break; fi
      echo "retry: $name $locale (attempt $attempt)" >&2
      xcrun simctl terminate "$simulator_udid" com.dopabreak.app >/dev/null 2>&1 || true
    done
    if [ "$ok" -ne 1 ]; then echo "FAILED: $name $locale" >&2; exit 1; fi
    grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "$log_dir/$name-$locale.log" | tail -1
    if ! grep -q "Executed 1 test, with 0 failures" "$log_dir/$name-$locale.log"; then
      echo "NOT RUN: $name $locale (test filter matched nothing or failed)" >&2; exit 1
    fi
    if grep -q "skipped" "$log_dir/$name-$locale.log"; then echo "SKIPPED: $name $locale" >&2; exit 1; fi
    # Snapshot this run's pixels: raw-core/ and theme-gallery/ are also written by other
    # sessions. Copy only files written after this test started.
    snapshot="$project_root/output/verify/appstore-rebuild-2026-09-28/raw/$locale"
    mkdir -p "$snapshot/theme"
    copy_fresh() {
      local source="$1" target="$2"
      if [ ! -f "$source" ] || [ "$(stat -f %m "$source")" -lt "$started_at" ]; then
        echo "STALE: $source was not written by this run" >&2; exit 1
      fi
      cp "$source" "$target"
    }
    case "$name" in
      testCaptureASABreathingScreens)
        short="$locale"; [ "$locale" = "en-US" ] && short="en"
        copy_fresh "$project_root/output/verify/asa-fix-2026-09-20/breathing-goals-$short.png" "$snapshot/breathing-goals.png" ;;
      testCaptureHomeScreen)
        copy_fresh "$project_root/output/app-store-screenshots/raw-core/$locale/home.png" "$snapshot/home.png" ;;
      testCaptureAdditionalSettingsScreens)
        copy_fresh "$project_root/output/app-store-screenshots/raw-core/$locale/deepfocus.png" "$snapshot/deepfocus.png" ;;
      testCaptureAppStoreThemeGallery)
        copy_fresh "$project_root/output/app-store-screenshots/theme-gallery/raw/$locale/e1.png" "$snapshot/theme/e1.png"
        copy_fresh "$project_root/output/app-store-screenshots/theme-gallery/raw/$locale/capture.json" "$snapshot/theme/capture.json" ;;
    esac
  done
  case "$tests" in
    *testCaptureAppStoreThemeGallery*)
      python3 "$project_root/scripts/generate-appstore-theme-gallery.py" --locales "$locale" > "$log_dir/theme-gallery-generate-$locale.log" 2>&1 ;;
  esac
done
echo "CAPTURE DONE"
