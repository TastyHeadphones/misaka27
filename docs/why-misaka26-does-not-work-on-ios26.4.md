# Why `misaka26` Does Not Work on iOS 26.4

This note is the short version of the broader study in [docs/misaka26-study.md](misaka26-study.md).

## Short Answer

`misaka26` depends on private, version-sensitive behavior that changed between the older iOS 26.0 stack and the current iOS 26.4 stack.

The biggest break is the `MobileGestalt` path. The package does not use a stable public API for that flow. It patches internal data by offset and expects older restore-era assumptions to still hold. Those assumptions are not stable across system updates.

## The Main Reasons

### 1) The `MobileGestalt` patcher is tied to private binary layout

The patching logic is not capability-based. It is offset-based.

- Observed patcher constants:
  - `START_INDEX = 1616`
  - `SLICE_LENGTH = 200`
  - regex `0+(?:5555)*([0-9A-F]{4})`
- Observed private key and value mapping:
  - `mtrAoWJ3gsq+I90ZnQ0vQw -> DeviceClassNumber`
  - `0x01 = iPhone`
  - `0x03 = iPad`
- Observed 26.0 vs 26.4 offset drift:
  - `mtrAoWJ3gsq+I90ZnQ0vQw: 229300 -> 224895`
  - `DeviceClassNumber: 250714 -> 248954`
  - `BuildVersion: 249971 -> 248190`

That only works if Apple keeps the same internal data layout. In the read-only 26.0 vs 26.4 comparison, `libMobileGestalt.dylib` changed size, key string offsets moved, and several exported getters disappeared. That is enough to break a private offset patcher even if the surrounding UI and host app still launch.

### 2) The package expects device-specific `MobileGestalt` data to still match exactly

The restore helpers explicitly reject plists that do not match the connected device.

- Observed validation mapping in one helper:
  - `mZfUC7qo4pURNhyMHZ62RQ -> BuildVersion`
  - `h9jDsbgj7xIVeIQ8S3/X3Q -> ProductType`
  - `qNNddlUK+B/YlooNoymwgA -> ProductVersion`
  - `LeSRsiLoJCMhjn6nd6GWbQ -> FirmwareVersion`
- Observed validation mapping in the JSON restore helper:
  - `mZfUC7qo4pURNhyMHZ62RQ -> BuildVersion`
  - `/YYygAofPDbhrwToVsXdeA -> HardwareModel`
  - `LeSRsiLoJCMhjn6nd6GWbQ -> FirmwareVersion`
- Observed shipped `MobileGestalt` values include:
  - `J522AP`
  - `iPad13,8`
  - `t8103`
  - `22B5034e`

That means the shipped `com.apple.MobileGestalt.plist` is not a generic payload. It assumes a matching device and matching build-era metadata. On a newer 26.4 stack, even small metadata or cache format drift can invalidate that assumption.

### 3) The restore flow still depends on legacy setup and restore artifacts

The bundle writes old-style setup and restore files into domains that were useful on earlier stacks.

- Observed restored files:
  - `BLDatabaseManager.sqlite`
  - `CloudConfigurationDetails.plist`
  - `com.apple.purplebuddy.plist`
- Observed target domains:
  - `SysSharedContainerDomain-systemgroup.com.apple.media.shared.books`
  - `SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles`
  - `ManagedPreferencesDomain`
- Observed `CloudConfigurationDetails.plist` values:
  - `AllowPairing = true`
  - `ConfigurationWasApplied = true`
  - `CloudConfigurationUIComplete = true`
  - `PostSetupProfileWasInstalled = true`
- Observed `com.apple.purplebuddy.plist` values:
  - `SetupDone = true`
  - `SetupFinishedAllSteps = true`
  - `UserChoseLanguage = true`

Those are restore-time assumptions, not stable public platform contracts. If Apple tightened validation in 26.4, the flow fails even if the files and paths still exist.

### 4) TrollStore install depends on the system Tips app path staying stable

The install helper looks up `com.apple.tips` and then targets its executable path.

- Observed target logic:
  - query source `InstallationProxyService.get_apps(application_type="System")`
  - bundle id `com.apple.tips`
  - write target `${tips_path.replace('/private', '')}/Tips`

This is a secondary failure point. Even if `MobileGestalt` were unchanged, the package still assumes the system app inventory and target path behave like older builds.

## What Changed Between 26.0 and 26.4

The read-only comparison found three concrete changes that matter:

- `libMobileGestalt.dylib` changed size between 26.0 and 26.4.
- Key offsets used by the patching logic moved.
- The exported `MobileGestalt` symbol surface shrank in 26.4.
- Observed removed exports include:
  - `_MobileGestalt_get_allowPhoneApp`
  - `_MobileGestalt_get_audioExclaveMicInputCapability`
  - `_MobileGestalt_get_dataCenterRegionCode`
  - `_MobileGestalt_get_deviceSupportsDarwinInitConfigFromNVRAM`
  - `_MobileGestalt_get_deviceSupportsHandwritingSynthesisModel`
  - `_MobileGestalt_get_fanCount`
  - `_MobileGestalt_get_oSMigrationCapability`
  - `_MobileGestalt_get_uSBPortCount`

That does not prove a single exact failing line without a live target device, but it is strong evidence that the package was relying on private implementation details that no longer match the current runtime.

## What This Means

`misaka26` failing on iOS 26.4 is not just a packaging bug or a missing dependency. The package appears to depend on:

- private `MobileGestalt` layout
- device-specific cache data
- legacy restore/setup semantics
- stable system app target paths

Those are all brittle across OS updates. When Apple changes any of them, the old assumptions stop being valid.

## Related Docs

- [docs/misaka26-study.md](misaka26-study.md)
- [docs/EVIDENCE_APPENDIX.md](EVIDENCE_APPENDIX.md)
