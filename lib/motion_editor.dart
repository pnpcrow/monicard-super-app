import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'clip_strip.dart';
import 'crop_editor.dart';
import 'l10n.dart';
import 'media.dart';
import 'motion.dart';
import 'motion_video.dart';
import 'theme.dart';

class MotionEditResult {
  const MotionEditResult({required this.mp4, required this.clip, required this.preview, required this.frames});
  final Uint8List mp4;
  final MotionClip clip;
  final Uint8List preview;
  final int frames;
}

Future<MotionEditResult?> showMotionEditor(
  BuildContext context, {
  required Uint8List bytes,
  required String name,
  required String mime,
  String? path,
  required S i18n,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE6080A10),
    builder: (context) {
      return const Center(
        child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: McColors.accent, strokeWidth: 3)),
      );
    },
  );
  await Future<void>.delayed(const Duration(milliseconds: 16));
  GifSequence? gif;
  VideoProbe? probe;
  Uint8List previewBytes;
  try {
    if (looksLikeGif(name, mime)) {
      gif = decodeGifSequence(bytes);
      previewBytes = Uint8List.fromList(img.encodeJpg(gif.frames.first, quality: 88));
    } else {
      probe = await probeVideo(bytes, path: path, mime: mime);
      previewBytes = await extractPreviewFrame(bytes, path: path, mime: mime, timeMs: 0);
    }
  } catch (error) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    rethrow;
  }
  if (!context.mounted) return null;
  Navigator.of(context, rootNavigator: true).pop();
  return showGeneralDialog<MotionEditResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xF2080A10),
    pageBuilder: (context, _, _) {
      return MotionCropEditor(
        bytes: bytes,
        name: name,
        mime: mime,
        path: path,
        i18n: i18n,
        gif: gif,
        probe: probe,
        previewBytes: previewBytes,
      );
    },
  );
}

