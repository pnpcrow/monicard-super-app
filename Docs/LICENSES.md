# 라이선스와 참고 자료

이 저장소의 앱 코드는 비공개 동반 앱입니다. 배포·판매 조건은 저장소 소유자에게 있습니다.

아래는 **앱에 실제로 포함되는 라이브러리**와 **구현할 때 참고만 한 SDK·문서**를 구분한 기록입니다.  
라이선스 문구는 2026-08-30 기준 `pubspec.lock`과 각 패키지 `LICENSE` 파일에서 확인했습니다.

식별자

| 구분 | 값 |
|---|---|
| Android applicationId / namespace | `dev.monicard.super_app` |
| Dart 패키지 이름 | `monicard_super_app` |
| 표시 이름 | MoniCard Super App |

Dart 이름은 pub 규칙상 밑줄만 허용하므로 Android ID와 표기가 다릅니다. 스토어·설치 패키지는 `dev.monicard.super_app` 입니다.

## 직접 의존성 (앱에 포함)

라이선스 전문은 각 패키지의 `LICENSE` 파일에 있습니다.

| 구성 | lock 버전 | 라이선스 | 저작권 표시 |
|---|---|---|---|
| Flutter SDK, `flutter_localizations` | SDK | BSD-3-Clause | Flutter Authors / Google |
| Dart SDK | SDK | BSD-3-Clause | Dart project authors |
| `collection` | 1.19.1 | BSD-3-Clause | Dart project authors |
| `web` | 1.1.1 | BSD-3-Clause | Dart project authors |
| `shared_preferences` | 2.5.5 | BSD-3-Clause | Flutter Authors |
| `flutter_lints` (개발) | 6.0.0 | BSD-3-Clause | Flutter Authors |
| `flutter_blue_plus` | 1.36.8 | BSD-3-Clause | Paul DeMarco, Bosko Popovic, Charles Weinberger, Thomas Clark / Buffalo PC Inc. |
| `cupertino_icons` | 1.0.9 | MIT | Vladimir Kharlampidi |
| `file_picker` | 10.3.10 | MIT | Miguel Ruivo |
| `image` | 4.9.2 | MIT | Brendan Duncan |
| `permission_handler` | 12.0.3 | MIT | Baseflow |
| `provider` | 6.1.5+1 | MIT | Remi Rousselet |

BSD-3-Clause와 MIT는 상업적 이용·수정·재배포가 가능합니다. 저작권 고지를 유지해야 하고, 상표를 보증처럼 쓰면 안 됩니다. 보증은 제공되지 않습니다.

웹 빌드는 CanvasKit / Skia 등 Flutter 엔진 구성도 함께 가져갑니다. 엔진도 Flutter BSD-3-Clause 계열입니다.

Android 빌드는 Android SDK와 Kotlin 표준 라이브러리를 링크합니다. 사용은 Google / JetBrains SDK 약관을 따릅니다. 이 저장소는 Android SDK를 재배포하지 않습니다.

## 주요 전이 의존성

직접 import하지 않지만 빌드에 딸려 옵니다. 플랫폼에 따라 빠지기도 합니다.

| 구성 | 라이선스 | 비고 |
|---|---|---|
| `archive` | MIT | `image`가 가져옴 |
| `cross_file`, `path_provider`, `ffi` | BSD-3-Clause | Flutter / Dart |
| `win32` | BSD-3-Clause | Windows 전용 |
| `bluez` | **MPL-2.0** | Linux 데스크톱에서 `flutter_blue_plus`가 사용. Android/웹 빌드에는 들어가지 않음. MPL은 수정한 해당 파일을 공개해야 할 수 있음 |

Linux 데스크톱 빌드를 배포할 때는 `bluez` MPL-2.0 고지를 따로 확인하세요. 이 앱의 주 대상은 Android와 웹입니다.

## 참고만 한 SDK·문서 (소스를 복사하지 않음)

동작과 프로토콜을 맞추기 위해 아래를 **관찰·문서화**했습니다. 원본 번들을 이 저장소에 넣지 않았습니다. 구현은 `CLEAN_ROOM_IMPLEMENTATION.md` 경계를 따릅니다.

| 자료 | 어디에 쓰였나 | 라이선스 상태 | 이 저장소의 취급 |
|---|---|---|---|
| [MoniCard 공개 웹 컴패니언](https://monicard-fullstack.azsoft-jp.workers.dev/) 및 [`/docs/`](https://monicard-fullstack.azsoft-jp.workers.dev/docs/) | GATT UUID, 프레임 레이아웃, 명령 ID, 이름 prefix `MoniCard`, 240×320 화면 | 사이트에 SPDX / 오픈소스 라이선스 고지가 없음. 저작물은 해당 운영자(azsoft 등)에 있음 | 소스·UI 문구·번들을 복사하지 않음. 상호운용에 필요한 바이트 레이아웃만 재기술 |
| Web Bluetooth API (W3C) | Chrome/Edge의 `requestDevice`, `getDevices`, GATT | 사양은 [W3C Software and Document License](https://www.w3.org/copyright/software-license-2023/). 브라우저 구현은 각 벤더 | API를 호출만 함. 스펙 원문을 재배포하지 않음 |
| Android Bluetooth / BLE 권한 모델 | 스캔·연결 | Android SDK 약관 | 권한 선언과 `flutter_blue_plus` 호출만 사용 |
| 공식/커뮤니티 태그 ID (`assets/tags/tags_master.json`) | 관심 태그 슬롯 | 하드웨어 상호운용용 ID. 원 카탈로그 저작권은 해당 커뮤니티·벤더 | ID와 표시 이름은 카드와 맞춰야 해서 유지. 원 사이트 스크립트는 없음 |

원본 웹 앱을 “SDK를 그대로 가져온 것”으로 표기하지 마세요. 이 앱은 문서와 관측된 프레임을 기준으로 다시 작성한 동반 앱입니다. 공식 제조사 SDK나 공식 앱이 아닙니다.

## 상표와 제품 외형

MoniCard, 魔力卡, MAGIC CARD, 소마(小魔) 및 하드웨어 외형은 해당 권리자의 상표·디자인일 수 있습니다.  
앱 안의 제품 사진·캐릭터는 동반 앱 자산으로 다시 그린 뒤 배경을 제거한 것입니다.

## 개발 도구 (런타임에 포함되지 않음)

| 도구 | 라이선스 | 용도 |
|---|---|---|
| `rembg` | MIT (패키지). 기본 U-2-Net 가중치는 별도 연구 라이선스일 수 있음 | 제품 PNG 배경 제거. 앱에 들어가지 않음 |
| eli5-manual 스킬 | MIT | 처음 사용자 PDF 매뉴얼 생성 |

## 고지 유지 방법

1. `pubspec.yaml`에 올린 패키지를 바꾸면 이 표의 버전과 라이선스를 같이 고칩니다.
2. 전문이 필요하면 `flutter pub get` 뒤 pub-cache의 각 `LICENSE`를 확인합니다.
3. 원본 사이트 소스를 트리에 넣지 않습니다.
4. Linux 데스크톱을 배포 대상에 넣을 때만 `bluez` MPL-2.0을 다시 검토합니다.
