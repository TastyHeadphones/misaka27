# misaka26 Compatibility Study

This report is repository-relative only. It does not use host-specific absolute paths.

## Scope

- Analyze the `misaka26` package as shipped in this repository.
- Identify platform assumptions in the bundle and helper tools.
- Compare the package against the older iOS 26.0 stack and the current iOS 26.4 stack.
- Provide only read-only validation methods.
- Inline snippet evidence is collected in `docs/EVIDENCE_APPENDIX.md`.

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
- Additional observed metadata:
  - `DTPlatformVersion = 26.0`
  - `DTSDKName = macosx26.0`
  - `DTXcode = 2601`
  - `DTXcodeBuild = 17A400`
  - `CFBundleShortVersionString = 26.1.6`

### 2) The executable surface is mostly Flutter/Dart

- `misaka26.app/Contents/MacOS/misaka26` exports only `_main`.
- `App.framework/App` exports only Dart snapshot symbols.
- Observed Dart snapshot symbols include:
  - `_kDartVmSnapshotData`
  - `_kDartVmSnapshotInstructions`
  - `_kDartIsolateSnapshotData`
  - `_kDartIsolateSnapshotInstructions`
- Observed strings include:
  - `package:misaka26/trollstore.dartr`
  - `simulateTap`
  - `SpringBoard`
  - `Please use the Shortcuts app on your device to extract the com.apple.MobileGestalt.plist file.`
  - `You might be using com.apple.MobileGestalt.plist of another device.`

### 3) `MobileGestalt` restore logic is version-sensitive

- The restore target path is:
  - `/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist`
- `_.py` validates these `CacheExtra` keys against the connected device:
  - `mZfUC7qo4pURNhyMHZ62RQ -> BuildVersion`
  - `h9jDsbgj7xIVeIQ8S3/X3Q -> ProductType`
  - `qNNddlUK+B/YlooNoymwgA -> ProductVersion`
  - `LeSRsiLoJCMhjn6nd6GWbQ -> FirmwareVersion`
- `json_restore.py` validates:
  - `mZfUC7qo4pURNhyMHZ62RQ -> BuildVersion`
  - `/YYygAofPDbhrwToVsXdeA -> HardwareModel`
  - `LeSRsiLoJCMhjn6nd6GWbQ -> FirmwareVersion`
- `trollpad_patcher.py` uses:
  - `START_INDEX = 1616`
  - `SLICE_LENGTH = 200`
  - regex `0+(?:5555)*([0-9A-F]{4})`
- `trollpad_patcher.m` uses the obfuscated key `mtrAoWJ3gsq+I90ZnQ0vQw` for `DeviceClassNumber`.
- The observed write values are:
  - `0x01 = iPhone`
  - `0x03 = iPad`
- The bundled `com.apple.MobileGestalt.plist` contains device-specific values including:
  - `/YYygAofPDbhrwToVsXdeA = J522AP`
  - `0+nc/Udy4WNG8S+Q7a/s1A = iPad13,8`
  - `5pYKlGnYYBzGvAlIU8RjEQ = t8103`
  - `mZfUC7qo4pURNhyMHZ62RQ = 22B5034e`
  - `CacheVersion = 22B5034e`
- `Off.plist` vs `On.plist` differs by one `CacheData` byte:
  - index `816`
  - `0x01 -> 0x03`
- `Off_patched.plist` matches `On.plist` for that patched byte.

### 4) The package assumes legacy restore/setup artifacts still work

- `gestalt_restore.py` writes into:
  - `SysSharedContainerDomain-systemgroup.com.apple.media.shared.books`
  - `SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles`
  - `ManagedPreferencesDomain`
- The restored files are:
  - `BLDatabaseManager.sqlite`
  - `CloudConfigurationDetails.plist`
  - `com.apple.purplebuddy.plist`
- Observed `CloudConfigurationDetails.plist` keys:
  - `AllowPairing = true`
  - `ConfigurationWasApplied = true`
  - `CloudConfigurationUIComplete = true`
  - `PostSetupProfileWasInstalled = true`
  - `IsSupervised = false`
  - `ConfigurationSource = 0`
- Observed `SkipSetup` entries include:
  - `Restore`
  - `AppleID`
  - `Passcode`
  - `Biometric`
  - `AppStore`
  - `RestoreCompleted`
  - `UpdateCompleted`
- Observed `com.apple.purplebuddy.plist` keys:
  - `SetupDone = true`
  - `SetupFinishedAllSteps = true`
  - `UserChoseLanguage = true`
- Observed `BLDatabaseManager.sqlite` tables:
  - `ZBLDOWNLOADINFO`
  - `ZBLDOWNLOADPOLICYINFO`
  - `Z_METADATA`
  - `Z_MODELCACHE`
  - `Z_PRIMARYKEY`

### 5) TrollStore install depends on the Tips system app

- `install_trollstore.py` resolves `com.apple.tips` via `InstallationProxyService.get_apps(application_type="System")`.
- It then writes to the Tips executable path.
- The observed lookup and path logic is:
  - bundle id `com.apple.tips`
  - result field `Path`
  - target path `${tips_path.replace('/private', '')}/Tips`

### 6) Eligibility assumptions are encoded in a template

- Observed `eligibility.plist` entries include:
  - `OS_ELIGIBILITY_DOMAIN_CALCIUM`
  - `OS_ELIGIBILITY_DOMAIN_GREYMATTER`
  - `OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE`
  - `OS_ELIGIBILITY_INPUT_DEVICE_LOCALE`
  - `OS_ELIGIBILITY_INPUT_DEVICE_REGION_CODE`
  - `OS_ELIGIBILITY_INPUT_GENERATIVE_MODEL_SYSTEM`
- Additional observed values:
  - `OS_ELIGIBILITY_DOMAIN_CALCIUM.os_eligibility_answer_t = 2`
  - `OS_ELIGIBILITY_DOMAIN_GREYMATTER.os_eligibility_answer_t = 4`
  - `OS_ELIGIBILITY_DOMAIN_GREYMATTER.status = 2`

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

Observed 26.0-only exported getters from the comparison include:

- `_MobileGestalt_copy_regionInfoFromActivation`
- `_MobileGestalt_copy_regionInfoFromSysconfig`
- `_MobileGestalt_copy_regionalBehaviorsFromActivation`
- `_MobileGestalt_get_allowPhoneApp`
- `_MobileGestalt_get_audioExclaveMicInputCapability`
- `_MobileGestalt_get_dataCenterRegionCode`
- `_MobileGestalt_get_deviceSupportsDarwinInitConfigFromNVRAM`
- `_MobileGestalt_get_deviceSupportsHandwritingSynthesisModel`
- `_MobileGestalt_get_fanCount`
- `_MobileGestalt_get_oSMigrationCapability`
- `_MobileGestalt_get_uSBPortCount`

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
plutil -p <local-copy-of-com.apple.MobileGestalt.plist>
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
plutil -convert xml1 -o - <local-copy-of-CloudConfigurationDetails.plist> | nl -ba
plutil -convert xml1 -o - <local-copy-of-com.apple.purplebuddy.plist> | nl -ba
sqlite3 <local-copy-of-BLDatabaseManager.sqlite> '.schema'
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
<local-copy-of-misaka26-get_apps>
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
