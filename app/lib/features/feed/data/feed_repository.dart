import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/post.dart';

class FeedRepository {
  FeedRepository(this._api);
  final ApiClient _api;

  Future<({List<FeedPost> items, String? nextCursor})> feed({String? cursor}) async {
    try {
      final res = await _api.raw.get('/feed', queryParameters: {if (cursor != null) 'cursor': cursor});
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List).map((e) => FeedPost.fromJson(e as Map<String, dynamic>)).toList();
      return (items: items, nextCursor: data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<FeedPost> createPost({String? body, String? linkUrl, String? sharedFromPostId}) async {
    try {
      final res = await _api.raw.post(
        '/posts',
        data: {if (body != null) 'body': body, if (linkUrl != null) 'linkUrl': linkUrl, if (sharedFromPostId != null) 'sharedFromPostId': sharedFromPostId},
      );
      return FeedPost.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<bool> toggleLike(String postId) async {
    try {
      final res = await _api.raw.post('/posts/$postId/like');
      return res.data['liked'] as bool? ?? false;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<FeedComment>> comments(String postId) async {
    try {
      final res = await _api.raw.get('/posts/$postId/comments');
      return (res.data as List).map((e) => FeedComment.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> addComment(String postId, String body) async {
    try {
      await _api.raw.post('/posts/$postId/comments', data: {'body': body});
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _api.raw.delete('/posts/$postId');
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> report({required String targetType, required String targetId, required String reason}) async {
    try {
      await _api.raw.post('/reports', data: {'targetType': targetType, 'targetId': targetId, 'reason': reason});
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
