import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/member_profile.dart';

class ProfilesRepository {
  ProfilesRepository(this._api);
  final ApiClient _api;

  Future<MemberProfile> myProfile() async {
    try {
      final res = await _api.raw.get('/me/profile');
      return MemberProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<MemberProfile> updateProfile(Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.patch('/me/profile', data: body);
      return MemberProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<MemberListItem>> listMembers({String? q, String? eventId}) async {
    try {
      final res = await _api.raw.get(
        '/members',
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q, if (eventId != null && eventId.isNotEmpty) 'eventId': eventId},
      );
      return (res.data as List).map((e) => MemberListItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<MemberProfile> getMember(String id) async {
    try {
      final res = await _api.raw.get('/members/$id');
      return MemberProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<VehicleItem> createVehicle(Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.post('/me/vehicles', data: body);
      return VehicleItem.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _api.raw.delete('/me/vehicles/$id');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<BusinessPageItem> upsertBusiness(Map<String, dynamic> body) async {
    try {
      final res = await _api.raw.put('/me/business-page', data: body);
      return BusinessPageItem.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> uploadVehiclePhoto({required String vehicleId, required String filename, required Uint8List bytes, required String mimeType}) async {
    try {
      final form = FormData.fromMap({
        'folder': 'vehicles',
        'ownerType': 'vehicle',
        'ownerId': vehicleId,
        'vehicleId': vehicleId,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      await _api.raw.post('/media/upload', data: form);
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
