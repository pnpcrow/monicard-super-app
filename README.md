# MoniCard Super App

MoniCard(매직카드)용 **Android / Web** 동반 앱입니다. Flutter 한 코드로 네이티브 BLE와 Chrome Web Bluetooth를 같이 다룹니다.

이 저장소는 공식 제조사 앱이 아닙니다. 공개 문서와 관측된 BLE 프레임을 기준으로 다시 작성했습니다.

| | |
|---|---|
| 웹 앱 | [pnpcrow.github.io/monicard-super-app](https://pnpcrow.github.io/monicard-super-app/) |
| 패키지 | `dev.monicard.super_app` |
| Dart | `monicard_super_app` |
| 버전 | `1.0.0` |
| 라이선스 | [MIT](LICENSE) |
| 처음 사용 매뉴얼 | [Docs/monicard-super-app-eli5-manual.pdf](Docs/monicard-super-app-eli5-manual.pdf) |
| 하드웨어 참고 | [원본 웹 컴패니언](https://monicard-fullstack.azsoft-jp.workers.dev/) |

## 웹에서 쓰기

배포 주소: **https://pnpcrow.github.io/monicard-super-app/**  
(빌드는 `gh-pages` 브랜치. 저장소 Settings → Pages에서 Branch `gh-pages` / root 를 고르면 이 주소로 열립니다.)

1. **Chrome** 또는 **Edge**로 연다. Safari·Firefox는 Web Bluetooth가 없어 기기를 찾지 못한다.
2. 주소가 `https`인지 확인한다.
3. 카드 전원을 켜고, PC/휴대폰 Bluetooth를 켠다.
4. 위쪽 알약 칩 또는 **기기 검색**을 누른 뒤, 브라우저 기기 창에서 이름이 `MoniCard`로 시작하는 기기를 고른다.
5. 칩에 카드 이름과 초록 점이 보이면 연결된 것이다. 그다음 홈에서 사진·애니메이션을 보낸다.

웹은 저장된 기기로 바로 붙지 않는다. 연결할 때마다 브라우저 선택 창에서 고른다. 미리보기 창(iframe) 안에서는 Bluetooth가 막힐 수 있다.

## 할 수 있는 일

- 이름이 `MoniCard`로 시작하는 기기 검색·연결. Android는 저장된 기기를 **바로 연결**
- 사진 → 앱 안에서 240×320 확대·이동·크롭 후 전송 (시스템 크롭 Intent 없음)
- GIF / MP4 / MOV에서 클립을 고르고 FPS(5·10·15·20)를 정해 애니메이션 전송
- 프로필 카드(UTF-8 최대 319바이트), 관심 태그 최대 5개
- 부저 / 진동 / 매칭 조명 / 주변광 / 브로드캐스트
- 받은 카드, 시리얼·펌웨어·배터리·저장공간
- 실험적 FILE 세션, 고위험 OTA (개발 기기 전용)
- 한국어 / 영어 / 일본어 / 중국어 / 러시아어

## 요구 사항

- Flutter 3.47+ / Dart 3.13+
- Android API 21+, Bluetooth
- 웹: Chrome 또는 Edge, **HTTPS**, Web Bluetooth

## 실행

```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run -d android
flutter build web --release --base-href /monicard-super-app/
flutter build apk --release
```

Android Studio에서 `android/`만 열지 마세요. 저장소 루트에서 `flutter pub get` 한 뒤 Flutter 프로젝트로 엽니다.

GitHub Pages에 올릴 때는 `--base-href /monicard-super-app/` 가 필요합니다.

## 문서

| 문서 | 내용 |
|---|---|
| [Docs/monicard-super-app-eli5-manual.pdf](Docs/monicard-super-app-eli5-manual.pdf) | 처음 15분에 연결하고 사진 한 장 보내기 |
| [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) | 런타임 구조 |
| [Docs/PROTOCOL_SPECIFICATION.md](Docs/PROTOCOL_SPECIFICATION.md) | BLE UUID, 프레임, 명령 |
| [Docs/LICENSES.md](Docs/LICENSES.md) | 직접 쓰는 패키지와 참고 SDK |
| [Docs/SECURITY.md](Docs/SECURITY.md) | FILE / OTA 위험 |

GATT 서비스 `7369666c-695f-7364-0000-000000000000`, 데이터 캐릭터리스틱 `…0002…`.  
프레임은 `category u8 | flags u8 | payload_length u16 LE | payload`. CONTROL 카테고리는 `0x1F`.

## 안전

OTA는 기기를 영구 정지시킬 수 있습니다. 서명·롤백·중단 복구가 검증되기 전까지 생산 기기에서 쓰지 마세요. FILE 세션도 형식이 맞지 않으면 저장 그림이 손상될 수 있습니다. 일상 전송은 **이미지**와 **애니메이션** 메뉴만 쓰면 됩니다.

## 라이선스

앱 코드는 MIT입니다. 태그 ID와 제품 이미지는 하드웨어와 맞추기 위해 실립니다. 원본 웹 앱·문서와의 구분은 [Docs/LICENSES.md](Docs/LICENSES.md)를 보세요.
