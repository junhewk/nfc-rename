import Foundation

struct RenameResult {
    let originalPath: String
    let newName: String?
    let error: String?

    var wasRenamed: Bool { newName != nil && error == nil }
    var wasSkipped: Bool { newName == nil && error == nil }
}

struct ConversionSummary {
    let results: [RenameResult]
    var renamed: Int { results.filter(\.wasRenamed).count }
    var skipped: Int { results.filter(\.wasSkipped).count }
    var failed: Int { results.filter { $0.error != nil }.count }
}

class NFCConverter {
    private let fileManager = FileManager.default

    func convert(urls: [URL], recursive: Bool) -> ConversionSummary {
        var results: [RenameResult] = []

        for url in urls {
            let path = url.path
            if recursive {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    results.append(contentsOf: convertRecursive(directory: path))
                }
            }
            results.append(convertSingle(path: path))
        }

        return ConversionSummary(results: results)
    }

    func convertSingle(path: String) -> RenameResult {
        let filename = (path as NSString).lastPathComponent
        let nfcFilename = filename.precomposedStringWithCanonicalMapping

        // Compare raw UTF-8 bytes — Swift String == treats NFD and NFC as equal
        guard filename.data(using: .utf8) != nfcFilename.data(using: .utf8) else {
            return RenameResult(originalPath: path, newName: nil, error: nil)
        }

        let parent = (path as NSString).deletingLastPathComponent
        let tempPath = (parent as NSString).appendingPathComponent(".nfc_temp_\(UUID().uuidString)")
        let newPath = (parent as NSString).appendingPathComponent(nfcFilename)

        // Use POSIX rename — FileManager.moveItem normalizes through URL and loses NFD/NFC distinction
        guard rename(path, tempPath) == 0 else {
            return RenameResult(originalPath: path, newName: nfcFilename, error: String(cString: strerror(errno)))
        }

        guard rename(tempPath, newPath) == 0 else {
            let err = String(cString: strerror(errno))
            // Try to restore
            rename(tempPath, path)
            return RenameResult(originalPath: path, newName: nfcFilename, error: err)
        }

        return RenameResult(originalPath: path, newName: nfcFilename, error: nil)
    }

    private func convertRecursive(directory: String) -> [RenameResult] {
        guard let enumerator = fileManager.enumerator(atPath: directory) else { return [] }

        var allPaths: [String] = []
        while let relative = enumerator.nextObject() as? String {
            // Skip hidden files
            if (relative as NSString).lastPathComponent.hasPrefix(".") { continue }
            allPaths.append((directory as NSString).appendingPathComponent(relative))
        }

        // Sort deepest paths first — renaming parent before children invalidates child paths
        allPaths.sort { $0.components(separatedBy: "/").count > $1.components(separatedBy: "/").count }

        return allPaths.map { convertSingle(path: $0) }
    }
}
