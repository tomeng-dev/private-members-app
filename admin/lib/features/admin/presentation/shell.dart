import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/ui/ui.dart';

class NavItem {
  const NavItem(this.label, this.route, this.icon, {this.badgeKey, this.exact = false});
  final String label;
  final String route;
  final IconData icon;
  final String? badgeKey;
  final bool exact;
}

class NavGroup {
  const NavGroup(this.label, this.items);
  final String label;
  final List<NavItem> items;
}

const navGroups = [
  NavGroup('', [NavItem('Overview', '/overview', Icons.space_dashboard_outlined)]),
  NavGroup('Membership', [
    NavItem('Applications', '/applications', Icons.inbox_outlined, badgeKey: 'applications'),
    NavItem('Members', '/members', Icons.people_outline_rounded),
    NavItem('Vehicles', '/vehicles', Icons.verified_outlined, badgeKey: 'vehicles'),
    NavItem('Dues', '/dues', Icons.receipt_long_outlined, badgeKey: 'dues'),
    NavItem('Invites', '/invites', Icons.key_outlined),
  ]),
  NavGroup('Events', [NavItem('Events', '/events', Icons.event_outlined), NavItem('Check-in', '/checkin', Icons.qr_code_scanner_rounded)]),
  NavGroup('Community', [
    NavItem('Content reports', '/reports', Icons.flag_outlined, badgeKey: 'reports', exact: true),
    NavItem('Message reports', '/reports/messages', Icons.mark_chat_unread_outlined),
    NavItem('Broadcast', '/broadcast', Icons.campaign_outlined),
  ]),
  NavGroup('Administration', [
    NavItem('Audit log', '/audit', Icons.history_rounded),
    NavItem('Staff & roles', '/staff', Icons.admin_panel_settings_outlined),
    NavItem('Settings', '/settings', Icons.settings_outlined),
  ]),
];

/// Pending-task counts for sidebar badges and the overview.
final consoleStatsProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepositoryProvider).consoleStats());

