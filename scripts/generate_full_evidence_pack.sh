#!/usr/bin/env bash

set -euo pipefail

# Full read-only evidence pack generator.
# This script collects detailed diagnostics, source evidence, symbol dumps,
# plist exports, and command logs without modifying devices or system files.

APP_PATH="misaka26.app"
OUT_DIR=""
IOS26_0_LIB_DEFAULT="/Library/Developer/CoreSimulator/Volumes/iOS_23A343/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.0.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
IOS26_4_LIB_DEFAULT="/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
IOS26_0_LIB="$IOS26_0_LIB_DEFAULT"
IOS26_4_LIB="$IOS26_4_LIB_DEFAULT"

usage() {
  cat <<'EOF'
Usage:
  scripts/generate_full_evidence_pack.sh [--app-path <path>] [--out-dir <path>] [--ios26-0-lib <path>] [--ios26-4-lib <path>]

Options:
  --app-path      Path to app bundle (default: misaka26.app)
  --out-dir       Output directory (default: evidence/full_pack_<timestamp>)
  --ios26-0-lib   Path to iOS 26.0 libMobileGestalt.dylib
  --ios26-4-lib   Path to iOS 26.4 libMobileGestalt.dylib
  --help          Show this message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      APP_PATH="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --ios26-0-lib)
      IOS26_0_LIB="$2"
      shift 2
      ;;
    --ios26-4-lib)
      IOS26_4_LIB="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="evidence/full_pack_$(date +%Y%m%d_%H%M%S)"
fi

APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
MAIN_BIN="$APP_PATH/Contents/MacOS/misaka26"
APP_FRAMEWORK_BIN="$APP_PATH/Contents/Frameworks/App.framework/App"
SPARSESTORE_DIR="$APP_PATH/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore"
RESOURCE_SPARSESTORE_DIR="$APP_PATH/Contents/Resources/sparserestore"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/commands" "$OUT_DIR/host" "$OUT_DIR/sdk" "$OUT_DIR/app" "$OUT_DIR/code" "$OUT_DIR/plists" "$OUT_DIR/runtime" "$OUT_DIR/device" "$OUT_DIR/db"

run_capture() {
  local name="$1"
  local cmd="$2"
  local cmd_file="$OUT_DIR/commands/${name}.cmd.sh"
  local out_file="$OUT_DIR/commands/${name}.txt"
  local status_file="$OUT_DIR/commands/${name}.status"

  printf '%s\n' "$cmd" > "$cmd_file"
  chmod +x "$cmd_file"

  if bash -lc "$cmd" > "$out_file" 2>&1; then
    echo "0" > "$status_file"
  else
    echo "$?" > "$status_file"
  fi
}

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -e "$src" ]]; then
    cp "$src" "$dst"
  fi
}

run_capture "host_date" "date"
run_capture "host_uname" "uname -a"
run_capture "host_sw_vers" "sw_vers || true"
run_capture "xcode_version" "xcodebuild -version"
run_capture "xcode_sdks" "xcodebuild -showsdks"
run_capture "sim_runtimes" "xcrun simctl list runtimes"
run_capture "sim_ios_26_subset" "xcrun simctl list runtimes | grep -E 'iOS 26\\.(0|4)' || true"

run_capture "app_info_plist_json" "plutil -p \"$APP_INFO_PLIST\""
run_capture "app_info_plist_xml" "plutil -convert xml1 -o - \"$APP_INFO_PLIST\""
run_capture "app_codesign_entitlements" "codesign -dv --entitlements :- \"$APP_PATH\" 2>&1"
run_capture "app_framework_codesign_entitlements" "codesign -dv --entitlements :- \"$APP_FRAMEWORK_BIN\" 2>&1"
run_capture "main_file_info" "file \"$MAIN_BIN\""
run_capture "framework_file_info" "file \"$APP_FRAMEWORK_BIN\""
run_capture "main_linked_libs" "otool -L \"$MAIN_BIN\""
run_capture "framework_linked_libs" "otool -L \"$APP_FRAMEWORK_BIN\""
run_capture "main_symbols_all" "nm -gjU \"$MAIN_BIN\" 2>/dev/null || true"
run_capture "framework_symbols_all" "nm -gjU \"$APP_FRAMEWORK_BIN\" 2>/dev/null || true"
run_capture "framework_strings_focus" "strings -a \"$APP_FRAMEWORK_BIN\" | grep -E 'trollstore|MobileGestalt|eligibility|SpringBoard|simulateTap|Find My|com.apple.tips|CloudConfigurationDetails|purplebuddy' || true"

