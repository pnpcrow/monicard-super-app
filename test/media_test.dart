import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monicard_super_app/media.dart';

Uint8List _png(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _split(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x < w / 2) {
        image.setPixelRgba(x, y, 255, 0, 0, 255);
      } else {
        image.setPixelRgba(x, y, 0, 0, 255, 255);
      }
    }
  }
  return image;
}

void main() {
  test('prepareStill always emits 240×320 png', () {
    final bytes = _png(_split(800, 400));
    final out = prepareStill(bytes);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, kCardWidth);
    expect(decoded.height, kCardHeight);
  });

  test('cover pan is horizontal-only for a wide source', () {
    final extent = panExtent(400, 200, 1);
    expect(extent.x, greaterThan(0));
    expect(extent.y, 0);
  });

  test('pan changes which side of a wide image is kept', () {
    final bytes = _png(_split(400, 200));
    final left = img.decodeImage(prepareStill(bytes, panX: 200))!;
    final right = img.decodeImage(prepareStill(bytes, panX: -200))!;
    final leftPx = left.getPixel(8, 8);
    final rightPx = right.getPixel(8, 8);
    expect(leftPx.r, greaterThan(200));
    expect(leftPx.b, lessThan(50));
    expect(rightPx.b, greaterThan(200));
    expect(rightPx.r, lessThan(50));
  });

  test('zoom 2 crops a smaller region than cover', () {
    final cover = clampStillCrop(const StillCrop(), 400, 200);
    final tight = clampStillCrop(const StillCrop(zoom: 2), 400, 200);
    expect(cover.zoom, 1);
    expect(tight.zoom, 2);
    expect(panExtent(400, 200, 2).x, greaterThan(panExtent(400, 200, 1).x));
  });

  test('zoomAround at the center keeps pan at zero', () {
    final next = zoomAround(
      current: const StillCrop(),
      nextZoom: 2,
      focalX: kCardWidth / 2,
      focalY: kCardHeight / 2,
      srcW: 400,
      srcH: 200,
    );
    expect(next.zoom, 2);
    expect(next.panX, closeTo(0, 0.001));
    expect(next.panY, closeTo(0, 0.001));
  });

  test('loadCropSource reports oriented dimensions', () {
    final bytes = _png(_split(320, 240));
    final source = loadCropSource(bytes);
    expect(source.width, 320);
    expect(source.height, 240);
    expect(source.preview, isNotEmpty);
  });
}
