import Combine
import Foundation

struct VercelTranscriptionModel: Decodable, Identifiable, Equatable, Sendable {
    struct Pricing: Decodable, Equatable, Sendable {
        let input: String?
        let output: String?
        let audioInputTokenCost: String?
        let transcriptionDurationCostPerSecond: String?

        enum CodingKeys: String, CodingKey {
            case input
            case output
            case audioInputTokenCost = "audio_input_token_cost"
            case transcriptionDurationCostPerSecond = "transcription_duration_cost_per_second"
        }

        init(
            input: String? = nil,
            output: String? = nil,
            audioInputTokenCost: String? = nil,
            transcriptionDurationCostPerSecond: String? = nil
        ) {
            self.input = input
            self.output = output
            self.audioInputTokenCost = audioInputTokenCost
            self.transcriptionDurationCostPerSecond = transcriptionDurationCostPerSecond
        }
    }

    let id: String
    let name: String
    let description: String
    let type: String
    let ownedBy: String
    let tags: [String]
    let supportedSpecifications: [String]
    let pricing: Pricing

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, tags, pricing
        case ownedBy = "owned_by"
        case supportedSpecifications = "supported_specifications"
    }

    init(
        id: String,
        name: String,
        description: String,
        type: String = "transcription",
        ownedBy: String,
        tags: [String] = [],
        supportedSpecifications: [String] = ["v4"],
        pricing: Pricing = .init()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.ownedBy = ownedBy
        self.tags = tags
        self.supportedSpecifications = supportedSpecifications
        self.pricing = pricing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(String.self, forKey: .type)
        ownedBy = try container.decode(String.self, forKey: .ownedBy)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        supportedSpecifications = try container.decodeIfPresent(
            [String].self,
            forKey: .supportedSpecifications
        ) ?? []
        pricing = try container.decodeIfPresent(Pricing.self, forKey: .pricing) ?? .init()
    }

    var isBatchCompatible: Bool {
        supportedSpecifications.contains("v4")
            && !tags.contains("websocket-realtime")
            && !id.hasSuffix("-live")
    }

    var isFree: Bool { tags.contains("free") }

    func providerName(_ language: AppLanguage) -> String {
        switch ownedBy {
        case "openai": return "OpenAI"
        case "google": return "Google"
        case "fish-audio": return "Fish Audio"
        case "spacexai": return "SpaceXAI"
        default: return ownedBy
        }
    }

    func priceText(_ language: AppLanguage) -> String {
        if isFree {
            return language.text("무료", "Free")
        }

        if let rawCost = pricing.transcriptionDurationCostPerSecond,
           let cost = Decimal(string: rawCost, locale: Locale(identifier: "en_US_POSIX")) {
            let hourlyCost = cost * Decimal(3_600)
            return "$\(Self.formattedPrice(hourlyCost, minimumFractionDigits: 2))/\(language.text("시간", "hr"))"
        }

        let audioCost = pricing.audioInputTokenCost ?? pricing.input
        if let audioCost,
           let audio = Decimal(string: audioCost, locale: Locale(identifier: "en_US_POSIX")) {
            let audioPerMillion = audio * Decimal(1_000_000)
            let audioText = Self.formattedPrice(audioPerMillion)
            if let rawOutput = pricing.output,
               let output = Decimal(string: rawOutput, locale: Locale(identifier: "en_US_POSIX")) {
                let outputPerMillion = output * Decimal(1_000_000)
                let outputText = Self.formattedPrice(outputPerMillion)
                return language.text(
                    "오디오 $\(audioText)/M · 출력 $\(outputText)/M",
                    "Audio $\(audioText)/M · output $\(outputText)/M"
                )
            }
            return language.text("오디오 $\(audioText)/M 토큰", "Audio $\(audioText)/M tokens")
        }

        return language.text("가격 확인 필요", "Check price")
    }

    func summary(_ language: AppLanguage) -> String {
        if !isBatchCompatible {
            return language.text(
                "실시간 스트리밍 전용 · 현재 Whisp 방식에서는 선택 불가",
                "Realtime streaming only · not available in Whisp's current mode"
            )
        }

        switch id {
        case "openai/gpt-4o-mini-transcribe":
            return language.text("가격과 정확도의 균형이 좋은 기본 추천", "Recommended balance of cost and accuracy")
        case "openai/gpt-4o-transcribe":
            return language.text("잡음과 억양이 어려운 음성에 더 높은 정확도", "Higher accuracy for noisy audio and strong accents")
        case "openai/whisper-1":
            return language.text("번역과 언어 감지도 지원하는 범용 모델", "General-purpose model with translation and language detection")
        case "google/gemini-3.5-transcribe":
            return language.text("Google의 최신 녹음 파일 전사 모델", "Google's latest recorded-audio transcription model")
        case "fish-audio/transcribe-1", "fish-audio/transcribe-1-free":
            return language.text("자동 언어 감지와 단어별 타임스탬프", "Automatic language detection and word-level timestamps")
        case "spacexai/grok-stt":
            return language.text("25개 언어를 지원하는 저렴한 전사 모델", "Low-cost transcription across 25 languages")
        default:
            return description
        }
    }

    private static func formattedPrice(_ value: Decimal, minimumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = 2
        return formatter.string(for: value) ?? "-"
    }
}

