import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';

class EventsRepository {
  EventsRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list({String filter = 'upcoming'}) async {
    try {
      final res = await _api.raw.get('/events', queryParameters: {'filter': filter});
      return ((res.data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> calendar({required int year, required int month}) async {
    try {
      final res = await _api.raw.get('/events/calendar', queryParameters: {'year': year, 'month': month});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> get(String id) async {
    try {
      final res = await _api.raw.get('/events/$id');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> rsvp(String id, String status) async {
    try {
      final res = await _api.raw.post('/events/$id/rsvp', data: {'status': status});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> ticket(String id) async {
    try {
      final res = await _api.raw.get('/events/$id/ticket');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<Map<String, dynamic>>> attendees(String id) async {
    try {
      final res = await _api.raw.get('/events/$id/attendees');
      return ((res.data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> archive(String id) async {
    try {
      final res = await _api.raw.get('/events/$id/archive');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> rsvpGoing(String id) async {
    await rsvp(id, 'going');
  }

  Future<({String threadId, List<Map<String, dynamic>> items})> thread(String eventId) async {
    try {
      final res = await _api.raw.get('/events/$eventId/thread');
      return (threadId: res.data['threadId'] as String, items: ((res.data['items'] as List?) ?? []).cast<Map<String, dynamic>>());
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> comment(String eventId, String body) async {
    try {
      await _api.raw.post('/events/$eventId/thread/comments', data: {'body': body});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String icsUrl(String id) => '${_api.raw.options.baseUrl}/events/$id/ics';

  String _msg(DioException e) =>
      (e.response?.data is Map && (e.response!.data as Map)['message'] != null) ? '${(e.response!.data as Map)['message']}' : e.message ?? 'Request failed';
}
