import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'media.dart';
import 'mjpeg.dart';
import 'motion_video.dart';

const kMotionFps = 20;
const kMaxMotionMs = 10000;
const kMinMotionMs = 250;
const kJpegQuality = 82;

class MotionClip {
  const MotionClip({
    this.crop = const StillCrop(),
    this.startMs = 0,
    this.endMs = kMaxMotionMs,
    this.fps = kMotionFps,
  });

  final StillCrop crop;
  final int startMs;
  final int endMs;
  final int fps;

  MotionClip copyWith({StillCrop? crop, int? startMs, int? endMs, int? fps}) {
    return MotionClip(
      crop: crop ?? this.crop,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      fps: fps ?? this.fps,
    );
  }
}

class MotionResult {
  const MotionResult({
    required this.mp4,
    required this.crop,
    required this.startMs,
    required this.endMs,
    required this.frames,
  });

  final Uint8List mp4;
  final StillCrop crop;
  final int startMs;
  final int endMs;
  final int frames;
}

class GifSequence {
  GifSequence({
    required this.frames,
    required this.durationsMs,
    required this.width,
    required this.height,
  });

  final List<img.Image> frames;
  final List<int> durationsMs;
  final int width;
  final int height;

  int get totalMs {
    final sum = durationsMs.fold<int>(0, (n, d) => n + d);
    return math.max(sum, 1);
  }

  img.Image frameAt(int timeMs) {
    var acc = 0;
    for (var i = 0; i < frames.length; i++) {
      acc += durationsMs[i];
      if (timeMs < acc) return frames[i];
    }
    return frames.last;
  }
}

GifSequence decodeGifSequence(Uint8List bytes) {
  final animation = img.decodeGif(bytes);
  if (animation == null || animation.numFrames == 0) {
    throw StateError('Could not decode the GIF.');
  }
  final frames = <img.Image>[];
  final durations = <int>[];
  for (final frame in animation.frames) {
    frames.add(img.bakeOrientation(frame));
    durations.add(math.max(20, frame.frameDuration == 0 ? 100 : frame.frameDuration));
  }
  return GifSequence(
    frames: frames,
    durationsMs: durations,
    width: frames.first.width,
    height: frames.first.height,
  );
}

({int startMs, int endMs}) clampClipWindow({
  required int startMs,
  required int endMs,
  required int totalMs,
}) {
  final total = totalMs < 1 ? 1 : totalMs;
  final minDur = total < kMinMotionMs ? 1 : kMinMotionMs;
  final maxDur = kMaxMotionMs < total ? kMaxMotionMs : total;
  var start = startMs;
  var end = endMs;
  if (start < 0) start = 0;
  if (end > total) end = total;
  if (end - start > maxDur) {
    end = start + maxDur;
    if (end > total) {
      end = total;
      start = end - maxDur;
      if (start < 0) start = 0;
    }
  }
  if (end - start < minDur) {
    end = start + minDur;
    if (end > total) {
      end = total;
      start = end - minDur;
      if (start < 0) start = 0;
    }
  }
  if (end <= start) end = start + 1;
  return (startMs: start, endMs: end);
}

({int startMs, int endMs}) moveClipStart({
  required int startMs,
  required int endMs,
  required int totalMs,
  required int nextStartMs,
}) {
  final total = totalMs < 1 ? 1 : totalMs;
  final minDur = total < kMinMotionMs ? 1 : kMinMotionMs;
  final maxDur = kMaxMotionMs < total ? kMaxMotionMs : total;
  var start = nextStartMs;
  if (start < 0) start = 0;
  if (start > endMs - minDur) start = endMs - minDur;
  if (start < endMs - maxDur) start = endMs - maxDur;
  if (start < 0) start = 0;
  return (startMs: start, endMs: endMs);
}

({int startMs, int endMs}) moveClipEnd({
  required int startMs,
  required int endMs,
  required int totalMs,
  required int nextEndMs,
}) {
  final total = totalMs < 1 ? 1 : totalMs;
  final minDur = total < kMinMotionMs ? 1 : kMinMotionMs;
  final maxDur = kMaxMotionMs < total ? kMaxMotionMs : total;
  var end = nextEndMs;
  if (end > total) end = total;
  if (end < startMs + minDur) end = startMs + minDur;
  if (end > startMs + maxDur) end = startMs + maxDur;
  if (end > total) end = total;
  return (startMs: startMs, endMs: end);
}

