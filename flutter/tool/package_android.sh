#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source src-tauri/scripts/android-env.sh
export KIYORA_ANDROID_ABIS="${KIYORA_ANDROID_ABIS:-arm64-v8a}"
IFS=',' read -ra kiyora_abis <<< "$KIYORA_ANDROID_ABIS"
kiyora_platforms=()
for kiyora_abi in "${kiyora_abis[@]}"; do
  case "$kiyora_abi" in
    arm64-v8a) kiyora_platforms+=(android-arm64) ;;
    x86_64) kiyora_platforms+=(android-x64) ;;
    *) echo "Unsupported Android ABI: $kiyora_abi" >&2; exit 1 ;;
  esac
  KIYORA_ANDROID_ABI="$kiyora_abi" bash src-tauri/scripts/prepare-android-native.sh
done
kiyora_targets=$(IFS=','; echo "${kiyora_platforms[*]}")
cd flutter
flutter pub get --enforce-lockfile
flutter build apk --release --no-pub --target-platform "$kiyora_targets"
flutter build appbundle --release --no-pub --target-platform "$kiyora_targets"
