# MoniCard Super

Android / Web companion for [MoniCard](https://monicard-fullstack.azsoft-jp.workers.dev/) hardware.

Flutter 한 코드베이스로 **Android 네이티브 BLE**와 **Chrome Web Bluetooth**를 같이 다룹니다. 프로토콜 빌더는 전송 계층과 분리되어 있고, FILE / OTA는 명시적 위험 고지 뒤에만 실행됩니다.

## 기능

- MoniCard 검색·연결 (이름 prefix `MoniCard`)
- 240×320 정지 이미지: 가져온 사진을 앱 안에서 확대·이동·크롭 (시스템 크롭 Intent 없음, Web/Android 공통)
- 애니메이션 / 캐러셀 소재 전송
- 프로필 카드 (UTF-8 최대 319바이트)
- 공식 중국 마스터 + 일본 커뮤니티 관심 태그 (최대 5)
- 부저 / 진동 / 매칭 조명 / 주변광 / 브로드캐스트
- 수신 카드, 시리얼·펌웨어·배터리·저장공간
- 실험적 FILE 세션, 고위험 OTA (개발 기기 전용)
- 프로토콜 진단 로그
- en / ja / zh / ko / ru

## 요구 사항

- Flutter 3.47+ / Dart 3.13+
- Android: API 21+, BLE
- Web: Chrome 또는 Edge, HTTPS, Web Bluetooth

## 실행

```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run -d android
flutter build web --release --base-href /
flutter build apk --release
```

웹 미리보기는 `build/web`을 정적 호스트하면 됩니다.

## 프로토콜

GATT 서비스 `7369666c-695f-7364-0000-000000000000`, 데이터 캐릭터리스틱 `…0002…`.
프레임은 `category u8 | flags u8 | payload_length u16 LE | payload`.
CONTROL 카테고리는 `0x1F`. 상세와 신뢰도 표는 [`Docs/PROTOCOL_SPECIFICATION.md`](Docs/PROTOCOL_SPECIFICATION.md).

구현은 배포된 웹 앱을 베낀 것이 아니라, 공개 문서와 관측된 프레임 레이아웃을 기준으로 다시 작성했습니다.

## 안전

OTA는 기기를 영구 정지시킬 수 있습니다. 서명·롤백·중단 복구가 검증되기 전까지 생산 기기에서 쓰지 마세요. FILE 세션도 형식 불일치 시 저장 데이터가 손상될 수 있습니다.

## 라이선스

Private companion for the repository owner. Bundled tag IDs exist for wire interoperability with MoniCard hardware.
