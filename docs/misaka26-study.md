# misaka26 Compatibility Study

This report is repository-relative only. It does not use host-specific absolute paths.

## Scope

- Analyze the `misaka26` package as shipped in this repository.
- Identify platform assumptions in the bundle and helper tools.
- Compare the package against the older iOS 26.0 stack and the current iOS 26.4 stack.
- Provide only read-only validation methods.

## Executive Summary

- `misaka26` is a macOS host app, not an iOS app bundle.
- The package is dominated by Flutter/Dart code plus bundled Python and Objective-C helper tools.
- The most fragile dependency is the `MobileGestalt` patching path, which assumes a stable private binary layout.
- The second fragile dependency is device-specific restore metadata, especially `com.apple.MobileGestalt.plist`.
- The current 26.4 stack shows `libMobileGestalt.dylib` drift relative to 26.0, including different offsets and a reduced exported symbol surface.

## Repository Inventory

### App bundle

- `misaka26.app/Contents/Info.plist`
- `misaka26.app/Contents/MacOS/misaka26`
- `misaka26.app/Contents/Frameworks/App.framework/App`
- `misaka26.app/Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS`
- Flutter plugin frameworks under `misaka26.app/Contents/Frameworks/`

### Restore and patch assets

- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/_.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/gestalt_restore.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/json_restore.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/install_trollstore.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/get_apps.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.py`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.m`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/com.apple.MobileGestalt.plist`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/CloudConfigurationDetails.plist`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/com.apple.purplebuddy.plist`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/BLDatabaseManager.sqlite`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/On.plist`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/Off.plist`
- `misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/Off_patched.plist`

### Packaged restore templates

- `misaka26.app/Contents/Resources/sparserestore/templates/write.json`
- `misaka26.app/Contents/Resources/sparserestore/templates/eligibility.plist`
- `misaka26.app/Contents/Resources/sparserestore/dist/arm64/CloudConfigurationDetails.plist`
- `misaka26.app/Contents/Resources/sparserestore/dist/arm64/com.apple.purplebuddy.plist`
- same files are also present under `dist/x86_64`

## Static Analysis Findings

### 1) Bundle identity and signing

- The bundle advertises `CFBundleSupportedPlatforms = MacOSX`.
- `NSPrincipalClass = NSApplication`.
- The app is ad hoc signed and has no Team ID.
- Entitlements include:
  - `com.apple.security.app-sandbox = false`
  - `com.apple.security.cs.allow-jit = true`
  - `com.apple.security.get-task-allow = true`
  - `com.apple.security.network.server = true`

Reference:

