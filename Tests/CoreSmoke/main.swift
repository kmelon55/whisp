import Darwin
import Carbon.HIToolbox
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(
    TextPostProcessor.clean("  안녕   하세요  ", vocabulary: []) == "안녕 하세요",
    "공백 정리"
)

expect(
    TextPostProcessor.clean("swiftui와 vercel을 사용합니다.", vocabulary: ["SwiftUI", "Vercel"])
        == "SwiftUI와 Vercel을 사용합니다.",
    "사용자 사전 표기 보정"
)

expect(AppLanguage.korean.text("일반", "General") == "일반", "한국어 UI 선택")
expect(AppLanguage.english.text("일반", "General") == "General", "영어 UI 선택")
expect(RemoteProvider.custom.title(.english) == "Custom", "provider 이름 현지화")
let catalogModelWithoutTags = try! JSONDecoder().decode(
    VercelTranscriptionModel.self,
    from: Data(#"{"id":"test/stt","name":"STT","description":"Test","type":"transcription","owned_by":"test","supported_specifications":["v4"],"pricing":{}}"#.utf8)
)
expect(catalogModelWithoutTags.tags.isEmpty, "catalog model decodes without tags")
expect(VercelModelCatalog.fallbackModels.count == 9, "Vercel STT fallback catalog")
expect(
    VercelModelCatalog.fallbackModels.first { $0.id == "openai/gpt-4o-mini-transcribe" }?
        .priceText(.english) == "Audio $1.25/M · output $5/M",
    "token price formatting"
)
expect(
    VercelModelCatalog.fallbackModels.first { $0.id == "spacexai/grok-stt" }?
        .priceText(.korean) == "$0.10/시간",
    "duration price formatting"
)
expect(
    VercelModelCatalog.fallbackModels.first { $0.id == "fish-audio/transcribe-1-free" }?
        .priceText(.korean) == "무료",
    "free price formatting"
)
expect(
    VercelModelCatalog.fallbackModels.first { $0.id == "openai/gpt-realtime-whisper" }?
        .isBatchCompatible == false,
    "realtime-only model is not selectable"
)
expect(
    AppLanguage.english.localizeError("마이크 녹음을 시작하지 못했습니다.")
        == "Could not start microphone recording.",
    "런타임 오류 현지화"
)
expect(
    ShortcutLabelFormatter.label(keyCode: 37, modifiers: UInt32(controlKey)) == "⌃L",
    "입력기와 무관한 물리 키 영문 라벨"
)
let legacyRecordingShortcut = try! JSONDecoder().decode(
    RecordingShortcutSetting.self,
    from: Data(#"{"mode":"custom","keyCode":37,"modifiers":4096,"label":"⌃ㄹ"}"#.utf8)
)
expect(legacyRecordingShortcut.kind == .keyCombination, "이전 녹음 단축키 형식 호환")

MainActor.assumeIsolated {
    let shortcutDefaultsName = "Whisp.CoreSmoke.ShortcutDefaults"
    let shortcutDefaults = UserDefaults(suiteName: shortcutDefaultsName)!
    shortcutDefaults.removePersistentDomain(forName: shortcutDefaultsName)
    shortcutDefaults.set(true, forKey: "didMigrateLegacyVercelKey")
    let defaultSettings = AppSettings(defaults: shortcutDefaults)
    let shortcutIsEnabled = defaultSettings.shortcutMode == .custom
    let shortcutIsDoubleControl = defaultSettings.customShortcutKind.rawValue
        == CustomShortcutKind.doubleControl.rawValue
    let shortcutLabelIsControl = defaultSettings.customShortcutLabel == "⌃  ⌃"
    expect(shortcutIsEnabled, "기본 단축키 활성화")
    expect(shortcutIsDoubleControl, "Control 두 번 기본값")
    expect(shortcutLabelIsControl, "Control 두 번 기본 라벨")
    expect(defaultSettings.recordingCancelShortcut == .cancelDefault, "녹음 중 취소는 Esc 기본값")
    expect(defaultSettings.recordingPasteShortcut == .pasteDefault, "붙여넣기는 녹음 시작 단축키 기본값")
    expect(
        defaultSettings.recordingPasteAndEnterShortcut == .pasteAndEnterDefault,
        "붙여넣고 Enter는 Return 기본값"
    )
    expect(defaultSettings.showRecordingShortcutHints, "녹음 중 단축키 표시 기본값")
    expect(defaultSettings.showTranscriptionStatus, "전사 중 상태 문구 표시 기본값")
    defaultSettings.setRecordingShortcut(
        kind: .singleControl,
        keyCode: 0,
        modifiers: 0,
        label: "⌃",
        for: .cancel
    )
    let reloadedSettings = AppSettings(defaults: shortcutDefaults)
    expect(reloadedSettings.recordingCancelShortcut.kind == .singleControl, "단독 Control 설정 저장")
    expect(reloadedSettings.recordingCancelShortcut.label == "⌃", "단독 Control 라벨 저장")
    reloadedSettings.setRecordingShortcut(
        kind: .singleControl,
        keyCode: 0,
        modifiers: 0,
        label: "⌃",
        for: .pasteAndEnter
    )
    expect(reloadedSettings.hasRecordingShortcutConflict(for: .cancel), "단독 보조 키 중복 감지")
    expect(reloadedSettings.hasRecordingShortcutConflict(for: .pasteAndEnter), "반대쪽 중복도 감지")
    shortcutDefaults.removePersistentDomain(forName: shortcutDefaultsName)
}

var form = MultipartFormData()
form.addField(name: "model", value: "gpt-4o-mini-transcribe")
form.addFile(name: "file", filename: "recording.wav", mimeType: "audio/wav", data: Data([0x01, 0x02]))
let multipart = String(decoding: form.finalizedData, as: UTF8.self)
expect(multipart.contains("name=\"model\""), "multipart model field")
expect(multipart.contains("filename=\"recording.wav\""), "multipart audio file")
expect(
    multipart.range(of: "name=\"model\"")!.lowerBound < multipart.range(of: "name=\"file\"")!.lowerBound,
    "multipart file field order"
)
expect(multipart.hasSuffix("--\(form.boundary)--\r\n"), "multipart closing boundary")

var modifierDetector = ModifierDoubleTapDetector()
expect(!modifierDetector.handle(modifierDown: true, hasOtherModifiers: false, isKeyDown: false, timestamp: 1.0), "first modifier down")
expect(!modifierDetector.handle(modifierDown: false, hasOtherModifiers: false, isKeyDown: false, timestamp: 1.08), "first modifier up")
expect(modifierDetector.handle(modifierDown: true, hasOtherModifiers: false, isKeyDown: false, timestamp: 1.24), "second modifier down")

modifierDetector.reset()
expect(!modifierDetector.handle(modifierDown: true, hasOtherModifiers: false, isKeyDown: false, timestamp: 2.0), "interrupted first down")
expect(!modifierDetector.handle(modifierDown: false, hasOtherModifiers: false, isKeyDown: false, timestamp: 2.08), "interrupted first up")
expect(!modifierDetector.handle(modifierDown: false, hasOtherModifiers: false, isKeyDown: true, timestamp: 2.15), "ordinary key resets gesture")
expect(!modifierDetector.handle(modifierDown: true, hasOtherModifiers: false, isKeyDown: false, timestamp: 2.22), "interrupted gesture rejected")

print("Core smoke tests passed")
