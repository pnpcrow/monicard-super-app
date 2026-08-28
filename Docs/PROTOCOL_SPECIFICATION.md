# MoniCard BLE Protocol Specification

**Document status:** Draft interoperability specification  
**Default byte order:** Little-endian for observed 16-bit values  
**Safety status:** CONTROL commands partially implemented; FILE and OTA sessions unverified on hardware

## Confidence labels

- **Confirmed:** value was directly present in distributed artifacts or repeatedly observed.
- **Strongly inferred:** structure is supported by multiple related observations.
- **Tentative:** plausible but not adequately validated.
- **Unknown:** semantics are not established.

## GATT identifiers

| Purpose | UUID | Confidence |
|---|---|---|
| Primary service | `7369666c-695f-7364-0000-000000000000` | Confirmed |
| Configuration characteristic | `7369666c-695f-7364-0001-000000000000` | Confirmed |
| Data characteristic | `7369666c-695f-7364-0002-000000000000` | Confirmed |

The current web implementation writes to the data characteristic and subscribes to notifications or indications on it when supported. The exact role of the configuration characteristic remains unverified.

## Transport chunking

Application frames may exceed a single GATT write. The browser transport splits a frame using:

```text
chunk_size = max(20, mtu - 3)
```

The web implementation defaults to an assumed MTU of 247 because Web Bluetooth does not provide a portable MTU negotiation API. Successful characteristic writes do not prove application-level acceptance.

## Top-level frame

```text
Offset  Size  Field
0       1     category
1       1     flags_or_sequence (currently written as 0)
2       2     payload_length, uint16 little-endian
4       N     payload
```

Confidence: **Strongly inferred**.

## Categories

| Name | Value | Confidence |
|---|---:|---|
| OTA | `0x01` | Confirmed |
| FILE | `0x04` | Confirmed |
| CONTROL | `0x1F` | Confirmed |

## CONTROL payload

```text
Offset  Size  Field
0       2     command_id, uint16 little-endian
2       2     command_payload_length, uint16 little-endian
4       N     command_payload
```

Confidence: **Strongly inferred**.

## CONTROL commands

| Name | ID | Direction / expected pair | Confidence |
|---|---:|---|---|
| SET_BLE_NAME | 10 | request | Confirmed |
| SET_BROADCAST | 12 | request | Confirmed |
| SET_CARD_INFO | 14 | request; response 15 | Confirmed |
| RESP_CARD_INFO | 15 | response | Confirmed |
| READ_CARD_INFO | 16 | request; response 17 | Confirmed |
| RESP_READ_CARD | 17 | response | Confirmed |
| GET_SERIAL_NUMBER | 18 | request | Confirmed |
| GET_VERSION | 20 | request | Confirmed |
| GET_BATTERY | 22 | request | Confirmed |
| CONTROL_INFO | 24 | request; response 25 | Confirmed |
| CONTROL_INFO_RESPONSE | 25 | response | Confirmed |
| SET_MAC | 30 | request | Confirmed |
| GET_FS_INFO | 32 | request; response 33 | Confirmed |
| GET_FS_INFO_RESPONSE | 33 | response | Confirmed |
| SET_TAGS | 34 | request; response 35 | Confirmed |
| RESP_TAGS | 35 | response | Confirmed |
| READ_CARDS_COUNT | 36 | request; response 37 | Confirmed |
| RESP_CARDS_COUNT | 37 | response | Confirmed |
| READ_CARD_BY_ID | 38 | request; response 39 | Confirmed |
| RESP_CARD_BY_ID | 39 | response | Confirmed |
| DELETE_CARD | 40 | request; response 41 | Confirmed |
| RESP_DELETE_CARD | 41 | response | Confirmed |
| SET_CAROUSEL | 42 | request; response 43 | Confirmed |
| RESP_CAROUSEL | 43 | response | Confirmed |
| READ_CAROUSEL | 44 | request; response 45 | Confirmed |
| RESP_CAROUSEL_RD | 45 | response | Confirmed |

Response payload schemas still require packet captures.

## Payload encodings

### Profile card

`SET_CARD_INFO` payload is normalized UTF-8 text with a maximum of 319 bytes.

### Tags

Current builder encoding:

```text
uint8 count
repeat count times:
  uint16 byte_length_le
  byte[byte_length] utf8_tag
```

Maximum number of tags: 5. Confidence: **Strongly inferred**.

### Control information

Current builder writes an eight-byte boolean vector, one byte per setting. The semantic order currently used by the UI is:

1. buzzer
2. vibration
3. interest-match light
4. interest matching
5. ambient light
6. carousel
7. reserved
8. reserved

The field order requires hardware verification. Confidence: **Tentative**.

### Carousel

Current builder payload:

```text
uint8 enabled
uint8 interval_seconds  // clamped to 1..60
```

Confidence: **Tentative**.

## FILE commands

| Name | ID |
|---|---:|
| START_REQUEST | 0 |
| START_RESPONSE | 1 |
| FILE_SEND_START_REQUEST | 2 |
| FILE_SEND_START_RESPONSE | 3 |
| FILE_SEND_DATA_REQUEST | 4 |
| FILE_SEND_DATA_RESPONSE | 5 |
| FILE_SEND_END_REQUEST | 6 |
| FILE_SEND_END_RESPONSE | 7 |
| END_REQUEST | 8 |
| END_RESPONSE | 9 |
| LOSE_CHECK_REQUEST | 10 |
| LOSE_CHECK_RESPONSE | 11 |
| ABORT_COMMAND | 12 |
| FILE_INFO_REQUEST | 13 |
| FILE_INFO_RESPONSE | 14 |
| FILE_PHOTO_PREVIEW_DATA | 15 |
| FILE_PHOTO_PREVIEW_DATA_RESPONSE | 16 |

IDs are confirmed. Session structure, file metadata, chunk indexes, checksums, acknowledgement timing, and loss bitmap encoding remain unverified.

## OTA

The OTA category and artifact roles HCPU, LCPU, RES, FONT, BOOTLOADER, and control package were identified. CRC32 and segmented transfer behavior were also indicated by artifacts, but the normative wire format has not been validated. OTA must remain disabled in production builds until recovery from interruption and invalid images is proven.

## Error handling requirements

An interoperable implementation should:

- serialize writes
- wait for protocol acknowledgements, not only GATT completion
- apply bounded retries
- support an explicit abort
- reject malformed declared lengths
- cap all allocation sizes
- persist enough session state to recover or restart safely
- treat unknown response IDs as diagnostic data, not success
