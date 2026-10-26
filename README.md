# NFCRename

A lightweight macOS utility that checks and converts NFD (decomposed) Unicode filenames to NFC (composed) — from a floating drop zone or straight from Finder's right-click menu.

macOS stores Korean filenames in NFD form, which causes broken filenames (e.g. `ㅎㅏㄴㄱㅡㄹ` instead of `한글`) when they're transferred to Windows, Linux, NAS devices, or some cloud services. NFCRename finds and fixes them.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

## Install

1. Download `NFCRename-<version>.zip` from [Releases](https://github.com/junhewk/nfc-rename/releases)
2. Unzip and move `NFCRename.app` to `/Applications`
3. Open it

The app is signed with a Developer ID and notarized by Apple, so it opens normally — no Gatekeeper workaround, no Full Disk Access, and no extensions to enable.

## Usage

### Finder right-click menu

Select files or folders in Finder, right-click, and choose from **Services** (or **Quick Actions**):

| Menu item | Korean system language | What it does |
|---|---|---|
| **Convert Filenames to NFC** | 파일 이름을 NFC로 변환 | Renames NFD names to NFC |
| **Check Filename Normalization** | 파일 이름 NFD/NFC 확인 | Reports how many names are NFD — renames nothing |

The result appears in the drop zone. After a check that found NFD names, hover over the drop zone and click **변환** to convert them.

> If the items don't show up right after installing, open NFCRename once. If they're still missing, enable them in **System Settings → Keyboard → Keyboard Shortcuts… → Services → Files and Folders**.

### Drop zone

A small always-on-top window that remembers its position.

- **Drop** files or folders → converted to NFC
- **Hold ⌥ while dropping** → check only, nothing is renamed
- **Hover** for quick controls: subfolder toggle, file picker, quit
- **Right-click** the drop zone for the same actions
- **⌘O** choose files to convert · **⌥⌘O** choose files to check

The result shows briefly: how many names were converted, or for a check, how many are NFD. Hover over a result to see the affected filenames, or why a rename failed.

**하위 폴더 (Include subfolders)** is on by default: dropping a folder processes everything inside it. Hidden files and folders such as `.git` are skipped.

## The problem

macOS uses NFD (Normalization Form Decomposed) for many filenames. The Korean character `한` is stored as three separate jamo: `ㅎ` + `ㅏ` + `ㄴ`. Most other operating systems expect NFC (Normalization Form Composed), where `한` is a single codepoint.

The two forms look identical in Finder, so you can't tell which one a file uses — that's what **Check Filename Normalization** is for. When you copy NFD-named files from macOS to a USB drive, NAS, or cloud storage, the names often appear garbled on the receiving end.

## Technical details

- Uses POSIX `rename()` for the actual file rename — Swift's `FileManager.moveItem` normalizes paths through `URL` and silently loses the NFD/NFC distinction
- Two-step rename (`original → temp → NFC`) because APFS is normalization-insensitive and would treat a direct NFD→NFC rename as a no-op
- Compares raw UTF-8 bytes to detect NFD filenames — Swift's `String ==` performs canonical equivalence and treats NFD/NFC as equal
- Bottom-up traversal for recursive folder conversion to avoid invalidating child paths
- Finder integration uses the system Services menu (`NSServices`), so it needs no app extension or extra permissions
- Conversion runs off the main thread, so large folders don't freeze the drop zone

## Build from source

Requires macOS 14.0+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/junhewk/nfc-rename.git
cd nfc-rename
xcodegen generate
open NFCRename.xcodeproj
```

To build a signed, notarized release (maintainers — requires Xcode signed in to the Developer ID team):

```bash
scripts/release.sh   # → build/release/NFCRename-<version>.zip
```

## Author

[Junhewk Kim](https://github.com/junhewk)

## License

MIT
