import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list({int limit = 50}) async {
    try {
      final res = await _api.raw.get('/notifications', queryParameters: {'limit': limit});
      final items = (res.data['items'] as List?) ?? [];
      return items.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _api.raw.patch('/notifications/$id/read');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.raw.post('/notifications/read-all');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getPrefs() async {
    try {
      final res = await _api.raw.get('/me/notification-preferences');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> updatePrefs(Map<String, bool> body) async {
    try {
      final res = await _api.raw.patch('/me/notification-preferences', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> registerDevice(String fcmToken, String platform) async {
    try {
      await _api.raw.post('/devices', data: {'fcmToken': fcmToken, 'platform': platform});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> unregisterDevice(String fcmToken) async {
    try {
      await _api.raw.post('/devices/unregister', data: {'fcmToken': fcmToken});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Network error';
  }
}
