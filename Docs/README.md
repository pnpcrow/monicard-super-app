# MoniCard Documentation

This directory separates implementation guidance from protocol observations so future changes do not blur verified facts into confident-looking guesses.

## Documents

| Document | Purpose |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Runtime components, state flow, and trust boundaries |
| [CLEAN_ROOM_IMPLEMENTATION.md](CLEAN_ROOM_IMPLEMENTATION.md) | Process for independent, auditable reimplementation |
| [PROTOCOL_SPECIFICATION.md](PROTOCOL_SPECIFICATION.md) | BLE UUIDs, framing, commands, limits, and confidence levels |
| [I18N.md](I18N.md) | Locale policy and translation workflow |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Setup, coding conventions, and release checklist |
| [SECURITY.md](SECURITY.md) | Browser, API, BLE, and firmware safety considerations |
| [LICENSES.md](LICENSES.md) | Direct dependencies and referenced SDKs |
| [monicard-super-app-eli5-manual.pdf](monicard-super-app-eli5-manual.pdf) | First-time user manual (ELI5) |

## Documentation rule

Any feature or protocol change must update the relevant document in the same change set. New command IDs must include provenance, confidence, expected request and response payloads, and hardware test results.