private struct VercelModelCatalogResponse: Decodable {
    let data: [VercelTranscriptionModel]
}

@MainActor
final class VercelModelCatalog: ObservableObject {
    @Published private(set) var models = fallbackModels
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshFailed = false

    private var hasRefreshed = false

    func refreshIfNeeded() async {
        guard !hasRefreshed, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let url = URL(string: "https://ai-gateway.vercel.sh/v1/models")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw CatalogError.invalidResponse
            }
            let decoded = try JSONDecoder().decode(VercelModelCatalogResponse.self, from: data)
            let transcriptionModels = decoded.data
                .filter { $0.type == "transcription" && $0.supportedSpecifications.contains("v4") }
                .sorted(by: Self.sortModels)
            guard !transcriptionModels.isEmpty else { throw CatalogError.emptyCatalog }
            models = transcriptionModels
            refreshFailed = false
            hasRefreshed = true
        } catch {
            refreshFailed = true
        }
    }

    private static func sortModels(_ lhs: VercelTranscriptionModel, _ rhs: VercelTranscriptionModel) -> Bool {
        let preferredOrder = [
            "openai/gpt-4o-mini-transcribe",
            "openai/gpt-4o-transcribe",
            "google/gemini-3.5-transcribe",
            "spacexai/grok-stt",
            "fish-audio/transcribe-1-free",
            "fish-audio/transcribe-1",
            "openai/whisper-1",
            "google/gemini-3.5-transcribe-live",
            "openai/gpt-realtime-whisper"
        ]
        let left = preferredOrder.firstIndex(of: lhs.id) ?? Int.max
        let right = preferredOrder.firstIndex(of: rhs.id) ?? Int.max
        return left == right ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending : left < right
    }

    private enum CatalogError: Error {
        case invalidResponse
        case emptyCatalog
    }

    nonisolated static let fallbackModels: [VercelTranscriptionModel] = [
        .init(
            id: "openai/gpt-4o-mini-transcribe",
            name: "GPT-4o mini Transcribe",
            description: "Cost-efficient speech-to-text model.",
            ownedBy: "openai",
            pricing: .init(input: "0.00000125", output: "0.000005", audioInputTokenCost: "0.00000125")
        ),
        .init(
            id: "openai/gpt-4o-transcribe",
            name: "GPT-4o Transcribe",
            description: "High-accuracy speech-to-text model.",
            ownedBy: "openai",
            pricing: .init(input: "0.0000025", output: "0.00001", audioInputTokenCost: "0.0000025")
        ),
        .init(
            id: "google/gemini-3.5-transcribe",
            name: "Gemini 3.5 Transcribe",
            description: "Transcription by Google.",
            ownedBy: "google",
            pricing: .init(input: "0.000002", output: "0.000012", audioInputTokenCost: "0.000002")
        ),
        .init(
            id: "spacexai/grok-stt",
            name: "Grok STT",
            description: "Transcription across 25 languages.",
            ownedBy: "spacexai",
            tags: ["websocket-transcription"],
            pricing: .init(input: "0", transcriptionDurationCostPerSecond: "0.000028")
        ),
        .init(
            id: "fish-audio/transcribe-1-free",
            name: "Transcribe-1 (Free)",
            description: "Fish Audio multilingual transcription.",
            ownedBy: "fish-audio",
            tags: ["free"]
        ),
        .init(
            id: "fish-audio/transcribe-1",
            name: "Transcribe-1",
            description: "Fish Audio multilingual transcription.",
            ownedBy: "fish-audio",
            tags: ["free"]
        ),
        .init(
            id: "openai/whisper-1",
            name: "Whisper",
            description: "General-purpose multilingual speech recognition.",
            ownedBy: "openai",
            pricing: .init(input: "0.0000000001", transcriptionDurationCostPerSecond: "0.0001")
        ),
        .init(
            id: "google/gemini-3.5-transcribe-live",
            name: "Gemini 3.5 Transcribe Live",
            description: "Live transcription by Google.",
            ownedBy: "google",
            tags: ["websocket-transcription"],
            pricing: .init(input: "0.0000000001", transcriptionDurationCostPerSecond: "0.00015")
        ),
        .init(
            id: "openai/gpt-realtime-whisper",
            name: "gpt-realtime-whisper",
            description: "Realtime streaming transcription.",
            ownedBy: "openai",
            tags: ["websocket-realtime", "websocket-transcription"],
            pricing: .init(input: "0.0000000002", transcriptionDurationCostPerSecond: "0.000284")
        )
    ]
}
