import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject {
    var onLevel: ((Double) -> Void)?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var outputURL: URL?
    private var smoothedLevel = 0.08

    func start() async throws {
        guard await requestMicrophoneAccess() else { throw AudioRecorderError.permissionDenied }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisp-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else { throw AudioRecorderError.couldNotStart }

        self.recorder = recorder
        outputURL = url
        smoothedLevel = 0.08
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleLevel() }
        }
    }

    func stop() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        smoothedLevel = 0.08
        onLevel?(0)
        defer { outputURL = nil }
        return outputURL
    }

    private func sampleLevel() {
        guard let recorder else { return }
        recorder.updateMeters()
        let power = Double(recorder.averagePower(forChannel: 0))
        let normalized = max(0.055, min(0.92, pow(10, power / 42) * 1.08))
        let response = normalized > smoothedLevel ? 0.58 : 0.2
        smoothedLevel += (normalized - smoothedLevel) * response
        onLevel?(smoothedLevel)
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "시스템 설정에서 Whisp의 마이크 접근을 허용해 주세요."
        case .couldNotStart: return "마이크 녹음을 시작하지 못했습니다."
        }
    }
}
