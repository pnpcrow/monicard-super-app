import 'dart:convert';
import 'dart:typed_data';

class Uuids {
  static const service = '7369666c-695f-7364-0000-000000000000';
  static const config = '7369666c-695f-7364-0001-000000000000';
  static const data = '7369666c-695f-7364-0002-000000000000';
}

class Category {
  static const ota = 0x01;
  static const file = 0x04;
  static const control = 0x1F;
}

class PhoneType {
  static const ios = 1;
  static const android = 2;
}

class FileType {
  static const resource = 1;
  static const ip = 2;
  static const purchase = 3;
  static const ui = 4;
}

class ControlCommand {
  static const setBleName = 10;
  static const setBroadcast = 12;
  static const setCardInfo = 14;
  static const respCardInfo = 15;
  static const readCardInfo = 16;
  static const respReadCard = 17;
  static const getSerialNumber = 18;
  static const respSerialNumber = 19;
  static const getVersion = 20;
  static const respVersion = 21;
  static const getBattery = 22;
  static const respBattery = 23;
  static const controlInfo = 24;
  static const controlInfoResponse = 25;
  static const setMac = 30;
  static const getFsInfo = 32;
  static const getFsInfoResponse = 33;
  static const setTags = 34;
  static const respTags = 35;
  static const readCardsCount = 36;
  static const respCardsCount = 37;
  static const readCardById = 38;
  static const respCardById = 39;
  static const deleteCard = 40;
  static const respDeleteCard = 41;
  static const setCarousel = 42;
  static const respCarousel = 43;
  static const readCarousel = 44;
  static const respCarouselRd = 45;
}

class FileCommand {
  static const startRequest = 0;
  static const startResponse = 1;
  static const fileSendStartRequest = 2;
  static const fileSendStartResponse = 3;
  static const fileSendDataRequest = 4;
  static const fileSendDataResponse = 5;
  static const fileSendEndRequest = 6;
  static const fileSendEndResponse = 7;
  static const endRequest = 8;
  static const endResponse = 9;
  static const loseCheckRequest = 10;
  static const loseCheckResponse = 11;
  static const abortCommand = 12;
  static const fileInfoRequest = 13;
  static const fileInfoResponse = 14;
}

class OtaCommand {
  static const initRequest = 0;
  static const initResponse = 1;
  static const initCompleted = 2;
  static const imageStartRequest = 6;
  static const imageStartResponse = 7;
  static const imageEndRequest = 8;
  static const imageEndResponse = 9;
  static const imagePacketRequest = 10;
  static const imagePacketResponse = 11;
  static const transmissionEnd = 12;
  static const endCommand = 13;
}

class Limits {
  static const broadcastBytes = 24;
  static const cardBytes = 319;
  static const tags = 5;
  static const controlInfoBytes = 8;
}

int readU16(Uint8List a, [int o = 0]) =>
    (a.length > o ? a[o] : 0) | ((a.length > o + 1 ? a[o + 1] : 0) << 8);

int readU32(Uint8List a, [int o = 0]) =>
    ((a.length > o ? a[o] : 0) |
        ((a.length > o + 1 ? a[o + 1] : 0) << 8) |
        ((a.length > o + 2 ? a[o + 2] : 0) << 16) |
        ((a.length > o + 3 ? a[o + 3] : 0) << 24)) &
    0xFFFFFFFF;

Uint8List concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (n, p) => n + p.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

Uint8List u16bytes(int n) => Uint8List.fromList([n & 255, (n >> 8) & 255]);

Uint8List u32bytes(int n) => Uint8List.fromList([
      n & 255,
      (n >> 8) & 255,
      (n >> 16) & 255,
      (n >> 24) & 255,
    ]);

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s.replaceAll('\r\n', '\n').replaceAll('\r', '\n')));

