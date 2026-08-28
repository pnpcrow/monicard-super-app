import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monicard_super_app/protocol.dart';

void main() {
  test('GET_VERSION frame', () {
    final bytes = getVersion();
    expect(bytes, Uint8List.fromList([0x1F, 0x00, 0x04, 0x00, 0x14, 0x00, 0x01, 0x00]));
  });

  test('profile byte limit', () {
    expect(() => setCardInfo('a' * 400), throwsA(isA<StateError>()));
    final ok = setCardInfo('hello');
    expect(ok[0], Category.control);
    expect(readU16(ok, 4), ControlCommand.setCardInfo);
  });

  test('tag encoding', () {
    final bytes = setTags([const TagRef(0, 1), const TagRef(3, 12)]);
    final payload = bytes.sublist(4);
    expect(payload[0], ControlCommand.setTags & 255);
    expect(payload[2], 2); // count
    expect(payload[3], 0); // category
    expect(readU16(payload, 4), 1);
  });

  test('carousel clamp', () {
    final high = setCarousel(9999);
    expect(readU16(high.sublist(6), 0), 3600);
    final zero = setCarousel(0);
    expect(readU16(zero.sublist(6), 0), 0);
  });

  test('splitFrame keeps payload length in first chunk', () {
    final frameBytes = control(ControlCommand.getVersion, Uint8List.fromList([1, 0]));
    final chunks = splitFrame(frameBytes, mtu: 247);
    expect(chunks, isNotEmpty);
    expect(chunks.first[0], Category.control);
    expect(readU16(chunks.first, 2), frameBytes.length - 4);
  });

  test('decodePacket reads command without inner length', () {
    final packet = Uint8List.fromList([0x1F, 0x00, 0x04, 0x00, 0x0F, 0x00, 0x41, 0x00]);
    final decoded = decodePacket(packet)!;
    expect(decoded.command, ControlCommand.respCardInfo);
    expect(decoded.data, Uint8List.fromList([0x41, 0x00]));
  });
}
