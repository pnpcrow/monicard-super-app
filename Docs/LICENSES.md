# 라이선스와 참고 자료

이 저장소의 앱 코드는 비공개 동반 앱입니다. 배포·판매 조건은 저장소 소유자에게 있습니다.
아래는 **직접 넣은 라이브러리**와 **구현할 때 참고만 한 SDK·문서**의 라이선스를 구분한 기록입니다.

Android 애플리케이션 ID는 `dev.monicard.super_app` 입니다. Dart 패키지 이름은 관례상 `monicard_super_app` 을 유지합니다.

## 직접 의존성 (앱에 포함)

라이선스 전문은 각 패키지의 `LICENSE` 파일에 있습니다. 빌드 산출물에는 해당 고지가 함께 실립니다.

| 구성 | 버전대 | 라이선스 | 권리 표시 |
|---|---|---|---|
| Flutter SDK, `flutter_localizations` | SDK | BSD-3-Clause | Flutter Authors / Google |
| Dart SDK, `collection`, `web` | SDK / pub | BSD-3-Clause | Dart project authors / Google LLC |
| `shared_preferences` | 2.5.x | BSD-3-Clause | Flutter Authors |
| `flutter_lints` | 6.x | BSD-3-Clause | Flutter Authors |
| `flutter_blue_plus` | 1.35+ | BSD-3-Clause | Paul DeMarco, Bosko Popovic, Charles Weinberger, Thomas Clark / Buffalo PC Inc. |
| `cupertino_icons` | 1.0.x | MIT | Vladimir Kharlampidi |
| `file_picker` | 10.3.x | MIT | Miguel Ruivo |
| `image` | 4.5.x | MIT | Brendan Duncan |
| `permission_handler` | 12.x | MIT | Baseflow |
| `provider` | 6.1.x | MIT | Remi Rousselet |

BSD-3-Clause와 MIT 모두 상업적 이용·수정·재배포가 가능합니다. 고지를 유지해야 하고, 상표(Google, Flutter, Buffalo PC 등)를 보증처럼 쓰면 안 됩니다. 보증은 제공되지 않습니다.

웹 빌드는 CanvasKit / Skia 등 Flutter 엔진 구성도 함께 가져갑니다. 엔진 쪽도 Flutter BSD-3-Clause 계열입니다.

Android 빌드는 Android SDK·Kotlin 표준 라이브러리를 링크합니다. 그 사용은 Google / JetBrains의 해당 SDK 약관을 따릅니다. 소스 트리에 Android SDK를 재배포하지는 않습니다.

## 참고만 한 SDK·문서 (소스를 복사하지 않음)

동작과 프로토콜을 맞추기 위해 아래를 **관찰·문서화**했습니다. 원본 번들을 이 저장소에 넣지 않았습니다. 구현은 `Docs/CLEAN_ROOM_IMPLEMENTATION.md` 경계를 따릅니다.

| 자료 | 어디에 쓰였나 | 라이선스 상태 | 이 저장소의 취급 |
|---|---|---|---|
| [MoniCard 공개 웹 컴패니언](https://monicard-fullstack.azsoft-jp.workers.dev/) 및 [`/docs/`](https://monicard-fullstack.azsoft-jp.workers.dev/docs/) | GATT UUID, 프레임 레이아웃, 명령 ID, 이름 prefix `MoniCard`, 240×320 화면 | 사이트에 SPDX가 없음. 저작물은 해당 운영자(azsoft 등)에 있음 | 소스·UI 문구·번들을 복사하지 않음. 상호운용에 필요한 바이트 레이아웃만 재기술 |
| Web Bluetooth API (W3C) | Chrome/Edge에서 `requestDevice` / GATT | 사양은 W3C 문서 라이선스. 구현은 브라우저 벤더 | API를 호출만 함. 스펙 텍스트를 재배포하지 않음 |
| Android Bluetooth / BLE 권한 모델 | 스캔·연결 | Android SDK 약관 | 권한 선언과 `flutter_blue_plus` 호출만 사용 |
| 공식/커뮤니티 태그 ID (`assets/tags/tags_master.json`) | 관심 태그 슬롯 순서 | 하드웨어 상호운용용 ID. 원 카탈로그 저작권은 해당 커뮤니티·벤더 | ID와 표시 이름은 카드와 맞춰야 해서 유지. 원 사이트 스크립트는 없음 |

원본 웹 앱을 “SDK를 그대로 가져온 것”으로 표기하지 마세요. 이 앱은 문서와 관측된 프레임을 기준으로 다시 작성한 동반 앱입니다.

## 상표와 제품 외형

MoniCard, 魔力卡, MAGIC CARD, 소마(小魔) 및 하드웨어 외형은 해당 권리자의 상표·디자인일 수 있습니다.
앱 안의 제품 사진·캐릭터 컷은 **동반 앱 자산**으로 다시 그린 뒤 배경을 제거한 것입니다. 공식 제조사 SDK나 공식 앱이 아닙니다.

## 개발 도구 (앱에 포함되지 않음)

이미지 배경 제거에 `rembg`(보통 MIT / 모델 가중치는 별도)를 로컬에서 쓴 적이 있습니다. 런타임 의존성은 아닙니다.

## 고지 유지 방법

1. `pubspec.yaml`에 올린 패키지를 바꾸면 이 표를 같이 고칩니다.
2. 라이선스 전문이 필요하면 `flutter pub get` 뒤 pub-cache의 각 `LICENSE`를 확인합니다.
3. 원본 사이트 소스를 트리에 넣지 않습니다.
