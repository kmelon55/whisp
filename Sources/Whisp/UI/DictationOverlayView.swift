import AppKit
import SwiftUI

struct DictationOverlayView: View {
    @EnvironmentObject private var appState: AppState
    let message: String?
    let usesNativeGlass: Bool

    var body: some View {
        Group {
            if usesNativeGlass {
                overlayContent
                    .background { GlassOpticsLayer() }
                    .overlay { GlassEdgeLayer() }
            } else {
                overlayContent
                    .background(.ultraThinMaterial, in: Capsule())
                    .background { GlassOpticsLayer() }
                    .overlay { GlassEdgeLayer() }
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            }
        }
        .padding(usesNativeGlass ? 0 : 12)
    }

    @ViewBuilder
    private var overlayContent: some View {
        if let message {
            HStack(spacing: 10) {
                Image(systemName: appState.phase.isFailure ? "mic.slash.fill" : "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appState.phase.isFailure ? Color.orange : Color.accentColor)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(width: 330, height: 58)
        } else {
            switch displayedPhase {
            case .recording:
                if appState.settings.showRecordingShortcutHints {
                    HStack(spacing: 12) {
                        WaveformView(amplitude: appState.amplitude, phase: displayedPhase)
                            .frame(width: 96, height: 25)
                        Divider().frame(height: 20).opacity(0.45)
                        ForEach(recordingHints) { hint in
                            RecordingKeyHint(key: hint.key, label: hint.label)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(width: recordingContentWidth, height: 50)
                } else {
                    WaveformView(amplitude: appState.amplitude, phase: displayedPhase)
                        .frame(width: 116, height: 25)
                        .padding(.horizontal, 24)
                        .frame(width: 164, height: 50)
                }
            case .transcribing:
                if appState.settings.showTranscriptionStatus {
                    HStack(spacing: 12) {
                        WaveformView(amplitude: 0, phase: displayedPhase)
                            .frame(width: 72, height: 23)
                        Text(displayedPhase.title(appLanguage) + "…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: 220, height: 50)
                } else {
                    WaveformView(amplitude: 0, phase: displayedPhase)
                        .frame(width: 116, height: 25)
                        .padding(.horizontal, 24)
                        .frame(width: 164, height: 50)
                }
            default:
                WaveformView(amplitude: appState.amplitude, phase: displayedPhase)
                    .frame(width: 116, height: 25)
                    .padding(.horizontal, 24)
                    .frame(width: 164, height: 50)
            }
        }
    }

    @Environment(\.appLanguage) private var appLanguage

    private var displayedPhase: DictationPhase {
        appState.overlayPreviewPhase ?? appState.phase
    }

    private var recordingHints: [RecordingOverlayHint] {
        RecordingShortcutAction.allCases.compactMap { action in
            guard !appState.settings.hasRecordingShortcutConflict(for: action),
                  let key = appState.settings.effectiveRecordingShortcutLabel(for: action)
            else {
                return nil
            }
            let label: String
            switch action {
            case .cancel: label = appLanguage.text("취소", "Cancel")
            case .paste: label = appLanguage.text("붙여넣기", "Paste")
            case .pasteAndEnter: label = appLanguage.text("전송", "Send")
            }
            return RecordingOverlayHint(action: action, key: key, label: label)
        }
    }

    private var recordingContentWidth: CGFloat {
        min(440, 150 + CGFloat(recordingHints.count) * 90)
    }
}

private struct RecordingOverlayHint: Identifiable {
    let action: RecordingShortcutAction
    let key: String
    let label: String

    var id: RecordingShortcutAction { action }
}

private struct RecordingKeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: key.count > 1 ? 9 : 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, key.count > 1 ? 5 : 6)
                .frame(height: 20)
                .background(.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.primary.opacity(0.12), lineWidth: 0.5)
                }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// 네이티브 글래스의 굴절은 그대로 남기고, 조명이 비치는 면만 아주 얇게 보강합니다.
/// 단색 반투명 배경을 올리지 않아 뒤 콘텐츠가 회색 덩어리로 뭉개지지 않습니다.
private struct GlassOpticsLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            GeometryReader { geometry in
                let lighting = GlassLighting.current

                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.045), location: 0),
                                .init(color: .white.opacity(0.008), location: 0.34),
                                .init(color: .clear, location: 0.62),
                                .init(color: .black.opacity(0.012), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        Capsule()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.105), .white.opacity(0.025), .clear],
                                center: lighting.point,
                                startRadius: 0,
                                endRadius: max(geometry.size.width, geometry.size.height) * 0.56
                            )
                        )
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 포인터를 가상의 광원으로 사용해 반사광이 표면을 따라 실시간으로 이동합니다.
/// 색 분산은 고정 테두리가 아니라 가장 밝은 반사점 주변에만 짧게 나타납니다.
private struct GlassEdgeLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            let lighting = GlassLighting.current

            ZStack {
                Capsule()
                    .strokeBorder(.white.opacity(0.19), lineWidth: 0.55)

                Capsule()
                    .inset(by: 0.45)
                    .strokeBorder(
                        AngularGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.065),
                                .init(color: .cyan.opacity(0.24), location: 0.095),
                                .init(color: .white.opacity(0.88), location: 0.12),
                                .init(color: .pink.opacity(0.18), location: 0.145),
                                .init(color: .clear, location: 0.205),
                                .init(color: .clear, location: 0.57),
                                .init(color: .white.opacity(0.22), location: 0.62),
                                .init(color: .clear, location: 0.69),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            angle: lighting.angle
                        ),
                        lineWidth: 1.05
                    )
                    .blendMode(.screen)

                Capsule()
                    .inset(by: 1.35)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .clear, .black.opacity(0.025)],
                            startPoint: lighting.point,
                            endPoint: lighting.oppositePoint
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct GlassLighting {
    let point: UnitPoint
    let oppositePoint: UnitPoint
    let angle: Angle

    static var current: GlassLighting {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.frame ?? .zero
        let normalizedX = frame.width > 0 ? (mouse.x - frame.minX) / frame.width : 0.5
        let normalizedY = frame.height > 0 ? 1 - (mouse.y - frame.minY) / frame.height : 0.25
        let x = min(0.88, max(0.12, normalizedX))
        let y = min(0.72, max(0.08, normalizedY))
        let radians = atan2(y - 0.5, x - 0.5)

        return GlassLighting(
            point: UnitPoint(x: x, y: y),
            oppositePoint: UnitPoint(x: 1 - x, y: 1 - y),
            angle: .radians(radians)
        )
    }
}

