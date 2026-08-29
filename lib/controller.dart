import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble/ble.dart';
import 'l10n.dart';
import 'protocol.dart';
import 'tags.dart';
import 'transfer.dart';

class DeviceSnapshot {
  DeviceSnapshot({
    this.id,
    this.name = 'MoniCard',
    this.connected = false,
    this.serial,
    this.firmwareVersion,
    this.battery,
    this.storage,
    this.freeBytes,
  });

  String? id;
  String name;
  bool connected;
  String? serial;
  String? firmwareVersion;
  int? battery;
  String? storage;
  int? freeBytes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connected': false,
        'serial': serial,
        'firmwareVersion': firmwareVersion,
        'battery': battery,
        'storage': storage,
        'freeBytes': freeBytes,
      };

  static DeviceSnapshot? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return DeviceSnapshot(
      id: raw['id']?.toString(),
      name: raw['name']?.toString() ?? 'MoniCard',
      serial: raw['serial']?.toString(),
      firmwareVersion: raw['firmwareVersion']?.toString(),
      battery: raw['battery'] is int ? raw['battery'] as int : int.tryParse('${raw['battery']}'),
      storage: raw['storage']?.toString(),
      freeBytes: raw['freeBytes'] is int ? raw['freeBytes'] as int : int.tryParse('${raw['freeBytes']}'),
    );
  }
}

class ControlSettings {
  ControlSettings({
    this.broadcast = true,
    this.buzzer = true,
    this.vibration = true,
    this.interestLight = true,
    this.interestScan = true,
    this.ambient = true,
    this.carousel = false,
    this.carouselSeconds = 5,
  });

  bool broadcast;
  bool buzzer;
  bool vibration;
  bool interestLight;
  bool interestScan;
  bool ambient;
  bool carousel;
  int carouselSeconds;

  Uint8List toBytes() => Uint8List.fromList([
        broadcast ? 1 : 0,
        buzzer ? 1 : 0,
        vibration ? 1 : 0,
        interestLight ? 1 : 0,
        interestScan ? 1 : 0,
        ambient ? 1 : 0,
        0,
        1,
      ]);

  void applyBytes(Uint8List bytes) {
    if (bytes.length < 8) return;
    broadcast = bytes[0] != 0;
    buzzer = bytes[1] != 0;
    vibration = bytes[2] != 0;
    interestLight = bytes[3] != 0;
    interestScan = bytes[4] != 0;
    ambient = bytes[5] != 0;
  }

  Map<String, dynamic> toJson() => {
        'broadcast': broadcast,
        'buzzer': buzzer,
        'vibration': vibration,
        'interestLight': interestLight,
        'interestScan': interestScan,
        'ambient': ambient,
        'carousel': carousel,
        'carouselSeconds': carouselSeconds,
      };

  static ControlSettings fromJson(dynamic raw) {
    final s = ControlSettings();
    if (raw is! Map) return s;
    s.broadcast = raw['broadcast'] != false;
    s.buzzer = raw['buzzer'] != false;
    s.vibration = raw['vibration'] != false;
    s.interestLight = raw['interestLight'] != false;
    s.interestScan = raw['interestScan'] != false;
    s.ambient = raw['ambient'] != false;
    s.carousel = raw['carousel'] == true;
    s.carouselSeconds = raw['carouselSeconds'] is int ? raw['carouselSeconds'] as int : 5;
    return s;
  }
}

class ReceivedCard {
  ReceivedCard({required this.title, required this.detail, required this.receivedAt});
  final String title;
  final String detail;
  final String receivedAt;
}

class LogLine {
  LogLine(this.time, this.message, [this.data]);
  final String time;
  final String message;
  final Object? data;
}

class AppController extends ChangeNotifier {
  AppController() {
    ble.onPacket = _onPacket;
    ble.onConnect = _onConnect;
    ble.onDisconnect = _onDisconnect;
  }

  final MoniCardBle ble = createBle();
  late final TransferController transfer = TransferController(ble);
  final S i18n = S('ko');
  SharedPreferences? _prefs;
  TagCatalog? catalog;

  String route = 'home';
  DeviceSnapshot? device;
  ControlSettings settings = ControlSettings();
  List<ReceivedCard> cards = [];
  final List<LogLine> logs = [];
  String profile = '';
  List<TagRef> selectedTags = [];
  String tagCategoryId = '';
  bool busy = false;
  bool connecting = false;
  bool lastConnectCancelled = false;
  String? toast;

