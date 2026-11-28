#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source rust/scripts/android-env.sh
export KIYORA_ANDROID_ABIS="${KIYORA_ANDROID_ABIS:-arm64-v8a}"
kiyora_mode=release
kiyora_bundle=1
for kiyora_option in "$@"; do
  case "$kiyora_option" in
    --debug) kiyora_mode=debug; kiyora_bundle=0 ;;
    --apk-only) kiyora_bundle=0 ;;
    *) echo "Usage: $0 [--debug] [--apk-only]" >&2; exit 1 ;;
  esac
done
IFS=',' read -ra kiyora_abis <<< "$KIYORA_ANDROID_ABIS"
kiyora_platforms=()
for kiyora_abi in "${kiyora_abis[@]}"; do
  case "$kiyora_abi" in
    arm64-v8a) kiyora_platforms+=(android-arm64) ;;
    x86_64) kiyora_platforms+=(android-x64) ;;
    *) echo "Unsupported Android ABI: $kiyora_abi" >&2; exit 1 ;;
  esac
  KIYORA_ANDROID_ABI="$kiyora_abi" bash rust/scripts/check-android-env.sh
done
for kiyora_abi in "${kiyora_abis[@]}"; do
  KIYORA_ANDROID_ABI="$kiyora_abi" bash rust/scripts/prepare-android-native.sh
done
kiyora_targets=$(IFS=','; echo "${kiyora_platforms[*]}")
cd flutter
flutter pub get --enforce-lockfile
flutter build apk "--$kiyora_mode" --no-pub --target-platform "$kiyora_targets"
kiyora_apk="build/app/outputs/flutter-apk/app-$kiyora_mode.apk"
python3 tool/verify_android_package.py "$kiyora_apk" --abis "$KIYORA_ANDROID_ABIS"
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -P 16 -v 4 "$kiyora_apk"
if [[ "$kiyora_mode" == debug || -f "${KIYORA_ANDROID_SIGNING_PROPERTIES:-$HOME/.local/share/kiyora/android-signing/keystore.properties}" ]]; then
  "$ANDROID_HOME/build-tools/36.0.0/apksigner" verify "$kiyora_apk"
else
  echo 'Release signing is not configured. Use --debug for a locally installable APK.' >&2
fi
if [[ "$kiyora_bundle" == 1 ]]; then
  flutter build appbundle --release --no-pub --target-platform "$kiyora_targets"
  python3 tool/verify_android_package.py build/app/outputs/bundle/release/app-release.aab --abis "$KIYORA_ANDROID_ABIS"
fi
