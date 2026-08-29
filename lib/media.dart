import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const kCardWidth = 240;
const kCardHeight = 320;
const kMinZoom = 1.0;
const kMaxZoom = 4.0;

class StillCrop {
  const StillCrop({this.zoom = 1, this.panX = 0, this.panY = 0});

  final double zoom;
  final double panX;
  final double panY;

  StillCrop copyWith({double? zoom, double? panX, double? panY}) {
    return StillCrop(
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
    );
  }
}

class CropSource {
  const CropSource({
    required this.original,
    required this.preview,
    required this.width,
    required this.height,
  });

  final Uint8List original;
  final Uint8List preview;
  final int width;
  final int height;
}

class StillCropResult {
  const StillCropResult({required this.png, required this.crop});

  final Uint8List png;
  final StillCrop crop;
}

double coverScale(int srcW, int srcH) {
  if (srcW <= 0 || srcH <= 0) return 1;
  return math.max(kCardWidth / srcW, kCardHeight / srcH);
}

({double x, double y}) panExtent(int srcW, int srcH, double zoom) {
  final scale = coverScale(srcW, srcH) * zoom.clamp(kMinZoom, kMaxZoom);
  return (
    x: math.max(0, (srcW * scale - kCardWidth) / 2),
    y: math.max(0, (srcH * scale - kCardHeight) / 2),
  );
}

StillCrop clampStillCrop(StillCrop crop, int srcW, int srcH) {
  final z = crop.zoom.clamp(kMinZoom, kMaxZoom);
  final lim = panExtent(srcW, srcH, z);
  return StillCrop(
    zoom: z,
    panX: crop.panX.clamp(-lim.x, lim.x),
    panY: crop.panY.clamp(-lim.y, lim.y),
  );
}

StillCrop zoomAround({
  required StillCrop current,
  required double nextZoom,
  required double focalX,
  required double focalY,
  required int srcW,
  required int srcH,
}) {
  final z0 = current.zoom.clamp(kMinZoom, kMaxZoom);
  final z1 = nextZoom.clamp(kMinZoom, kMaxZoom);
  final cover = coverScale(srcW, srcH);
  final oldScale = cover * z0;
  final newScale = cover * z1;
  if (oldScale <= 0 || newScale <= 0) {
    return clampStillCrop(current.copyWith(zoom: z1), srcW, srcH);
  }
  final startLeft = kCardWidth / 2 - srcW * oldScale / 2 + current.panX;
  final startTop = kCardHeight / 2 - srcH * oldScale / 2 + current.panY;
  final srcX = (focalX - startLeft) / oldScale;
  final srcY = (focalY - startTop) / oldScale;
  final newLeft = focalX - srcX * newScale;
  final newTop = focalY - srcY * newScale;
  return clampStillCrop(
    StillCrop(
      zoom: z1,
      panX: newLeft - (kCardWidth / 2 - srcW * newScale / 2),
      panY: newTop - (kCardHeight / 2 - srcH * newScale / 2),
    ),
    srcW,
    srcH,
  );
}

img.Image decodeOriented(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode the image.');
  }
  return img.bakeOrientation(decoded);
}

CropSource loadCropSource(Uint8List bytes) {
  final oriented = decodeOriented(bytes);
  var preview = oriented;
  const maxSide = 1600;
  if (oriented.width > maxSide || oriented.height > maxSide) {
    preview = oriented.width >= oriented.height
        ? img.copyResize(oriented, width: maxSide, interpolation: img.Interpolation.linear)
        : img.copyResize(oriented, height: maxSide, interpolation: img.Interpolation.linear);
  }
  return CropSource(
    original: bytes,
    preview: Uint8List.fromList(img.encodeJpg(preview, quality: 88)),
    width: oriented.width,
    height: oriented.height,
  );
}

img.Image cropToCard(img.Image decoded, StillCrop crop) {
  final rect = sourceRectFor(decoded.width, decoded.height, crop);
  final cropped = img.copyCrop(
    decoded,
    x: rect.sx,
    y: rect.sy,
    width: rect.sw,
    height: rect.sh,
  );
  return img.copyResize(
    cropped,
    width: kCardWidth,
    height: kCardHeight,
    interpolation: img.Interpolation.cubic,
  );
}

({int sx, int sy, int sw, int sh}) sourceRectFor(int srcW, int srcH, StillCrop crop) {
  final applied = clampStillCrop(crop, srcW, srcH);
  final scale = coverScale(srcW, srcH) * applied.zoom;
  final left = kCardWidth / 2 - srcW * scale / 2 + applied.panX;
  final top = kCardHeight / 2 - srcH * scale / 2 + applied.panY;
  var sx = (-left / scale).round();
  var sy = (-top / scale).round();
  var sw = math.max(1, (kCardWidth / scale).round());
  var sh = math.max(1, (kCardHeight / scale).round());
  if (sx < 0) {
    sw += sx;
    sx = 0;
  }
  if (sy < 0) {
    sh += sy;
    sy = 0;
  }
  if (sx + sw > srcW) sw = srcW - sx;
  if (sy + sh > srcH) sh = srcH - sy;
  sw = sw.clamp(1, srcW);
  sh = sh.clamp(1, srcH);
  sx = sx.clamp(0, srcW - sw);
  sy = sy.clamp(0, srcH - sh);
  return (sx: sx, sy: sy, sw: sw, sh: sh);
}

Uint8List prepareStill(
  Uint8List bytes, {
  double zoom = 1,
  double panX = 0,
  double panY = 0,
  StillCrop? crop,
}) {
  final decoded = decodeOriented(bytes);
  final applied = crop ?? StillCrop(zoom: zoom, panX: panX, panY: panY);
  return Uint8List.fromList(img.encodePng(cropToCard(decoded, applied)));
}

bool looksLikeGif(String name, String mime) {
  final n = name.toLowerCase();
  final m = mime.toLowerCase();
  return m == 'image/gif' || m == 'gif' || n.endsWith('.gif');
}

bool looksLikeMotion(String name, String mime) {
  final n = name.toLowerCase();
  final m = mime.toLowerCase();
  return looksLikeGif(name, mime) ||
      m.startsWith('video/') ||
      n.endsWith('.mp4') ||
      n.endsWith('.mov') ||
      n.endsWith('.m4v') ||
      n.endsWith('.webm');
}

String deviceResourceName({required bool motion}) {
  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  return motion ? 'v$suffix.mp4' : 'c$suffix.png';
}
