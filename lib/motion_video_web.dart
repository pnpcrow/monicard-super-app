import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'media.dart';

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

String _blobType(String mime) {
  if (mime.startsWith('video/')) return mime;
  if (mime == 'mp4' || mime == 'm4v') return 'video/mp4';
  if (mime == 'webm') return 'video/webm';
  if (mime == 'mov') return 'video/quicktime';
  return 'video/mp4';
}

Future<web.HTMLVideoElement> _loadVideo(Uint8List bytes, String mime) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: _blobType(mime)),
  );
  final url = web.URL.createObjectURL(blob);
  final video = web.HTMLVideoElement()
    ..muted = true
    ..preload = 'auto'
    ..playsInline = true
    ..src = url;
  video.setAttribute('playsinline', 'true');
  try {
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 8));
    return video;
  } catch (error) {
    web.URL.revokeObjectURL(url);
    throw const MotionVideoUnsupported();
  }
}

Future<void> _seek(web.HTMLVideoElement video, double seconds) async {
  final target = seconds.clamp(0, mathMax(0, video.duration - 0.001));
  if ((video.currentTime - target).abs() < 0.005) return;
  final done = video.onSeeked.first;
  video.currentTime = target;
  await done.timeout(const Duration(seconds: 3));
}

double mathMax(double a, double b) => a > b ? a : b;

Uint8List _jpegFromCanvas(web.HTMLCanvasElement canvas) {
  final dataUrl = canvas.toDataURL('image/jpeg', 0.82.toJS);
  final comma = dataUrl.indexOf(',');
  if (comma < 0) throw const MotionVideoUnsupported();
  return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
}

Future<VideoProbe> probeVideo(Uint8List bytes, {String? path, String mime = ''}) async {
  final video = await _loadVideo(bytes, mime);
  try {
    final durationMs = ((video.duration.isFinite ? video.duration : 1) * 1000).round().clamp(1, 60 * 60 * 1000);
    final width = video.videoWidth == 0 ? kCardWidth : video.videoWidth;
    final height = video.videoHeight == 0 ? kCardHeight : video.videoHeight;
    return VideoProbe(durationMs: durationMs, width: width, height: height);
  } finally {
    web.URL.revokeObjectURL(video.src);
    video.src = '';
  }
}

Future<Uint8List> extractPreviewFrame(Uint8List bytes, {String mime = '', int timeMs = 0}) async {
  final video = await _loadVideo(bytes, mime);
  try {
    await _seek(video, timeMs / 1000);
    final canvas = web.HTMLCanvasElement()
      ..width = video.videoWidth == 0 ? kCardWidth : video.videoWidth
      ..height = video.videoHeight == 0 ? kCardHeight : video.videoHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0);
    return _jpegFromCanvas(canvas);
  } finally {
    web.URL.revokeObjectURL(video.src);
    video.src = '';
  }
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
  final video = await _loadVideo(bytes, mime);
  try {
    final canvas = web.HTMLCanvasElement()
      ..width = kCardWidth
      ..height = kCardHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.imageSmoothingEnabled = true;
    final out = <Uint8List>[];
    for (var i = 0; i < timesMs.length; i++) {
      await _seek(video, timesMs[i] / 1000);
      ctx.fillStyle = '#000'.toJS;
      ctx.fillRect(0, 0, kCardWidth, kCardHeight);
      ctx.drawImage(video, sx, sy, sw, sh, 0, 0, kCardWidth, kCardHeight);
      out.add(_jpegFromCanvas(canvas));
      onProgress?.call((5 + ((i + 1) / timesMs.length) * 85).round());
    }
    return out;
  } finally {
    web.URL.revokeObjectURL(video.src);
    video.src = '';
  }
}
