#!/bin/bash

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <language> <region> <output-locale> <simulator-udid>" >&2
  exit 64
fi

language="$1"
region="$2"
output_locale="$3"
simulator_udid="$4"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
ios_dir="$project_root/ios"
artifact_root="${DOPABREAK_SCREENSHOT_ROOT:-raw}"
derived_data_name="${DOPABREAK_DERIVED_DATA:-derived-data}"
output_dir="$project_root/output/app-store-screenshots/$artifact_root/$output_locale/onboarding"
derived_data="$project_root/output/app-store-screenshots/$derived_data_name"
log_file="$project_root/output/app-store-screenshots/capture-onboarding-$artifact_root-$output_locale.log"
developer_dir="/Applications/Xcode.app/Contents/Developer"

mkdir -p "$output_dir"
: > "$log_file"

wait_for_marker() {
  local marker="$1"
  local attempts=0

  while ! grep -q "$marker" "$log_file"; do
    if ! kill -0 "$test_pid" 2>/dev/null; then
      wait "$test_pid"
      echo "Capture test exited before marker: $marker" >&2
      exit 1
    fi
    attempts=$((attempts + 1))
    if [ "$attempts" -gt 600 ]; then
      echo "Timed out waiting for marker: $marker" >&2
      kill "$test_pid" 2>/dev/null || true
      exit 1
    fi
    sleep 0.2
  done
}

(
  cd "$ios_dir"
  DEVELOPER_DIR="$developer_dir" xcodebuild test-without-building \
    -project DopaBreak.xcodeproj \
    -scheme DopaBreak \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -derivedDataPath "$derived_data" \
    -only-testing:DopaBreakTests/OnboardingMotionCapture/testHoldOnboardingStagesOnScreen \
    -testLanguage "$language" \
    -testRegion "$region" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY= \
    > "$log_file" 2>&1
) &
test_pid=$!

stages=(
  "01-goal-empty"
  "02-goal-filled"
  "03-quiz-result"
  "04-choose-mode"
  "05-ready"
)

for stage in "${stages[@]}"; do
  wait_for_marker "ONB_STAGE_BEGIN $stage"
  sleep 0.8
  DEVELOPER_DIR="$developer_dir" xcrun simctl io "$simulator_udid" screenshot \
    --type=png "$output_dir/$stage.png"
  echo "Captured $output_locale/$stage"
done

wait "$test_pid"
echo "Completed onboarding capture for $output_locale"
