import AppKit
import Foundation

struct WhisperModel: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let size: String
    let url: URL

    static let catalog: [WhisperModel] = [
        .init(id: "tiny", name: "Tiny", detail: "가장 빠름 · 간단한 메모", size: "75 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!),
        .init(id: "base", name: "Base", detail: "속도와 정확도의 균형", size: "142 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!),
        .init(id: "small", name: "Small", detail: "한국어 정확도 우선", size: "466 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!)
    ]

    func detail(_ language: AppLanguage) -> String {
        switch id {
        case "tiny": return language.text("가장 빠름 · 간단한 메모", "Fastest · Quick notes")
        case "base": return language.text("속도와 정확도의 균형", "Balanced speed and accuracy")
        case "small": return language.text("한국어 정확도 우선", "Better accuracy, especially for Korean")
        default: return detail
        }
    }
}

@MainActor
final class ModelManager: ObservableObject {
    @Published private(set) var downloading = Set<String>()
    @Published var errorMessage: String?

    let modelsDirectory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = support.appendingPathComponent("Whisp/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func localURL(for id: String) -> URL {
        modelsDirectory.appendingPathComponent("ggml-\(id).bin")
    }

    func isInstalled(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: model.id).path)
    }

    func install(_ model: WhisperModel) {
        guard !downloading.contains(model.id) else { return }
        downloading.insert(model.id)
        errorMessage = nil

        Task {
            defer { downloading.remove(model.id) }
            do {
                let (temporary, response) = try await URLSession.shared.download(from: model.url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw ModelManagerError.downloadFailed
                }
                let destination = localURL(for: model.id)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: temporary, to: destination)
                objectWillChange.send()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func remove(_ model: WhisperModel) {
        do {
            try FileManager.default.removeItem(at: localURL(for: model.id))
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealModelsFolder() {
        NSWorkspace.shared.open(modelsDirectory)
    }
}

enum ModelManagerError: LocalizedError {
    case downloadFailed
    var errorDescription: String? { "모델 다운로드에 실패했습니다." }
}
