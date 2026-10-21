import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/features/messaging/domain/entities/conversation.dart';

void main() {
  test('ConversationSummary.fromJson maps unread and peer', () {
    final c = ConversationSummary.fromJson({
      'id': 'c1',
      'unreadCount': 3,
      'participants': [
        {'id': 'u2', 'firstName': 'Alex', 'lastName': 'Owner'},
      ],
      'lastMessage': {'body': 'Hello'},
    });
    expect(c.participantName, 'Alex Owner');
    expect(c.unreadCount, 3);
    expect(c.lastBody, 'Hello');
  });

  test('ChatMessage.fromJson marks mine', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'body': 'Hi',
      'createdAt': '2026-10-19T00:00:00.000Z',
      'sender': {'id': 'me', 'firstName': 'A', 'lastName': 'B'},
    }, 'me');
    expect(m.mine, true);
    expect(m.senderName, 'A B');
  });
}
