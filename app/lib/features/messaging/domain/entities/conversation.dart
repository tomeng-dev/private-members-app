class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.participantName,
    required this.participantId,
    this.lastBody,
    required this.unreadCount,
    this.lastAt,
    this.participantFounding = false,
  });

  final String id;
  final String participantName;
  final String participantId;
  final String? lastBody;
  final int unreadCount;
  final DateTime? lastAt;
  final bool participantFounding;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final parts = (json['participants'] as List? ?? []);
    final p = parts.isNotEmpty ? parts.first as Map<String, dynamic> : null;
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ConversationSummary(
      id: json['id'] as String,
      participantId: p?['id'] as String? ?? '',
      participantName: p == null ? 'Member' : '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim(),
      lastBody: last?['body'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastAt: DateTime.tryParse((last?['createdAt'] ?? json['updatedAt'])?.toString() ?? ''),
      participantFounding: p?['foundingMember'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.mine,
    required this.createdAt,
    this.sharedPostId,
  });

  final String id;
  final String? body;
  final String senderId;
  final String senderName;
  final bool mine;
  final DateTime createdAt;
  final String? sharedPostId;

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myId) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String?,
      senderId: sender?['id'] as String? ?? json['senderId'] as String? ?? '',
      senderName: sender == null ? '' : '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim(),
      mine: (sender?['id'] as String? ?? '') == myId,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      sharedPostId: json['sharedPostId'] as String?,
    );
  }
}
