import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

enum _ClipHit { start, end, body, playhead, track, none }

class ClipStrip extends StatefulWidget {
  const ClipStrip({
    super.key,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    required this.viewStartMs,
    required this.viewEndMs,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
    required this.onShift,
    required this.onPlayhead,
    required this.onViewChange,
    required this.format,
    this.thumbs = const [],
    this.onDragEnd,
  });

  final int totalMs;
  final int startMs;
  final int endMs;
  final int playheadMs;
  final int viewStartMs;
  final int viewEndMs;
  final bool enabled;
  final ValueChanged<int> onStart;
  final ValueChanged<int> onEnd;
  final ValueChanged<int> onShift;
  final ValueChanged<int> onPlayhead;
  final void Function(int viewStartMs, int viewEndMs) onViewChange;
  final VoidCallback? onDragEnd;
  final String Function(int ms) format;
  final List<Uint8List> thumbs;

  @override
  State<ClipStrip> createState() => _ClipStripState();
}

class _ClipStripState extends State<ClipStrip> {
  _ClipHit _hit = _ClipHit.none;
  double _lastX = 0;
  int _viewDur = 1;
  bool _moved = false;
  double _pinchDur = 1;
  int _pinchCenterMs = 0;

  int get _total => math.max(1, widget.totalMs);

  double _msToX(int ms, double width) {
    return ((ms - widget.viewStartMs) / math.max(1, widget.viewEndMs - widget.viewStartMs)) * width;
  }

  int _clampViewStart(int start, int dur) {
    var vs = start;
    if (vs < 0) vs = 0;
    if (vs + dur > _total) vs = _total - dur;
    if (vs < 0) vs = 0;
    return vs;
  }

  void _setView(int start, [int? dur]) {
    final length = dur ?? _viewDur;
    final vs = _clampViewStart(start, length);
    widget.onViewChange(vs, vs + length);
  }

  void _edgePan(double handleX, double width) {
    const edge = 44.0;
    if (handleX < edge) {
      final t = ((edge - handleX) / edge).clamp(0.0, 1.0);
      _setView(widget.viewStartMs - (t * _viewDur * 0.045).round().clamp(1, _viewDur));
    } else if (handleX > width - edge) {
      final t = ((handleX - (width - edge)) / edge).clamp(0.0, 1.0);
      _setView(widget.viewStartMs + (t * _viewDur * 0.045).round().clamp(1, _viewDur));
    }
  }

  _ClipHit _hitTest(Offset local, double width) {
    final startX = _msToX(widget.startMs, width);
    final endX = _msToX(widget.endMs, width);
    final playX = _msToX(widget.playheadMs, width);
    const thumb = 28.0;
    if (endX - startX < 56) {
      if (local.dx <= (startX + endX) / 2) return _ClipHit.start;
      return _ClipHit.end;
    }
    if ((local.dx - startX).abs() <= thumb) return _ClipHit.start;
    if ((local.dx - endX).abs() <= thumb) return _ClipHit.end;
    if (local.dx >= startX && local.dx <= endX && (local.dx - playX).abs() <= 14) {
      return _ClipHit.playhead;
    }
    if (local.dx >= startX && local.dx <= endX) return _ClipHit.body;
    return _ClipHit.track;
  }

  void _onScaleStart(Offset local, double width, int pointers) {
    _lastX = local.dx;
    _moved = false;
    _viewDur = math.max(1, widget.viewEndMs - widget.viewStartMs);
    _pinchDur = _viewDur.toDouble();
    _pinchCenterMs = widget.viewStartMs + (local.dx / width * _viewDur).round();
    _hit = pointers >= 2 ? _ClipHit.none : _hitTest(local, width);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (details.pointerCount >= 2) {
      final next = zoomClipView(
        viewStartMs: widget.viewStartMs,
        viewEndMs: widget.viewEndMs,
        totalMs: _total,
        startMs: widget.startMs,
        endMs: widget.endMs,
        factor: (_pinchDur * details.scale) / math.max(1, widget.viewEndMs - widget.viewStartMs),
        aroundMs: _pinchCenterMs,
      );
      widget.onViewChange(next.viewStartMs, next.viewEndMs);
      _moved = true;
      return;
    }
    if (_hit == _ClipHit.none) return;
    final local = details.localFocalPoint;
    final dx = local.dx - _lastX;
    if (dx.abs() < 0.4) return;
    _lastX = local.dx;
    _moved = true;
    final deltaMs = (dx / width * _viewDur).round();
    if (deltaMs == 0 && _hit != _ClipHit.start && _hit != _ClipHit.end) return;

    switch (_hit) {
      case _ClipHit.start:
        final next = moveClipStart(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          nextStartMs: widget.startMs + deltaMs,
        );
        widget.onStart(next.startMs);
        _edgePan(_msToX(next.startMs, width), width);
        break;
      case _ClipHit.end:
        final next = moveClipEnd(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          nextEndMs: widget.endMs + deltaMs,
        );
        widget.onEnd(next.endMs);
        _edgePan(_msToX(next.endMs, width), width);
        break;
      case _ClipHit.body:
        final next = shiftClip(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          deltaMs: deltaMs,
        );
        widget.onShift(next.startMs - widget.startMs);
        _edgePan(_msToX((next.startMs + next.endMs) ~/ 2, width), width);
        break;
      case _ClipHit.playhead:
        widget.onPlayhead(
          (widget.playheadMs + deltaMs).clamp(widget.startMs, math.max(widget.startMs, widget.endMs - 1)),
        );
        break;
      case _ClipHit.track:
        _setView(widget.viewStartMs - deltaMs);
        break;
      case _ClipHit.none:
        break;
    }
  }

