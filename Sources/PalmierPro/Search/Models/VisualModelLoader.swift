import AppKit
import Foundation

/// App-level search model loader. Loads the SigLIP model on app launch.
@MainActor
@Observable
final class VisualModelLoader {
    static let shared = VisualModelLoader()

    enum State: Equatable {
        case unknown
        case notInstalled
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    private(set) var state: State = .unknown
    private(set) var enabled = SearchIndexConfig.enabled
    @ObservationIgnored private(set) var embedder: VisualEmbedder?
    private let downloader = ModelDownloader()
    private var downloadConfirmationVisible = false

    var isReady: Bool { state == .ready }

    private init() {}

    /// Loads an installed model if present; never downloads. Idempotent
    func prepare() async {
        guard enabled, state == .unknown else { return }
        guard let installed = ModelDownloader.installed(for: SearchIndexConfig.manifest) else {
            state = .notInstalled
            return
        }
        state = .preparing
        await load(installed)
    }

    func requestDownload() {
        switch state {
        case .downloading, .preparing, .ready: return
        default: break
        }
        guard !downloadConfirmationVisible else { return }

        downloadConfirmationVisible = true
        let alert = NSAlert()
        alert.messageText = "Download Smart Search model?"
        alert.informativeText = Self.downloadDescription
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")

        let handleResponse: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            self.downloadConfirmationVisible = false
            guard response == .alertFirstButtonReturn else { return }
            self.download()
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(alert.runModal())
        }
    }

    private func download() {
        switch state {
        case .downloading, .preparing, .ready: return
        default: break
        }
        state = .downloading(0)
        Task {
            do {
                let installed = try await downloader.install(
                    manifest: SearchIndexConfig.manifest, baseURL: SearchIndexConfig.baseURL
                ) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = .downloading(fraction)
                    }
                }
                guard enabled else { state = .unknown; return }
                state = .preparing
                await load(installed)
            } catch {
                state = .failed(error.localizedDescription)
                Log.search.error("model download failed: \(error.localizedDescription)")
            }
        }
    }

    private static var downloadDescription: String {
        let manifest = SearchIndexConfig.manifest
        let size = ByteCountFormatter.string(fromByteCount: manifest.downloadBytes, countStyle: .file)

        return """
        This will download a model from HuggingFace.
        
        Model: \(manifest.model), version \(manifest.version)
        Download size: \(size)
        """
    }

    func setEnabled(_ value: Bool) {
        SearchIndexConfig.enabled = value
        enabled = value
        if value {
            Task { await prepare(); SearchIndexCoordinator.sweepAll() }
        } else {
            Task {
                await SearchIndexCoordinator.cancelAll()
                embedder = nil
                if state == .ready || state == .preparing { state = .unknown }
            }
        }
    }

    /// Deletes the installed model and resets every project's index state.
    func remove() async {
        await SearchIndexCoordinator.resetAll()
        embedder = nil
        state = .notInstalled
        try? FileManager.default.removeItem(at: ModelDownloader.modelsDir)
    }

    private func load(_ installed: ModelDownloader.InstalledModel) async {
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                let tokenizer = try await TextTokenizer(
                    tokenizerFolder: installed.tokenizerFolder,
                    contextLength: installed.spec.contextLength
                )
                let model = try VisualEmbedder(
                    imageEncoderURL: installed.imageEncoderURL,
                    textEncoderURL: installed.textEncoderURL,
                    tokenizer: tokenizer,
                    spec: installed.spec
                )
                _ = try model.encode(text: "warm up")
                return model
            }.value
            embedder = loaded
            state = .ready
            Log.search.notice("search model ready dim=\(loaded.spec.embeddingDim)")
            SearchIndexCoordinator.sweepAll()
        } catch {
            state = .failed(error.localizedDescription)
            Log.search.error("search model load failed: \(error.localizedDescription)")
        }
    }
}