String decodeText(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  while (text.endsWith('\u0000')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

Uint8List frame(int category, [Uint8List? payload]) {
  final body = payload ?? Uint8List(0);
  return concat([
    Uint8List.fromList([category, 0, body.length & 255, (body.length >> 8) & 255]),
    body,
  ]);
}

Uint8List message(int category, int command, [Uint8List? payload]) {
  final body = payload ?? Uint8List(0);
  return frame(
    category,
    concat([u16bytes(command), u16bytes(body.length), body]),
  );
}

Uint8List control(int command, [Uint8List? payload]) {
  final body = payload ?? Uint8List(0);
  return frame(Category.control, concat([u16bytes(command), body]));
}

Uint8List setCardInfo(String text) {
  final bytes = utf8Bytes(text);
  if (bytes.length > Limits.cardBytes) {
    throw StateError('Profile content exceeds ${Limits.cardBytes} bytes');
  }
  return control(ControlCommand.setCardInfo, bytes);
}

Uint8List readCardInfo() => control(ControlCommand.readCardInfo, Uint8List.fromList([1]));
Uint8List getSerialNumber() => control(ControlCommand.getSerialNumber, Uint8List.fromList([1, 0]));
Uint8List getVersion() => control(ControlCommand.getVersion, Uint8List.fromList([1, 0]));
Uint8List getBattery() => control(ControlCommand.getBattery, Uint8List.fromList([1, 0]));
Uint8List getFileSystemInfo() => control(ControlCommand.getFsInfo, Uint8List.fromList([1]));
Uint8List readControlInfo() => control(ControlCommand.controlInfo, Uint8List.fromList([1]));

Uint8List writeControlInfo(Uint8List values) {
  if (values.length != Limits.controlInfoBytes) {
    throw StateError('Control info must be ${Limits.controlInfoBytes} bytes');
  }
  final body = Uint8List(9);
  body[0] = 2;
  body.setRange(1, 9, values);
  return control(ControlCommand.controlInfo, body);
}

class TagRef {
  const TagRef(this.category, this.tagId);
  final int category;
  final int tagId;
  String get key => '$category:$tagId';

  static TagRef? parse(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final c = int.tryParse(parts[0]);
    final t = int.tryParse(parts[1]);
    if (c == null || t == null) return null;
    return TagRef(c, t);
  }
}

Uint8List setTags(List<TagRef> tags) {
  final clean = tags.take(Limits.tags).toList();
  final p = <int>[clean.length];
  for (final item in clean) {
    if (item.category < 0 || item.category > 255 || item.tagId < 0 || item.tagId > 65535) {
      throw StateError('Invalid tag id');
    }
    p.add(item.category & 255);
    p.add(item.tagId & 255);
    p.add((item.tagId >> 8) & 255);
  }
  return control(ControlCommand.setTags, Uint8List.fromList(p));
}

Uint8List setCarousel(int seconds) {
  final value = seconds.clamp(0, 3600);
  return control(ControlCommand.setCarousel, u16bytes(value));
}

Uint8List readCarousel() => control(ControlCommand.readCarousel, Uint8List.fromList([1]));

Uint8List fileTransferStart(int fileLength, {int fileType = FileType.resource, int phoneType = PhoneType.android}) {
  return message(
    Category.file,
    FileCommand.startRequest,
    concat([u16bytes(fileType), Uint8List.fromList([phoneType]), u32bytes(fileLength)]),
  );
}

Uint8List fileInfoRequest([int blockCount = 1]) {
  return message(Category.file, FileCommand.fileInfoRequest, u32bytes(blockCount < 1 ? 1 : blockCount));
}

Uint8List fileSendStart(int fileLength, String fileName) {
  final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
  final clipped = safe.length > 120 ? safe.substring(0, 120) : safe;
  final name = utf8Bytes(clipped);
  return message(
    Category.file,
    FileCommand.fileSendStartRequest,
    concat([u32bytes(fileLength), u16bytes(name.length), name]),
  );
}

Uint8List fileSendData(int index, Uint8List data) {
  return message(Category.file, FileCommand.fileSendDataRequest, concat([u32bytes(index), data]));
}

Uint8List fileSendEnd([int status = 0]) {
  return message(Category.file, FileCommand.fileSendEndRequest, u16bytes(status));
}

Uint8List fileTransferEnd() => message(Category.file, FileCommand.endRequest);
Uint8List fileLoseCheckResponse([int status = 0]) =>
    message(Category.file, FileCommand.loseCheckResponse, u16bytes(status));
Uint8List fileAbort() => message(Category.file, FileCommand.abortCommand);

Uint8List otaMessage(int command, [Uint8List? payload]) => message(Category.ota, command, payload);
Uint8List otaInitRequest([Uint8List? payload]) => otaMessage(OtaCommand.initRequest, payload);
Uint8List otaInitCompleted() => otaMessage(OtaCommand.initCompleted, Uint8List.fromList([1]));

Uint8List otaImageStart(int fileLength, int crc32Value, {int imageId = 0, int flags = 0}) {
  return otaMessage(
    OtaCommand.imageStartRequest,
    concat([
      u32bytes(fileLength),
      u32bytes(crc32Value),
      Uint8List.fromList([imageId & 255, flags & 255]),
    ]),
  );
}

Uint8List otaImagePacket(int packetIndex, int imageId, Uint8List data) {
  return otaMessage(
    OtaCommand.imagePacketRequest,
    concat([u16bytes(packetIndex), u16bytes(imageId), u16bytes(data.length), data]),
  );
}

Uint8List otaImageEnd({int imageId = 0, bool ok = true}) =>
    otaMessage(OtaCommand.imageEndRequest, Uint8List.fromList([imageId & 255, ok ? 1 : 0]));

Uint8List otaTransmissionEnd() => otaMessage(OtaCommand.transmissionEnd, Uint8List.fromList([0]));
Uint8List otaEndCommand() => otaMessage(OtaCommand.endCommand, Uint8List.fromList([0]));

List<Uint8List> splitFrame(Uint8List bytes, {int mtu = 247, int maxWrite = 512}) {
  var att = mtu < 23 ? 23 : mtu;
  if (maxWrite > 0 && att - 3 > maxWrite) {
    att = maxWrite + 3;
  }
  final payloadSize = att - 7;
  final totalPayloadLength = bytes.length < 4 ? 0 : bytes.length - 4;
  if (payloadSize < 1) {
    return [Uint8List.fromList(bytes)];
  }
  if (bytes.length <= payloadSize) {
    final out = Uint8List.fromList(bytes);
    if (out.length >= 4) {
      out[1] = 0;
      out[2] = totalPayloadLength & 255;
      out[3] = (totalPayloadLength >> 8) & 255;
    }
    return [out];
  }
  final result = <Uint8List>[];
  var offset = 0;
  while (offset < totalPayloadLength) {
    final remain = totalPayloadLength - offset;
    final size = remain < payloadSize ? remain : payloadSize;
    if (offset == 0) {
      result.add(concat([
        Uint8List.fromList([bytes[0], 1, totalPayloadLength & 255, (totalPayloadLength >> 8) & 255]),
        bytes.sublist(4, 4 + size),
      ]));
    } else {
      final kind = remain > payloadSize ? 2 : 3;
      result.add(concat([
        Uint8List.fromList([bytes[0], kind]),
        bytes.sublist(4 + offset, 4 + offset + size),
      ]));
    }
    offset += size;
  }
  return result;
}

int bleWriteMtu(int attMtu, {bool withoutResponse = true, int maxWrite = 512}) {
  final att = attMtu < 23 ? 23 : attMtu;
  final payload = att - 3;
  final cap = withoutResponse && payload > maxWrite ? maxWrite : payload;
  return cap + 3;
}

class DecodedPacket {
  DecodedPacket({required this.category, required this.command, required this.data, required this.raw});
  final int category;
  final int command;
  final Uint8List data;
  final Uint8List raw;
}

DecodedPacket? decodePacket(Uint8List bytes) {
  if (bytes.length < 4) return null;
  final category = bytes[0];
  final payloadLength = readU16(bytes, 2);
  final end = 4 + payloadLength > bytes.length ? bytes.length : 4 + payloadLength;
  final payload = bytes.sublist(4, end);
  if (payload.length < 2) return null;
  return DecodedPacket(
    category: category,
    command: readU16(payload, 0),
    data: payload.sublist(2),
    raw: bytes,
  );
}

int firmwareFileCrc(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= (byte << 24) & 0xFFFFFFFF;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x80000000) != 0 ? (((crc << 1) & 0xFFFFFFFF) ^ 0x04C11DB7) : ((crc << 1) & 0xFFFFFFFF);
    }
  }
  return crc & 0xFFFFFFFF;
}

int crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? ((crc >> 1) ^ 0xEDB88320) : (crc >> 1);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

String reverseUuid(String uuid) {
  final compact = uuid.toLowerCase().replaceAll('-', '');
  if (compact.length != 32) return uuid;
  final bytes = <String>[];
  for (var i = 0; i < 32; i += 2) {
    bytes.add(compact.substring(i, i + 2));
  }
  final reversed = bytes.reversed.join();
  return '${reversed.substring(0, 8)}-${reversed.substring(8, 12)}-${reversed.substring(12, 16)}-${reversed.substring(16, 20)}-${reversed.substring(20)}';
}

bool uuidMatches(String actual, String expected) {
  String n(String u) => u.toLowerCase().replaceAll('-', '');
  return n(actual) == n(expected) || n(actual) == n(reverseUuid(expected));
}
