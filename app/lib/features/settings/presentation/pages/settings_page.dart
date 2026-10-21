import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/ui/ui.dart';

/// Settings & privacy: appearance, notifications, data export, deletion, sign out.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ref.read(apiClientProvider).raw.get('/members/me/export');
      final size = res.data.toString().length;
      if (context.mounted) showToast(context, 'Your data export is ready (${(size / 1024).toStringAsFixed(1)} KB)', kind: ToastKind.success);
    } catch (_) {
      if (context.mounted) showToast(context, 'Export failed — please try again', kind: ToastKind.error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message: 'Your account is scheduled for deletion after a 30-day grace period. You can cancel by signing in again before then.',
      confirmLabel: 'Request deletion',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiClientProvider).raw.post('/members/me/delete');
      if (context.mounted) showToast(context, 'Deletion scheduled. We\u2019re sorry to see you go.', kind: ToastKind.success);
    } catch (_) {
      if (context.mounted) showToast(context, 'Could not request deletion', kind: ToastKind.error);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: 'Sign out?', message: 'You can sign back in at any time.', confirmLabel: 'Sign out');
    if (!ok) return;
    ref.read(socketServiceProvider).disconnect();
    await ref.read(authRepositoryProvider).logout();
    ref.read(authSessionProvider.notifier).setLoggedIn(false);
    if (context.mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    Widget group(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        LuxCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(children: children),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=profile'),
        title: const Text('Settings & privacy'),
      ),
      body: CenteredContent(
        maxWidth: 720,
        child: ListView(
          padding: pagePadding(context, top: 0),
          children: [
            const SectionHeader('Appearance', subtitle: 'Dark is recommended for evening events'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest_outlined)),
              ],
              selected: {mode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
            group('Notifications', [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Push & email preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/notifications'),
              ),
            ]),
            group('Privacy & data', [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Profile visibility'),
                subtitle: const Text('Choose what other members can see'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/edit'),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export my data'),
                subtitle: const Text('Download a copy of your information'),
                onTap: () => _export(context, ref),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.lux.danger),
                title: Text('Delete account', style: TextStyle(color: context.lux.danger)),
                subtitle: const Text('30-day grace period'),
                onTap: () => _delete(context, ref),
              ),
            ]),
            group('Account', [ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Sign out'), onTap: () => _signOut(context, ref))]),
            const SizedBox(height: AppSpacing.xl),
            Center(child: Text('Private Members · v1.0.0${AppConfig.isDevelopment ? ' · development build' : ''}', style: context.text.bodySmall)),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
