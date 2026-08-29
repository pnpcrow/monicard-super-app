import 'dart:typed_data';

class VideoProbe {
  const VideoProbe({required this.durationMs, required this.width, required this.height});
  final int durationMs;
  final int width;
  final int height;
}

class MotionVideoUnsupported implements Exception {
  const MotionVideoUnsupported();
  @override
  String toString() => 'This video cannot be decoded here. Use a GIF, or open the web app in Chrome.';
}

Future<VideoProbe> probeVideo(Uint8List bytes, {String? path, String mime = ''}) async {
  throw const MotionVideoUnsupported();
}

Future<Uint8List> extractPreviewFrame(Uint8List bytes, {String mime = '', int timeMs = 0}) async {
  throw const MotionVideoUnsupported();
}

Future<List<Uint8List>> extractCroppedJpegFrames(
  Uint8List bytes, {
  String? path,
  String mime = '',
  required List<int> timesMs,
  required int sx,
  required int sy,
  required int sw,
  required int sh,
  void Function(int progress)? onProgress,
}) async {
  throw const MotionVideoUnsupported();
}
