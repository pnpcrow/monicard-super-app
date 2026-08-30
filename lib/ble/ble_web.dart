import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../protocol.dart';
import 'ble_interface.dart';

MoniCardBle createBle() => WebBle();

@JS('navigator.bluetooth')
external Bluetooth? get _bluetooth;

extension type Bluetooth._(JSObject _) implements JSObject {
  external JSPromise<BluetoothDevice> requestDevice(RequestDeviceOptions options);
  external JSPromise<JSArray<BluetoothDevice>> getDevices();
}

extension type RequestDeviceOptions._(JSObject _) implements JSObject {
  external factory RequestDeviceOptions({
    JSArray<BluetoothLEScanFilterInit> filters,
    JSArray<JSString> optionalServices,
  });
}

extension type BluetoothLEScanFilterInit._(JSObject _) implements JSObject {
  external factory BluetoothLEScanFilterInit({String namePrefix});
}

extension type BluetoothDevice._(JSObject _) implements JSObject {
  external String get id;
  external String? get name;
  external BluetoothRemoteGATTServer? get gatt;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type BluetoothRemoteGATTServer._(JSObject _) implements JSObject {
  external bool get connected;
  external JSPromise<BluetoothRemoteGATTServer> connect();
  external void disconnect();
  external JSPromise<JSArray<BluetoothRemoteGATTService>> getPrimaryServices();
}

extension type BluetoothRemoteGATTService._(JSObject _) implements JSObject {
  external String get uuid;
  external JSPromise<JSArray<BluetoothRemoteGATTCharacteristic>> getCharacteristics();
}

extension type BluetoothRemoteGATTCharacteristic._(JSObject _) implements JSObject {
  external String get uuid;
  external BluetoothCharacteristicProperties get properties;
  external JSDataView? get value;
  external JSPromise<BluetoothRemoteGATTCharacteristic> startNotifications();
  external JSPromise<JSAny?> writeValueWithoutResponse(JSUint8Array data);
  external JSPromise<JSAny?> writeValueWithResponse(JSUint8Array data);
  external JSPromise<JSAny?> writeValue(JSUint8Array data);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type BluetoothCharacteristicProperties._(JSObject _) implements JSObject {
  external bool get notify;
  external bool get indicate;
  external bool get write;
  external bool get writeWithoutResponse;
}

extension type _DomEvent._(JSObject _) implements JSObject {
  external BluetoothRemoteGATTCharacteristic get target;
}

class WebBle implements MoniCardBle {
  BluetoothDevice? _device;
  BluetoothDevice? _lastDevice;
  BluetoothRemoteGATTCharacteristic? _dataChar;
  JSFunction? _disconnectFn;
  JSFunction? _notifyFn;
  Future<void> _queue = Future.value();
  bool _sending = false;
  final List<_Urgent> _urgent = [];
  final List<Uint8List> _rxParts = [];
  int? _rxCategory;
  int _rxExpectedLength = 0;

  bool _radioUp = false;
  @override
  bool get connected => _radioUp;
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

  @override
  Future<void> connect({String? knownId, bool picker = false, bool auto = false}) async {
    final bluetooth = _bluetooth;
    if (bluetooth == null) {
      throw const BleUnavailable();
    }

    final timeout = auto ? const Duration(seconds: 6) : const Duration(seconds: 12);

    if (!picker && knownId != null && knownId.isNotEmpty) {
      final remembered = await _deviceForId(bluetooth, knownId);
      if (remembered != null) {
        try {
          await _attach(remembered, timeout: timeout, waitForAdv: true);
          return;
        } catch (_) {
          if (auto) rethrow;
        }
      } else if (auto) {
        throw StateError('Saved device is not available');
      }
    }

    if (auto) {
      throw StateError('Saved device is not available');
    }

    final BluetoothDevice selected;
    try {
      selected = await bluetooth
          .requestDevice(
            RequestDeviceOptions(
              filters: [
                BluetoothLEScanFilterInit(namePrefix: 'MoniCard'),
                BluetoothLEScanFilterInit(namePrefix: 'MONICARD'),
                BluetoothLEScanFilterInit(namePrefix: 'monicard'),
              ].toJS,
              optionalServices: [
                Uuids.service.toJS,
                reverseUuid(Uuids.service).toJS,
              ].toJS,
            ),
          )
          .toDart;
    } catch (error) {
      if (_cancelled(error)) rethrow;
      if (_unavailable(error)) throw const BleUnavailable();
      rethrow;
    }
    await _attach(selected, timeout: timeout, waitForAdv: false);
  }

