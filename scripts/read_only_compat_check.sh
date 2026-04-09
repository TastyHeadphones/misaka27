#!/usr/bin/env bash

set -u

# Read-only compatibility checker for misaka26 package analysis.
# This script does not restore files, patch binaries, or modify devices.

APP_PATH="misaka26.app"
OUTPUT_PATH=""
IOS26_0_LIB_DEFAULT="/Library/Developer/CoreSimulator/Volumes/iOS_23A343/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.0.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
IOS26_4_LIB_DEFAULT="/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
IOS26_0_LIB="$IOS26_0_LIB_DEFAULT"
IOS26_4_LIB="$IOS26_4_LIB_DEFAULT"

usage() {
  cat <<'EOF'
Usage:
  scripts/read_only_compat_check.sh [--app-path <path>] [--output <path>] [--ios26-0-lib <path>] [--ios26-4-lib <path>]

Options:
  --app-path      Path to misaka26 app bundle (default: misaka26.app)
  --output        Output markdown report path (default: reports/read_only_compat_report_<timestamp>.md)
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
    --output)
      OUTPUT_PATH="$2"
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

if [[ -z "$OUTPUT_PATH" ]]; then
  mkdir -p reports
  OUTPUT_PATH="reports/read_only_compat_report_$(date +%Y%m%d_%H%M%S).md"
fi
mkdir -p "$(dirname "$OUTPUT_PATH")"

APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
SPARSESTORE_DIR="$APP_PATH/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore"
RESOURCES_DIR="$APP_PATH/Contents/Resources/sparserestore"

RG_BIN="rg"
if ! command -v rg >/dev/null 2>&1; then
  RG_BIN="grep -E"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/misaka26-readonly-XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

append_header() {
  local title="$1"
  {
    echo
    echo "## $title"
    echo
  } >> "$OUTPUT_PATH"
}

append_text() {
  echo "$1" >> "$OUTPUT_PATH"
}

append_command() {
  local label="$1"
  local cmd="$2"
  {
    echo "### $label"
    echo
    echo '```sh'
    echo "$cmd"
    echo '```'
    echo
  } >> "$OUTPUT_PATH"

  if output="$(bash -lc "$cmd" 2>&1)"; then
    {
      echo '```text'
      echo "$output"
      echo '```'
      echo
    } >> "$OUTPUT_PATH"
  else
    {
      echo '```text'
      echo "[command exited non-zero]"
      echo "$output"
      echo '```'
      echo
    } >> "$OUTPUT_PATH"
  fi
}

append_exists() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    append_text "- $label: present (\`$path\`)"
  else
    append_text "- $label: missing (\`$path\`)"
  fi
}

{
  echo "# misaka26 Read-Only Compatibility Report"
  echo
  echo "- Generated: $(date -Iseconds)"
  echo "- Working directory: $(pwd)"
  echo "- App path: \`$APP_PATH\`"
  echo "- iOS 26.0 MobileGestalt path: \`$IOS26_0_LIB\`"
  echo "- iOS 26.4 MobileGestalt path: \`$IOS26_4_LIB\`"
  echo
  echo "This report is generated using read-only commands only."
  echo "No device restore, no patch execution, and no system/binary modification is performed."
} > "$OUTPUT_PATH"

append_header "Artifact Presence"
append_exists "App bundle" "$APP_PATH"
append_exists "Info.plist" "$APP_INFO_PLIST"
append_exists "Sparserestore directory" "$SPARSESTORE_DIR"
append_exists "Template directory" "$RESOURCES_DIR/templates"
append_exists "iOS 26.0 libMobileGestalt" "$IOS26_0_LIB"
append_exists "iOS 26.4 libMobileGestalt" "$IOS26_4_LIB"

append_header "Host and SDK Metadata"
append_command "Host Date" "date"
append_command "Host OS" "uname -a"
append_command "Xcode Version" "xcodebuild -version"
append_command "Installed SDKs" "xcodebuild -showsdks"
append_command "iOS Simulator Runtimes" "xcrun simctl list runtimes | grep -E 'iOS 26\\.(0|4)' || true"

append_header "Bundle Metadata and Entitlements"
append_command "Info.plist Summary" "plutil -p \"$APP_INFO_PLIST\" | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleSupportedPlatforms|DTPlatformVersion|DTSDKName|DTXcode|NSPrincipalClass' || true"
append_command "App Entitlements" "codesign -dv --entitlements :- \"$APP_PATH\" 2>&1 | tail -n +1"
append_command "App Framework Symbols" "nm -gjU \"$APP_PATH/Contents/Frameworks/App.framework/App\" 2>/dev/null | head -n 20"

