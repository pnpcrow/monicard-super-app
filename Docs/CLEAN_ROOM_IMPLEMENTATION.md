# Clean-Room Implementation Guide

## Objective

Produce an interoperable implementation from documented behavior and interface facts without copying original source-code expression.

## Roles

A strict clean-room project should separate two roles:

1. **Analyst:** observes public behavior, permitted build artifacts, BLE traffic, and device responses. The analyst writes neutral specifications and test vectors.
2. **Implementer:** receives only the neutral specification and test vectors, then writes new code independently.

For a small project where role separation is impossible, retain a detailed provenance log and avoid copying identifiers, comments, control flow, UI text, or structural expression unless the item is required for interoperability.

## Permitted evidence record

For each finding, record:

- Evidence source and acquisition date
- Artifact or firmware version
- Observation method
- Exact bytes sent and received, when relevant
- Whether the fact is required for interoperability
- Confidence level: Confirmed, Strongly inferred, Tentative, or Unknown
- Reproduction steps

## Workflow

### 1. Inventory behavior

List screens, user actions, persistent values, device states, error conditions, and externally visible network or BLE interactions.

### 2. Capture interfaces

Document service UUIDs, characteristic properties, packet boundaries, byte order, command IDs, payload lengths, response IDs, retry behavior, and timeouts.

### 3. Create test vectors

For each command, provide semantic input and expected bytes. Example:

```text
Operation: GET_VERSION
Expected frame: 1f 00 04 00 14 00 00 00
```

The vector above follows the currently inferred frame layout and must be revalidated against hardware before being treated as normative.

### 4. Implement from the specification

Keep protocol construction, transport, response parsing, UI, and persistence in separate modules. Do not translate minified control flow line by line.

### 5. Differential validation

Compare observable outcomes rather than source structure:

- Generated request bytes
- Device response bytes
- Displayed device behavior
- Timing and retry behavior
- Error and recovery paths

### 6. Mark uncertainty

Unknown fields must remain named `reserved`, `unknown`, or `unverified`. Do not invent semantic names merely because a byte happens to change once.

## Repository policy

- No original minified bundles should be committed to the clean implementation repository.
- No copied original UI text unless separately licensed or essential for interoperability.
- Generated packet captures should redact personal identifiers.
- Every protocol change must update `PROTOCOL_SPECIFICATION.md` and add a test vector.
- Hardware-destructive features remain behind an explicit experimental build flag.

## Current implementation boundary

Implemented independently:

- Node.js / Express host
- Responsive web UI
- i18n catalog
- Web Bluetooth transport abstraction
- Packet framing and known CONTROL builders
- Local persistence and diagnostics

Documented but intentionally not activated:

- Stateful FILE transfer
- Missing-chunk recovery
- OTA package execution
- Device reboot and post-update verification