- [`misaka26.app/Contents/Info.plist`](../misaka26.app/Contents/Info.plist#L25)

### 2) The executable surface is mostly Flutter/Dart

- `misaka26.app/Contents/MacOS/misaka26` exports only `_main`.
- `App.framework/App` exports only Dart snapshot symbols.
- The Dart snapshot strings reference:
  - `package:misaka26/trollstore.dartr`
  - `simulateTap`
  - `SpringBoard`
  - `Please use the Shortcuts app on your device to extract the com.apple.MobileGestalt.plist file.`
  - `You might be using com.apple.MobileGestalt.plist of another device.`

### 3) `MobileGestalt` restore logic is version-sensitive

- `_.py` checks `BuildVersion`, `ProductType`, `ProductVersion`, and `FirmwareVersion` before restoring to the MobileGestalt cache path.
- `json_restore.py` performs a similar check and also validates `HardwareModel`.
- `trollpad_patcher.py` searches inside `CacheData` using a fixed index window and then flips a single nibble.
- `trollpad_patcher.m` resolves the offset from `/usr/lib/libMobileGestalt.dylib` and writes `0x03` for iPad or `0x01` for iPhone.

Reference:

- [`_.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/_.py#L40)
- [`json_restore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/json_restore.py#L25)
- [`trollpad_patcher.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.py#L5)
- [`trollpad_patcher.m`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.m#L16)

### 4) The package assumes legacy restore/setup artifacts still work

- `gestalt_restore.py` writes into:
  - `SysSharedContainerDomain-systemgroup.com.apple.media.shared.books`
  - `SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles`
  - `ManagedPreferencesDomain`
- `CloudConfigurationDetails.plist` sets `AllowPairing`, `ConfigurationWasApplied`, `CloudConfigurationUIComplete`, and `PostSetupProfileWasInstalled`.
- `com.apple.purplebuddy.plist` sets `SetupDone`, `SetupFinishedAllSteps`, and `UserChoseLanguage`.

Reference:

- [`gestalt_restore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/gestalt_restore.py#L78)
- [`CloudConfigurationDetails.plist`](../misaka26.app/Contents/Resources/sparserestore/dist/arm64/CloudConfigurationDetails.plist#L5)
- [`com.apple.purplebuddy.plist`](../misaka26.app/Contents/Resources/sparserestore/dist/arm64/com.apple.purplebuddy.plist#L5)

### 5) TrollStore install depends on the Tips system app

- `install_trollstore.py` resolves `com.apple.tips` via `InstallationProxyService.get_apps(application_type="System")`.
- It then writes to the Tips executable path.

Reference:

- [`install_trollstore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/install_trollstore.py#L19)

### 6) Eligibility assumptions are encoded in a template

- `eligibility.plist` contains:
  - `OS_ELIGIBILITY_DOMAIN_CALCIUM`
  - `OS_ELIGIBILITY_DOMAIN_GREYMATTER`
  - `OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE`
  - `OS_ELIGIBILITY_INPUT_DEVICE_LOCALE`
  - `OS_ELIGIBILITY_INPUT_DEVICE_REGION_CODE`
  - `OS_ELIGIBILITY_INPUT_GENERATIVE_MODEL_SYSTEM`

Reference:

- [`eligibility.plist`](../misaka26.app/Contents/Resources/sparserestore/templates/eligibility.plist#L5)

## Old vs Current Runtime Comparison

| Area | iOS 26.0 stack | iOS 26.4 stack | Impact |
| --- | --- | --- | --- |
| `libMobileGestalt.dylib` size | 939,984 bytes | 973,792 bytes | Binary drift is real |
| `mtrAoWJ3gsq+I90ZnQ0vQw` offset | 229300 | 224895 | Offset-based patching is fragile |
| `DeviceClassNumber` offset | 250714 | 248954 | Data moved in the current stack |
| `BuildVersion` offset | 249971 | 248190 | More evidence of layout drift |
| Export surface | Several getters present | Several getters removed | Private API surface changed |
| Path strings | Present | Present | Path assumptions still exist |
| Runtime arch | arm64-only | arm64-only | Simulator validation is still architecture-limited |

## Root-Cause Hypotheses

### Hypothesis 1: `libMobileGestalt` layout drift breaks the patcher

Why it is plausible:

- The patcher depends on a hardcoded search window and a derived byte offset.
- The 26.4 runtime changed offsets and removed multiple exports.

Read-only validation:

```sh
nm -gjU <26.0-libMobileGestalt> | sort > mg-26.0.syms
nm -gjU <26.4-libMobileGestalt> | sort > mg-26.4.syms
comm -23 mg-26.0.syms mg-26.4.syms
strings -a -t d <26.0-libMobileGestalt> | rg 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion'
strings -a -t d <26.4-libMobileGestalt> | rg 'mtrAoWJ3gsq\\+I90ZnQ0vQw|DeviceClassNumber|BuildVersion'
```

Expected true:

- Different offsets or missing symbols.

Expected false:

- Identical offsets and symbol sets.

### Hypothesis 2: The bundled MobileGestalt blob is stale or from another device

Why it is plausible:

- The scripts explicitly reject mismatched device/build values.
- The shipped plist contains device-specific values.

Read-only validation:

```sh
plutil -p misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/com.apple.MobileGestalt.plist
```

If a device is attached, compare the values returned by `lockdown.all_values` with the `CacheExtra` keys in the plist. Do not write anything.

Expected true:

- A mismatch in `BuildVersion`, `ProductType`, `ProductVersion`, `FirmwareVersion`, or `HardwareModel`.

Expected false:

- All visible fields match exactly.

### Hypothesis 3: Setup/pairing hardening blocks the restore payloads

Why it is plausible:

- The package still writes setup-related plists into legacy domains.
- Current stacks may validate these more strictly.

Read-only validation:

```sh
plutil -convert xml1 -o - misaka26.app/Contents/Resources/sparserestore/dist/arm64/CloudConfigurationDetails.plist | nl -ba
plutil -convert xml1 -o - misaka26.app/Contents/Resources/sparserestore/dist/arm64/com.apple.purplebuddy.plist | nl -ba
sqlite3 misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/BLDatabaseManager.sqlite '.schema'
```

Expected true:

- The payloads still encode legacy restore behavior and setup suppression.

Expected false:

- The payloads are empty or unrelated.

### Hypothesis 4: Tips app discovery changed

Why it is plausible:

- TrollStore install is tied to `com.apple.tips`.

Read-only validation:

```sh
misaka26.app/Contents/Resources/sparserestore/dist/arm64/misaka26-get_apps
misaka26.app/Contents/Resources/sparserestore/dist/x86_64/misaka26-get_apps
```

If a device is attached, confirm the output includes `com.apple.tips` and compare the reported `Path` to what `install_trollstore.py` expects.

Expected true:

- `com.apple.tips` is missing or the path differs.

Expected false:

- `com.apple.tips` is present with a stable path.

## Safe Validation Checklist

- Compare `libMobileGestalt.dylib` offsets across 26.0 and 26.4 using `nm` and `strings`.
- Inspect plist contents with `plutil` only.
- Inspect `BLDatabaseManager.sqlite` with `sqlite3 .schema` only.
- Run the packaged `misaka26-get_apps` helper read-only.
- If a device is attached, compare `lockdown.all_values` against the packaged MobileGestalt plist without writing anything.

## Residual Gap

The current environment does not have a connected iPhone or iPad, so the live-device `com.apple.tips` inventory check and the `lockdown.all_values` comparison could not be completed here.

