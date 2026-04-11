# misaka27

## Usage

This App has been updated to bypass metadata checks and cleanly parse private system caches, making it fully compatible with iOS 26.4.

1. Download **`misaka27.zip`** from the GitHub release assets.
2. Unzip and run `misaka27.app` on your Mac.
3. Extract `com.apple.MobileGestalt.plist` using the Shortcuts app on your iOS device.
4. Run the app to dynamically patch your MobileGestalt for TrollPad or TrollStore!

---
Repository study notes for `misaka26` are in [docs/misaka26-study.md](docs/misaka26-study.md).
The short explanation for iOS 26.4 incompatibility is in [docs/why-misaka26-does-not-work-on-ios26.4.md](docs/why-misaka26-does-not-work-on-ios26.4.md).

Read-only compatibility checker:

```sh
./scripts/read_only_compat_check.sh --output reports/read_only_compat_report_latest.md
```

Full evidence pack (detailed command logs + copied code/plist evidence):

```sh
./scripts/generate_full_evidence_pack.sh --out-dir evidence/full_pack_latest
```

Disclosure package template:

- [SECURITY_REPORT.md](SECURITY_REPORT.md)
