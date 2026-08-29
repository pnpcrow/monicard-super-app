import 'dart:math' as math;

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

  @override
  State<ClipStrip> createState() => _ClipStripState();
}

class _ClipStripState extends State<ClipStrip> {
  _ClipHit _hit = _ClipHit.none;
  double _lastX = 0;
  int _viewDur = 1;
  bool _moved = false;

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

  void _setView(int start) {
    final dur = _viewDur;
    final vs = _clampViewStart(start, dur);
    widget.onViewChange(vs, vs + dur);
  }

  _ClipHit _hitTest(Offset local, double width) {
    final startX = _msToX(widget.startMs, width);
    final endX = _msToX(widget.endMs, width);
    final playX = _msToX(widget.playheadMs, width);
    const thumb = 24.0;
    if ((local.dx - startX).abs() <= thumb) return _ClipHit.start;
    if ((local.dx - endX).abs() <= thumb) return _ClipHit.end;
    if (local.dx >= startX && local.dx <= endX && (local.dx - playX).abs() <= 12) {
      return _ClipHit.playhead;
    }
    if (local.dx >= startX && local.dx <= endX) return _ClipHit.body;
    return _ClipHit.track;
  }

  void _onDown(Offset local, double width) {
    _hit = _hitTest(local, width);
    _lastX = local.dx;
    _moved = false;
    _viewDur = math.max(1, widget.viewEndMs - widget.viewStartMs);
  }

  void _onDrag(Offset local, double width) {
    if (_hit == _ClipHit.none) return;
    final dx = local.dx - _lastX;
    if (dx.abs() < 0.5) return;
    _lastX = local.dx;
    _moved = true;
    final deltaMs = (dx / width * _viewDur).round();
    if (deltaMs == 0) return;

    switch (_hit) {
      case _ClipHit.start:
        final next = moveClipStart(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          nextStartMs: widget.startMs + deltaMs,
        );
        final applied = next.startMs - widget.startMs;
        widget.onStart(next.startMs);
        _setView(widget.viewStartMs + applied);
        break;
      case _ClipHit.end:
        final next = moveClipEnd(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          nextEndMs: widget.endMs + deltaMs,
        );
        final applied = next.endMs - widget.endMs;
        widget.onEnd(next.endMs);
        _setView(widget.viewStartMs + applied);
        break;
      case _ClipHit.body:
        final next = shiftClip(
          startMs: widget.startMs,
          endMs: widget.endMs,
          totalMs: _total,
          deltaMs: deltaMs,
        );
        final applied = next.startMs - widget.startMs;
        widget.onShift(applied);
        _setView(widget.viewStartMs + applied);
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

  void _onEnd(double width) {
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
      return;
    }
    if (was == _ClipHit.start || was == _ClipHit.end || was == _ClipHit.body) {
      final view = clipViewWindow(
        startMs: widget.startMs,
        endMs: widget.endMs,
        totalMs: _total,
        widthPx: width.round(),
      );
      final frac = (widget.endMs - widget.startMs) / math.max(1, widget.viewEndMs - widget.viewStartMs);
      if (frac < 0.28 || frac > 0.78) {
        widget.onViewChange(view.viewStartMs, view.viewEndMs);
      }
    }
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.enabled ? (d) => _onDown(d.localPosition, width) : null,
          onPanUpdate: widget.enabled ? (d) => _onDrag(d.localPosition, width) : null,
          onPanEnd: widget.enabled ? (_) => _onEnd(width) : null,
          onPanCancel: widget.enabled ? () => _onEnd(width) : null,
          child: SizedBox(
            height: 72,
            width: width,
            child: CustomPaint(
              painter: _RangePainter(
                totalMs: _total,
                startMs: widget.startMs,
                endMs: widget.endMs,
                playheadMs: widget.playheadMs,
                viewStartMs: widget.viewStartMs,
                viewEndMs: widget.viewEndMs,
                format: widget.format,
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
    final trackY = 22.0;
    final track = Rect.fromLTWH(0, trackY, size.width, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(99)),
      Paint()..color = McColors.panel,
    );

    _ticks(canvas, size, trackY);

    final sx = xFor(startMs).clamp(-20.0, size.width + 20);
    final ex = xFor(endMs).clamp(-20.0, size.width + 20);
    final px = xFor(playheadMs.clamp(startMs, math.max(startMs, endMs - 1)));

    canvas.drawRRect(
      RRect.fromLTRBR(sx, trackY, ex, trackY + 8, const Radius.circular(99)),
      Paint()..color = McColors.accent,
    );

    if (px >= 0 && px <= size.width) {
      canvas.drawCircle(Offset(px, trackY + 4), 3, Paint()..color = McColors.ink);
    }

    _thumb(canvas, Offset(sx, trackY + 4));
    _thumb(canvas, Offset(ex, trackY + 4));

    _label(canvas, format(startMs), Offset(sx, trackY + 22), size.width, alignLeft: true);
    _label(canvas, format(endMs), Offset(ex, trackY + 22), size.width, alignLeft: false);
  }

  void _ticks(Canvas canvas, Size size, double trackY) {
    final viewDur = math.max(1, viewEndMs - viewStartMs);
    var step = 1000;
    if (viewDur > 60000) {
      step = 10000;
    } else if (viewDur > 20000) {
      step = 5000;
    }
    final paint = Paint()..color = McColors.line;
    final first = (viewStartMs / step).ceil() * step;
    for (var t = first; t <= viewEndMs; t += step) {
      final x = ((t - viewStartMs) / viewDur) * size.width;
      canvas.drawLine(Offset(x, trackY - 8), Offset(x, trackY - 2), paint);
    }
  }

  void _thumb(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xFFF2F2F7));
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFFFFF8DC));
    canvas.drawCircle(center, 4, Paint()..color = McColors.accent);
  }

  void _label(Canvas canvas, String text, Offset at, double width, {required bool alignLeft}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: McColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
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