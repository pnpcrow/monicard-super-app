import 'package:flutter_test/flutter_test.dart';
import 'package:monicard_super_app/l10n.dart';
import 'package:monicard_super_app/protocol.dart';

void main() {
  test('korean catalog has core keys', () {
    final s = S('ko');
    expect(s.t('appName'), 'MoniCard Super');
    expect(s.t('devices'), '기기');
    expect(s.t('connectTitle'), contains('MoniCard'));
  });

  test('uuid reverse is 16-byte swap', () {
    expect(reverseUuid(Uuids.service).replaceAll('-', '').length, 32);
    expect(uuidMatches(reverseUuid(Uuids.service), Uuids.service), isTrue);
  });
}
