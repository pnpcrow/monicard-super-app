# Testing Strategy

## Automated tests

Protocol tests should assert exact output bytes for:

- empty CONTROL frame
- GET_VERSION
- UTF-8 profile text and byte limit
- tag count and lengths
- control vector length
- carousel interval clamping
- transport chunk boundaries

## Browser matrix

| Platform | Browser | Expected |
|---|---|---|
| Windows | Chrome / Edge | UI and Web Bluetooth |
| macOS | Chrome / Edge | UI and Web Bluetooth where OS permits |
| Linux | Chrome / Chromium | Environment-dependent BLE support |
| Android | Chrome | Mobile UI and Web Bluetooth |
| iOS / iPadOS | Safari / Chrome | UI only; no Web Bluetooth |

## Locale matrix

For every release, open Home, Device control, Profile, Tags, Device information, Settings, and Diagnostics in all five locales. Check clipping, button wrapping, and text overflow.

## Hardware validation sequence

1. Connect and record discovered services and characteristic properties.
2. Send read-only information commands.
3. Capture and decode responses.
4. Test reversible controls.
5. Test profile and tag writes with known values.
6. Reboot and verify persistence.
7. Validate FILE transfer with a disposable asset.
8. Interrupt transfer at each phase and test recovery.
9. Test OTA only with recoverable development hardware.

Every capture should record firmware version, timestamp, request bytes, response bytes, and observed device behavior.
