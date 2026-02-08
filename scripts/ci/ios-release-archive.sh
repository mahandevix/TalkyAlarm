#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SCHEME="${SCHEME:-TalkyAlarm}"
PROJECT_PATH="${PROJECT_PATH:-TalkyAlarm.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${ROOT_DIR}/DerivedDataRelease}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/build/TalkyAlarm.xcarchive}"
IOS_DESTINATION="${IOS_DESTINATION:-generic/platform=iOS}"

echo "Generating Xcode project..."
xcodegen generate

echo "Archiving Release build for ${SCHEME}..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "${IOS_DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  archive