class MotionCropEditor extends StatefulWidget {
  const MotionCropEditor({
    super.key,
    required this.bytes,
    required this.name,
    required this.mime,
    required this.i18n,
    required this.previewBytes,
    this.path,
    this.gif,
    this.probe,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
  final String? path;
  final S i18n;
  final GifSequence? gif;
  final VideoProbe? probe;
  final Uint8List previewBytes;

  @override
  State<MotionCropEditor> createState() => _MotionCropEditorState();
}

class _MotionCropEditorState extends State<MotionCropEditor> {
  late StillCrop crop;
  late CropSource source;
  late int startMs;
  late int endMs;
  late int viewStartMs;
  late int viewEndMs;
  StillCrop? _scaleBase;
  Offset _scaleFocal = Offset.zero;
  bool busy = false;
  bool grabbing = false;
  int progress = 0;
  int playheadMs = 0;
  int fps = kMotionFps;
  List<Uint8List> thumbs = [];
  Timer? _thumbTimer;
  int _thumbGen = 0;

  int get srcW => source.width;
  int get srcH => source.height;
  int get totalMs => widget.gif?.totalMs ?? widget.probe?.durationMs ?? 1000;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.previewBytes);
    source = CropSource(
      original: widget.previewBytes,
      preview: widget.previewBytes,
      width: widget.gif?.width ?? widget.probe?.width ?? decoded?.width ?? kCardWidth,
      height: widget.gif?.height ?? widget.probe?.height ?? decoded?.height ?? kCardHeight,
    );
    crop = clampStillCrop(const StillCrop(), srcW, srcH);
    final window = clampClipWindow(startMs: 0, endMs: math.min(totalMs, kMaxMotionMs), totalMs: totalMs);
    startMs = window.startMs;
    endMs = window.endMs;
    playheadMs = startMs;
    final view = clipViewWindow(startMs: startMs, endMs: endMs, totalMs: totalMs);
    viewStartMs = view.viewStartMs;
    viewEndMs = view.viewEndMs;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThumbs());
  }

  @override
  void dispose() {
    _thumbTimer?.cancel();
    super.dispose();
  }

  void _scheduleThumbs() {
    _thumbTimer?.cancel();
    _thumbTimer = Timer(const Duration(milliseconds: 160), _loadThumbs);
  }

  Future<void> _loadThumbs() async {
    const n = 10;
    final gen = ++_thumbGen;
    final span = math.max(1, viewEndMs - viewStartMs);
    final out = <Uint8List>[];
    for (var i = 0; i < n; i++) {
      final ms = (viewStartMs + ((i + 0.5) / n * span).round()).clamp(0, math.max(0, totalMs - 1)).toInt();
      try {
        if (widget.gif != null) {
          final frame = widget.gif!.frameAt(ms);
          final small = img.copyResize(frame, width: 48, height: 64);
          out.add(Uint8List.fromList(img.encodeJpg(small, quality: 48)));
        } else {
          out.add(await extractPreviewFrame(widget.bytes, path: widget.path, mime: widget.mime, timeMs: ms));
        }
      } catch (_) {
        break;
      }
      if (!mounted || gen != _thumbGen) return;
    }
    if (!mounted || gen != _thumbGen || out.isEmpty) return;
    setState(() => thumbs = out);
  }

  void _reframe() {
    final view = clipViewWindow(startMs: startMs, endMs: endMs, totalMs: totalMs);
    viewStartMs = view.viewStartMs;
    viewEndMs = view.viewEndMs;
  }

  void _apply(StillCrop next) {
    setState(() => crop = clampStillCrop(next, srcW, srcH));
  }

  void _reset() {
    final window = clampClipWindow(startMs: 0, endMs: math.min(totalMs, kMaxMotionMs), totalMs: totalMs);
    setState(() {
      crop = clampStillCrop(const StillCrop(), srcW, srcH);
      startMs = window.startMs;
      endMs = window.endMs;
      playheadMs = startMs;
      _reframe();
      fps = kMotionFps;
    });
    _scheduleThumbs();
  }

  void _onScaleStart(ScaleStartDetails details) {
    grabbing = true;
    _scaleBase = crop;
    _scaleFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double viewScale) {
    final base = _scaleBase ?? crop;
    if (details.pointerCount <= 1 && details.scale == 1) {
      _apply(base.copyWith(
        panX: base.panX + details.focalPointDelta.dx / viewScale,
        panY: base.panY + details.focalPointDelta.dy / viewScale,
      ));
      _scaleBase = crop;
      _scaleFocal = details.localFocalPoint;
      return;
    }
    _apply(zoomAround(
      current: base,
      nextZoom: base.zoom * details.scale,
      focalX: _scaleFocal.dx / viewScale,
      focalY: _scaleFocal.dy / viewScale,
      srcW: srcW,
      srcH: srcH,
    ));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    grabbing = false;
    _scaleBase = null;
  }

  void _wheelZoom(PointerScrollEvent event, double viewScale) {
    final factor = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
    _apply(zoomAround(
      current: crop,
      nextZoom: crop.zoom * factor,
      focalX: event.localPosition.dx / viewScale,
      focalY: event.localPosition.dy / viewScale,
      srcW: srcW,
      srcH: srcH,
    ));
  }

  void _sliderZoom(double value) {
    _apply(zoomAround(
      current: crop,
      nextZoom: value,
      focalX: kCardWidth / 2,
      focalY: kCardHeight / 2,
      srcW: srcW,
      srcH: srcH,
    ));
  }

  Future<void> _scrub(int ms) async {
    playheadMs = ms.clamp(startMs, math.max(startMs, endMs - 1));
    if (widget.gif != null) {
      final frame = widget.gif!.frameAt(playheadMs);
      setState(() {
        source = CropSource(
          original: widget.previewBytes,
          preview: Uint8List.fromList(img.encodeJpg(frame, quality: 80)),
          width: srcW,
          height: srcH,
        );
      });
      return;
    }
    try {
      final frame = await extractPreviewFrame(widget.bytes, path: widget.path, mime: widget.mime, timeMs: playheadMs);
      if (!mounted) return;
      setState(() {
        source = CropSource(original: widget.previewBytes, preview: frame, width: srcW, height: srcH);
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _keepPlayhead() {
    if (playheadMs < startMs || playheadMs >= endMs) playheadMs = startMs;
  }

  void _onStart(int ms) {
    final next = moveClipStart(startMs: startMs, endMs: endMs, totalMs: totalMs, nextStartMs: ms);
    setState(() {
      startMs = next.startMs;
      endMs = next.endMs;
      _keepPlayhead();
    });
  }

  void _onEnd(int ms) {
    final next = moveClipEnd(startMs: startMs, endMs: endMs, totalMs: totalMs, nextEndMs: ms);
    setState(() {
      startMs = next.startMs;
      endMs = next.endMs;
      _keepPlayhead();
    });
  }

  void _onShift(int delta) {
    final next = shiftClip(startMs: startMs, endMs: endMs, totalMs: totalMs, deltaMs: delta);
    setState(() {
      startMs = next.startMs;
      endMs = next.endMs;
      _keepPlayhead();
    });
  }

  void _onPlayhead(int ms) {
    setState(() => playheadMs = ms.clamp(startMs, math.max(startMs, endMs - 1)));
  }

  Future<void> _confirm() async {
    setState(() {
      busy = true;
      progress = 0;
    });
    try {
      final clip = MotionClip(crop: crop, startMs: startMs, endMs: endMs, fps: fps);
      final result = widget.gif != null
          ? prepareGifMotion(widget.gif!, clip, onProgress: (p) {
              if (mounted) setState(() => progress = p);
            })
          : await prepareMotion(
              widget.bytes,
              name: widget.name,
              mime: widget.mime,
              path: widget.path,
              clip: clip,
              onProgress: (p) {
                if (mounted) setState(() => progress = p);
              },
            );
      final preview = widget.gif != null
          ? Uint8List.fromList(img.encodeJpg(cropToCard(widget.gif!.frameAt(startMs), crop), quality: 85))
          : jpegCardFrame(img.decodeImage(source.preview) ?? img.Image(width: kCardWidth, height: kCardHeight), crop);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(MotionEditResult(
        mp4: result.mp4,
        clip: clip.copyWith(startMs: result.startMs, endMs: result.endMs),
        preview: preview,
        frames: result.frames,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  String _fmt(int ms) {
    final s = (ms / 1000).clamp(0, 999);
    return '${s.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.i18n;
    final lengthMs = endMs - startMs;
    return Material(
      color: McColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: busy ? null : () => Navigator.of(context, rootNavigator: true).pop(),
                    icon: const Icon(Icons.close, color: McColors.text),
                    tooltip: s.t('cancel'),
                  ),
                  Expanded(
                    child: Text(
                      s.t('motionTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                  ),
                  TextButton(onPressed: busy ? null : _reset, child: Text(s.t('cropReset'))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                s.t('motionHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: McColors.muted, height: 1.45, fontSize: 13),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final maxByWidth = math.max(0.0, box.maxWidth - 32);
                  final maxByHeight = box.maxHeight * kCardWidth / kCardHeight;
                  final displayW = math.max(160.0, math.min(kCardWidth.toDouble(), math.min(maxByWidth, maxByHeight)));
                  final displayH = displayW * kCardHeight / kCardWidth;
                  final viewScale = displayW / kCardWidth;
                  return Center(
                    child: CropViewport(
                      source: source,
                      crop: crop,
                      displayW: displayW,
                      displayH: displayH,
                      viewScale: viewScale,
                      grabbing: grabbing,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: (d) => _onScaleUpdate(d, viewScale),
                      onScaleEnd: _onScaleEnd,
                      onWheel: (e) => _wheelZoom(e, viewScale),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.t('zoom')}  ${crop.zoom.toStringAsFixed(2)}×', style: const TextStyle(color: McColors.muted, fontSize: 13)),
                  Slider(value: crop.zoom, min: kMinZoom, max: kMaxZoom, onChanged: busy ? null : _sliderZoom),
                  Text(
                    '${s.t('motionClip')}  ${_fmt(lengthMs)} / ${_fmt(math.min(totalMs, kMaxMotionMs))}',
                    style: const TextStyle(color: McColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ClipStrip(
                    totalMs: totalMs,
                    startMs: startMs,
                    endMs: endMs,
                    playheadMs: playheadMs,
                    viewStartMs: viewStartMs,
                    viewEndMs: viewEndMs,
                    enabled: !busy,
                    format: _fmt,
                    onStart: _onStart,
                    onEnd: _onEnd,
                    onShift: _onShift,
                    onPlayhead: (ms) {
                      _onPlayhead(ms);
                    },
                    onViewChange: (vs, ve) {
                      setState(() {
                        viewStartMs = vs;
                        viewEndMs = ve;
                      });
                      _scheduleThumbs();
                    },
                    onDragEnd: () => _scrub(playheadMs),
                    thumbs: thumbs,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        onPressed: busy
                            ? null
                            : () {
                                final next = zoomClipView(
                                  viewStartMs: viewStartMs,
                                  viewEndMs: viewEndMs,
                                  totalMs: totalMs,
                                  startMs: startMs,
                                  endMs: endMs,
                                  factor: 0.72,
                                );
                                setState(() {
                                  viewStartMs = next.viewStartMs;
                                  viewEndMs = next.viewEndMs;
                                });
                                _scheduleThumbs();
                              },
                        tooltip: s.t('motionZoomIn'),
                        icon: const Icon(Icons.zoom_in, color: McColors.text),
                      ),
                      IconButton(
                        onPressed: busy
                            ? null
                            : () {
                                final next = zoomClipView(
                                  viewStartMs: viewStartMs,
                                  viewEndMs: viewEndMs,
                                  totalMs: totalMs,
                                  startMs: startMs,
                                  endMs: endMs,
                                  factor: 1.35,
                                );
                                setState(() {
                                  viewStartMs = next.viewStartMs;
                                  viewEndMs = next.viewEndMs;
                                });
                                _scheduleThumbs();
                              },
                        tooltip: s.t('motionZoomOut'),
                        icon: const Icon(Icons.zoom_out, color: McColors.text),
                      ),
                      const Spacer(),
                      Text(s.t('motionFps'), style: const TextStyle(color: McColors.muted, fontSize: 13)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final value in kMotionFpsChoices)
                        ChoiceChip(
                          label: Text('$value FPS'),
                          selected: fps == value,
                          showCheckmark: false,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => fps = value),
                          selectedColor: McColors.accent,
                          labelStyle: TextStyle(
                            color: fps == value ? McColors.onAccent : McColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          backgroundColor: McColors.panel,
                          side: BorderSide(color: fps == value ? McColors.accent : McColors.line),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('motionSize', {
                      'size': formatMotionEstimate(durationMs: lengthMs, fps: fps),
                    }),
                    style: const TextStyle(color: McColors.muted, fontSize: 12, height: 1.35),
                  ),
                  Text(s.t('motionFpsHint'), style: const TextStyle(color: McColors.muted, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(s.t('motionClipHint'), style: const TextStyle(color: McColors.muted, fontSize: 12, height: 1.35)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : _confirm,
                      child: busy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: McColors.ink)),
                                const SizedBox(width: 10),
                                Text(s.t('motionPreparing', {'p': '$progress'})),
                              ],
                            )
                          : Text(s.t('motionUse')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
