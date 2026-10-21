import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<List<dynamic>> listApplications({String? status}) async {
    try {
      final res = await _api.raw.get('/admin/applications', queryParameters: {if (status != null && status.isNotEmpty) 'status': status});
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getApplication(String id) async {
    try {
      final res = await _api.raw.get('/admin/applications/$id');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> review(String id, Map<String, dynamic> body) async {
    try {
      await _api.raw.post('/admin/applications/$id/review', data: body);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> listMembers() async {
    try {
      final res = await _api.raw.get('/admin/members');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> updateDues(String id, Map<String, dynamic> body) async {
    try {
      await _api.raw.patch('/admin/members/$id/dues', data: body);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> auditLogs() async {
    try {
      final res = await _api.raw.get('/admin/audit-logs', queryParameters: {'limit': 100});
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getMemberProfile(String id) async {
    try {
      final res = await _api.raw.get('/admin/members/$id/profile');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> hideContent({required String type, required String id, bool hide = true}) async {
    try {
      await _api.raw.post('/admin/moderation/hide', data: {'type': type, 'id': id, 'hide': hide});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> listReports({String? status}) async {
    try {
      final res = await _api.raw.get('/admin/reports', queryParameters: {if (status != null) 'status': status});
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> resolveReport(String id, Map<String, dynamic> body) async {
    try {
      await _api.raw.post('/admin/reports/$id/resolve', data: body);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String proofUrl(String mediaId) => '${_api.baseUrl}/admin/applications/proof/$mediaId';

  Future<List<dynamic>> listEvents() async {
    try {
      final res = await _api.raw.get('/admin/events');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    try {
      final res = await _api.raw.get('/admin/events/$id');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.post('/admin/events', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.put('/admin/events/$id', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markRsvpPayment(String eventId, String rsvpId, String paymentStatus) async {
    try {
      await _api.raw.patch('/admin/events/$eventId/rsvps/$rsvpId/payment', data: {'paymentStatus': paymentStatus});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> previewCheckin(String eventId, String token) async {
    try {
      final res = await _api.raw.post('/admin/events/$eventId/checkin/preview', data: {'token': token});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> confirmCheckin(String eventId, String token) async {
    try {
      final res = await _api.raw.post('/admin/events/$eventId/checkin/confirm', data: {'token': token});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> manualCheckin(String eventId, String userId, {bool walkIn = false}) async {
    try {
      await _api.raw.post('/admin/events/$eventId/checkin/manual', data: {'userId': userId, 'walkIn': walkIn});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> searchCheckin(String eventId, String q) async {
    try {
      final res = await _api.raw.get('/admin/events/$eventId/checkin/search', queryParameters: {'q': q});
      return (res.data['items'] as List?) ?? [];
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> attendance(String eventId) async {
    try {
      final res = await _api.raw.get('/admin/events/$eventId/attendance');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String attendanceCsvUrl(String eventId) => '${_api.raw.options.baseUrl}/admin/events/$eventId/attendance.csv';

  Future<Map<String, dynamic>> overview() async {
    try {
      final res = await _api.raw.get('/admin/overview');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> vehicleVerifications() async {
    try {
      final res = await _api.raw.get('/admin/vehicles/verifications');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> reviewVehicle(String id, String decision, {String? note}) async {
    try {
      await _api.raw.post('/admin/vehicles/$id/review', data: {'decision': decision, if (note != null) 'note': note});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> vehicleProofUrl(String mediaId) async {
    try {
      final res = await _api.raw.get('/admin/vehicles/proof/$mediaId');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> listInvites() async {
    try {
      final res = await _api.raw.get('/admin/invites');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> createInvite(Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.post('/admin/invites', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> revokeInvite(String id) async {
    try {
      await _api.raw.post('/admin/invites/$id/revoke');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> auditLogsFiltered({String? action, String? from, String? to}) async {
    try {
      final res = await _api.raw.get(
        '/admin/audit-logs',
        queryParameters: {if (action != null && action.isNotEmpty) 'action': action, if (from != null) 'from': from, if (to != null) 'to': to, 'limit': 200},
      );
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> assignRoles(String memberId, List<String> roles) async {
    try {
      await _api.raw.patch('/admin/members/$memberId/roles', data: {'roles': roles});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> moderate(String memberId, String action, String reason) async {
    try {
      await _api.raw.post('/admin/members/$memberId/moderation', data: {'action': action, 'reason': reason});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  // ---------------------------------------------------------------------------
  // Admin console (UX round): server-side tables, stats, search, bulk, broadcast
  // ---------------------------------------------------------------------------

  Future<T> _call<T>(Future<Response<dynamic>> Function() req) async {
    try {
      final res = await req();
      return res.data as T;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<String> consoleEnv() async {
    final data = await _call<Map<String, dynamic>>(() => _api.raw.get('/admin/console/env'));
    return '${data['environment'] ?? 'DEV'}';
  }

  Future<Map<String, dynamic>> consoleStats() => _call(() => _api.raw.get('/admin/console/stats'));

  Future<Map<String, dynamic>> globalSearch(String q) => _call(() => _api.raw.get('/admin/console/search', queryParameters: {'q': q}));

  Future<Map<String, dynamic>> membersTable(Map<String, dynamic> params) => _call(() => _api.raw.get('/admin/console/members', queryParameters: params));

  Future<String> membersCsv(Map<String, dynamic> params) => _call(
    () => _api.raw.get(
      '/admin/console/members.csv',
      queryParameters: params,
      options: Options(responseType: ResponseType.plain),
    ),
  );

  Future<Map<String, dynamic>> memberDetail(String id) => _call(() => _api.raw.get('/admin/console/members/$id'));

  Future<Map<String, dynamic>> bulkMembers(List<String> ids, String action, String reason) =>
      _call(() => _api.raw.post('/admin/console/members/bulk', data: {'ids': ids, 'action': action, 'reason': reason}));

  Future<Map<String, dynamic>> applicationsTable(Map<String, dynamic> params) =>
      _call(() => _api.raw.get('/admin/console/applications', queryParameters: params));

  Future<String> applicationsCsv(Map<String, dynamic> params) => _call(
    () => _api.raw.get(
      '/admin/console/applications.csv',
      queryParameters: params,
      options: Options(responseType: ResponseType.plain),
    ),
  );

  Future<Map<String, dynamic>> bulkApplications(List<String> ids, String action, {String? reason}) => _call(
    () => _api.raw.post('/admin/console/applications/bulk', data: {'ids': ids, 'action': action, if (reason != null && reason.isNotEmpty) 'reason': reason}),
  );

  Future<Map<String, dynamic>> broadcast(Map<String, dynamic> body) => _call(() => _api.raw.post('/admin/console/broadcast', data: body));

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Network error';
  }
}
