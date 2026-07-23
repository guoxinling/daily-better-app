#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/guoxl/Documents/Playground/DailyBetter"
APP_PATH="${PROJECT_DIR}/.DerivedData/Build/Products/Debug-iphonesimulator/DailyBetter.app"
OUTPUT_DIR="${PROJECT_DIR}/AppStore/Screenshots"
BUNDLE_ID="com.guoxl.DailyBetter"
LAUNCH_SETTLE_SECONDS=20

IPHONE_NAME="iPhone 16 Pro Max"
IPAD_NAME="iPad Pro 13-inch (M4)"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at ${APP_PATH}. Build the project first."
  exit 1
fi

mkdir -p "${OUTPUT_DIR}/iPhone-6.9" "${OUTPUT_DIR}/iPad-13"

lookup_udid() {
  local device_name="$1"
  python3 - "$device_name" <<'PY'
import json
import subprocess
import sys

device_name = sys.argv[1]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
for devices in data["devices"].values():
    for device in devices:
        if device["name"] == device_name and device.get("isAvailable"):
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
PY
}

iphone_udid="$(lookup_udid "${IPHONE_NAME}")"
ipad_udid="$(lookup_udid "${IPAD_NAME}")"

if [[ -z "${iphone_udid}" || -z "${ipad_udid}" ]]; then
  echo "Required simulators are not available."
  exit 1
fi

boot_and_prepare() {
  local udid="$1"
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b
  xcrun simctl ui "${udid}" appearance light >/dev/null 2>&1 || true
  xcrun simctl status_bar "${udid}" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

capture_set() {
  local udid="$1"
  local folder="$2"

  xcrun simctl uninstall "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  xcrun simctl install "${udid}" "${APP_PATH}"

  for screen in checkIn timeline; do
    xcrun simctl terminate "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
    SIMCTL_CHILD_DAILYBETTER_SCREENSHOT_MODE=1 \
    SIMCTL_CHILD_DAILYBETTER_SCREEN="${screen}" \
      xcrun simctl launch "${udid}" "${BUNDLE_ID}" --args -ui-testing -seed-check-ins >/dev/null
    sleep "${LAUNCH_SETTLE_SECONDS}"
    xcrun simctl io "${udid}" screenshot "${folder}/${screen}.png" >/dev/null
  done
}

boot_and_prepare "${iphone_udid}"
boot_and_prepare "${ipad_udid}"

capture_set "${iphone_udid}" "${OUTPUT_DIR}/iPhone-6.9"
capture_set "${ipad_udid}" "${OUTPUT_DIR}/iPad-13"

xcrun simctl status_bar "${iphone_udid}" clear >/dev/null 2>&1 || true
xcrun simctl status_bar "${ipad_udid}" clear >/dev/null 2>&1 || true

echo "Screenshots saved in ${OUTPUT_DIR}"
