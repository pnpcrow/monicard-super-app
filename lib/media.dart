import 'dart:typed_data';

import 'package:image/image.dart' as img;

const kCardWidth = 240;
const kCardHeight = 320;

Uint8List prepareStill(Uint8List bytes, {double zoom = 1}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode the image.');
  }
  final z = zoom < 1 ? 1.0 : (zoom > 3 ? 3.0 : zoom);
  final targetRatio = kCardWidth / kCardHeight;
  final sourceRatio = decoded.width / decoded.height;
  late int sw, sh;
  if (sourceRatio > targetRatio) {
    sh = (decoded.height / z).round().clamp(1, decoded.height);
    sw = (sh * targetRatio).round().clamp(1, decoded.width);
  } else {
    sw = (decoded.width / z).round().clamp(1, decoded.width);
    sh = (sw / targetRatio).round().clamp(1, decoded.height);
  }
  final sx = ((decoded.width - sw) / 2).round().clamp(0, decoded.width - 1);
  final sy = ((decoded.height - sh) / 2).round().clamp(0, decoded.height - 1);
  final cropped = img.copyCrop(decoded, x: sx, y: sy, width: sw, height: sh);
  final sized = img.copyResize(cropped, width: kCardWidth, height: kCardHeight, interpolation: img.Interpolation.cubic);
  return Uint8List.fromList(img.encodePng(sized));
}

bool looksLikeMotion(String name, String mime) {
  final n = name.toLowerCase();
  final m = mime.toLowerCase();
  return m.startsWith('video/') || m == 'image/gif' || n.endsWith('.gif') || n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.m4v');
}

String deviceResourceName({required bool motion}) {
  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  return motion ? 'v$suffix.mp4' : 'c$suffix.png';
}
