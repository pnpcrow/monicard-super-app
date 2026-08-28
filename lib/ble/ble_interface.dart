import 'dart:typed_data';

typedef PacketHandler = void Function(Uint8List packet);
typedef VoidHandler = void Function();

abstract class MoniCardBle {
  bool get connected;
  String? get deviceId;
  String? get deviceName;
  int get mtu;

  PacketHandler? onPacket;
  VoidHandler? onConnect;
  VoidHandler? onDisconnect;

  Future<void> connect();
  Future<void> send(Uint8List bytes, {void Function(int progress)? onProgress});
  Future<void> sendPriority(Uint8List bytes);
  Future<void> disconnect();
}