  final Map<int, List<_Pending>> _pending = {};

  Future<void> boot() async {
    _prefs = await SharedPreferences.getInstance();
    final locale = _prefs?.getString('monicard-locale') ?? 'ko';
    i18n.locale = S.supported.contains(locale) ? locale : 'en';
    final deviceRaw = _prefs?.getString('monicard-device');
    if (deviceRaw != null) {
      try {
        device = DeviceSnapshot.fromJson(jsonDecode(deviceRaw));
      } catch (_) {}
    }
    final settingsRaw = _prefs?.getString('monicard-settings');
    if (settingsRaw != null) {
      try {
        settings = ControlSettings.fromJson(jsonDecode(settingsRaw));
      } catch (_) {}
    }
    profile = _prefs?.getString('monicard-card') ?? '';
    final tagRaw = _prefs?.getString('monicard-tag-ids');
    if (tagRaw != null) {
      try {
        final list = jsonDecode(tagRaw);
        if (list is List) {
          selectedTags = list
              .map((v) => v is String ? TagRef.parse(v) : null)
              .whereType<TagRef>()
              .take(Limits.tags)
              .toList();
        }
      } catch (_) {}
    }
    tagCategoryId = _prefs?.getString('monicard-tag-category-key') ?? '';
    catalog = await TagCatalog.load();
    log('MoniCard Super ready');
    notifyListeners();
    unawaited(_autoReconnect());
  }

  bool get hasSavedDevice =>
      device != null && device!.id != null && device!.id != 'preview';

  Future<void> _autoReconnect() async {
    if (kIsWeb) return;
    if (!hasSavedDevice || ble.connected || connecting) return;
    await connect(auto: true);
  }

  void go(String next) {
    route = next;
    notifyListeners();
  }

  bool get isHome => route == 'home';

  void back() {
    if (route.startsWith('card-detail/')) {
      go('received-cards');
      return;
    }
    if (route == 'diagnostics' || route == 'docs') {
      go('settings');
      return;
    }
    if (route != 'home') go('home');
  }

  String titleForRoute() {
    if (route.startsWith('card-detail/')) return i18n.t('cardDetails');
    switch (route) {
      case 'media-image':
        return i18n.t('image');
      case 'media-animation':
        return i18n.t('animation');
      case 'device-settings':
        return i18n.t('deviceControl');
      case 'card':
        return i18n.t('profile');
      case 'tags':
        return i18n.t('tags');
      case 'carousel':
        return i18n.t('carousel');
      case 'received-cards':
        return i18n.t('receivedCards');
      case 'device-info':
        return i18n.t('deviceInfo');
      case 'file-transfer':
        return i18n.t('fileTransfer');
      case 'ota-update':
        return i18n.t('otaUpdate');
      case 'settings':
        return i18n.t('appSettings');
      case 'diagnostics':
        return i18n.t('diagnostics');
      case 'docs':
        return i18n.t('documentation');
      default:
        return device?.name ?? i18n.t('appName');
    }
  }

  void setLocale(String code) {
    i18n.locale = S.supported.contains(code) ? code : 'en';
    _prefs?.setString('monicard-locale', i18n.locale);
    notifyListeners();
  }

  void persist() {
    if (device != null) {
      _prefs?.setString('monicard-device', jsonEncode(device!.toJson()));
    } else {
      _prefs?.remove('monicard-device');
    }
    _prefs?.setString('monicard-settings', jsonEncode(settings.toJson()));
    _prefs?.setString('monicard-card', profile);
    _prefs?.setString('monicard-tag-ids', jsonEncode(selectedTags.map((t) => t.key).toList()));
    _prefs?.setString('monicard-tag-category-key', tagCategoryId);
  }

  void log(String message, [Object? data]) {
    logs.insert(0, LogLine(_clock(), message, data));
    if (logs.length > 100) logs.removeLast();
    debugPrint('[MoniCard] $message ${data ?? ''}');
  }

  void showToast(String message) {
    toast = message;
    notifyListeners();
  }

  String _clock() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  void _onPacket(Uint8List raw) {
    if (transfer.handlePacket(raw)) {
      log('RX FILE/OTA packet');
      return;
    }
    final decoded = decodePacket(raw);
    log('RX packet', decoded == null ? raw : {'category': decoded.category, 'command': decoded.command});
    if (decoded == null) return;
    final queue = _pending[decoded.command];
    if (queue == null || queue.isEmpty) return;
    final item = queue.removeAt(0);
    item.timer.cancel();
    item.complete(decoded);
    if (queue.isEmpty) _pending.remove(decoded.command);
  }

