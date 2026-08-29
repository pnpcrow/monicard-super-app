import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'media.dart';
import 'theme.dart';

Future<StillCropResult?> showStillCropEditor(
  BuildContext context, {
  required Uint8List bytes,
  required S i18n,
  StillCrop initial = const StillCrop(),
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE6080A10),
    builder: (context) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: McColors.accent, strokeWidth: 3),
        ),
      );
    },
  );
  await Future<void>.delayed(const Duration(milliseconds: 16));
  late CropSource source;
  try {
    source = loadCropSource(bytes);
  } catch (error) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    rethrow;
  }
  if (!context.mounted) return null;
  Navigator.of(context, rootNavigator: true).pop();
  return showGeneralDialog<StillCropResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xF2080A10),
    pageBuilder: (context, animation, secondary) {
      return StillCropEditor(source: source, i18n: i18n, initial: initial);
    },
  );
}

class StillCropEditor extends StatefulWidget {
  const StillCropEditor({
    super.key,
    required this.source,
    required this.i18n,
    this.initial = const StillCrop(),
  });

  final CropSource source;
  final S i18n;
  final StillCrop initial;

  @override
  State<StillCropEditor> createState() => _StillCropEditorState();
}

class _StillCropEditorState extends State<StillCropEditor> {
  late StillCrop crop;
  StillCrop? _scaleBase;
  Offset _scaleFocal = Offset.zero;
  bool busy = false;
  bool grabbing = false;

  int get srcW => widget.source.width;
  int get srcH => widget.source.height;

  @override
  void initState() {
    super.initState();
    crop = clampStillCrop(widget.initial, srcW, srcH);
  }

  void _apply(StillCrop next) {
    setState(() => crop = clampStillCrop(next, srcW, srcH));
  }

  void _reset() => _apply(const StillCrop());

  void _onScaleStart(ScaleStartDetails details) {
    _scaleBase = crop;
    _scaleFocal = details.localFocalPoint;
    setState(() => grabbing = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double viewScale) {
    final base = _scaleBase ?? crop;
    final baseFocal = Offset(_scaleFocal.dx / viewScale, _scaleFocal.dy / viewScale);
    final focal = Offset(details.localFocalPoint.dx / viewScale, details.localFocalPoint.dy / viewScale);
    final nextZoom = (base.zoom * details.scale).clamp(kMinZoom, kMaxZoom);
    final zoomed = zoomAround(
      current: base,
      nextZoom: nextZoom,
      focalX: baseFocal.dx,
      focalY: baseFocal.dy,
      srcW: srcW,
      srcH: srcH,
    );
    _apply(zoomed.copyWith(
      panX: zoomed.panX + (focal.dx - baseFocal.dx),
      panY: zoomed.panY + (focal.dy - baseFocal.dy),
    ));
  }


  void _onScaleEnd(ScaleEndDetails details) {
    _scaleBase = null;
    setState(() => grabbing = false);
  }

  void _sliderZoom(double next) {
    _apply(zoomAround(
      current: crop,
      nextZoom: next,
      focalX: kCardWidth / 2,
      focalY: kCardHeight / 2,
      srcW: srcW,
      srcH: srcH,
    ));
  }

  void _wheelZoom(PointerScrollEvent event, double viewScale) {
    final factor = event.scrollDelta.dy > 0 ? 0.94 : 1.06;
    final next = (crop.zoom * factor).clamp(kMinZoom, kMaxZoom);
    _apply(zoomAround(
      current: crop,
      nextZoom: next,
      focalX: event.localPosition.dx / viewScale,
      focalY: event.localPosition.dy / viewScale,
      srcW: srcW,
      srcH: srcH,
    ));
  }

  Future<void> _confirm() async {
    if (busy) return;
    setState(() => busy = true);
    await Future<void>.delayed(Duration.zero);
    try {
      final png = prepareStill(widget.source.original, crop: crop);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(StillCropResult(png: png, crop: crop));
    } catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.i18n;
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
                      s.t('cropTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _reset,
                    child: Text(s.t('cropReset')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                s.t('cropHint'),
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
                      source: widget.source,
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.t('zoom')}  ${crop.zoom.toStringAsFixed(2)}×',
                    style: const TextStyle(color: McColors.muted, fontSize: 13),
                  ),
                  Slider(
                    value: crop.zoom,
                    min: kMinZoom,
                    max: kMaxZoom,
                    onChanged: busy ? null : _sliderZoom,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : _confirm,
                      child: busy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: McColors.ink),
                                ),
                                const SizedBox(width: 10),
                                Text(s.t('cropPreparing')),
                              ],
                            )
                          : Text(s.t('cropUse')),
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

class CropViewport extends StatelessWidget {
  const CropViewport({
    super.key,
    required this.source,
    required this.crop,
    required this.displayW,
    required this.displayH,
    required this.viewScale,
    required this.grabbing,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onWheel,
  });

  final CropSource source;
  final StillCrop crop;
  final double displayW;
  final double displayH;
  final double viewScale;
  final bool grabbing;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;
  final void Function(PointerScrollEvent event) onWheel;

  @override
  Widget build(BuildContext context) {
    final scale = coverScale(source.width, source.height) * crop.zoom;
    final imgW = source.width * scale * viewScale;
    final imgH = source.height * scale * viewScale;
    final left = (kCardWidth / 2 - source.width * scale / 2 + crop.panX) * viewScale;
    final top = (kCardHeight / 2 - source.height * scale / 2 + crop.panY) * viewScale;
    return MouseRegion(
      cursor: grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) onWheel(event);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onScaleEnd: onScaleEnd,
          child: SizedBox(
            width: displayW,
            height: displayH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const ColoredBox(color: Color(0xFF090C11), child: SizedBox.expand()),
                  Positioned(
                    left: left,
                    top: top,
                    width: imgW,
                    height: imgH,
                    child: Image.memory(
                      source.preview,
                      width: imgW,
                      height: imgH,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                  const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: ViewfinderPainter()))),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCC080A10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: McColors.line),
                      ),
                      child: const Text(
                        '240×320',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: McColors.accent, letterSpacing: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  const ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0x66F3EB28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)), border);

    final mark = Paint()
      ..color = McColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.square;
    const inset = 10.0;
    const arm = 22.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * arm, y), mark);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * arm), mark);
    }

    corner(inset, inset, 1, 1);
    corner(size.width - inset, inset, -1, 1);
    corner(inset, size.height - inset, 1, -1);
    corner(size.width - inset, size.height - inset, -1, -1);

    final thirds = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), thirds);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), thirds);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), thirds);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), thirds);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
