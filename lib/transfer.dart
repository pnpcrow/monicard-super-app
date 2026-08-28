import 'dart:async';
import 'dart:typed_data';

import 'ble/ble.dart';
import 'protocol.dart';

class TransferResult {
  TransferResult({
    required this.bytes,
    required this.packets,
    required this.crc32hex,
    this.transferBytes,
    this.fileBlocks,
  });
  final int bytes;
  final int packets;
  final String crc32hex;
  final int? transferBytes;
  final int? fileBlocks;
}

class TransferController {
  TransferController(this.ble);

  final MoniCardBle ble;
  bool aborted = false;
  final Map<String, List<_Waiter>> _waiters = {};
  static const fileBlockSize = 10240;

  bool handlePacket(Uint8List raw) {
    final packet = decodePacket(raw);
    if (packet == null) return false;
    if (packet.category == Category.file && packet.command == FileCommand.loseCheckRequest) {
      ble.sendPriority(fileLoseCheckResponse(0)).catchError((_) {});
      return true;
    }
    final key = '${packet.category}:${packet.command}';
    final queue = _waiters[key];
    if (queue == null || queue.isEmpty) return false;
    final waiter = queue.removeAt(0);
    waiter.timer.cancel();
    waiter.complete(packet);
    if (queue.isEmpty) _waiters.remove(key);
    return true;
  }

  Future<DecodedPacket> wait(int category, int command, {Duration timeout = const Duration(seconds: 12)}) {
    final key = '$category:$command';
    late _Waiter waiter;
    waiter = _Waiter()
      ..timer = Timer(timeout, () {
        final queue = _waiters[key] ?? [];
        queue.remove(waiter);
        waiter.completeError(StateError('Device response timed out (category $category, command $command)'));
      });
    _waiters.putIfAbsent(key, () => []).add(waiter);
    return waiter.future;
  }

  Future<DecodedPacket> sendAndWait(
    Uint8List bytes,
    int category,
    int responseCommand, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final pending = wait(category, responseCommand, timeout: timeout);
    await ble.send(bytes);
    return pending;
  }

  DecodedPacket assertOk(DecodedPacket packet, String label) {
    final data = packet.data;
    if (data.length < 2) return packet;
    final declaredLength = readU16(data, 0);
    final hasLengthPrefix = declaredLength > 0 && declaredLength <= data.length - 2;
    final payload = hasLengthPrefix ? data.sublist(2, 2 + declaredLength) : data;
    final code = payload.length >= 2 ? readU16(payload, 0) : 0;
    if (code != 0) {
      const messages = {
        1: 'Device storage is full',
        2: 'Unsupported file type',
        3: 'File is too large',
        4: 'Invalid file name',
        5: 'Checksum mismatch',
      };
      throw StateError('$label: ${messages[code] ?? 'Device error ($code)'}');
    }
    return packet;
  }

  Future<void> abort() async {
    aborted = true;
    try {
      await ble.send(fileAbort());
    } catch (_) {}
  }

  void check() {
    if (aborted) throw StateError('Transfer aborted');
    if (!ble.connected) throw StateError('Device is not connected');
  }