class SidebarCollapsedNotifier extends Notifier<bool?> {
  @override
  bool? build() => null; // null = automatic (collapsed below 1100px)
  void set(bool v) => state = v;
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool?>(SidebarCollapsedNotifier.new);

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _searchFocus = FocusNode(debugLabel: 'global-search');
  final _collapsedGroups = <String>{};

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  bool _isActive(NavItem item) {
    final path = Uri.parse(widget.location).path;
    if (item.exact) return path == item.route || (path.startsWith('${item.route}/') && !path.startsWith('/reports/messages'));
    return path == item.route || path.startsWith('${item.route}/');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final collapsed = ref.watch(sidebarCollapsedProvider) ?? width < 1100;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _FocusSearchIntent(),
      },
      child: Actions(
        actions: {_FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (_) => _searchFocus.requestFocus())},
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(
                collapsed: collapsed,
                isActive: _isActive,
                collapsedGroups: _collapsedGroups,
                onToggleGroup: (g) => setState(() => _collapsedGroups.contains(g) ? _collapsedGroups.remove(g) : _collapsedGroups.add(g)),
                onToggleCollapsed: () => ref.read(sidebarCollapsedProvider.notifier).set(!collapsed),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(searchFocus: _searchFocus),
                    Expanded(child: FocusTraversalGroup(child: widget.child)),
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

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.collapsed,
    required this.isActive,
    required this.collapsedGroups,
    required this.onToggleGroup,
    required this.onToggleCollapsed,
  });
  final bool collapsed;
  final bool Function(NavItem) isActive;
  final Set<String> collapsedGroups;
  final ValueChanged<String> onToggleGroup;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(consoleStatsProvider).value;
    final badges = <String, int>{for (final p in (stats?['pendingTasks'] as List? ?? const [])) '${(p as Map)['key']}': (p['count'] as num?)?.toInt() ?? 0};
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 76 : 256,
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Semantics(
        container: true,
        label: 'Main navigation',
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : Gap.lg),
                child: Row(
                  mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: const Text(
                        'PM',
                        style: TextStyle(fontFamily: AppFonts.serif, color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Private Members', style: context.text.titleMedium?.copyWith(fontFamily: AppFonts.serif, fontSize: 16)),
                            Text('ADMIN CONSOLE', style: context.text.labelSmall?.copyWith(color: t.accentText, fontSize: 9.5, letterSpacing: 1.6)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: t.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
                children: [
                  for (final g in navGroups) ...[
                    if (g.label.isNotEmpty)
                      collapsed
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.lg),
                              child: Divider(height: 1, color: t.border),
                            )
                          : _GroupHeader(label: g.label, open: !collapsedGroups.contains(g.label), onTap: () => onToggleGroup(g.label)),
                    if (collapsed || g.label.isEmpty || !collapsedGroups.contains(g.label))
                      for (final item in g.items)
                        _NavTile(item: item, active: isActive(item), collapsed: collapsed, badge: item.badgeKey == null ? 0 : (badges[item.badgeKey] ?? 0)),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Tooltip(
                message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: onToggleCollapsed,
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        if (!collapsed) const SizedBox(width: Gap.md),
                        Icon(collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded, size: 20, color: t.textMuted),
                        if (!collapsed) ...[const SizedBox(width: Gap.md), Text('Collapse', style: context.text.bodySmall?.copyWith(fontSize: 13))],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.open, required this.onTap});
  final String label;
  final bool open;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      label: '$label section',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.sm, Gap.xs + 2),
          child: Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: context.text.labelSmall?.copyWith(fontSize: 10.5, letterSpacing: 1.2))),
              AnimatedRotation(
                turns: open ? 0 : -0.25,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.expand_more_rounded, size: 16, color: context.tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.collapsed, this.badge = 0});
  final NavItem item;
  final bool active;
  final bool collapsed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = active ? t.textPrimary : t.textMuted;
    final badgeW = badge > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(Radii.pill)),
            child: Text(
              '$badge',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.black),
            ),
          )
        : null;
    final tile = Semantics(
      button: true,
      selected: active,
      label: '${item.label}${badge > 0 ? ', $badge pending' : ''}',
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.gold.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => context.go(item.route),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: Gap.md),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon, size: 20, color: active ? t.accentText : fg),
                    if (collapsed && badge > 0)
                      Positioned(
                        right: -4,
                        top: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                if (!collapsed) ...[
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: fg),
                    ),
                  ),
                  ?badgeW,
                  const SizedBox(width: Gap.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: collapsed ? Tooltip(message: item.label, preferBelow: false, child: tile) : tile,
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.searchFocus});
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final env = ref.watch(environmentProvider).value ?? 'DEV';
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      decoration: BoxDecoration(
        color: t.canvas,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: GlobalSearch(focusNode: searchFocus),
            ),
          ),
          const SizedBox(width: Gap.lg),
          EnvBadge(env: env),
          const SizedBox(width: Gap.md),
          IconButton(
            tooltip: 'Refresh data',
            onPressed: () {
              ref.invalidate(consoleStatsProvider);
              showToast(context, 'Refreshed');
            },
            icon: Icon(Icons.refresh_rounded, color: t.textMuted),
          ),
          const SizedBox(width: Gap.xs),
          const _ProfileMenu(),
        ],
      ),
    );
  }
}

