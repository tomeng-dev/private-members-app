import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/features/feed/domain/entities/post.dart';

void main() {
  test('FeedPost.fromJson', () {
    final p = FeedPost.fromJson({
      'id': '1',
      'body': 'Hi',
      'createdAt': '2026-10-19T00:00:00.000Z',
      'author': {'firstName': 'A', 'lastName': 'B'},
      'likeCount': 2,
      'commentCount': 1,
      'likedByMe': true,
      'isOwner': false,
    });
    expect(p.authorName, 'A B');
    expect(p.likedByMe, true);
  });
}
