#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SCHEME="${SCHEME:-TalkyAlarm}"
PROJECT_PATH="${PROJECT_PATH:-TalkyAlarm.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${ROOT_DIR}/DerivedDataCI}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=latest}"

echo "Generating Xcode project..."
xcodegen generate

echo "Building tests for ${SCHEME}..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${IOS_DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing

echo "Running smoke tests for ${SCHEME}..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${IOS_DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  test-without-building