  Future<BluetoothDevice?> _deviceForId(Bluetooth bluetooth, String id) async {
    if (_lastDevice != null && _lastDevice!.id == id) {
      return _lastDevice;
    }
    if (_device != null && _device!.id == id) {
      return _device;
    }
    try {
      final raw = await bluetooth.callMethod<JSPromise<JSAny>>('getDevices'.toJS).toDart;
      final devices = <BluetoothDevice>[];
      if (raw.isA<JSArray>()) {
        for (final item in (raw as JSArray).toDart) {
          if (item == null) continue;
          devices.add(BluetoothDevice._(item as JSObject));
        }
      }
      for (final device in devices) {
        if (device.id == id) return device;
      }
      for (final device in devices) {
        final name = (device.name ?? '').toLowerCase();
        if (name.contains('monicard')) return device;
      }
      if (devices.length == 1) return devices.first;
    } catch (_) {}
    return null;
  }

  Future<void> _attach(
    BluetoothDevice selected, {
    required Duration timeout,
    required bool waitForAdv,
  }) async {
    _clear(disconnectGatt: false);
    _device = selected;
    _lastDevice = selected;
    deviceId = selected.id;
    deviceName = (selected.name == null || selected.name!.isEmpty) ? 'MoniCard' : selected.name;
    _disconnectFn = ((JSAny _) {
      final was = _radioUp;
      _clear(disconnectGatt: false);
      if (was) onDisconnect?.call();
    }).toJS;
    selected.addEventListener('gattserverdisconnected', _disconnectFn!);

    if (waitForAdv) {
      try {
        await selected.callMethod<JSPromise<JSAny>>('watchAdvertisements'.toJS).toDart;
        await _waitForAdvertisement(selected, const Duration(seconds: 5));
      } catch (_) {}
    }

    final gatt = selected.gatt;
    if (gatt == null) {
      throw StateError('GATT server is missing on ${deviceName!}');
    }
    final server = await gatt.connect().toDart.timeout(timeout);
    final services = (await server.getPrimaryServices().toDart).toDart;
    BluetoothRemoteGATTService? service;
    for (final item in services) {
      if (uuidMatches(item.uuid, Uuids.service)) {
        service = item;
        break;
      }
    }
    if (service == null) {
      throw StateError('MoniCard GATT service was not found.');
    }
    final characteristics = (await service.getCharacteristics().toDart).toDart;
    BluetoothRemoteGATTCharacteristic? dataChar;
    for (final item in characteristics) {
      if (uuidMatches(item.uuid, Uuids.data)) {
        dataChar = item;
        break;
      }
    }
    if (dataChar == null) {
      throw StateError('MoniCard data characteristic was not found.');
    }
    _dataChar = dataChar;
    if (dataChar.properties.notify || dataChar.properties.indicate) {
      await dataChar.startNotifications().toDart;
      _notifyFn = ((JSAny event) {
        _handleIncoming(_bytesFromEvent(event as _DomEvent));
      }).toJS;
      dataChar.addEventListener('characteristicvaluechanged', _notifyFn!);
    }
    _radioUp = true;
    onConnect?.call();
  }

  Future<void> _waitForAdvertisement(BluetoothDevice device, Duration timeout) async {
    final done = Completer<void>();
    final fn = ((JSAny _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    device.addEventListener('advertisementreceived', fn);
    try {
      await Future.any([done.future, Future<void>.delayed(timeout)]);
    } finally {
      device.removeEventListener('advertisementreceived', fn);
    }
  }

  Uint8List _bytesFromEvent(_DomEvent event) {
    final view = event.target.value;
    if (view == null) return Uint8List(0);
    final data = view.toDart;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    final data = Uint8List.fromList(chunk).toJS;
    final props = char.properties;
    if (props.writeWithoutResponse) {
      await char.writeValueWithoutResponse(data).toDart;
    } else if (props.write) {
      await char.writeValueWithResponse(data).toDart;
    } else {
      await char.writeValue(data).toDart;
    }
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
    _clear(disconnectGatt: true);
  }

  void _clear({required bool disconnectGatt}) {
    final char = _dataChar;
    final fn = _notifyFn;
    if (char != null && fn != null) {
      char.removeEventListener('characteristicvaluechanged', fn);
    }
    final device = _device;
    final disc = _disconnectFn;
    if (device != null && disc != null) {
      device.removeEventListener('gattserverdisconnected', disc);
      if (disconnectGatt && device.gatt?.connected == true) {
        device.gatt!.disconnect();
      }
    }
    _notifyFn = null;
    _disconnectFn = null;
    _device = null;
    _dataChar = null;
    _radioUp = false;
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

  bool _cancelled(Object error) {
    final t = error.toString().toLowerCase();
    return t.contains('notfound') || t.contains('abort') || t.contains('cancel');
  }

  bool _unavailable(Object error) {
    final t = error.toString().toLowerCase();
    return t.contains('not supported') ||
        t.contains('not available') ||
        t.contains('undefined') ||
        t.contains('securityerror') ||
        t.contains('permissions policy') ||
        t.contains('typeerror') ||
        t.contains('illegal invocation');
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