run_capture "helper_key_mappings" "rg -n 'mZfUC7qo4pURNhyMHZ62RQ|h9jDsbgj7xIVeIQ8S3/X3Q|qNNddlUK\\+B/YlooNoymwgA|LeSRsiLoJCMhjn6nd6GWbQ|/YYygAofPDbhrwToVsXdeA|systemgroup.com.apple.mobilegestaltcache|Find My' \"$SPARSESTORE_DIR/_.py\" \"$SPARSESTORE_DIR/json_restore.py\""
run_capture "helper_trollpad_assumptions" "rg -n 'START_INDEX|SLICE_LENGTH|mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|0x03|0x01|/usr/lib/libMobileGestalt.dylib' \"$SPARSESTORE_DIR/trollpad_patcher.py\" \"$SPARSESTORE_DIR/trollpad_patcher.m\""
run_capture "helper_restore_domains" "rg -n 'SysSharedContainerDomain-systemgroup.com.apple.media.shared.books|SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles|ManagedPreferencesDomain|CloudConfigurationDetails|purplebuddy' \"$SPARSESTORE_DIR/gestalt_restore.py\""
run_capture "helper_tips_dependency" "rg -n 'com\\.apple\\.tips|get_apps|InstallationProxyService|replace\\(' \"$SPARSESTORE_DIR/install_trollstore.py\""
run_capture "helper_get_apps_behavior" "sed -n '1,220p' \"$SPARSESTORE_DIR/get_apps.py\""

copy_if_exists "$SPARSESTORE_DIR/_.py" "$OUT_DIR/code/_.py"
copy_if_exists "$SPARSESTORE_DIR/json_restore.py" "$OUT_DIR/code/json_restore.py"
copy_if_exists "$SPARSESTORE_DIR/gestalt_restore.py" "$OUT_DIR/code/gestalt_restore.py"
copy_if_exists "$SPARSESTORE_DIR/install_trollstore.py" "$OUT_DIR/code/install_trollstore.py"
copy_if_exists "$SPARSESTORE_DIR/get_apps.py" "$OUT_DIR/code/get_apps.py"
copy_if_exists "$SPARSESTORE_DIR/trollpad_patcher.py" "$OUT_DIR/code/trollpad_patcher.py"
copy_if_exists "$SPARSESTORE_DIR/trollpad_patcher.m" "$OUT_DIR/code/trollpad_patcher.m"

run_capture "code_sha256" "shasum -a 256 \"$OUT_DIR/code\"/* 2>/dev/null || true"
run_capture "code_line_counts" "wc -l \"$OUT_DIR/code\"/* 2>/dev/null || true"

copy_if_exists "$SPARSESTORE_DIR/com.apple.MobileGestalt.plist" "$OUT_DIR/plists/com.apple.MobileGestalt.plist"
copy_if_exists "$SPARSESTORE_DIR/CloudConfigurationDetails.plist" "$OUT_DIR/plists/CloudConfigurationDetails.plist"
copy_if_exists "$SPARSESTORE_DIR/com.apple.purplebuddy.plist" "$OUT_DIR/plists/com.apple.purplebuddy.plist"
copy_if_exists "$RESOURCE_SPARSESTORE_DIR/templates/eligibility.plist" "$OUT_DIR/plists/eligibility.plist"
copy_if_exists "$RESOURCE_SPARSESTORE_DIR/templates/write.json" "$OUT_DIR/plists/write.json"
copy_if_exists "$SPARSESTORE_DIR/On.plist" "$OUT_DIR/plists/On.plist"
copy_if_exists "$SPARSESTORE_DIR/Off.plist" "$OUT_DIR/plists/Off.plist"
copy_if_exists "$SPARSESTORE_DIR/Off_patched.plist" "$OUT_DIR/plists/Off_patched.plist"

run_capture "plist_mobilegestalt_focus" "plutil -p \"$OUT_DIR/plists/com.apple.MobileGestalt.plist\" | grep -E 'CacheVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA|0\\+nc/Udy4WNG8S\\+Q7a/s1A|5pYKlGnYYBzGvAlIU8RjEQ|\\+3Uf0Pm5F8Xy7Onyvko0vA' || true"
run_capture "plist_cloudconfiguration_full" "plutil -convert xml1 -o - \"$OUT_DIR/plists/CloudConfigurationDetails.plist\" || true"
run_capture "plist_purplebuddy_full" "plutil -convert xml1 -o - \"$OUT_DIR/plists/com.apple.purplebuddy.plist\" || true"
run_capture "plist_eligibility_full" "plutil -convert xml1 -o - \"$OUT_DIR/plists/eligibility.plist\" || true"
run_capture "plist_write_json" "cat \"$OUT_DIR/plists/write.json\" || true"
run_capture "plist_off_on_diff" "cmp -l \"$OUT_DIR/plists/Off.plist\" \"$OUT_DIR/plists/On.plist\" | head -n 50 || true"
run_capture "plist_off_offpatched_diff" "cmp -l \"$OUT_DIR/plists/Off.plist\" \"$OUT_DIR/plists/Off_patched.plist\" | head -n 50 || true"
run_capture "plist_blob_hashes" "shasum -a 256 \"$OUT_DIR/plists\"/* 2>/dev/null || true"