({int startMs, int endMs}) shiftClip({
  required int startMs,
  required int endMs,
  required int totalMs,
  required int deltaMs,
}) {
  final total = totalMs < 1 ? 1 : totalMs;
  var dur = endMs - startMs;
  if (dur < 1) dur = 1;
  if (dur > kMaxMotionMs) dur = kMaxMotionMs;
  if (dur > total) dur = total;
  var start = startMs + deltaMs;
  if (start < 0) start = 0;
  if (start + dur > total) start = total - dur;
  if (start < 0) start = 0;
  return (startMs: start, endMs: start + dur);
}

({int viewStartMs, int viewEndMs}) clipViewWindow({
  required int startMs,
  required int endMs,
  required int totalMs,
  int widthPx = 320,
}) {
  final total = totalMs < 1 ? 1 : totalMs;
  final dur = math.max(1, endMs - startMs);
  var view = (dur * 2.2).round();
  const minSelectionPx = 80;
  if (widthPx > minSelectionPx) {
    final needed = (dur * widthPx / minSelectionPx).round();
    if (view > needed) view = needed;
  }
  if (view < dur + 800) view = dur + 800;
  if (view > total) view = total;
  final center = startMs + dur / 2;
  var viewStart = (center - view / 2).round();
  if (viewStart < 0) viewStart = 0;
  if (viewStart + view > total) viewStart = total - view;
  if (viewStart < 0) viewStart = 0;
  return (viewStartMs: viewStart, viewEndMs: viewStart + view);
}

Uint8List jpegCardFrame(img.Image source, StillCrop crop) {
  return Uint8List.fromList(img.encodeJpg(cropToCard(source, crop), quality: kJpegQuality));
}

List<int> sampleTimesMs({required int startMs, required int endMs, int fps = kMotionFps}) {
  final duration = math.max(1, endMs - startMs);
  final count = math.max(1, (duration / 1000 * fps).ceil());
  return List<int>.generate(count, (i) {
    final t = startMs + (i * 1000 / fps).round();
    return math.min(endMs - 1, t);
  });
}

MotionResult muxJpegFrames(List<Uint8List> jpegs, MotionClip clip) {
  if (jpegs.isEmpty) throw StateError('No animation frames were produced.');
  return MotionResult(
    mp4: makeMjpegMp4(jpegs, width: kCardWidth, height: kCardHeight, fps: clip.fps),
    crop: clip.crop,
    startMs: clip.startMs,
    endMs: clip.endMs,
    frames: jpegs.length,
  );
}

MotionResult prepareGifMotion(GifSequence gif, MotionClip clip, {void Function(int progress)? onProgress}) {
  final window = clampClipWindow(startMs: clip.startMs, endMs: clip.endMs, totalMs: gif.totalMs);
  final times = sampleTimesMs(startMs: window.startMs, endMs: window.endMs, fps: clip.fps);
  final jpegs = <Uint8List>[];
  for (var i = 0; i < times.length; i++) {
    jpegs.add(jpegCardFrame(gif.frameAt(times[i]), clip.crop));
    onProgress?.call((((i + 1) / times.length) * 90).round());
  }
  return muxJpegFrames(jpegs, clip.copyWith(startMs: window.startMs, endMs: window.endMs));
}

Future<MotionResult> prepareMotion(
  Uint8List bytes, {
  required String name,
  String mime = '',
  String? path,
  MotionClip clip = const MotionClip(),
  void Function(int progress)? onProgress,
}) async {
  if (looksLikeGif(name, mime)) {
    return prepareGifMotion(decodeGifSequence(bytes), clip, onProgress: onProgress);
  }
  final probe = await probeVideo(bytes, path: path, mime: mime);
  final window = clampClipWindow(startMs: clip.startMs, endMs: clip.endMs, totalMs: probe.durationMs);
  final times = sampleTimesMs(startMs: window.startMs, endMs: window.endMs, fps: clip.fps);
  final rect = sourceRectFor(probe.width, probe.height, clip.crop);
  onProgress?.call(5);
  final jpegs = await extractCroppedJpegFrames(
    bytes,
    path: path,
    mime: mime,
    timesMs: times,
    sx: rect.sx,
    sy: rect.sy,
    sw: rect.sw,
    sh: rect.sh,
    onProgress: onProgress,
  );
  return muxJpegFrames(jpegs, clip.copyWith(startMs: window.startMs, endMs: window.endMs));
}
