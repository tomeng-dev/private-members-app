import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/ui/ui.dart';
import 'shell.dart';

/// Console preferences and read-only environment information.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider).value ?? '…';
    final mode = ref.watch(themeModeProvider);
    final user = ref.watch(staffUserProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    return PageScaffold(
      scroll: true,
      maxWidth: 960,
      title: 'Settings',
      subtitle: 'Console preferences and environment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: context.text.titleSmall),
                const SizedBox(height: Gap.sm),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
                  ],
                  selected: {mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark},
                  onSelectionChanged: (s) {
                    if (s.first != mode) ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
                const SizedBox(height: Gap.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compact sidebar'),
                  subtitle: Text('Icons only. Automatically enabled on narrow windows.', style: context.text.bodySmall),
                  value: collapsed ?? MediaQuery.sizeOf(context).width < 1100,
                  onChanged: (v) => ref.read(sidebarCollapsedProvider.notifier).set(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          SectionCard(
            title: 'Your account',
            child: Column(
              children: [
                InfoRow('Name', user == null ? '—' : fullName(user)),
                InfoRow('Email', '${user?['email'] ?? '—'}'),
                InfoRow(
                  'Roles',
                  ((user?['roles'] as List?) ?? const []).map((e) => humanize('$e')).join(', ').trim().isEmpty
                      ? '—'
                      : ((user?['roles'] as List?) ?? const []).map((e) => humanize('$e')).join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          SectionCard(
            title: 'Environment',
            child: Column(
              children: [
                InfoRow('Environment', env, trailing: EnvBadge(env: env)),
                const InfoRow('API base URL', AppConfig.apiBaseUrl),
                const InfoRow('Keyboard', 'Ctrl/⌘ K — global search · Tab / Enter — navigate tables · Esc — close'),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          SectionCard(
            title: 'Security',
            child: Text(
              'Staff accounts require two-factor authentication in production. Every administrative action — approvals, suspensions, role and dues changes, '
              'broadcasts and moderation — is written to the audit log with actor, IP and timestamp.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