copy_if_exists "$SPARSESTORE_DIR/BLDatabaseManager.sqlite" "$OUT_DIR/db/BLDatabaseManager.sqlite"
run_capture "db_schema" "sqlite3 \"$OUT_DIR/db/BLDatabaseManager.sqlite\" '.schema' || true"
run_capture "db_tables" "sqlite3 \"$OUT_DIR/db/BLDatabaseManager.sqlite\" \"select name from sqlite_master where type='table' order by name;\" || true"
run_capture "db_hash" "shasum -a 256 \"$OUT_DIR/db/BLDatabaseManager.sqlite\" 2>/dev/null || true"

run_capture "runtime_lib_sizes_and_hashes" "wc -c \"$IOS26_0_LIB\" \"$IOS26_4_LIB\" && shasum -a 256 \"$IOS26_0_LIB\" \"$IOS26_4_LIB\""
run_capture "runtime_26_0_key_offsets" "strings -a -t d \"$IOS26_0_LIB\" | grep -E 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA|CacheExtra' || true"
run_capture "runtime_26_4_key_offsets" "strings -a -t d \"$IOS26_4_LIB\" | grep -E 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA|CacheExtra' || true"
run_capture "runtime_26_0_symbols_all" "nm -gjU \"$IOS26_0_LIB\" 2>/dev/null | sort"
run_capture "runtime_26_4_symbols_all" "nm -gjU \"$IOS26_4_LIB\" 2>/dev/null | sort"
run_capture "runtime_symbol_delta" "comm -23 \"$OUT_DIR/commands/runtime_26_0_symbols_all.txt\" \"$OUT_DIR/commands/runtime_26_4_symbols_all.txt\" > \"$OUT_DIR/runtime/only_26_0_symbols.txt\"; comm -13 \"$OUT_DIR/commands/runtime_26_0_symbols_all.txt\" \"$OUT_DIR/commands/runtime_26_4_symbols_all.txt\" > \"$OUT_DIR/runtime/only_26_4_symbols.txt\"; echo 'Only in 26.0:'; head -n 60 \"$OUT_DIR/runtime/only_26_0_symbols.txt\"; echo; echo 'Only in 26.4:'; head -n 60 \"$OUT_DIR/runtime/only_26_4_symbols.txt\""
run_capture "runtime_mobilegestalt_symbol_delta" "grep '^_MobileGestalt' \"$OUT_DIR/runtime/only_26_0_symbols.txt\" > \"$OUT_DIR/runtime/only_26_0_mobilegestalt_symbols.txt\" || true; grep '^_MobileGestalt' \"$OUT_DIR/runtime/only_26_4_symbols.txt\" > \"$OUT_DIR/runtime/only_26_4_mobilegestalt_symbols.txt\" || true; echo 'Only in 26.0 (MobileGestalt):'; cat \"$OUT_DIR/runtime/only_26_0_mobilegestalt_symbols.txt\"; echo; echo 'Only in 26.4 (MobileGestalt):'; cat \"$OUT_DIR/runtime/only_26_4_mobilegestalt_symbols.txt\""

run_capture "device_tool_availability" "command -v pymobiledevice3 || true; command -v idevice_id || true; command -v ideviceinfo || true; command -v cfgutil || true"
run_capture "device_usb_presence_check" "ioreg -p IOUSB -l | grep -Ei 'iPhone|iPad|iPod|Apple Mobile Device|USB Product Name|USB Vendor Name' | grep -Ev 'IOKitDiagnostics|Darwin Kernel' | head -n 120 || true"

{
  echo "# Full Read-Only Evidence Pack"
  echo
  echo "- Generated: $(date -Iseconds)"
  echo "- App path: \`$APP_PATH\`"
  echo "- iOS 26.0 lib: \`$IOS26_0_LIB\`"
  echo "- iOS 26.4 lib: \`$IOS26_4_LIB\`"
  echo
  echo "## Safety"
  echo
  echo "- This pack is generated with read-only commands only."
  echo "- No restore operation was executed."
  echo "- No patch helper was executed."
  echo "- No device, simulator, or binary modification was performed."
  echo
  echo "## Directory Layout"
  echo
  echo "- \`commands/\`: command text, output, and status files"
  echo "- \`code/\`: copied helper source evidence"
  echo "- \`plists/\`: copied plist/json payload evidence"
  echo "- \`db/\`: copied SQLite evidence"
  echo "- \`runtime/\`: symbol delta files"
  echo
  echo "## Key Files"
  echo
  echo "- \`commands/runtime_lib_sizes_and_hashes.txt\`"
  echo "- \`commands/runtime_26_0_key_offsets.txt\`"
  echo "- \`commands/runtime_26_4_key_offsets.txt\`"
  echo "- \`commands/runtime_mobilegestalt_symbol_delta.txt\`"
  echo "- \`commands/helper_key_mappings.txt\`"
  echo "- \`commands/helper_trollpad_assumptions.txt\`"
  echo "- \`commands/helper_restore_domains.txt\`"
  echo "- \`commands/helper_tips_dependency.txt\`"
  echo "- \`commands/plist_mobilegestalt_focus.txt\`"
  echo "- \`commands/db_schema.txt\`"
} > "$OUT_DIR/EVIDENCE_INDEX.md"

echo "Full read-only evidence pack generated: $OUT_DIR"