  void _onScaleEnd(double width) {
    final was = _hit;
    final jumped = !_moved && was == _ClipHit.track;
    _hit = _ClipHit.none;
    if (jumped) {
      final t = widget.viewStartMs + (_lastX / width * _viewDur).round();
      final dur = widget.endMs - widget.startMs;
      final target = t - dur ~/ 2;
      final next = shiftClip(startMs: widget.startMs, endMs: widget.endMs, totalMs: _total, deltaMs: target - widget.startMs);
      widget.onShift(next.startMs - widget.startMs);
      final view = clipViewWindow(startMs: next.startMs, endMs: next.endMs, totalMs: _total, widthPx: width.round());
      widget.onViewChange(view.viewStartMs, view.viewEndMs);
      widget.onDragEnd?.call();
      return;
    }
    widget.onDragEnd?.call();
  }

  void _onScroll(PointerScrollEvent event, double width) {
    if (!widget.enabled) return;
    _viewDur = math.max(1, widget.viewEndMs - widget.viewStartMs);
    if (event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()) {
      final deltaMs = (event.scrollDelta.dx / width * _viewDur).round();
      _setView(widget.viewStartMs + deltaMs);
      return;
    }
    final factor = event.scrollDelta.dy > 0 ? 1.12 : 0.88;
    final around = widget.viewStartMs + (_lastX <= 0 ? 0.5 : _lastX / width).clamp(0, 1) * _viewDur;
    final next = zoomClipView(
      viewStartMs: widget.viewStartMs,
      viewEndMs: widget.viewEndMs,
      totalMs: _total,
      startMs: widget.startMs,
      endMs: widget.endMs,
      factor: factor,
      aroundMs: around.round(),
    );
    widget.onViewChange(next.viewStartMs, next.viewEndMs);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) _onScroll(e, width);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: widget.enabled
                ? (d) => _onScaleStart(d.localFocalPoint, width, d.pointerCount)
                : null,
            onScaleUpdate: widget.enabled ? (d) => _onScaleUpdate(d, width) : null,
            onScaleEnd: widget.enabled ? (_) => _onScaleEnd(width) : null,
            child: SizedBox(
              height: 92,
              width: width,
              child: CustomPaint(
                foregroundPainter: _RangePainter(
                  totalMs: _total,
                  startMs: widget.startMs,
                  endMs: widget.endMs,
                  playheadMs: widget.playheadMs,
                  viewStartMs: widget.viewStartMs,
                  viewEndMs: widget.viewEndMs,
                  format: widget.format,
                ),
                child: widget.thumbs.isEmpty
                    ? const SizedBox.expand()
                    : Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 36),
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              for (final thumb in widget.thumbs)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.memory(
                                        thumb,
                                        fit: BoxFit.cover,
                                        height: 52,
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.low,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    required this.viewStartMs,
    required this.viewEndMs,
    required this.format,
  });

  final int totalMs;
  final int startMs;
  final int endMs;
  final int playheadMs;
  final int viewStartMs;
  final int viewEndMs;
  final String Function(int ms) format;

  @override
  void paint(Canvas canvas, Size size) {
    final viewDur = math.max(1, viewEndMs - viewStartMs);
    double xFor(int ms) => ((ms - viewStartMs) / viewDur) * size.width;
    final film = Rect.fromLTWH(0, 4, size.width, 52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(film, const Radius.circular(8)),
      Paint()..color = McColors.panel,
    );

    final sx = xFor(startMs).clamp(-24.0, size.width + 24);
    final ex = xFor(endMs).clamp(-24.0, size.width + 24);
    final px = xFor(playheadMs.clamp(startMs, math.max(startMs, endMs - 1)));

    final dim = Paint()..color = const Color(0x9908060F);
    if (sx > 0) canvas.drawRect(Rect.fromLTRB(0, film.top, sx, film.bottom), dim);
    if (ex < size.width) canvas.drawRect(Rect.fromLTRB(ex, film.top, size.width, film.bottom), dim);

    canvas.drawRRect(
      RRect.fromLTRBR(sx, film.top, ex, film.bottom, const Radius.circular(6)),
      Paint()
        ..color = McColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (px >= 0 && px <= size.width) {
      canvas.drawLine(
        Offset(px, film.top),
        Offset(px, film.bottom),
        Paint()
          ..color = McColors.ink
          ..strokeWidth = 1.5,
      );
    }

    _handle(canvas, Offset(sx, film.center.dy), left: true);
    _handle(canvas, Offset(ex, film.center.dy), left: false);

    _label(canvas, format(startMs), Offset(sx, film.bottom + 8), size.width, alignLeft: true);
    _label(canvas, format(endMs), Offset(ex, film.bottom + 8), size.width, alignLeft: false);
  }

  void _handle(Canvas canvas, Offset center, {required bool left}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 18, height: 36),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFFFF8DC));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = McColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final x = center.dx + (left ? 2 : -2);
    final paint = Paint()
      ..color = McColors.onAccent
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 2, center.dy - 8), Offset(x - 2, center.dy + 8), paint);
    canvas.drawLine(Offset(x + 2, center.dy - 8), Offset(x + 2, center.dy + 8), paint);
  }

  void _label(Canvas canvas, String text, Offset at, double width, {required bool alignLeft}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: McColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = alignLeft ? at.dx - 4 : at.dx - painter.width + 4;
    x = x.clamp(0.0, math.max(0.0, width - painter.width));
    painter.paint(canvas, Offset(x, at.dy));
  }

  @override
  bool shouldRepaint(covariant _RangePainter old) {
    return old.startMs != startMs ||
        old.endMs != endMs ||
        old.playheadMs != playheadMs ||
        old.viewStartMs != viewStartMs ||
        old.viewEndMs != viewEndMs ||
        old.totalMs != totalMs;
  }
}
