# Vignette

<p align="right"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a></p>

멀티 모니터 환경을 위한 가벼운 macOS 메뉴바 앱입니다. 디스플레이별 밝기를
조절할 수 있고, 버튼 하나로 켜는 "영화 감상 모드"는 지금 영상이 재생 중인
화면만 남기고 나머지 모든 화면을 어둡게 만들어 시선이 분산되지 않게 해줍니다.

한국어, 영어, 일본어를 지원합니다.

## 주요 기능

- **디스플레이별 밝기 조절** — 연결된 모든 화면마다 메뉴바에서 바로 조작할
  수 있는 밝기 슬라이더를 제공합니다.
- **영화 감상 모드** — 재생 중인 화면을 고르면 나머지 연결된 화면 전부에
  부드러운 그라데이션 오버레이가 덮입니다. 끄면 즉시 원래대로 돌아옵니다.
- **가능한 경우 실제 백라이트 제어** — 내장 패널이나 DDC/CI를 지원하는 외장
  모니터처럼 실제로 제어 가능한 화면에서는 화면 위에 오버레이만 덧씌우는 게
  아니라 진짜 백라이트 밝기를 낮춥니다. 지원하지 않는 환경에서는 자동으로
  오버레이로 대체되므로, 밝기 슬라이더는 어떤 모니터에서든 항상 눈에 보이는
  효과를 냅니다.

## 요구 사항

- macOS 13 Ventura 이상
- Apple Silicon 또는 Intel Mac

## 설치

Vignette는 디스플레이 백라이트를 제어하기 위해 비공개·비문서화된 macOS
프레임워크를 사용합니다 ([왜 비공개 API를 쓰나요](#왜-비공개-api를-쓰나요)
참고). 그래서 Mac App Store로는 배포할 수 없고, 아래 빌드들은 Apple
Developer ID로 서명되어 있지 않습니다. 처음 실행하면 Gatekeeper가 제지할 수
있는데, 이 섹션 끝의 안내를 참고하세요.

### Homebrew

```sh
brew tap mrKangHo/vignette https://github.com/mrKangHo/vignette
brew install --cask vignette
```

(이 저장소 이름이 `homebrew-vignette`가 아니기 때문에 tap URL을 명시적으로
줘야 합니다.) 이후 업데이트: `brew update && brew upgrade --cask vignette`.

### 직접 다운로드

[Releases 페이지](https://github.com/mrKangHo/vignette/releases)에서 최신
`Vignette-*.dmg`를 받아 열고, Vignette.app을 Applications 폴더로 드래그하세요.

### Gatekeeper

이 빌드들은 Developer ID가 아니라 ad-hoc 서명만 되어 있어서, macOS가
Vignette.app이 "손상되어 열 수 없음"이라고 말할 수 있습니다. 실제로 손상된
게 아니니, 그 메시지를 믿는 대신 격리(quarantine) 플래그를 지우세요:

```sh
xattr -cr /Applications/Vignette.app
```

또는 Finder에서 Vignette.app을 우클릭(Control-클릭)한 뒤 "열기"를 선택해
"확인되지 않은 개발자" 경고를 수락해도 됩니다.

### 소스에서 빌드하기

```sh
git clone https://github.com/mrKangHo/vignette.git
cd vignette
tuist generate
```

생성된 Xcode 프로젝트가 열리면 `Vignette` 스킴을 빌드/실행하세요.
[Tuist](https://tuist.dev)가 필요합니다 (`brew install tuist`).

커맨드라인에서 바로 빌드하려면:

```sh
tuist generate --no-open
xcodebuild -workspace Vignette.xcworkspace -scheme Vignette -configuration Debug -destination 'platform=macOS' build
```

## 사용법

Vignette는 메뉴바에 상주합니다 (Dock 아이콘은 없고, 겹쳐진 두 디스플레이
모양 아이콘을 찾으면 됩니다). 아이콘을 클릭하면:

- 연결된 각 디스플레이의 밝기를 조절할 수 있습니다.
- 영화 감상 모드를 켜고, 지금 재생 중인 화면을 고를 수 있습니다.

팝오버의 톱니바퀴 아이콘을 누르면 열리는 "설정" 창에서 영화 감상 모드의
어둡게 하는 강도를 조절할 수 있습니다.

## 왜 비공개 API를 쓰나요

디스플레이 백라이트를 제어하는 공식 macOS API는 없습니다 — 내장 패널이든
DDC/CI를 쓰는 외장 모니터든 마찬가지입니다. Vignette는 macOS Control
Center나 MonitorControl, Lunar 같은 도구들이 쓰는 것과 동일한 비공개
메커니즘을 `dlopen`/`dlsym`으로 런타임에 동적으로 찾아 사용합니다. 이렇게 해
두면 나중에 Apple이 이 메커니즘을 제거하더라도 Vignette가 충돌하는 대신
"소프트웨어 오버레이만 동작"하는 상태로 자연스럽게 저하됩니다.

이 때문에:

- Developer ID 서명/공증을 통한 배포만 가능하고, Mac App Store에는 올릴 수
  없습니다. (이 프로젝트에는 아직 Developer ID 계정이 없어서, 현재 릴리스는
  ad-hoc 서명만 되어 있습니다 — [설치](#설치) 참고.)
- 외장 모니터 밝기 제어(DDC/CI)는 best-effort입니다 — 모니터, 케이블, 중간에
  거치는 USB-C/Thunderbolt 허브에 따라 특정 환경에서는 아예 동작하지 않을 수
  있습니다. 이 경우에도 소프트웨어 오버레이는 항상 보장되는 대안입니다.

## 라이선스

[MIT](LICENSE)
