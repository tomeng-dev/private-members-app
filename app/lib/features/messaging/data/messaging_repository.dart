import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/conversation.dart';

class MessagingRepository {
  MessagingRepository(this._api);
  final ApiClient _api;

  Future<List<ConversationSummary>> conversations() async {
    try {
      final res = await _api.raw.get('/conversations');
      final items = (res.data['items'] as List? ?? []).map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
      return items;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<String> startConversation(String memberId) async {
    try {
      final res = await _api.raw.post('/conversations', data: {'memberId': memberId});
      return res.data['id'] as String;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<ChatMessage>> messages(String conversationId, {required String myId, String? cursor}) async {
    try {
      final res = await _api.raw.get('/conversations/$conversationId/messages', queryParameters: {if (cursor != null) 'cursor': cursor});
      return (res.data['items'] as List? ?? []).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, myId)).toList().reversed.toList();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ChatMessage> send(String conversationId, String body, {required String myId}) async {
    try {
      final res = await _api.raw.post('/conversations/$conversationId/messages', data: {'body': body});
      return ChatMessage.fromJson(res.data as Map<String, dynamic>, myId);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _api.raw.post('/conversations/$conversationId/read');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> block(String memberId) async {
    try {
      await _api.raw.post('/blocks', data: {'memberId': memberId});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> reportMessage(String messageId, String reason) async {
    try {
      await _api.raw.post('/messages/report', data: {'messageId': messageId, 'reason': reason});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> sharePost({required String postId, required String memberId, String? note}) async {
    try {
      await _api.raw.post('/messages/share-post', data: {'postId': postId, 'memberId': memberId, if (note != null) 'note': note});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  String _msg(DioException e) =>
      (e.response?.data is Map && (e.response!.data as Map)['message'] != null) ? '${(e.response!.data as Map)['message']}' : e.message ?? 'Request failed';
}
