import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/ui/ui.dart';
import '../../../events/presentation/pages/events_list_page.dart';
import '../../../feed/presentation/pages/feed_page.dart';
import '../../../messaging/presentation/pages/conversations_page.dart';
import '../../../profiles/presentation/pages/members_directory_page.dart';
import '../../../profiles/presentation/pages/my_profile_page.dart';

class _Tab {
  const _Tab(this.name, this.label, this.icon, this.selectedIcon);
  final String name;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Responsive app shell:
/// * < 600dp: bottom NavigationBar (5 tabs) + top app bar
/// * 600–900dp: NavigationRail
/// * >= 900dp: full sidebar with brand, compose action and account footer
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  static const tabs = [
    _Tab('feed', 'Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('events', 'Events', Icons.event_outlined, Icons.event_rounded),
    _Tab('members', 'Members', Icons.people_outline, Icons.people_rounded),
    _Tab('messages', 'Messages', Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
    _Tab('profile', 'Profile', Icons.person_outline, Icons.person_rounded),
  ];

  static int tabFromName(String? name) {
    final i = tabs.indexWhere((t) => t.name == name);
    return i < 0 ? 0 : i;
  }

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int index = widget.initialTab;
  final _visited = <int>{};
  int unread = 0;

  @override
  void initState() {
    super.initState();
    _visited.add(index);
    _loadUnread();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Deep links such as /home?tab=events re-use this state; follow the URL.
    if (oldWidget.initialTab != widget.initialTab) _select(widget.initialTab);
  }

  Future<void> _loadUnread() async {
    try {
      final items = await ref.read(notificationsRepositoryProvider).list(limit: 50);
      if (mounted) setState(() => unread = items.where((n) => n['readAt'] == null).length);
    } catch (_) {}
  }

  void _select(int i) {
    setState(() {
      index = i;
      _visited.add(i);
    });
  }

  Widget _page(int i) => switch (i) {
    0 => const FeedPage(),
    1 => const EventsListPage(),
    2 => const MembersDirectoryPage(),
    3 => const ConversationsPage(),
    _ => const MyProfilePage(),
  };

  Widget _body() =>
      IndexedStack(index: index, children: [for (var i = 0; i < HomeShell.tabs.length; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink()]);

  Widget _bell() => Semantics(
    label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
    button: true,
    child: IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await context.push('/notifications');
        _loadUnread();
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: AppColors.gold,
        textColor: AppColors.black,
        child: const Icon(Icons.notifications_none_rounded, size: 26),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;
    final tab = HomeShell.tabs[index];
    if (size == ScreenSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: index == 0 ? const _Wordmark() : Text(tab.label),
          actions: [
            _bell(),
            if (index == 4) IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: _body(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          destinations: [
            for (final t in HomeShell.tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label, tooltip: t.label),
          ],
        ),
      );
    }

    final lux = context.lux;
    final header = Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lux.border)),
      ),
      child: Row(
        children: [
          Semantics(header: true, child: Text(tab.label, style: context.text.headlineMedium)),
          const Spacer(),
          if (AppConfig.isDevelopment)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: StatusPill('DEV BUILD', icon: Icons.code),
            ),
          _bell(),
          IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
    );

    final nav = size == ScreenSize.medium
        ? NavigationRail(
            selectedIndex: index,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: _Monogram(),
            ),
            destinations: [
              for (final t in HomeShell.tabs) NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: Text(t.label)),
            ],
          )
        : _Sidebar(index: index, onSelect: _select);

    return Scaffold(
      body: Row(
        children: [
          nav,
          VerticalDivider(width: 1, color: lux.border),
          Expanded(
            child: Column(
              children: [
                header,
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lux = context.lux;
    return Container(
      width: 264,
      color: lux.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xxl),
            child: _Wordmark(large: true),
          ),
          for (var i = 0; i < HomeShell.tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _SideItem(tab: HomeShell.tabs[i], selected: i == index, onTap: () => onSelect(i)),
            ),
          const SizedBox(height: AppSpacing.xl),
          LuxButton(label: 'New post', icon: Icons.edit_outlined, expand: true, onPressed: () => context.push('/compose')),
          const Spacer(),
          Divider(color: lux.border),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text('Sign out', style: context.text.titleSmall),
            onTap: () async {
              ref.read(socketServiceProvider).disconnect();
              await ref.read(authRepositoryProvider).logout();
              ref.read(authSessionProvider.notifier).setLoggedIn(false);
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.tab, required this.selected, required this.onTap});
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: Material(
        color: selected ? (context.isDark ? const Color(0xFF2A2315) : AppColors.champagne) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(selected ? tab.selectedIcon : tab.icon, color: selected ? lux.accentText : lux.textMuted),
                const SizedBox(width: AppSpacing.md),
                ExcludeSemantics(
                  child: Text(
                    tab.label,
                    style: context.text.titleMedium?.copyWith(
                      color: selected ? lux.textPrimary : lux.textMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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

class _Monogram extends StatelessWidget {
  const _Monogram();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.gold, width: 1.5),
    ),
    child: const Text(
      'PM',
      style: TextStyle(fontFamily: AppFonts.serif, fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.gold),
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Private Members',
    header: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (large) ...[const _Monogram(), const SizedBox(width: AppSpacing.md)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Private Members',
                style: TextStyle(fontFamily: AppFonts.serif, fontSize: large ? 20 : 22, fontWeight: FontWeight.w600, color: context.lux.textPrimary),
              ),
              if (large)
                Text(
                  'AUTOMOTIVE CLUB',
                  style: TextStyle(fontFamily: AppFonts.sans, fontSize: 10.5, letterSpacing: 2.2, fontWeight: FontWeight.w600, color: context.lux.accentText),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
