import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/application.dart';
import '../../domain/repositories/applications_repository.dart';

class ApplicationsRepositoryImpl implements ApplicationsRepository {
  ApplicationsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<MemberApplication> submit(Map<String, dynamic> payload) async {
    try {
      final res = await _api.raw.post('/applications', data: payload);
      return MemberApplication.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<void> uploadProof({
    required String applicationId,
    required String email,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final form = FormData.fromMap({'email': email, 'file': MultipartFile.fromBytes(bytes, filename: filename)});
      await _api.raw.post('/applications/$applicationId/proof', data: form);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<MemberApplication> statusByEmail(String email) async {
    try {
      final res = await _api.raw.get('/applications/status', queryParameters: {'email': email});
      return MemberApplication.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List) return m.join(', ');
      return m.toString();
    }
    return e.message ?? 'Network error';
  }
}