  void _onConnect() {
    device = DeviceSnapshot(
      id: ble.deviceId ?? device?.id,
      name: ble.deviceName ?? device?.name ?? 'MoniCard',
      connected: true,
      serial: device?.serial,
      firmwareVersion: device?.firmwareVersion,
      battery: device?.battery,
      storage: device?.storage,
      freeBytes: device?.freeBytes,
    );
    persist();
    log('BLE connected');
    notifyListeners();
    refreshRuntime(silent: true).catchError((e) => log('Initial refresh failed', e.toString()));
  }

  void _onDisconnect() {
    device?.connected = false;
    for (final queue in _pending.values) {
      for (final item in queue) {
        item.timer.cancel();
        item.completeError(StateError('BLE disconnected'));
      }
    }
    _pending.clear();
    persist();
    log('BLE disconnected');
    notifyListeners();
  }

  Future<DecodedPacket> request(Uint8List bytes, int responseCommand, {Duration timeout = const Duration(seconds: 5)}) {
    late _Pending item;
    item = _Pending()
      ..timer = Timer(timeout, () {
        final q = _pending[responseCommand] ?? [];
        q.remove(item);
        item.completeError(StateError('Response timed out (command $responseCommand)'));
      });
    _pending.putIfAbsent(responseCommand, () => []).add(item);
    ble.send(bytes).catchError((e) {
      item.timer.cancel();
      item.completeError(e is Object ? e : StateError('$e'));
    });
    return item.future;
  }

  bool get previewDevice => device?.id == 'preview';