private extension DictationPhase {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

private struct WaveformView: View {
    let amplitude: Double
    let phase: DictationPhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 45)) { context in
            Canvas { canvas, size in
                let bars = 21
                let spacing: CGFloat = 3.25
                let width = (size.width - CGFloat(bars - 1) * spacing) / CGFloat(bars)
                let time = context.date.timeIntervalSinceReferenceDate
                // 실제 마이크 레벨은 낮은 구간에 오래 머무르므로 완만한 곡선으로
                // 중간 음량을 끌어올려 말할 때 높이 변화가 눈에 보이게 합니다.
                let responsiveAmplitude = pow(max(0, amplitude), 0.72)
                let isRecording = phase == .recording
                let isTranscribing = phase == .transcribing
                let loadingPulse = (sin(time * 3.8) + 1) / 2
                let energy = isRecording
                    ? min(0.90, max(0.13, responsiveAmplitude * 1.35))
                    : isTranscribing ? 0.34 + loadingPulse * 0.10 : 0.035
                let speed = isRecording ? 6.2 : isTranscribing ? 5.2 : 2.1

                for index in 0..<bars {
                    let x = CGFloat(index) * (width + spacing)
                    let normalizedPosition = abs((Double(index) / Double(bars - 1)) * 2 - 1)
                    let envelope = 0.62 + (1 - normalizedPosition) * 0.38
                    let primary = (sin(Double(index) * 0.76 + time * speed) + 1) / 2
                    let secondary = (sin(Double(index) * 0.31 - time * speed * 0.58) + 1) / 2
                    let motion = 0.50 + primary * 0.36 + secondary * 0.14
                    let loadingSweep = (sin(Double(index) * 0.56 - time * 5.4) + 1) / 2
                    let barEnergy = isTranscribing ? 0.13 + loadingSweep * 0.62 : energy
                    let activeHeight = size.height * CGFloat(0.10 + barEnergy * 0.86)
                    let height = max(isRecording ? 3.8 : 2.6, activeHeight * CGFloat(envelope * motion))
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: max(2, width), height: height)
                    canvas.fill(
                        Path(roundedRect: rect, cornerRadius: width / 2),
                        with: .color(isTranscribing
                            ? Color.accentColor.opacity(0.76)
                            : Color.primary.opacity(isRecording ? 0.92 : 0.38))
                    )
                }
            }
        }
        .animation(.smooth(duration: 0.16), value: amplitude)
        .animation(.easeOut(duration: 0.22), value: phase)
        .accessibilityLabel(phase.title(appLanguage))
    }

    @Environment(\.appLanguage) private var appLanguage
}
