import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monicard_super_app/media.dart';
import 'package:monicard_super_app/mjpeg.dart';
import 'package:monicard_super_app/motion.dart';

Uint8List _gif() {
  final encoder = img.GifEncoder();
  final first = img.Image(width: 80, height: 40);
  img.fill(first, color: img.ColorRgb8(255, 0, 0));
  encoder.addFrame(first, duration: 10);
  final second = img.Image(width: 80, height: 40);
  img.fill(second, color: img.ColorRgb8(0, 0, 255));
  encoder.addFrame(second, duration: 10);
  return encoder.finish()!;
}

void main() {
  test('mjpeg mp4 contains ftyp and mdat', () {
    final frame = img.Image(width: 240, height: 320);
    img.fill(frame, color: img.ColorRgb8(20, 30, 40));
    final jpeg = Uint8List.fromList(img.encodeJpg(frame, quality: 82));
    final mp4 = makeMjpegMp4([jpeg, jpeg], width: 240, height: 320, fps: 20);
    expect(ascii.decode(mp4.sublist(4, 8)), 'ftyp');
    expect(mp4.length, greaterThan(jpeg.length * 2));
  });

  test('clip window caps at 10 seconds', () {
    final window = clampClipWindow(startMs: 0, endMs: 20000, totalMs: 30000);
    expect(window.endMs - window.startMs, kMaxMotionMs);
  });

  test('moving start does not drag the end', () {
    final moved = moveClipStart(startMs: 0, endMs: 10000, totalMs: 30000, nextStartMs: 4000);
    expect(moved.startMs, 4000);
    expect(moved.endMs, 10000);
  });

  test('moving end does not drag the start', () {
    final moved = moveClipEnd(startMs: 5000, endMs: 15000, totalMs: 30000, nextEndMs: 22000);
    expect(moved.startMs, 5000);
    expect(moved.endMs, 15000);
  });

  test('shift keeps duration and stays in bounds', () {
    final moved = shiftClip(startMs: 0, endMs: 10000, totalMs: 30000, deltaMs: 5000);
    expect(moved.startMs, 5000);
    expect(moved.endMs, 15000);
    final clamped = shiftClip(startMs: 0, endMs: 10000, totalMs: 30000, deltaMs: 50000);
    expect(clamped.endMs, 30000);
    expect(clamped.endMs - clamped.startMs, 10000);
  });

  test('zoomed view keeps a long clip selectable', () {
    final view = clipViewWindow(startMs: 0, endMs: 10000, totalMs: 300000, widthPx: 320);
    expect(view.viewEndMs - view.viewStartMs, lessThan(300000));
    expect(view.viewEndMs - view.viewStartMs, greaterThan(10000));
  });

  test('gif motion is 240×320 mjpeg', () async {
    final gif = decodeGifSequence(_gif());
    expect(gif.frames.length, greaterThanOrEqualTo(2));
    final result = await prepareGifMotion(gif, const MotionClip(endMs: 200));
    expect(ascii.decode(result.mp4.sublist(4, 8)), 'ftyp');
    expect(result.frames, greaterThan(0));
    final card = cropToCard(gif.frames.first, const StillCrop());
    expect(card.width, kCardWidth);
    expect(card.height, kCardHeight);
  });

  test('lower fps samples fewer frames', () {
    final fast = sampleTimesMs(startMs: 0, endMs: 10000, fps: 20);
    final slow = sampleTimesMs(startMs: 0, endMs: 10000, fps: 5);
    expect(fast.length, 200);
    expect(slow.length, 50);
    expect(estimateMotionKb(durationMs: 10000, fps: 5) * 4, estimateMotionKb(durationMs: 10000, fps: 20));
  });

  test('timeline zoom keeps the clip in view', () {
    final zoomed = zoomClipView(
      viewStartMs: 0,
      viewEndMs: 30000,
      totalMs: 30000,
      startMs: 0,
      endMs: 10000,
      factor: 0.5,
    );
    expect(zoomed.viewEndMs - zoomed.viewStartMs, lessThan(30000));
    expect(zoomed.viewEndMs - zoomed.viewStartMs, greaterThanOrEqualTo(10000));
  });
}