  Future<bool> connect({bool scan = false, bool auto = false}) async {
    if (connecting) return ble.connected;
    if (ble.connected && !scan) return true;
    lastConnectCancelled = false;
    connecting = true;
    notifyListeners();
    try {
      final id = device?.id;
      final useSaved = !kIsWeb && !scan && id != null && id != 'preview';
      await ble.connect(
        knownId: useSaved ? id : null,
        picker: scan || !useSaved,
        auto: auto,
      );
      return ble.connected;
    } catch (error) {
      if (auto) {
        log('auto reconnect skipped', error.toString());
        return false;
      }
      if (error is BleUnavailable) {
        if (scan || !hasSavedDevice) {
          enterPreview();
        }
        return false;
      }
      final text = error.toString();
      lastConnectCancelled = text.contains('NotFoundError') ||
          text.contains('cancelled') ||
          text.contains('AbortError');
      if (lastConnectCancelled) return false;
      if (!(hasSavedDevice && !scan)) {
        showToast(i18n.t('connectFailed', {'error': text}));
      }
      log('connect failed', text);
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  void enterPreview() {
    device = DeviceSnapshot(
      id: 'preview',
      name: i18n.t('previewDeviceName'),
      connected: false,
      firmwareVersion: i18n.t('previewFirmware'),
    );
    persist();
    log('preview device opened');
    showToast(i18n.t('previewEntered'));
  }

  Future<void> disconnect() => ble.disconnect();

  void updateProfile(String value) {
    profile = value;
    notifyListeners();
  }

  void clearSelectedTags() {
    selectedTags = [];
    persist();
    notifyListeners();
  }

  void saveLocalName() {
    persist();
    showToast(i18n.t('localOnlyName'));
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  void touch() {
    persist();
    notifyListeners();
  }

  void setTagCategory(String id) {
    tagCategoryId = id;
    persist();
    notifyListeners();
  }

  void forget() {
    ble.disconnect();
    device = null;
    persist();
    notifyListeners();
    go('home');
  }

  Future<bool> forgetAndScan() async {
    forget();
    return connect(scan: true);
  }

  Future<void> refreshRuntime({bool silent = false}) async {
    if (!ble.connected || busy) return;
    busy = true;
    notifyListeners();
    try {
      final serial = await _soft(request(getSerialNumber(), ControlCommand.respSerialNumber));
      final version = await _soft(request(getVersion(), ControlCommand.respVersion));
      final battery = await _soft(request(getBattery(), ControlCommand.respBattery));
      final fs = await _soft(request(getFileSystemInfo(), ControlCommand.getFsInfoResponse));
      final controls = await _soft(request(readControlInfo(), ControlCommand.controlInfoResponse));
      final carousel = await _soft(request(readCarousel(), ControlCommand.respCarouselRd));
      final card = await _soft(request(readCardInfo(), ControlCommand.respReadCard));
      device ??= DeviceSnapshot(connected: true);
      device!.connected = true;
      if (serial != null) device!.serial = decodeText(serial.data);
      if (version != null) device!.firmwareVersion = decodeText(version.data);
      if (battery != null) device!.battery = readU16(battery.data, 0);
      if (fs != null && fs.data.length >= 12) {
        final block = readU32(fs.data, 0);
        final total = readU32(fs.data, 4);
        final free = readU32(fs.data, 8);
        device!.storage = '${_fmt(block * (total - free))} / ${_fmt(block * total)}';
        device!.freeBytes = block * free;
      }
      if (controls != null) settings.applyBytes(controls.data.length >= 8 ? controls.data.sublist(0, 8) : controls.data);
      if (carousel != null) {
        settings.carouselSeconds = readU16(carousel.data, 0);
        settings.carousel = settings.carouselSeconds > 0;
      }
      if (card != null) profile = decodeText(card.data);
      persist();
      if (!silent) showToast(i18n.t('refreshOk'));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<DecodedPacket?> _soft(Future<DecodedPacket> future) async {
    try {
      return await future;
    } catch (e) {
      log('soft request failed', e.toString());
      return null;
    }
  }

  String _fmt(int n) {
    if (n >= 1073741824) return '${(n / 1073741824).toStringAsFixed(1)} GB';
    if (n >= 1048576) return '${(n / 1048576).toStringAsFixed(1)} MB';
    if (n >= 1024) return '${(n / 1024).round()} KB';
    return '$n B';
  }

  void toggleSetting(String key) {
    switch (key) {
      case 'broadcast':
        settings.broadcast = !settings.broadcast;
        break;
      case 'buzzer':
        settings.buzzer = !settings.buzzer;
        break;
      case 'vibration':
        settings.vibration = !settings.vibration;
        break;
      case 'interestLight':
        settings.interestLight = !settings.interestLight;
        break;
      case 'interestScan':
        settings.interestScan = !settings.interestScan;
        break;
      case 'ambient':
        settings.ambient = !settings.ambient;
        break;
    }
    persist();
    notifyListeners();
  }

  Future<void> writeSettings() async {
    await request(writeControlInfo(settings.toBytes()), ControlCommand.controlInfoResponse);
    persist();
    showToast(i18n.t('settingsWrite'));
  }

  Future<void> saveProfile() async {
    final bytes = utf8Bytes(profile);
    if (bytes.length > Limits.cardBytes) {
      showToast(i18n.t('overBytes', {'max': '${Limits.cardBytes}'}));
      return;
    }
    persist();
    await request(setCardInfo(profile), ControlCommand.respCardInfo);
    showToast(i18n.t('profileWrite'));
  }

  Future<void> readProfile() async {
    final res = await request(readCardInfo(), ControlCommand.respReadCard);
    profile = decodeText(res.data);
    persist();
    notifyListeners();
    showToast(i18n.t('profileRead'));
  }

  Future<void> saveTags() async {
    persist();
    await request(setTags(selectedTags), ControlCommand.respTags);
    showToast(i18n.t('tagsWrite'));
  }

  void toggleTag(TagRef ref) {
    final index = selectedTags.indexWhere((t) => t.key == ref.key);
    if (index >= 0) {
      selectedTags.removeAt(index);
    } else if (selectedTags.length >= Limits.tags) {
      showToast(i18n.t('maxTags', {'max': '${Limits.tags}'}));
      return;
    } else {
      selectedTags.add(ref);
    }
    persist();
    notifyListeners();
  }

  Future<void> writeCarousel(int seconds) async {
    await request(setCarousel(seconds), ControlCommand.respCarousel);
    settings.carousel = seconds > 0;
    settings.carouselSeconds = seconds;
    persist();
    notifyListeners();
  }
}

class _Pending {
  late final Timer timer;
  final _c = Completer<DecodedPacket>();
  Future<DecodedPacket> get future => _c.future;
  void complete(DecodedPacket p) {
    if (!_c.isCompleted) _c.complete(p);
  }

  void completeError(Object e) {
    if (!_c.isCompleted) _c.completeError(e);
  }
}
