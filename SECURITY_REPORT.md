# SECURITY_REPORT: misaka26 iOS 26.4 Compatibility and Safety Findings

## Purpose

This document provides a responsible-disclosure style package based on read-only evidence collection.

- No device restore was performed.
- No patch helper was executed.
- No system file, app binary, entitlement, backup, or simulator runtime was modified.

Use `scripts/read_only_compat_check.sh` to regenerate evidence in a reproducible way.
Use `scripts/generate_full_evidence_pack.sh` to generate a detailed evidence bundle with copied helper code, plist payloads, full command logs, and symbol diffs.

## Reproduction (Read-Only)

Run from repository root:

```sh
./scripts/read_only_compat_check.sh --output reports/read_only_compat_report_latest.md
./scripts/generate_full_evidence_pack.sh --out-dir evidence/full_pack_latest
```

Artifacts produced:

- `reports/read_only_compat_report_latest.md`
- `evidence/full_pack_latest/EVIDENCE_INDEX.md`
- `evidence/full_pack_latest/commands/*.txt`
- `evidence/full_pack_latest/code/*`
- `evidence/full_pack_latest/plists/*`

## Environment Snapshot (example from latest run)

- Host OS: macOS 25.4 (arm64)
- Xcode: 26.4 (`17E192`)
- Installed iOS SDK: 26.4
- Simulator runtimes present:
  - iOS 26.0 (`23A343`)
  - iOS 26.4 (`23E244`)

## Key Evidence Summary

1. `misaka26` relies on private `MobileGestalt` assumptions.
- Read-only script evidence shows direct references to obfuscated keys and fixed patch constants in helper scripts.
- Observed constants include `START_INDEX = 1616`, `SLICE_LENGTH = 200`, and key `mtrAoWJ3gsq+I90ZnQ0vQw`.

2. Device/build identity checks are strict and device-specific.
- Observed key mappings in helper code:
  - `mZfUC7qo4pURNhyMHZ62RQ -> BuildVersion`
  - `h9jDsbgj7xIVeIQ8S3/X3Q -> ProductType`
  - `qNNddlUK+B/YlooNoymwgA -> ProductVersion`
  - `LeSRsiLoJCMhjn6nd6GWbQ -> FirmwareVersion`
  - `/YYygAofPDbhrwToVsXdeA -> HardwareModel`

3. Runtime drift is visible between iOS 26.0 and iOS 26.4.
- `libMobileGestalt.dylib` size differs:
  - 26.0: `939984`
  - 26.4: `973792`
- Key string offsets differ:
  - `mtrAoWJ3gsq+I90ZnQ0vQw`: `229300` -> `224895`
  - `DeviceClassNumber`: `250714` -> `248954`
  - `BuildVersion`: `249971` -> `248190`
- Export-surface delta exists between 26.0 and 26.4 in `MobileGestalt_*` symbols.
- The generated evidence pack records the full delta in:
  - `commands/runtime_mobilegestalt_symbol_delta.txt`
  - `runtime/only_26_0_mobilegestalt_symbols.txt`
  - `runtime/only_26_4_mobilegestalt_symbols.txt`

4. Legacy restore/setup assumptions are present in payload logic.
- Observed keys in payload templates include:
  - `AllowPairing`
  - `ConfigurationWasApplied`
  - `CloudConfigurationUIComplete`
  - `PostSetupProfileWasInstalled`
  - `SetupDone`
  - `SetupFinishedAllSteps`
  - `UserChoseLanguage`

## Risk Characterization

- This package appears sensitive to private runtime layout changes.
- Compatibility breakage on iOS 26.4 is consistent with private implementation drift.
- The evidence does not require enabling or executing modification behavior.

## What Is Included

- Reproducible read-only collection script:
  - `scripts/read_only_compat_check.sh`
- Detailed read-only evidence bundle script:
  - `scripts/generate_full_evidence_pack.sh`
- Generated evidence report path (created locally when script is run):
  - `reports/read_only_compat_report_latest.md`
- Detailed evidence bundle path (created locally when script is run):
  - `evidence/full_pack_latest/`

## What Is Explicitly Excluded

- No exploit adaptation instructions.
- No guidance to bypass platform protections.
- No steps to re-enable blocked functionality.

## Suggested Apple Security Contact Template

Subject:

`Read-only compatibility and safety findings for private MobileGestalt-dependent behavior on iOS 26.4`

Body:

```text
Hello Apple Security,

I am reporting read-only compatibility and safety findings related to a third-party package that appears to rely on private MobileGestalt-dependent behavior. I am not including or requesting exploit enablement.

I collected evidence using static analysis and runtime metadata only, without modifying devices, simulator runtimes, binaries, entitlements, backups, or system files.

Attached:
1) SECURITY_REPORT.md
2) reports/read_only_compat_report_latest.md

Key observations:
- iOS 26.0 vs 26.4 runtime drift in libMobileGestalt (size, offsets, symbol-surface delta).
- Device/build-specific assumptions in helper logic and payload metadata.
- Legacy setup/restore assumptions in packaged payloads.

Please let me know if you want the report in a different format.

Regards,
<name>
```
