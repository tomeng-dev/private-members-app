import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';

/// A demo account returned by GET /api/dev/accounts (development only).
class DevAccount {
  const DevAccount({required this.email, required this.name, required this.status, this.founding = false, this.roles = const []});
  final String email;
  final String name;
  final String status;
  final bool founding;
  final List<String> roles;

  factory DevAccount.fromJson(Map<String, dynamic> j) => DevAccount(
    email: j['email'] as String,
    name: j['name'] as String? ?? j['email'] as String,
    status: j['status'] as String? ?? 'active',
    founding: j['foundingMember'] as bool? ?? false,
    roles: ((j['roles'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

typedef DevAccountsLoader = Future<List<DevAccount>> Function();

/// DEV ONLY account picker. The login page only builds this widget when
/// `AppConfig.isDevelopment` (a compile-time const) is true, so it is
/// tree-shaken from production builds. The API also 404s /dev/* in production.
class DevQuickLogin extends StatefulWidget {
  const DevQuickLogin({super.key, required this.loader, required this.onPick});
  final DevAccountsLoader loader;
  final ValueChanged<DevAccount> onPick;

  @override
  State<DevQuickLogin> createState() => _DevQuickLoginState();
}

class _DevQuickLoginState extends State<DevQuickLogin> {
  late Future<List<DevAccount>> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return Container(
      key: const Key('dev-quick-login'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: lux.warning.withValues(alpha: 0.6)),
        color: lux.warning.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode, color: lux.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Dev quick login', style: context.text.titleSmall?.copyWith(color: lux.warning)),
              const Spacer(),
              StatusPill('DEVELOPMENT', color: lux.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Demo accounts — not available in production builds.', style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<DevAccount>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Column(children: [Skeleton(height: 48), SizedBox(height: 8), Skeleton(height: 48)]);
              }
              if (snap.hasError || (snap.data ?? []).isEmpty) {
                return Row(
                  children: [
                    Expanded(child: Text('No demo accounts (is the API seeded and running?)', style: context.text.bodySmall)),
                    TextButton(onPressed: () => setState(() => _future = widget.loader()), child: const Text('Retry')),
                  ],
                );
              }
              return Column(
                children: [
                  for (final a in snap.data!)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      leading: MemberAvatar(name: a.name, size: 36, founding: a.founding),
                      title: Text(a.name, style: context.text.titleSmall),
                      subtitle: Text('${a.email} · ${a.status}${a.roles.contains('moderator') ? ' · moderator' : ''}'),
                      trailing: const Icon(Icons.login_rounded),
                      enabled: a.status == 'active' || a.status == 'suspended',
                      onTap: () => widget.onPick(a),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
