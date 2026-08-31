# Whisp

[English](README.md) | [한국어](README.ko.md)

Whisp는 작고 오픈 소스인 macOS 받아쓰기 앱입니다. Control 키를 두 번 눌러 녹음을 시작하고, 말한 뒤 다시 두 번 누르면 사용하던 입력란에 변환된 문장이 입력됩니다.

하나의 전역 단축키, 작고 실시간으로 움직이는 파형, 원격 또는 완전한 로컬 음성 인식에 집중했으며 오디오와 받아쓰기 기록을 저장하지 않습니다.

<p align="center">
  <img src="Resources/Screenshots/whisp-settings.png" alt="Whisp 설정 화면" width="820" />
</p>

## 주요 기능

- 기본 단축키: Control 키 두 번으로 받아쓰기 시작 및 종료
- 일반 키 조합과 보조 키 두 번 누르기 단축키 사용자 지정
- macOS 26의 네이티브 Liquid Glass를 사용하는 작은 플로팅 파형
- Vercel AI Gateway, OpenAI, xAI Grok, Groq, OpenAI 호환 STT 지원
- `whisper.cpp`를 이용한 완전한 로컬 음성 인식
- Tiny, Base, Small 로컬 모델 다운로드 및 관리
- 사용자 사전과 음성 인식 프롬프트
- 한국어 및 영어 인터페이스
- 이전에 사용하던 입력란에 바로 입력하고, 실패하면 클립보드로 복사
- API 키를 macOS 키체인에만 저장
- 메뉴 막대에서 Sparkle 서명 업데이트 확인
- 오디오와 받아쓰기 내역을 저장하지 않음

## 다운로드

[최신 Whisp DMG 다운로드](https://github.com/kmelon55/whisp/releases/latest/download/Whisp.dmg)

1. `Whisp.dmg`를 엽니다.
2. **Whisp**를 **Applications** 폴더로 드래그합니다.
3. Whisp를 실행하고 사용하는 기능에 필요한 권한을 허용합니다.

현재 공개 버전인 `v0.3.1`은 임시 서명되어 있으며 Apple Developer ID 공증을 받지 않았습니다. 따라서 macOS가 첫 실행을 차단할 수 있습니다. 이후 태그 릴리스는 Developer ID 서명과 Apple 공증을 통과해야만 게시되도록 구성되어 있습니다.

설치 후에는 Whisp가 새 버전을 자동으로 확인할 수 있습니다. 메뉴 막대의 **업데이트 확인…**을 직접 선택해도 됩니다.

## 요구 사항

- macOS 14 Sonoma 이상
- Apple Silicon Mac
- 마이크 권한
- 입력란에 직접 입력하고 전역 보조 키 단축키를 사용하기 위한 손쉬운 사용 권한
- 로컬 음성 인식을 사용할 때만 `whisper.cpp` 필요

## 빠른 시작

1. Whisp를 엽니다.
2. 원격 STT 제공자를 선택하거나 로컬 모델을 다운로드합니다.
3. **Control** 키를 두 번 눌러 녹음을 시작합니다.
4. 말합니다.
5. **Control** 키를 다시 두 번 눌러 음성을 텍스트로 변환하고 입력합니다.

단축키는 **Whisp → 일반**에서 변경하거나 끌 수 있습니다.

## 원격 음성 인식

**Whisp → 모델 → 원격 STT**에서 제공자를 선택하고 API 키를 저장합니다.

| 제공자 | 기본 모델 또는 API | 엔드포인트 방식 |
| --- | --- | --- |
| Vercel | `openai/gpt-4o-mini-transcribe` | Vercel AI Gateway transcription |
| OpenAI | `gpt-4o-mini-transcribe` | `/v1/audio/transcriptions` |
| xAI Grok | `grok-transcribe` | `/v1/stt` |
| Groq | `whisper-large-v3-turbo` | OpenAI 호환 transcription |
| 사용자 지정 | `whisper-1` | OpenAI 호환 사용자 지정 엔드포인트 |

오디오는 현재 음성 인식에 선택한 제공자에게만 전송됩니다. 제공자 인증 정보는 macOS 키체인에 보관됩니다.

## 로컬 음성 인식

먼저 `whisper.cpp`를 설치합니다.

```bash
brew install whisper-cpp
```

그런 다음 **Whisp → 모델**에서 모델을 다운로드하고 음성 인식 위치로 **이 Mac에서**를 선택합니다.

| 모델 | 대략적인 크기 | 용도 |
| --- | ---: | --- |
| Tiny | 75 MB | 빠르고 짧은 메모 |
| Base | 142 MB | 일상 사용에 권장되는 균형 |
| Small | 466 MB | 더 나은 한국어 정확도 |

로컬 모델은 `~/Library/Application Support/Whisp/Models`에 저장됩니다. 로컬 모드의 녹음은 Mac 밖으로 전송되지 않습니다.

## Raycast 및 URL 스킴

Whisp는 다음 URL을 지원합니다.

```bash
open 'whisp://toggle'
```

Raycast가 단축키를 사용하게 하려면 Whisp 단축키를 **없음**으로 바꾸고 이 URL을 Raycast Script Command 또는 Shell Command에 연결합니다.

## 개인정보 보호

- 임시 녹음은 음성 인식이 끝난 뒤 삭제됩니다.
- Whisp는 받아쓰기 내역을 보관하지 않습니다.
- 원격 모드 오디오는 선택한 STT 제공자에게만 전송됩니다.
- 로컬 모드는 음성 인식 네트워크 요청 없이 `whisper.cpp`로 실행됩니다.
- API 키는 macOS 키체인에 저장됩니다.

## 소스에서 빌드

Swift 5.10 이상과 macOS SDK를 포함한 Xcode 도구 모음이 필요합니다.

```bash
git clone https://github.com/kmelon55/whisp.git
cd whisp
./Scripts/build-app.sh
open dist/Whisp.app
```

배포용 DMG를 만들려면 다음을 실행합니다.

```bash
./Scripts/package-release.sh
```

로컬 앱 번들은 임시 서명됩니다. GitHub 태그 릴리스는 Developer ID 서명, Apple 공증, 스테이플을 필수로 수행하고 `appcast.xml`에 Sparkle EdDSA 서명도 포함합니다. 자세한 내용은 [릴리스 가이드](docs/RELEASING.md)를 참고하세요.

## 테스트

```bash
swift build
./Scripts/test-core.sh
```

마이크 녹음, 전역 단축키, 직접 입력, 제공자 음성 인식은 앱 번들에서 직접 확인해야 합니다. 원격 제공자 테스트는 API 비용이 발생할 수 있어 자동으로 실행하지 않습니다.

## 라이선스

Whisp는 [MIT 라이선스](LICENSE)로 제공됩니다.
