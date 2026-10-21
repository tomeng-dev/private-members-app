import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/conversation.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId, required this.peerName, this.peerId});
  final String conversationId;
  final String peerName;
  final String? peerId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> messages = [];
  String myId = '';
  String? error;
  bool loading = true;
  bool peerTyping = false;
  DateTime? peerReadAt;
  Timer? _typingOff;
  Timer? _typingThrottle;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final me = await ref.read(profilesRepositoryProvider).myProfile();
      myId = me.id;
      final sock = ref.read(socketServiceProvider);
      await sock.connect();
      sock.joinConversation(widget.conversationId);
      sock.on('message:new', _onSocketMessage);
      sock.on('typing', _onTyping);
      sock.on('conversation:read', _onRead);
      messages = await ref.read(messagingRepositoryProvider).messages(widget.conversationId, myId: myId);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await ref.read(messagingRepositoryProvider).markRead(widget.conversationId);
      sock.emit('conversation:read', {'conversationId': widget.conversationId});
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: AppMotion.medium, curve: AppMotion.standard);
    });
  }

  void _onTextChanged() {
    setState(() {});
    if (_ctrl.text.isEmpty || _typingThrottle?.isActive == true) return;
    ref.read(socketServiceProvider).emit('typing', {'conversationId': widget.conversationId, 'isTyping': true});
    _typingThrottle = Timer(const Duration(seconds: 2), () {});
  }

  void _onTyping(dynamic data) {
    if (data is! Map || data['conversationId'] != widget.conversationId || data['userId'] == myId) return;
    if (!mounted) return;
    setState(() => peerTyping = data['isTyping'] != false);
    _typingOff?.cancel();
    _typingOff = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => peerTyping = false);
    });
    _toBottom();
  }

  void _onRead(dynamic data) {
    if (data is! Map || data['conversationId'] != widget.conversationId || data['userId'] == myId) return;
    if (mounted) setState(() => peerReadAt = DateTime.tryParse('${data['readAt']}') ?? DateTime.now());
  }

  void _onSocketMessage(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversationId'] != widget.conversationId) return;
    final msg = ChatMessage.fromJson(map, myId);
    if (messages.any((m) => m.id == msg.id)) return;
    if (!mounted) return;
    setState(() {
      messages = [...messages, msg];
      if (!msg.mine) peerTyping = false;
    });
    _toBottom();
    ref.read(messagingRepositoryProvider).markRead(widget.conversationId);
    ref.read(socketServiceProvider).emit('conversation:read', {'conversationId': widget.conversationId});
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    _ctrl.clear();
    try {
      final msg = await ref.read(messagingRepositoryProvider).send(widget.conversationId, body, myId: myId);
      if (!messages.any((m) => m.id == msg.id)) setState(() => messages = [...messages, msg]);
      _toBottom();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _block() async {
    if (widget.peerId == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Block ${widget.peerName}?',
      message: 'They won\u2019t be able to message you.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(messagingRepositoryProvider).block(widget.peerId!);
      if (mounted) showToast(context, 'Member blocked', kind: ToastKind.success);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _messageActions(ChatMessage m) async {
    if (m.mine) return;
    final ok = await showConfirmDialog(context, title: 'Report message?', message: 'Moderators will review this message.', confirmLabel: 'Report');
    if (!ok) return;
    try {
      await ref.read(messagingRepositoryProvider).reportMessage(m.id, 'Reported from chat');
      if (mounted) showToast(context, 'Message reported', kind: ToastKind.success);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  void dispose() {
    final sock = ref.read(socketServiceProvider);
    sock.off('message:new');
    sock.off('typing');
    sock.off('conversation:read');
    sock.leaveConversation(widget.conversationId);
    _typingOff?.cancel();
    _typingThrottle?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final l = d.toLocal();
    if (l.year == now.year && l.month == now.month && l.day == now.day) return 'Today';
    final y = now.subtract(const Duration(days: 1));
    if (l.year == y.year && l.month == y.month && l.day == y.day) return 'Yesterday';
    return DateFormat.yMMMMd().format(l);
  }

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    final lastMine = messages.lastIndexWhere((m) => m.mine);
    final rows = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final newDay = prev == null || prev.createdAt.toLocal().day != m.createdAt.toLocal().day || prev.createdAt.toLocal().month != m.createdAt.toLocal().month;
      if (newDay) rows.add(_DayDivider(label: _dayLabel(m.createdAt)));
      final grouped = prev != null && !newDay && prev.mine == m.mine && m.createdAt.difference(prev.createdAt).inMinutes < 5;
      final read = m.mine && peerReadAt != null && !m.createdAt.isAfter(peerReadAt!);
      rows.add(_Bubble(message: m, grouped: grouped, showStatus: i == lastMine, read: read, onLongPress: () => _messageActions(m)));
    }
    if (peerTyping) rows.add(_TypingBubble(name: widget.peerName));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=messages'),
        titleSpacing: 0,
        title: InkWell(
          onTap: widget.peerId == null ? null : () => context.push('/members/${widget.peerId}'),
          child: Row(
            children: [
              MemberAvatar(name: widget.peerName, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.peerName, style: context.text.titleMedium, overflow: TextOverflow.ellipsis),
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        peerTyping ? 'typing…' : 'Private conversation',
                        key: ValueKey(peerTyping),
                        style: context.text.bodySmall?.copyWith(color: peerTyping ? lux.accentText : null),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.peerId != null)
            PopupMenuButton<String>(
              tooltip: 'Conversation options',
              onSelected: (_) => _block(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'block', child: Text('Block member'))],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? ErrorState(message: error!, onRetry: _bootstrap)
                : messages.isEmpty
                ? EmptyState(icon: Icons.waving_hand_outlined, title: 'Say hello', message: 'Messages are private between you and ${widget.peerName}.')
                : CenteredContent(
                    maxWidth: 820,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                      children: rows,
                    ),
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: lux.surface,
              border: Border(top: BorderSide(color: lux.border)),
            ),
            child: SafeArea(
              top: false,
              child: CenteredContent(
                maxWidth: 820,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Message',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              borderSide: BorderSide(color: lux.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              borderSide: BorderSide(color: lux.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              borderSide: const BorderSide(color: AppColors.gold),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: _ctrl.text.trim().isEmpty ? null : _send,
                        style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.black, minimumSize: const Size(52, 52)),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(label, style: context.text.labelSmall?.copyWith(color: context.lux.textMuted)),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.grouped, required this.showStatus, required this.read, this.onLongPress});
  final ChatMessage message;
  final bool grouped;
  final bool showStatus;
  final bool read;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final lux = context.lux;
    final mine = m.mine;
    const r = Radius.circular(AppRadii.lg);
    const tight = Radius.circular(AppRadii.sm / 2);
    final radius = BorderRadius.only(topLeft: r, topRight: r, bottomLeft: mine ? r : (grouped ? r : tight), bottomRight: mine ? (grouped ? r : tight) : r);
    final time = DateFormat.jm().format(m.createdAt.toLocal());
    final bg = mine ? (context.isDark ? const Color(0xFF3A2E15) : AppColors.champagne) : lux.surfaceRaised;
    return Semantics(
      label: '${mine ? 'You' : m.senderName}: ${m.body ?? 'shared a post'}, $time${showStatus ? (read ? ', read' : ', sent') : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(top: grouped ? 2 : AppSpacing.sm),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width * 0.75).clamp(200, 520)),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                    border: mine ? null : Border.all(color: lux.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.sharedPostId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.article_outlined, size: 16, color: lux.accentText),
                              const SizedBox(width: 4),
                              Text('Shared post', style: context.text.labelSmall),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Text(m.body ?? '', style: context.text.bodyLarge),
                      ),
                      const SizedBox(height: 2),
                      Text(time, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              if (showStatus)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: read ? lux.accentText : lux.textMuted),
                      const SizedBox(width: 3),
                      Text(read ? 'Read' : 'Sent', style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.name});
  final String name;
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${widget.name} is typing',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.lux.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: context.lux.border),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
