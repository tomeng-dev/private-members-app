class FeedPost {
  FeedPost({
    required this.id,
    this.body,
    this.linkUrl,
    this.linkTitle,
    required this.createdAt,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.isOwner,
    this.sharedFromBody,
    this.sharedFromAuthor,
    this.authorId,
    this.authorFounding = false,
    this.authorSubtitle,
  });

  final String id;
  final String? body;
  final String? linkUrl;
  final String? linkTitle;
  final DateTime createdAt;
  final String authorName;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool isOwner;
  final String? sharedFromBody;
  final String? sharedFromAuthor;
  final String? authorId;
  final bool authorFounding;
  final String? authorSubtitle;

  FeedPost copyWith({int? likeCount, bool? likedByMe, int? commentCount}) => FeedPost(
    id: id,
    body: body,
    linkUrl: linkUrl,
    linkTitle: linkTitle,
    createdAt: createdAt,
    authorName: authorName,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    isOwner: isOwner,
    sharedFromBody: sharedFromBody,
    sharedFromAuthor: sharedFromAuthor,
    authorId: authorId,
    authorFounding: authorFounding,
    authorSubtitle: authorSubtitle,
  );

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    final shared = json['sharedFrom'] as Map<String, dynamic>?;
    final sharedAuthor = shared?['author'] as Map<String, dynamic>?;
    return FeedPost(
      id: json['id'] as String,
      body: json['body'] as String?,
      linkUrl: json['linkUrl'] as String?,
      linkTitle: json['linkTitle'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorName: '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim(),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      sharedFromBody: shared?['body'] as String?,
      sharedFromAuthor: sharedAuthor == null ? null : '${sharedAuthor['firstName'] ?? ''} ${sharedAuthor['lastName'] ?? ''}'.trim(),
      authorId: author['id'] as String?,
      authorFounding: author['foundingMember'] as bool? ?? false,
      authorSubtitle: [author['title'], author['company']].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
    );
  }
}

class FeedComment {
  FeedComment({required this.id, required this.body, required this.authorName, this.createdAt, this.authorFounding = false});
  final String id;
  final String body;
  final String authorName;
  final DateTime? createdAt;
  final bool authorFounding;
  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final a = json['author'] as Map<String, dynamic>? ?? {};
    return FeedComment(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      authorName: '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      authorFounding: a['foundingMember'] as bool? ?? false,
    );
  }
}
