import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

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

const _channel = MethodChannel('dev.monicard.super_app/video');
const _progress = EventChannel('dev.monicard.super_app/video/progress');

String? _cachedPath;
int? _cachedLength;

Future<Uint8List?> loadPickedBytes(Uint8List? bytes, String? path) async {
  if (bytes != null && bytes.isNotEmpty) return bytes;
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

String _extension(String mime) {
  final lower = mime.toLowerCase();
  if (lower.contains('webm')) return 'webm';
  if (lower.contains('mov') || lower.contains('quicktime')) return 'mov';
  if (lower.contains('m4v')) return 'm4v';
  return 'mp4';
}

Future<String> _ensurePath(Uint8List bytes, String? path, String mime) async {
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (file.existsSync()) return path;
  }
  if (_cachedPath != null &&
      _cachedLength == bytes.length &&
      File(_cachedPath!).existsSync()) {
    return _cachedPath!;
  }
  final file = File(
    '${Directory.systemTemp.path}/mc_motion_${DateTime.now().microsecondsSinceEpoch}.${_extension(mime)}',
  );
  await file.writeAsBytes(bytes, flush: true);
  _cachedPath = file.path;
  _cachedLength = bytes.length;
  return file.path;
}

Future<T> _invoke<T>(String method, Map<String, Object?> args) async {
  try {
    final value = await _channel.invokeMethod<T>(method, args);
    if (value == null) throw const MotionVideoUnsupported();
    return value;
  } on MissingPluginException {
    throw const MotionVideoUnsupported();
  } on PlatformException {
    throw const MotionVideoUnsupported();
  }
}

Future<VideoProbe> probeVideo(Uint8List bytes, {String? path, String mime = ''}) async {
  final filePath = await _ensurePath(bytes, path, mime);
  final map = await _invoke<Map<Object?, Object?>>('probe', {'path': filePath});
  final duration = (map['durationMs'] as num?)?.toInt() ?? 0;
  final width = (map['width'] as num?)?.toInt() ?? 0;
  final height = (map['height'] as num?)?.toInt() ?? 0;
  if (duration < 1 || width < 1 || height < 1) {
    throw const MotionVideoUnsupported();
  }
  return VideoProbe(durationMs: duration, width: width, height: height);
}

Future<Uint8List> extractPreviewFrame(
  Uint8List bytes, {
  String? path,
  String mime = '',
  int timeMs = 0,
}) async {
  final filePath = await _ensurePath(bytes, path, mime);
  final jpeg = await _invoke<Uint8List>('frame', {
    'path': filePath,
    'timeMs': timeMs,
  });
  if (jpeg.isEmpty) throw const MotionVideoUnsupported();
  return jpeg;
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
  final filePath = await _ensurePath(bytes, path, mime);
  onProgress?.call(8);
  final sub = _progress.receiveBroadcastStream().listen((value) {
    final parsed = value is int ? value : (value is num ? value.round() : null);
    if (parsed == null) return;
    final percent = parsed < 8 ? 8 : (parsed > 92 ? 92 : parsed);
    onProgress?.call(percent);
  });
  await Future<void>.delayed(Duration.zero);
  try {
    final raw = await _invoke<List<Object?>>('frames', {
      'path': filePath,
      'timesMs': timesMs,
      'sx': sx,
      'sy': sy,
      'sw': sw,
      'sh': sh,
    });
    final jpegs = <Uint8List>[];
    for (final item in raw) {
      if (item is Uint8List) {
        jpegs.add(item);
      }
    }
    if (jpegs.isEmpty) throw const MotionVideoUnsupported();
    onProgress?.call(92);
    return jpegs;
  } finally {
    await sub.cancel();
  }
}
