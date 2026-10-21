import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/member_profile.dart';

class MembersDirectoryPage extends ConsumerStatefulWidget {
  const MembersDirectoryPage({super.key});
  @override
  ConsumerState<MembersDirectoryPage> createState() => _MembersDirectoryPageState();
}

class _MembersDirectoryPageState extends ConsumerState<MembersDirectoryPage> {
  final q = TextEditingController();
  Timer? _debounce;
  List<MemberListItem> items = [];
  List<Map<String, dynamic>> events = [];
  String? eventId;
  String? eventTitle;
  bool foundingOnly = false;
  String? city;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    q.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final r = await Future.wait([repo.list(filter: 'past'), repo.list(filter: 'upcoming')]);
      events = [...r[0], ...r[1]];
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      items = await ref.read(profilesRepositoryProvider).listMembers(q: q.text.trim(), eventId: eventId);
    } on Failure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load members.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  List<MemberListItem> get _visible => items.where((m) => (!foundingOnly || m.foundingMember) && (city == null || m.city == city)).toList();

  Future<void> _pickEvent() async {
    final chosen = await showLuxSheet<Map<String, dynamic>>(
      context,
      title: 'Attended event',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(leading: const Icon(Icons.clear_all), title: const Text('Any event'), onTap: () => Navigator.pop(ctx, <String, dynamic>{})),
          for (final e in events)
            ListTile(leading: const Icon(Icons.event_outlined), title: Text(e['title']?.toString() ?? 'Event'), onTap: () => Navigator.pop(ctx, e)),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
    if (chosen == null) return;
    setState(() {
      eventId = chosen['id'] as String?;
      eventTitle = chosen['title'] as String?;
    });
    await _load();
  }

  Future<void> _message(MemberListItem m) async {
    try {
      final id = await ref.read(messagingRepositoryProvider).startConversation(m.id);
      if (mounted) context.push('/messages/$id?name=${Uri.encodeComponent('${m.firstName} ${m.lastName}')}&peer=${m.id}');
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = items.map((m) => m.city).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()..sort();
    final visible = _visible;
    final hPad = context.isCompact ? AppSpacing.lg : AppSpacing.xl;
    return CenteredContent(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.lg, hPad, AppSpacing.sm),
            child: TextField(
              controller: q,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, company, city or vehicle',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: q.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          q.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.xs),
              children: [
                FilterChip(
                  label: const Text('Founding'),
                  avatar: const Icon(Icons.star_rounded, size: 18),
                  selected: foundingOnly,
                  onSelected: (v) => setState(() => foundingOnly = v),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  label: Text(eventTitle ?? 'Attended event'),
                  avatar: const Icon(Icons.event_outlined, size: 18),
                  selected: eventId != null,
                  onSelected: (_) => _pickEvent(),
                ),
                for (final c in cities.take(6)) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(label: Text(c), selected: city == c, onSelected: (v) => setState(() => city = v ? c : null)),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.xs, hPad, AppSpacing.sm),
            child: Row(
              children: [Text(loading ? 'Loading members…' : '${visible.length} member${visible.length == 1 ? '' : 's'}', style: context.text.bodySmall)],
            ),
          ),
          Expanded(
            child: loading
                ? SkeletonList(count: 4, padding: EdgeInsets.symmetric(horizontal: hPad))
                : error != null
                ? ErrorState(message: error!, onRetry: _load)
                : visible.isEmpty
                ? const EmptyState(icon: Icons.person_search_outlined, title: 'No members found', message: 'Try a different search or clear filters.')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final cols = gridColumns(c.maxWidth, minTile: 300, max: 4);
                        if (cols == 1) {
                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppSpacing.xxl),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) => _MemberTile(m: visible[i], onMessage: () => _message(visible[i])),
                          );
                        }
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppSpacing.xxl),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: AppSpacing.lg,
                            crossAxisSpacing: AppSpacing.lg,
                            mainAxisExtent: 250 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4),
                          ),
                          itemCount: visible.length,
                          itemBuilder: (_, i) => _MemberCard(m: visible[i], onMessage: () => _message(visible[i])),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.m, required this.onMessage});
  final MemberListItem m;
  final VoidCallback onMessage;
  @override
  Widget build(BuildContext context) {
    final name = '${m.firstName} ${m.lastName}';
    return LuxCard(
      onTap: () => context.push('/members/${m.id}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          MemberAvatar(name: name, size: 52, founding: m.foundingMember, heroTag: 'avatar-${m.id}'),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: context.text.titleMedium, overflow: TextOverflow.ellipsis),
                    ),
                    if (m.foundingMember) ...[const SizedBox(width: AppSpacing.sm), const FoundingBadge(compact: true)],
                  ],
                ),
                Text(
                  [m.title, m.company].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((m.city ?? '').isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: context.lux.textMuted),
                      const SizedBox(width: 2),
                      Text(m.city!, style: context.text.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Message $name',
            onPressed: onMessage,
            icon: Icon(Icons.chat_bubble_outline, color: context.lux.accentText),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.m, required this.onMessage});
  final MemberListItem m;
  final VoidCallback onMessage;
  @override
  Widget build(BuildContext context) {
    final name = '${m.firstName} ${m.lastName}';
    return LuxCard(
      onTap: () => context.push('/members/${m.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  bottom: 40,
                  child: CoverArt(seed: m.id, height: 68, icon: Icons.blur_on),
                ),
                Positioned(
                  bottom: 0,
                  child: MemberAvatar(name: name, size: 76, founding: m.foundingMember, heroTag: 'avatar-${m.id}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                Text(name, style: context.text.titleMedium, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [m.title, m.company].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((m.city ?? '').isNotEmpty) Text(m.city!, style: context.text.bodySmall),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(onPressed: onMessage, icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Message')),
            ),
          ),
        ],
      ),
    );
  }
}