  Future<TransferResult> sendFile(
    Uint8List source, {
    required String name,
    int fileType = FileType.resource,
    void Function(int progress)? onProgress,
  }) async {
    aborted = false;
    final prepared = _prepareTransferBytes(source);
    final transferBytes = prepared.bytes;
    final mtu = ble.mtu < 23 ? 23 : ble.mtu;
    final mtuDerived = 50 * (mtu - 7) - 8;
    final filePacketSize = (mtuDerived < 256 ? 256 : mtuDerived).clamp(256, fileBlockSize);
    final chunks = <Uint8List>[];
    for (var i = 0; i < transferBytes.length; i += filePacketSize) {
      final end = i + filePacketSize > transferBytes.length ? transferBytes.length : i + filePacketSize;
      chunks.add(transferBytes.sublist(i, end));
    }
    final fileBlocks = (transferBytes.length / fileBlockSize).ceil().clamp(1, 0x7fffffff);
    onProgress?.call(3);
    assertOk(
      await sendAndWait(
        fileTransferStart(transferBytes.length, fileType: fileType, phoneType: PhoneType.ios),
        Category.file,
        FileCommand.startResponse,
        timeout: const Duration(seconds: 15),
      ),
      'Start transfer',
    );
    onProgress?.call(8);
    assertOk(await sendAndWait(fileInfoRequest(fileBlocks), Category.file, FileCommand.fileInfoResponse), 'File info');
    onProgress?.call(12);
    assertOk(
      await sendAndWait(fileSendStart(transferBytes.length, name), Category.file, FileCommand.fileSendStartResponse),
      'File start',
    );
    for (var i = 0; i < chunks.length; i++) {
      check();
      assertOk(
        await sendAndWait(
          fileSendData(i, chunks[i]),
          Category.file,
          FileCommand.fileSendDataResponse,
          timeout: const Duration(seconds: 20),
        ),
        'Packet ${i + 1}/${chunks.length}',
      );
      onProgress?.call(15 + (((i + 1) / chunks.length) * 77).round());
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    check();
    assertOk(
      await sendAndWait(fileSendEnd(0), Category.file, FileCommand.fileSendEndResponse, timeout: const Duration(seconds: 20)),
      'File end',
    );
    onProgress?.call(96);
    assertOk(
      await sendAndWait(fileTransferEnd(), Category.file, FileCommand.endResponse, timeout: const Duration(seconds: 20)),
      'Transfer end',
    );
    onProgress?.call(100);
    return TransferResult(
      bytes: source.length,
      packets: chunks.length,
      crc32hex: prepared.checksum.toRadixString(16).padLeft(8, '0'),
      transferBytes: transferBytes.length,
      fileBlocks: fileBlocks,
    );
  }

  Future<TransferResult> sendOta(
    Uint8List bytes, {
    int imageId = 0,
    int packetSize = 512,
    void Function(int progress)? onProgress,
  }) async {
    aborted = false;
    final checksum = crc32(bytes);
    final chunks = <Uint8List>[];
    for (var i = 0; i < bytes.length; i += packetSize) {
      final end = i + packetSize > bytes.length ? bytes.length : i + packetSize;
      chunks.add(bytes.sublist(i, end));
    }
    await ble.send(otaInitRequest());
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await ble.send(otaInitCompleted());
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await ble.send(otaImageStart(bytes.length, checksum, imageId: imageId));
    await Future<void>.delayed(const Duration(milliseconds: 180));
    for (var i = 0; i < chunks.length; i++) {
      check();
      await ble.send(otaImagePacket(i, imageId, chunks[i]));
      onProgress?.call((((i + 1) / chunks.length) * 94).round());
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
    check();
    await ble.send(otaImageEnd(imageId: imageId, ok: true));
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await ble.send(otaTransmissionEnd());
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await ble.send(otaEndCommand());
    onProgress?.call(100);
    return TransferResult(
      bytes: bytes.length,
      packets: chunks.length,
      crc32hex: checksum.toRadixString(16).padLeft(8, '0'),
    );
  }

  _Prepared _prepareTransferBytes(Uint8List source) {
    final alignedLength = (source.length + 3) & ~3;
    final aligned = Uint8List(alignedLength)..setRange(0, source.length, source);
    final checksum = firmwareFileCrc(aligned);
    return _Prepared(concat([aligned, u32bytes(checksum)]), checksum);
  }
}

class _Prepared {
  _Prepared(this.bytes, this.checksum);
  final Uint8List bytes;
  final int checksum;
}

class _Waiter {
  late final Timer timer;
  final _c = Completer<DecodedPacket>();
  Future<DecodedPacket> get future => _c.future;
  void complete(DecodedPacket p) {
    if (!_c.isCompleted) _c.complete(p);
  }

  void completeError(Object e) {
    if (!_c.isCompleted) _c.completeError(e);
  }
}
