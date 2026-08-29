# Development Guide

## Commands

```bash
flutter pub get
flutter test
flutter run -d chrome
flutter run -d android
flutter build apk --release
flutter build web --release --base-href /
```

Android application ID is `dev.monicard.super_app`. Do not change it without a Play/ sideload migration plan.

## Android Studio

`android/local.properties` is generated on each machine and is gitignored. Gradle needs `flutter.sdk` in that file.

1. Install Flutter and put it on PATH (or set `FLUTTER_ROOT`).
2. From the **repository root** (`monicard-super-app`), run `flutter pub get`. That writes `android/local.properties` and `.dart_tool/package_config.json`.
3. Open the **Flutter project root**, not the `android/` folder, in Android Studio with the Flutter plugin.

Android Studio의 `assembleDebug`는 `.dart_tool/package_config.json`이 없으면 먼저 `flutter pub get`을 돌립니다. 그래도 실패하면 저장소 루트에서 `flutter pub get`을 직접 한 뒤 다시 빌드하세요.


If Gradle still reports a missing `flutter.sdk`, Android Studio's Gradle daemon often cannot see PATH. Create `android/local.properties` with your real paths:

```
sdk.dir=C:\\Users\\YOU\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\src\\flutter
```

`where flutter` on Windows prints the `flutter.bat` path. The SDK is two folders above that file. After saving, sync Gradle again. The settings script also searches PATH, FVM, and common install folders and writes `local.properties` when it finds one.


## Design rules

- Keep BLE transport independent from protocol construction.
- Keep protocol builders deterministic and side-effect free.
- Do not report device success until an application-level response is decoded.
- Keep unsupported or unsafe features visibly disabled rather than simulated.
- Update documentation with every feature or protocol change.
- Avoid framework dependencies unless they remove more complexity than they add.
- Still images are cropped in-app to 240×320 (pan + zoom). Do not use an Android crop Intent; Web must share the same editor.

## API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Runtime health |
| GET | `/api/content/:type` | Local informational content |
| GET | `/api/firmware/latest` | Firmware metadata only |
| POST | `/api/feedback` | Store local feedback record |
| GET | `/docs/` | Browser documentation index |

## Release checklist

1. Run tests.
2. Start the server and request `/api/health`.
3. Open the SPA in desktop Chrome and test all routes.
4. Test one mobile viewport.
5. Switch through all five locales.
6. Verify no unimplemented operation claims success.
7. Confirm FILE and OTA remain disabled unless a hardware validation release explicitly enables them.
8. Update `README.md`, `Docs/`, and version metadata.
