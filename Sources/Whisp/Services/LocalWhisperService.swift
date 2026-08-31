import Foundation

struct LocalWhisperService {
    static func resolveExecutable(customPath: String) throws -> URL {
        let candidates = [customPath, "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"]
            .filter { !$0.isEmpty }
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw LocalWhisperError.executableMissing
    }

    func transcribe(
        audioURL: URL,
        executableURL: URL,
        modelURL: URL,
        language: String,
        prompt: String
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let outputBase = FileManager.default.temporaryDirectory
                .appendingPathComponent("whisp-output-\(UUID().uuidString)")
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executableURL
            process.standardOutput = pipe
            process.standardError = pipe
            process.arguments = [
                "-m", modelURL.path,
                "-f", audioURL.path,
                "-l", language,
                "-otxt",
                "-of", outputBase.path,
                "-np"
            ] + (prompt.isEmpty ? [] : ["-p", prompt])

            try process.run()
            process.waitUntilExit()
            let diagnostic = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw LocalWhisperError.processFailed(diagnostic.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            let textURL = outputBase.appendingPathExtension("txt")
            defer { try? FileManager.default.removeItem(at: textURL) }
            guard let text = try? String(contentsOf: textURL, encoding: .utf8) else {
                throw LocalWhisperError.noOutput
            }
            return text
        }.value
    }
}

enum LocalWhisperError: LocalizedError {
    case executableMissing
    case processFailed(String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case .executableMissing:
            return "whisper.cpp가 없습니다. `brew install whisper-cpp` 후 다시 시도해 주세요."
        case .processFailed(let message):
            return message.isEmpty ? "로컬 전사에 실패했습니다." : "로컬 전사 실패: \(message)"
        case .noOutput:
            return "whisper.cpp가 결과 파일을 만들지 못했습니다."
        }
    }
}