append_header "Static Evidence: Key Assumptions in Helper Scripts"
append_command "MobileGestalt and Restore Key Mapping" "$RG_BIN -n 'mZfUC7qo4pURNhyMHZ62RQ|h9jDsbgj7xIVeIQ8S3/X3Q|qNNddlUK\\+B/YlooNoymwgA|LeSRsiLoJCMhjn6nd6GWbQ|/YYygAofPDbhrwToVsXdeA|systemgroup.com.apple.mobilegestaltcache' \"$SPARSESTORE_DIR/_.py\" \"$SPARSESTORE_DIR/json_restore.py\""
append_command "TrollPad Patcher Constants" "$RG_BIN -n 'START_INDEX|SLICE_LENGTH|mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|0x03|0x01' \"$SPARSESTORE_DIR/trollpad_patcher.py\" \"$SPARSESTORE_DIR/trollpad_patcher.m\""
append_command "Legacy Restore Domains" "$RG_BIN -n 'SysSharedContainerDomain-systemgroup.com.apple.media.shared.books|SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles|ManagedPreferencesDomain|CloudConfigurationDetails|purplebuddy' \"$SPARSESTORE_DIR/gestalt_restore.py\""
append_command "Tips Dependency" "$RG_BIN -n 'com\\.apple\\.tips|get_apps|InstallationProxyService|replace\\(' \"$SPARSESTORE_DIR/install_trollstore.py\""

append_header "Static Evidence: Payload and Template Metadata"
append_command "MobileGestalt Cache Fields" "plutil -p \"$SPARSESTORE_DIR/com.apple.MobileGestalt.plist\" | grep -E 'CacheVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA|0\\+nc/Udy4WNG8S\\+Q7a/s1A|5pYKlGnYYBzGvAlIU8RjEQ' || true"
append_command "CloudConfigurationDetails Keys" "plutil -p \"$SPARSESTORE_DIR/CloudConfigurationDetails.plist\" | grep -E 'AllowPairing|ConfigurationWasApplied|CloudConfigurationUIComplete|PostSetupProfileWasInstalled|SkipSetup|IsSupervised' || true"
append_command "purplebuddy Keys" "plutil -p \"$SPARSESTORE_DIR/com.apple.purplebuddy.plist\" | grep -E 'SetupDone|SetupFinishedAllSteps|UserChoseLanguage' || true"
append_command "eligibility Template Keys" "plutil -p \"$RESOURCES_DIR/templates/eligibility.plist\" | grep -E 'OS_ELIGIBILITY_DOMAIN_CALCIUM|OS_ELIGIBILITY_DOMAIN_GREYMATTER|OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE|OS_ELIGIBILITY_INPUT_DEVICE_LOCALE|OS_ELIGIBILITY_INPUT_DEVICE_REGION_CODE|OS_ELIGIBILITY_INPUT_GENERATIVE_MODEL_SYSTEM' || true"
append_command "BLDatabase Schema" "sqlite3 \"$SPARSESTORE_DIR/BLDatabaseManager.sqlite\" '.schema' | head -n 80"

append_header "iOS 26.0 vs 26.4 MobileGestalt Runtime Diff"
append_command "libMobileGestalt Sizes and SHA256" "wc -c \"$IOS26_0_LIB\" \"$IOS26_4_LIB\" && shasum -a 256 \"$IOS26_0_LIB\" \"$IOS26_4_LIB\""
append_command "Key String Offsets (26.0)" "strings -a -t d \"$IOS26_0_LIB\" | grep -E 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA' || true"
append_command "Key String Offsets (26.4)" "strings -a -t d \"$IOS26_4_LIB\" | grep -E 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion|mZfUC7qo4pURNhyMHZ62RQ|/YYygAofPDbhrwToVsXdeA' || true"
append_command "MobileGestalt Export Delta (26.0 -> 26.4)" "nm -gjU \"$IOS26_0_LIB\" 2>/dev/null | sort > \"$TMP_DIR/old.syms\"; nm -gjU \"$IOS26_4_LIB\" 2>/dev/null | sort > \"$TMP_DIR/new.syms\"; echo 'Only in 26.0:'; comm -23 \"$TMP_DIR/old.syms\" \"$TMP_DIR/new.syms\" | grep '^_MobileGestalt' | head -n 40 || true; echo; echo 'Only in 26.4:'; comm -13 \"$TMP_DIR/old.syms\" \"$TMP_DIR/new.syms\" | grep '^_MobileGestalt' | head -n 40 || true"

append_header "Device Observation Capability (Read-Only)"
append_command "Tool Availability" "command -v pymobiledevice3 || true; command -v idevice_id || true; command -v ideviceinfo || true; command -v cfgutil || true"
append_command "USB Apple Device Presence Check" "ioreg -p IOUSB -l | grep -Ei 'iPhone|iPad|iPod|Apple Mobile Device|USB Product Name|USB Vendor Name' | grep -Ev 'IOKitDiagnostics|Darwin Kernel' | head -n 60 || true"

append_header "Conclusion"
append_text "- This report only captures read-only evidence."
append_text "- The strongest compatibility risk indicators are private MobileGestalt layout drift, key offset movement, and an exported-symbol surface delta between 26.0 and 26.4."
append_text "- Additional live-device, read-only checks can be performed later by comparing \`lockdown.all_values\` against packaged \`CacheExtra\` values when a device is connected."
echo >> "$OUTPUT_PATH"
append_text "Report written to: \`$OUTPUT_PATH\`"

echo "Read-only compatibility report generated: $OUTPUT_PATH"
