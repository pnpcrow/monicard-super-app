import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../protocol.dart';
import 'ble_interface.dart';

MoniCardBle createBle() => FbpBle();

class FbpBle implements MoniCardBle {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  Future<void> _queue = Future.value();
  bool _sending = false;
  final List<_Urgent> _urgent = [];
  final List<Uint8List> _rxParts = [];
  int? _rxCategory;
  int _rxExpectedLength = 0;
  final Map<String, BluetoothDevice> _found = {};
  final Map<String, int> _rssi = {};
  final StreamController<List<NearbyCard>> _scanCtrl =
      StreamController<List<NearbyCard>>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  Stream<List<NearbyCard>> get scanResults => _scanCtrl.stream;

  @override
  bool connected = false;
  @override
  String? deviceId;
  @override
  String? deviceName;
  @override
  int mtu = 247;
  @override
  PacketHandler? onPacket;
  @override
  VoidHandler? onConnect;
  @override
  VoidHandler? onDisconnect;

  Future<void> _ensurePermissions() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }
  }

  @override
  Future<void> connect({String? knownId, bool picker = false, bool auto = false}) async {
    await _ensurePermissions();
    if (!kIsWeb) {
      if (await FlutterBluePlus.isSupported == false) {
        throw const BleUnavailable();
      }
      await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw StateError('Turn Bluetooth on and try again.'),
          );
    }

    final timeout = auto ? const Duration(seconds: 6) : const Duration(seconds: 12);

    if (knownId != null && knownId.isNotEmpty && !picker) {
      await stopScan();
      final cached = _found[knownId];
      if (cached != null) {
        await _bind(cached, timeout: timeout);
        return;
      }
      final found = await _scanForSaved(knownId, timeout);
      if (found != null) {
        await _bind(found, timeout: timeout);
        return;
      }
      if (auto) {
        throw StateError('Saved device is not available');
      }
      throw StateError('Saved device is not available');
    }

    if (auto) {
      throw StateError('Saved device is not available');
    }

    // Picker is the scan list in the UI. Never auto-bind the first advertisement.
    if (picker) {
      throw StateError('Select a device from the scan list');
    }

    throw StateError('No device selected');
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    await _ensurePermissions();
    if (await FlutterBluePlus.isSupported == false) {
      throw const BleUnavailable();
    }
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw StateError('Turn Bluetooth on and try again.'),
        );
    await stopScan();
    _found.clear();
    _rssi.clear();
    _emitScan();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final name = r.device.platformName;
        final adv = r.advertisementData.advName;
        final label = name.isNotEmpty ? name : adv;
        if (!label.toLowerCase().contains('monicard')) continue;
        final id = r.device.remoteId.str;
        _found[id] = r.device;
        _rssi[id] = r.rssi;
        changed = true;
      }
      if (changed) _emitScan();
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withKeywords: const ['MoniCard', 'MONICARD', 'monicard'],
        androidUsesFineLocation: false,
      );
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first.timeout(
            timeout + const Duration(seconds: 2),
            onTimeout: () => false,
          );
    } catch (error) {
      await stopScan();
      if (_unavailable(error)) throw const BleUnavailable();
      rethrow;
    } finally {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  void _emitScan() {
    final list = _found.entries
        .map(
          (e) => NearbyCard(
            id: e.key,
            name: e.value.platformName.isEmpty ? 'MoniCard' : e.value.platformName,
            rssi: _rssi[e.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (!_scanCtrl.isClosed) _scanCtrl.add(list);
  }

  Future<BluetoothDevice?> _scanForSaved(String knownId, Duration timeout) async {
    BluetoothDevice? found;
    final done = Completer<void>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        final name = r.device.platformName.toLowerCase();
        final adv = r.advertisementData.advName.toLowerCase();
        if (id == knownId || name.contains('monicard') || adv.contains('monicard')) {
          if (id == knownId || found == null) found = r.device;
          if (id == knownId && !done.isCompleted) done.complete();
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withKeywords: const ['MoniCard', 'MONICARD', 'monicard'],
        androidUsesFineLocation: false,
      );
      await Future.any([
        done.future,
        FlutterBluePlus.isScanning.where((scanning) => !scanning).first,
        Future<void>.delayed(timeout),
      ]);
    } catch (error) {
      await FlutterBluePlus.stopScan();
      if (_unavailable(error)) throw const BleUnavailable();
      rethrow;
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
    return found;
  }

  bool _unavailable(Object error) {
    final t = error.toString().toLowerCase();
    if (t.contains('notfound') || t.contains('abort') || t.contains('cancel')) {
      return false;
    }
    return t.contains('not supported') ||
        t.contains('not available') ||
        t.contains('undefined') ||
        t.contains('securityerror') ||
        t.contains('permissions policy') ||
        t.contains('typeerror') ||
        t.contains('javascripterror') ||
        t.contains('illegal invocation');
  }

  Future<void> _bind(BluetoothDevice device, {Duration timeout = const Duration(seconds: 15)}) async {
    _clear();
    _device = device;
    deviceId = device.remoteId.str;
    deviceName = device.platformName.isEmpty ? 'MoniCard' : device.platformName;
    _stateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && connected) {
        _clear();
        onDisconnect?.call();
      }
    });
    await device.connect(timeout: timeout, autoConnect: false);
    var negotiated = 23;
    try {
      if (!kIsWeb) {
        negotiated = await device.requestMtu(512);
      }
    } catch (_) {
      try {
        if (!kIsWeb) negotiated = await device.requestMtu(247);
      } catch (_) {
        negotiated = device.mtuNow > 20 ? device.mtuNow : 23;
      }
    }
    if (negotiated < 23) negotiated = device.mtuNow > 20 ? device.mtuNow : 23;
    mtu = bleWriteMtu(negotiated, withoutResponse: true);
    final services = await device.discoverServices();
    BluetoothService? service;
    for (final s in services) {
      if (uuidMatches(s.uuid.str, Uuids.service)) {
        service = s;
        break;
      }
    }
    if (service == null) {
      throw StateError('MoniCard GATT service was not found.');
    }
    BluetoothCharacteristic? dataChar;
    for (final c in service.characteristics) {
      if (uuidMatches(c.uuid.str, Uuids.data)) {
        dataChar = c;
        break;
      }
    }
    if (dataChar == null) {
      throw StateError('MoniCard data characteristic was not found.');
    }
    _dataChar = dataChar;
    mtu = bleWriteMtu(
      device.mtuNow > 23 ? device.mtuNow : negotiated,
      withoutResponse: dataChar.properties.writeWithoutResponse,
    );
    await dataChar.setNotifyValue(true);
    _notifySub = dataChar.onValueReceived.listen((value) {
      _handleIncoming(Uint8List.fromList(value));
    });
    connected = true;
    onConnect?.call();
  }

  void _handleIncoming(Uint8List packet) {
    if (packet.isEmpty) return;
    final kind = packet.length > 1 ? packet[1] : 0;
    if (kind == 0) {
      onPacket?.call(Uint8List.fromList(packet));
      return;
    }
    if (kind == 1) {
      _rxCategory = packet[0];
      _rxExpectedLength = packet.length >= 4 ? readU16(packet, 2) : 0;
      _rxParts
        ..clear()
        ..add(packet.sublist(4));
      return;
    }
    if ((kind == 2 || kind == 3) && _rxParts.isNotEmpty) {
      _rxParts.add(packet.sublist(2));
      if (kind == 3) {
        final received = _rxParts.fold<int>(0, (n, p) => n + p.length);
        final length = _rxExpectedLength == 0 ? received : _rxExpectedLength;
        final full = Uint8List(4 + length);
        full[0] = _rxCategory ?? packet[0];
        full[1] = 0;
        full[2] = length & 255;
        full[3] = (length >> 8) & 255;
        var offset = 4;
        for (final part in _rxParts) {
          final remaining = full.length - offset;
          if (remaining <= 0) break;
          final take = part.length < remaining ? part.length : remaining;
          full.setRange(offset, offset + take, part);
          offset += take;
        }
        _rxParts.clear();
        _rxCategory = null;
        _rxExpectedLength = 0;
        onPacket?.call(full);
      }
    }
  }

  Future<void> _writeChunk(Uint8List chunk) async {
    final char = _dataChar;
    if (!connected || char == null) throw StateError('Device is not connected');
    final without = char.properties.writeWithoutResponse;
    await char.write(chunk, withoutResponse: without, allowLongWrite: false, timeout: 8);
  }

  Future<void> _drainUrgent() async {
    while (_urgent.isNotEmpty) {
      final job = _urgent.removeAt(0);
      try {
        for (final chunk in job.chunks) {
          await _writeChunk(chunk);
        }
        job.complete();
      } catch (e, st) {
        job.completeError(e, st);
      }
    }
  }

  @override
  Future<void> send(Uint8List bytes, {void Function(int progress)? onProgress}) {
    final chunks = splitFrame(bytes, mtu: mtu);
    _queue = _queue.then((_) async {
      _sending = true;
      try {
        for (var i = 0; i < chunks.length; i++) {
          if (!connected) throw StateError('BLE disconnected during transfer');
          await _writeChunk(chunks[i]);
          await _drainUrgent();
          onProgress?.call((((i + 1) / chunks.length) * 100).round());
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        await _drainUrgent();
      } finally {
        _sending = false;
      }
    });
    return _queue;
  }

  @override
  Future<void> sendPriority(Uint8List bytes) {
    if (!connected || _dataChar == null) {
      return Future.error(StateError('Device is not connected'));
    }
    final chunks = splitFrame(bytes, mtu: mtu);
    final job = _Urgent(chunks);
    _urgent.add(job);
    if (!_sending) {
      _queue = _queue.then((_) async {
        _sending = true;
        try {
          await _drainUrgent();
        } finally {
          _sending = false;
        }
      });
    }
    return job.future;
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _clear();
  }

  void _clear() {
    _notifySub?.cancel();
    _stateSub?.cancel();
    _notifySub = null;
    _stateSub = null;
    _device = null;
    _dataChar = null;
    connected = false;
    _queue = Future.value();
    _rxParts.clear();
    _rxCategory = null;
    _rxExpectedLength = 0;
    for (final job in _urgent) {
      job.completeError(StateError('BLE disconnected'));
    }
    _urgent.clear();
    _sending = false;
  }
}

class _Urgent {
  _Urgent(this.chunks);
  final List<Uint8List> chunks;
  final _c = Completer<void>();
  Future<void> get future => _c.future;
  void complete() {
    if (!_c.isCompleted) _c.complete();
  }

  void completeError(Object e, [StackTrace? st]) {
    if (!_c.isCompleted) _c.completeError(e, st);
  }
}
