import 'dart:typed_data';
import '../entities/application.dart';

abstract class ApplicationsRepository {
  Future<MemberApplication> submit(Map<String, dynamic> payload);
  Future<void> uploadProof({
    required String applicationId,
    required String email,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  });
  Future<MemberApplication> statusByEmail(String email);
}
