import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monicard_super_app/crop_editor.dart';
import 'package:monicard_super_app/l10n.dart';
import 'package:monicard_super_app/media.dart';
import 'package:monicard_super_app/protocol.dart';

void main() {
  test('korean catalog has core keys', () {
    final s = S('ko');
    expect(s.t('appName'), 'MoniCard Super');
    expect(s.t('devices'), '기기');
    expect(s.t('connectTitle'), contains('MoniCard'));
    expect(s.t('cropTitle'), contains('240×320'));
    expect(s.t('cropUse'), isNotEmpty);
    expect(s.t('previewContinue'), '미리보기로 둘러보기');
    expect(s.t('previewEntered'), contains('Bluetooth'));
    expect(s.t('sectionDisplay'), '화면');
    expect(s.t('notConnected'), contains('연결'));
    expect(s.t('openSettings'), '설정');
    expect(s.t('motionTitle'), contains('240×320'));
    expect(s.t('passName'), '매직카드');
    expect(s.t('slogan'), '경계를 넘고, 취향을 잇다.');
    expect(s.t('quickConnect'), '바로 연결');
    expect(s.t('disconnectAction'), '연결 해제');
    expect(S('en').t('passName'), 'MAGIC CARD');
    expect(S('en').t('slogan'), contains('taste'));
    expect(S('ja').t('passName'), 'マジックカード');
    expect(S('zh').t('slogan'), contains('同好'));
    expect(S('ru').t('passName'), 'MAGIC CARD');
  });

  test('uuid reverse is 16-byte swap', () {
    expect(reverseUuid(Uuids.service).replaceAll('-', '').length, 32);
    expect(uuidMatches(reverseUuid(Uuids.service), Uuids.service), isTrue);
  });

  testWidgets('crop editor shows the 240×320 frame', (tester) async {
    final image = img.Image(width: 80, height: 120);
    img.fill(image, color: img.ColorRgb8(30, 40, 80));
    final source = loadCropSource(Uint8List.fromList(img.encodePng(image)));
    await tester.pumpWidget(
      MaterialApp(
        home: StillCropEditor(source: source, i18n: S('ko')),
      ),
    );
    expect(find.text('240×320에 맞추기'), findsOneWidget);
    expect(find.text('이 크롭 사용'), findsOneWidget);
    expect(find.text('240×320'), findsOneWidget);
  });
}
