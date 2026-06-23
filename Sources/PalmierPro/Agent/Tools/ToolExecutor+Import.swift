import Foundation

extension ToolExecutor {
    static let importBytesMaxBase64Length = 15 * 1024 * 1024

    private static let importMediaAllowedKeys: Set<String> = ["source", "name", "folderId"]
    private static let importSourceAllowedKeys: Set<String> = ["path", "bytes", "mimeType"]

    func importMedia(_ editor: EditorViewModel, _ args: [String: Any]) async throws -> ToolResult {
        try validateUnknownKeys(args, allowed: Self.importMediaAllowedKeys, path: "import_media")
        guard let source = args["source"] as? [String: Any] else {
            throw ToolError("Missing required 'source' object")
        }
        try validateUnknownKeys(source, allowed: Self.importSourceAllowedKeys, path: "source")

        let path = source.string("path")
        let bytes = source.string("bytes")
        guard [path, bytes].compactMap({ $0 }).count == 1 else {
            throw ToolError("source must set exactly one of 'path' or 'bytes'")
        }

        let folderId = try resolveFolderId(args, editor: editor)
        let name = args.string("name")
        if let path {
            return try await importFromPath(editor: editor, path: path, name: name, folderId: folderId)
        }
        guard let bytes, let mimeType = source.string("mimeType") else {
            throw ToolError("source.mimeType is required when source.bytes is set")
        }
        return try importFromBytes(
            editor: editor,
            base64: bytes,
            mimeType: mimeType,
            name: name,
            folderId: folderId
        )
    }

    private func importFromPath(editor: EditorViewModel, path: String, name: String?, folderId: String?) async throws -> ToolResult {
        let fileURL = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            throw ToolError("File not found: \(path)")
        }
        if isDirectory.boolValue {
            let summary = await editor.importFinderItems([fileURL], into: folderId)
            guard summary.assetCount > 0 else {
                throw ToolError("No supported media found in folder: \(path)")
            }
            return .ok("Imported \(summary.assetCount) file(s) from '\(fileURL.lastPathComponent)'.")
        }
        let ext = fileURL.pathExtension.lowercased()
        guard ClipType(fileExtension: ext) != nil else {
            throw ToolError("Unsupported file extension '.\(ext)'. Supported: mov/mp4/m4v, mp3/wav/aac/m4a/aiff/aifc/flac, png/jpg/jpeg/tiff/heic, json.")
        }
        guard let asset = editor.addMediaAsset(from: fileURL) else {
            throw ToolError("Failed to import file: \(path)")
        }
        applyImportMetadata(editor: editor, asset: asset, name: name, folderId: folderId)
        return .ok("Imported '\(asset.name)' (id: \(asset.id), type: \(asset.type.rawValue)).")
    }

    private func importFromBytes(
        editor: EditorViewModel,
        base64: String,
        mimeType: String,
        name: String?,
        folderId: String?
    ) throws -> ToolResult {
        guard base64.utf8.count <= Self.importBytesMaxBase64Length else {
            throw ToolError("source.bytes is too large; use source.path for larger files.")
        }
        guard let fileExtension = Self.fileExtension(forMime: mimeType) else {
            throw ToolError("Unsupported mimeType '\(mimeType)'.")
        }
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]), !data.isEmpty else {
            throw ToolError("source.bytes is not valid non-empty base64")
        }
        guard let projectURL = editor.projectURL else {
            throw ToolError("No project is open; cannot import bytes")
        }

        let mediaDirectory = projectURL.appendingPathComponent(Project.mediaDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let destination = mediaDirectory.appendingPathComponent(
            "imported-\(UUID().uuidString.prefix(8)).\(fileExtension)"
        )
        try data.write(to: destination)

        guard let asset = editor.addMediaAsset(from: destination) else {
            try? FileManager.default.removeItem(at: destination)
            throw ToolError("Failed to register imported asset")
        }
        applyImportMetadata(editor: editor, asset: asset, name: name, folderId: folderId)
        return .ok("Imported '\(asset.name)' (id: \(asset.id), type: \(asset.type.rawValue)).")
    }

    private func applyImportMetadata(editor: EditorViewModel, asset: MediaAsset, name: String?, folderId: String?) {
        if let name {
            asset.name = name
            if let index = editor.mediaManifest.entries.firstIndex(where: { $0.id == asset.id }) {
                editor.mediaManifest.entries[index].name = name
            }
        }
        if let folderId {
            editor.moveAssetsToFolder(assetIds: [asset.id], folderId: folderId)
        }
    }

    private static func fileExtension(forMime mime: String) -> String? {
        switch mime.lowercased() {
        case "video/mp4", "video/mpeg4": "mp4"
        case "video/quicktime": "mov"
        case "audio/mpeg", "audio/mp3": "mp3"
        case "audio/wav", "audio/x-wav", "audio/wave": "wav"
        case "audio/aac": "aac"
        case "audio/mp4", "audio/m4a", "audio/x-m4a": "m4a"
        case "audio/aiff", "audio/x-aiff": "aiff"
        case "audio/aifc", "audio/x-aifc": "aifc"
        case "audio/flac", "audio/x-flac": "flac"
        case "image/png": "png"
        case "image/jpeg", "image/jpg": "jpg"
        case "image/tiff": "tiff"
        case "image/heic", "image/heif": "heic"
        case "application/json", "application/vnd.lottie+json": "json"
        default: nil
        }
    }
}
