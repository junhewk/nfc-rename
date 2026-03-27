# NFCRename

A lightweight macOS drop zone that converts NFD (decomposed) Unicode filenames to NFC (composed).

macOS internally stores Korean filenames in NFD form, which causes broken filenames (e.g. `ㅎㅏㄴㄱㅡㄹ` instead of `한글`) when transferred to Windows, Linux, or NAS devices. NFCRename fixes this — just drag and drop.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

## How it works

1. Launch the app — a small floating drop zone appears on screen
2. Drag files or folders from Finder onto the drop zone
3. Done. Filenames are converted from NFD to NFC

- Always-on-top floating window — stays visible while you work in Finder
- Borderless, draggable — move it anywhere, position is remembered across launches
- Shows conversion results briefly, then fades

## The problem

macOS uses NFD (Normalization Form Decomposed) for filenames on APFS. The Korean character `한` is stored as three separate jamo: `ㅎ` + `ㅏ` + `ㄴ`. Most other operating systems expect NFC (Normalization Form Composed), where `한` is a single codepoint.

When you copy files from macOS to a USB drive, NAS, or cloud storage, the NFD filenames often appear garbled on the receiving end.

## Technical details

- Uses POSIX `rename()` for the actual file rename — Swift's `FileManager.moveItem` normalizes paths through `URL` and silently loses the NFD/NFC distinction
- Two-step rename (`original → temp → NFC`) because APFS is normalization-insensitive and would treat a direct NFD→NFC rename as a no-op
- Compares raw UTF-8 bytes to detect NFD filenames — Swift's `String ==` performs canonical equivalence and treats NFD/NFC as equal
- Bottom-up traversal for recursive folder conversion to avoid invalidating child paths

## Install

No signed binary is provided — you need to build from source. Requires macOS 14.0+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
# 1. Install XcodeGen (if not installed)
brew install xcodegen

# 2. Clone and build
git clone https://github.com/junhewk/nfc-rename.git
cd nfc-rename
xcodegen generate
xcodebuild -scheme NFCRename -configuration Release build

# 3. Copy to Applications
cp -r ~/Library/Developer/Xcode/DerivedData/NFCRename-*/Build/Products/Release/NFCRename.app ~/Applications/

# 4. Launch
open ~/Applications/NFCRename.app
```

Since the app is not notarized, macOS may block it on first launch. Right-click the app → Open → Open to bypass Gatekeeper.

## License

MIT
