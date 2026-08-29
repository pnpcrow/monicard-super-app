import 'dart:convert';
import 'dart:typed_data';

Uint8List makeMjpegMp4(
  List<Uint8List> frames, {
  required int width,
  required int height,
  required int fps,
}) {
  if (frames.isEmpty) {
    throw StateError('No animation frames were produced.');
  }
  final timescale = 1000;
  final sampleDelta = (timescale / fps).round().clamp(1, timescale);
  final duration = sampleDelta * frames.length;
  final ftyp = _box('ftyp', [
    _str('isom'),
    _u32(0x200),
    _str('isom'),
    _str('iso2'),
    _str('mp41'),
  ]);
  final mdatPayload = _concat(frames);
  final mdat = _box('mdat', [mdatPayload]);
  var current = ftyp.length + 8;
  final sizes = <int>[];
  final offsets = <int>[];
  for (final frame in frames) {
    sizes.add(frame.length);
    offsets.add(current);
    current += frame.length;
  }

  final mvhd = _fullBox('mvhd', 0, 0, [
    _u32(0),
    _u32(0),
    _u32(timescale),
    _u32(duration),
    _fixed16(1),
    _u16(0x0100),
    _u16(0),
    _u32(0),
    _u32(0),
    _matrixIdentity(),
    Uint8List(24),
    _u32(2),
  ]);
  final tkhd = _fullBox('tkhd', 0, 7, [
    _u32(0),
    _u32(0),
    _u32(1),
    _u32(0),
    _u32(duration),
    _u32(0),
    _u32(0),
    _u16(0),
    _u16(0),
    _u16(0),
    _u16(0),
    _matrixIdentity(),
    _fixed16(width.toDouble()),
    _fixed16(height.toDouble()),
  ]);
  final mdhd = _fullBox('mdhd', 0, 0, [
    _u32(0),
    _u32(0),
    _u32(timescale),
    _u32(duration),
    _u16(0x55c4),
    _u16(0),
  ]);
  final hdlr = _fullBox('hdlr', 0, 0, [
    _u32(0),
    _str('vide'),
    _u32(0),
    _u32(0),
    _u32(0),
    _str('VideoHandler\u0000'),
  ]);
  final vmhd = _fullBox('vmhd', 0, 1, [_u16(0), _u16(0), _u16(0), _u16(0)]);
  final url = _fullBox('url ', 0, 1, const []);
  final dref = _fullBox('dref', 0, 0, [_u32(1), url]);
  final dinf = _box('dinf', [dref]);
  final compressor = Uint8List(32);
  final name = _str('Motion JPEG');
  compressor[0] = name.length.clamp(0, 31);
  compressor.setRange(1, 1 + compressor[0], name.sublist(0, compressor[0]));
  final jpegEntry = _box('jpeg', [
    Uint8List(6),
    _u16(1),
    _u16(0),
    _u16(0),
    _u32(0),
    _u32(0),
    _u32(0),
    _u16(width),
    _u16(height),
    _fixed16(72),
    _fixed16(72),
    _u32(0),
    _u16(1),
    compressor,
    _u16(24),
    _u16(0xffff),
  ]);
  final stsd = _fullBox('stsd', 0, 0, [_u32(1), jpegEntry]);
  final stts = _fullBox('stts', 0, 0, [_u32(1), _u32(frames.length), _u32(sampleDelta)]);
  final stsc = _fullBox('stsc', 0, 0, [_u32(1), _u32(1), _u32(1), _u32(1)]);
  final stsz = _fullBox('stsz', 0, 0, [_u32(0), _u32(frames.length), ...sizes.map(_u32)]);
  final stco = _fullBox('stco', 0, 0, [_u32(frames.length), ...offsets.map(_u32)]);
  final stbl = _box('stbl', [stsd, stts, stsc, stsz, stco]);
  final minf = _box('minf', [vmhd, dinf, stbl]);
  final mdia = _box('mdia', [mdhd, hdlr, minf]);
  final trak = _box('trak', [tkhd, mdia]);
  final moov = _box('moov', [mvhd, trak]);
  return _concat([ftyp, mdat, moov]);
}

Uint8List _u16(int n) => Uint8List.fromList([(n >> 8) & 255, n & 255]);
Uint8List _u32(int n) => Uint8List.fromList([(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]);
Uint8List _str(String value) => Uint8List.fromList(utf8.encode(value));
Uint8List _fixed16(double n) => _u32((n * 65536).round());

Uint8List _matrixIdentity() => _concat([
      _fixed16(1),
      _u32(0),
      _u32(0),
      _u32(0),
      _fixed16(1),
      _u32(0),
      _u32(0),
      _u32(0),
      _u32(0x40000000),
    ]);

Uint8List _concat(Iterable<Uint8List> parts) {
  final length = parts.fold<int>(0, (n, p) => n + p.length);
  final out = Uint8List(length);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

Uint8List _box(String type, List<Uint8List> payload) {
  final body = _concat(payload);
  return _concat([_u32(body.length + 8), _str(type), body]);
}

Uint8List _fullBox(String type, int version, int flags, List<Uint8List> payload) {
  return _box(type, [
    Uint8List.fromList([version, (flags >> 16) & 255, (flags >> 8) & 255, flags & 255]),
    ...payload,
  ]);
}
