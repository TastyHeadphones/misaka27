# Why `misaka26` Does Not Work on iOS 26.4

This note is the short version of the broader study in [docs/misaka26-study.md](misaka26-study.md).

## Short Answer

`misaka26` depends on private, version-sensitive behavior that changed between the older iOS 26.0 stack and the current iOS 26.4 stack.

The biggest break is the `MobileGestalt` path. The package does not use a stable public API for that flow. It patches internal data by offset and expects older restore-era assumptions to still hold. Those assumptions are not stable across system updates.

## The Main Reasons

### 1) The `MobileGestalt` patcher is tied to private binary layout

The patching logic is not capability-based. It is offset-based.

- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.py#L5) searches `CacheData` inside a fixed window starting at `START_INDEX = 1616`.
- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.m`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/trollpad_patcher.m#L16) resolves an offset from `/usr/lib/libMobileGestalt.dylib` and writes the `DeviceClassNumber` byte directly.

That only works if Apple keeps the same internal data layout. In the read-only 26.0 vs 26.4 comparison, `libMobileGestalt.dylib` changed size, key string offsets moved, and several exported getters disappeared. That is enough to break a private offset patcher even if the surrounding UI and host app still launch.

### 2) The package expects device-specific `MobileGestalt` data to still match exactly

The restore helpers explicitly reject plists that do not match the connected device.

- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/_.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/_.py#L51) checks `BuildVersion`, `ProductType`, `ProductVersion`, and `FirmwareVersion`.
- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/json_restore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/json_restore.py#L42) checks `BuildVersion`, `HardwareModel`, and `FirmwareVersion`.

That means the shipped `com.apple.MobileGestalt.plist` is not a generic payload. It assumes a matching device and matching build-era metadata. On a newer 26.4 stack, even small metadata or cache format drift can invalidate that assumption.

### 3) The restore flow still depends on legacy setup and restore artifacts

The bundle writes old-style setup and restore files into domains that were useful on earlier stacks.

- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/gestalt_restore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/gestalt_restore.py#L78) restores:
  - `BLDatabaseManager.sqlite`
  - `CloudConfigurationDetails.plist`
  - `com.apple.purplebuddy.plist`
- [`misaka26.app/Contents/Resources/sparserestore/dist/arm64/CloudConfigurationDetails.plist`](../misaka26.app/Contents/Resources/sparserestore/dist/arm64/CloudConfigurationDetails.plist#L51) sets `AllowPairing`, `ConfigurationWasApplied`, and `CloudConfigurationUIComplete`.
- [`misaka26.app/Contents/Resources/sparserestore/dist/arm64/com.apple.purplebuddy.plist`](../misaka26.app/Contents/Resources/sparserestore/dist/arm64/com.apple.purplebuddy.plist#L5) marks setup as complete.

Those are restore-time assumptions, not stable public platform contracts. If Apple tightened validation in 26.4, the flow fails even if the files and paths still exist.

### 4) TrollStore install depends on the system Tips app path staying stable

The install helper looks up `com.apple.tips` and then targets its executable path.

- [`misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/install_trollstore.py`](../misaka26.app/Contents/Frameworks/App.framework/Resources/flutter_assets/sparserestore/install_trollstore.py#L19)

This is a secondary failure point. Even if `MobileGestalt` were unchanged, the package still assumes the system app inventory and target path behave like older builds.

## What Changed Between 26.0 and 26.4

The read-only comparison found three concrete changes that matter:

- `libMobileGestalt.dylib` changed size between 26.0 and 26.4.
- Key offsets used by the patching logic moved.
- The exported `MobileGestalt` symbol surface shrank in 26.4.

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

