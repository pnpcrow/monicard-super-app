# Security and Safety

## Web application

- Use HTTPS outside localhost.
- Keep Express JSON limits bounded.
- Escape all user and device strings before inserting HTML.
- Do not expose feedback records through a public endpoint by default.
- Add authentication and CSRF protection before enabling administrative APIs.
- Set production security headers with a reverse proxy or middleware.

## Bluetooth

- Device selection must require an explicit user gesture.
- Filter discovery by the confirmed service UUID.
- Treat notification data as hostile binary input.
- Validate category, command, and declared lengths before parsing.
- Do not store Bluetooth identifiers in server logs unless necessary.

## Media

- File type declarations are advisory; inspect content before decoding.
- Cap file size, dimensions, frame count, and processing time.
- Revoke object URLs after use in a future media-processing implementation.

## Firmware

OTA can permanently disable hardware. Before enabling it, verify:

- package authenticity or signature
- target model and hardware revision
- size and CRC
- interruption recovery
- rollback or rescue path
- battery and storage prerequisites
- final version confirmation after reboot

The current UI intentionally omits OTA execution.
