import 'dart:typed_data';

typedef PacketHandler = void Function(Uint8List packet);
typedef VoidHandler = void Function();

class BleUnavailable implements Exception {
  const BleUnavailable([this.reason = 'Bluetooth is not available here.']);
  final String reason;
  @override
  String toString() => reason;
}

class NearbyCard {
  NearbyCard({required this.id, required this.name, this.rssi = 0});
  final String id;
  final String name;
  final int rssi;
}

abstract class MoniCardBle {
  bool get connected;
  String? get deviceId;
  String? get deviceName;
  int get mtu;

  PacketHandler? onPacket;
  VoidHandler? onConnect;
  VoidHandler? onDisconnect;

  Stream<List<NearbyCard>> get scanResults;

  Future<void> startScan({Duration timeout = const Duration(seconds: 12)});
  Future<void> stopScan();
  Future<void> connect({String? knownId, bool picker = false, bool auto = false});
  Future<void> send(Uint8List bytes, {void Function(int progress)? onProgress});
  Future<void> sendPriority(Uint8List bytes);
  Future<void> disconnect();
}
