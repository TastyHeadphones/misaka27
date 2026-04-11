# misaka27

## Usage

This App has been updated to bypass metadata checks and cleanly parse private system caches, making it fully compatible with iOS 26.4.

1. Download **`misaka27.zip`** from the GitHub release assets.
2. Unzip and run `misaka27.app` on your Mac.
3. Obtain your `com.apple.MobileGestalt.plist` using the **`SaveMobileGestaltV2.shortcut`**:
   - Download `SaveMobileGestaltV2.shortcut` from the [GitHub release page](https://github.com/TastyHeadphones/misaka27/releases/tag/v1.0.0).
   - **Double-click** the file on your Mac to open the Shortcuts app and add it. Since your Mac and iPhone share the same Apple ID, it will automatically sync to your iOS device!
   - Open the **Shortcuts app on your iOS 26.4 device** and run the shortcut.
   - It will display a popup with a `file:///` link. **Tap the link** to open the Quick Look preview.
   - **Select All** the text in the document and tap **Copy**. 
   - Tap **Done** to return to the shortcut. 
   - The shortcut will instantly fetch the copied data, format it into the correct `.plist` file, and open a Share menu for you.
   - Tap **AirDrop** to securely send your extracted `com.apple.MobileGestalt.plist` directly to your Mac!
4. Finally, on your Mac, drop the obtained `com.apple.MobileGestalt.plist` into `misaka27.app` and press Restore to dynamically patch your device for TrollPad or TrollStore!

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
