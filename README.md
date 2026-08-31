# Whisp

말하면 현재 커서 위치에 바로 입력되는, 작고 빠른 오픈소스 macOS 딕테이션 앱입니다.
Raycast Dictation처럼 전역 단축키 하나와 화면 중앙의 파형에 집중했습니다.

<p align="center">
  <img src="Resources/Screenshots/whisp-settings.png" alt="Whisp settings in English" width="820" />
</p>

<p align="center">
  <img src="Resources/Screenshots/whisp-waveform.png" alt="Whisp glass waveform while recording" width="282" />
</p>

## 지금 들어 있는 기능

- 직접 지정한 전역 키 조합 또는 두 번 누르는 보조키로 녹음 시작/완료
- 작업을 가리지 않는 중앙 플로팅 파형 · macOS 26 네이티브 Liquid Glass
- Vercel, OpenAI, xAI Grok, Groq, 사용자 지정 OpenAI 호환 STT
- `whisper.cpp` 기반 완전 로컬 STT
- Tiny / Base / Small 로컬 모델 다운로드·선택·삭제
- 제품명과 고유명사를 위한 사용자 사전
- 문장부호와 말투를 정하는 전사 프롬프트
- 시스템 설정 / 한국어 / English 앱 내부 언어 전환
- 녹음 시작 시 선택된 입력 칸에 직접 입력하고, 찾지 못한 경우에만 클립보드로 복사
- API 키는 macOS Keychain에만 저장
- 메뉴바 상주, 라이트/다크 모드 지원

## 요구 사항

- macOS 14 Sonoma 이상
- Apple Silicon Mac 권장
- 소스 빌드: Swift 5.10 이상 또는 Xcode 16 이상
- 로컬 모드: [`whisper.cpp`](https://github.com/ggerganov/whisper.cpp)

## 실행

앱 번들을 만듭니다.

```bash
./Scripts/build-app.sh
open dist/Whisp.app
```

스크립트는 Swift 릴리스 빌드 후 `dist/Whisp.app`을 만들고 로컬 실행용 ad-hoc 서명을 적용합니다. 개발 중에는 `swift build`로 빠르게 컴파일할 수 있습니다.

처음 실행하면 사용 방식에 따라 다음 권한을 허용합니다.

1. **마이크** — 음성 녹음
2. **손쉬운 사용** — 선택한 입력 칸에 결과 입력 및 보조키 두 번 전역 감지

손쉬운 사용을 허용하지 않아도 전사 결과는 클립보드에 복사됩니다.

## 원격 API 모드

Whisp → 모델 → 원격 STT에서 provider를 선택하고 해당 API 키를 입력합니다.

| Provider | 기본 모델/방식 | Endpoint |
| --- | --- | --- |
| Vercel | `openai/gpt-4o-mini-transcribe` | AI Gateway transcription model |
| OpenAI | `gpt-4o-mini-transcribe` | `/v1/audio/transcriptions` |
| xAI Grok | Grok Speech to Text | `/v1/stt` |
| Groq | `whisper-large-v3-turbo` | `/openai/v1/audio/transcriptions` |
| 사용자 지정 | 직접 입력 | OpenAI 호환 `/audio/transcriptions` |

Vercel의 팀 단위 BYOK를 설정했다면 같은 Gateway 키로 해당 provider credential을 사용할 수 있습니다. OpenAI, Groq와 사용자 지정 provider는 같은 multipart transcription 규격을 공유하고, xAI만 전용 STT 규격으로 처리합니다. 별도 서버나 JavaScript 런타임은 필요하지 않습니다.

원격 모드에서는 요청 오디오가 선택한 provider로 전송됩니다.

## 단축키와 Raycast

기본 단축키는 `⌥ Space`이며 설정의 단축키 버튼을 누른 뒤 원하는 동작을 그대로 입력해 바꿀 수 있습니다.

- **키 조합 직접 지정** — `⌘ Space` 같은 조합 또는 `Control, Control`처럼 보조키를 두 번 눌러 저장
- **지정 안 함** — Whisp가 전역 키를 점유하지 않음

Raycast에서 단축키를 관리하려면 Whisp 단축키를 **지정 안 함**으로 바꾸고 Script Command 또는 Shell Command에 아래 명령을 연결합니다.

```bash
open 'whisp://toggle'
```

## 로컬 모드

먼저 CLI를 설치합니다.

```bash
brew install whisper-cpp
```

Whisp → 모델에서 원하는 모델을 다운로드하고, 일반 → 전사 위치에서 **내 Mac**을 고릅니다.

| 모델 | 크기 | 용도 |
| --- | ---: | --- |
| Tiny | 75 MB | 가장 빠른 짧은 메모 |
| Base | 142 MB | 일상 사용 권장 |
| Small | 466 MB | 한국어 정확도 우선 |

모델은 `~/Library/Application Support/Whisp/Models`에 저장됩니다. 녹음과 전사는 네트워크 요청 없이 기기 안에서 처리됩니다.

## 작동 방식

```text
단축키 → WAV 녹음 → 선택한 API 또는 whisper.cpp
                         ↓
             사전 표기 보정 → 선택한 입력 칸에 직접 입력
                                      ↓ 실패 시
                              클립보드 복사·붙여넣기
```

녹음은 16 kHz mono WAV 임시 파일로 만들며 전사 직후 삭제합니다. 앱 설정에는 오디오나 전사 기록을 보관하지 않습니다.

## 프로젝트 구조

```text
Sources/Whisp/
├── Core/       상태, 설정, Keychain, 텍스트 보정
├── Services/   녹음, Gateway, whisper.cpp, 단축키, 붙여넣기
└── UI/         중앙 파형 패널과 설정 화면
```

SwiftUI, AppKit, AVFoundation, Carbon만 사용합니다. 외부 Swift 패키지 의존성이 없습니다.

## 테스트

```bash
swift build
./Scripts/test-core.sh
```

마이크, 전역 단축키, 자동 붙여넣기는 macOS 권한이 필요한 기능이므로 실제 앱 번들에서도 확인해야 합니다. API 전사 테스트는 사용자의 키와 비용을 사용하므로 자동으로 실행하지 않습니다.

## 기여

작은 기능과 명확한 UI를 유지하는 PR을 환영합니다. 버그 리포트에는 macOS 버전, Mac 칩, 사용한 전사 모드와 모델을 함께 적어 주세요.

MIT License
