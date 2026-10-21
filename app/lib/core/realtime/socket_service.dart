import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../network/api_client.dart';

class SocketService {
  SocketService(this._api);
  final ApiClient _api;
  io.Socket? _socket;

  bool get connected => _socket?.connected == true;

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    final token = await _api.getAccessToken();
    if (token == null || token.isEmpty) return;
    _socket?.dispose();
    _socket = io.io(
      '${AppConfig.socketOrigin}/realtime',
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().setAuth({'token': token}).build(),
    );
    _socket!.connect();
  }

  Future<void> reauth() async {
    final token = await _api.getAccessToken();
    if (token == null) return;
    if (_socket?.connected != true) {
      await connect();
      return;
    }
    _socket!.emit('auth:refresh', {'token': token});
  }

  void joinConversation(String id) {
    _socket?.emit('conversation:join', {'conversationId': id});
  }

  void leaveConversation(String id) {
    _socket?.emit('conversation:leave', {'conversationId': id});
  }

  void joinThread(String threadId) {
    _socket?.emit('thread:join', {'threadId': threadId});
  }

  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
