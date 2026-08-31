import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case korean
    case english

    var id: String { rawValue }

    var usesKorean: Bool {
        switch self {
        case .korean: return true
        case .english: return false
        case .system:
            return Locale.preferredLanguages.first?.lowercased().hasPrefix("ko") == true
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .korean: return Locale(identifier: "ko")
        case .english: return Locale(identifier: "en")
        }
    }

    func text(_ korean: String, _ english: String) -> String {
        usesKorean ? korean : english
    }

    func pickerTitle(in interfaceLanguage: AppLanguage) -> String {
        switch self {
        case .system: return interfaceLanguage.text("시스템 설정", "System")
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    func localizeError(_ message: String) -> String {
        guard !usesKorean else { return message }

        let exact: [String: String] = [
            "녹음 파일을 만들지 못했습니다.": "Could not create the recording file.",
            "선택한 로컬 모델을 먼저 내려받아 주세요.": "Download the selected local model first.",
            "음성을 인식하지 못했습니다. 다시 말해 주세요.": "No speech was recognized. Please try again.",
            "시스템 설정에서 Whisp의 마이크 접근을 허용해 주세요.": "Allow Whisp to access the microphone in System Settings.",
            "마이크 녹음을 시작하지 못했습니다.": "Could not start microphone recording.",
            "API Base URL을 입력해 주세요.": "Enter an API Base URL.",
            "올바른 HTTPS API Base URL을 입력해 주세요.": "Enter a valid HTTPS API Base URL.",
            "전사 API 응답을 읽지 못했습니다.": "Could not read the transcription API response.",
            "Vercel Gateway 응답을 읽지 못했습니다.": "Could not read the Vercel Gateway response.",
            "whisper.cpp가 없습니다. `brew install whisper-cpp` 후 다시 시도해 주세요.": "whisper.cpp was not found. Run `brew install whisper-cpp` and try again.",
            "로컬 전사에 실패했습니다.": "Local transcription failed.",
            "whisper.cpp가 결과 파일을 만들지 못했습니다.": "whisper.cpp did not create an output file.",
            "모델 다운로드에 실패했습니다.": "The model download failed."
        ]
        if let translated = exact[message] { return translated }

        if message.hasPrefix("설정에서 "), message.hasSuffix(" API 키를 입력해 주세요.") {
            let provider = message
                .dropFirst("설정에서 ".count)
                .dropLast(" API 키를 입력해 주세요.".count)
            return "Enter your \(provider) API key in Settings."
        }
        if message.hasPrefix("전사 API 오류 ") {
            return message.replacingOccurrences(of: "전사 API 오류", with: "Transcription API error")
        }
        if message.hasPrefix("Vercel Gateway 오류 ") {
            return message.replacingOccurrences(of: "Vercel Gateway 오류", with: "Vercel Gateway error")
        }
        if message.hasPrefix("로컬 전사 실패:") {
            return message.replacingOccurrences(of: "로컬 전사 실패:", with: "Local transcription failed:")
        }
        return message
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.system
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}