class EnvBadge extends StatelessWidget {
  const EnvBadge({super.key, required this.env});
  final String env;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = switch (env) {
      'PROD' => t.danger,
      'STAGING' => t.info,
      _ => t.warning,
    };
    return Tooltip(
      message: switch (env) {
        'PROD' => 'Production — changes affect real members',
        'STAGING' => 'Staging environment',
        _ => 'Development environment — demo data',
      },
      child: Semantics(
        label: 'Environment: $env',
        excludeSemantics: true,
        child: Container(
          key: const Key('env-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: c.withValues(alpha: 0.5)),
          ),
          child: Text(
            env,
            style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(staffUserProvider);
    final name = user == null ? 'Staff' : fullName(user);
    final roles = ((user?['roles'] as List?) ?? const []).map((e) => '$e').where((r) => r != 'member').toList();
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 6),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.text.titleSmall),
              if (user?['email'] != null) Text('${user!['email']}', style: context.text.bodySmall),
              if (roles.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                Wrap(spacing: 4, children: [for (final r in roles) StatusChip(r, dense: true)]),
              ],
            ],
          ),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          child: Text(isDark ? 'Light theme' : 'Dark theme'),
        ),
        MenuItemButton(leadingIcon: const Icon(Icons.settings_outlined, size: 18), onPressed: () => context.go('/settings'), child: const Text('Settings')),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded, size: 18),
          onPressed: () async {
            await ref.read(authRepositoryProvider).logout();
            ref.read(adminSessionProvider.notifier).setLoggedIn(false);
            await ref.read(staffUserProvider.notifier).set(null);
            if (context.mounted) context.go('/login');
          },
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, ctrl, _) => Semantics(
        button: true,
        label: 'Account menu for $name',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Avatar(name: name, size: 34),
                if (MediaQuery.sizeOf(context).width > 1000) ...[
                  const SizedBox(width: Gap.sm),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.text.titleSmall?.copyWith(fontSize: 13)),
                      Text(roles.isEmpty ? 'Staff' : humanize(roles.first), style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
                    ],
                  ),
                  const SizedBox(width: Gap.xs),
                  Icon(Icons.expand_more_rounded, size: 18, color: context.tokens.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Global search
// ---------------------------------------------------------------------------

class GlobalSearch extends ConsumerStatefulWidget {
  const GlobalSearch({super.key, required this.focusNode});
  final FocusNode focusNode;
  @override
  ConsumerState<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends ConsumerState<GlobalSearch> {
  final _ctrl = TextEditingController();
  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  Timer? _debounce;
  Map<String, dynamic>? _results;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (!widget.focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !widget.focusNode.hasFocus) _overlay.hide();
        });
      } else if (_results != null) {
        _overlay.show();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = null);
      _overlay.hide();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loading = true);
      try {
        final r = await ref.read(adminRepositoryProvider).globalSearch(q.trim());
        if (!mounted) return;
        setState(() => _results = r);
        _overlay.show();
      } catch (_) {
        if (mounted) setState(() => _results = {'members': [], 'applications': [], 'events': []});
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _go(String route) {
    _overlay.hide();
    _ctrl.clear();
    setState(() => _results = null);
    widget.focusNode.unfocus();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (context) => Positioned(
          width: 520,
          child: CompositedTransformFollower(
            link: _link,
            offset: const Offset(0, 50),
            showWhenUnlinked: false,
            child: _SearchResults(results: _results ?? const {}, onOpen: _go),
          ),
        ),
        child: SizedBox(
          width: 460,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                _overlay.hide();
                widget.focusNode.unfocus();
              },
            },
            child: TextField(
              key: const Key('global-search'),
              controller: _ctrl,
              focusNode: widget.focusNode,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search members, applications, events…',
                prefixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.search_rounded, size: 20),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.tokens.border),
                      ),
                      child: Text('Ctrl K', style: context.text.labelSmall?.copyWith(fontSize: 10)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onOpen});
  final Map<String, dynamic> results;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final members = (results['members'] as List? ?? const []).cast<Map>();
    final apps = (results['applications'] as List? ?? const []).cast<Map>();
    final events = (results['events'] as List? ?? const []).cast<Map>();
    final t = context.tokens;
    Widget section(String label, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xs),
          child: Text(label.toUpperCase(), style: context.text.labelSmall),
        ),
        ...children,
      ],
    );
    Widget tile({required Widget leading, required String title, String? subtitle, Widget? trailing, required String route}) => ListTile(
      dense: true,
      leading: leading,
      title: Text(title, style: context.text.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle, style: context.text.bodySmall),
      trailing: trailing,
      onTap: () => onOpen(route),
    );
    final empty = members.isEmpty && apps.isEmpty && events.isEmpty;
    return Material(
      color: t.surfaceRaised,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: t.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: empty
            ? Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Text('No matches', style: context.text.bodySmall),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Gap.sm),
                children: [
                  if (members.isNotEmpty)
                    section('Members', [
                      for (final m in members)
                        tile(
                          leading: Avatar(name: fullName(Map<String, dynamic>.from(m)), founding: m['foundingMember'] == true, size: 30),
                          title: fullName(Map<String, dynamic>.from(m)),
                          subtitle: '${m['email']}',
                          trailing: StatusChip('${m['status']}', dense: true),
                          route: '/members?open=${m['id']}',
                        ),
                    ]),
                  if (apps.isNotEmpty)
                    section('Applications', [
                      for (final a in apps)
                        tile(
                          leading: const Icon(Icons.inbox_outlined, size: 20),
                          title: fullName(Map<String, dynamic>.from(a)),
                          subtitle: '${a['email']}',
                          trailing: StatusChip('${a['status']}', dense: true),
                          route: '/applications/${a['id']}',
                        ),
                    ]),
                  if (events.isNotEmpty)
                    section('Events', [
                      for (final e in events)
                        tile(
                          leading: const Icon(Icons.event_outlined, size: 20),
                          title: '${e['title']}',
                          subtitle: fmtDate(e['startsAt'], time: true),
                          trailing: StatusChip('${e['status']}', dense: true),
                          route: '/events/${e['id']}',
                        ),
                    ]),
                ],
              ),
      ),
    );
  }
}
