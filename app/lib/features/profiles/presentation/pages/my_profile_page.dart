import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/member_profile.dart';
import '../widgets/profile_view.dart';

class MyProfilePage extends ConsumerStatefulWidget {
  const MyProfilePage({super.key});
  @override
  ConsumerState<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends ConsumerState<MyProfilePage> {
  MemberProfile? profile;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      profile = await ref.read(profilesRepositoryProvider).myProfile();
      error = null;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _go(String path) async {
    await context.push(path);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SkeletonList(count: 2, media: true);
    if (profile == null) return ErrorState(message: error ?? 'Profile unavailable', onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ProfileView(
        profile: profile!,
        actions: [
          LuxButton(label: 'Edit profile', icon: Icons.edit_outlined, onPressed: () => _go('/profile/edit')),
          LuxButton.secondary(label: 'Garage', icon: Icons.directions_car_outlined, onPressed: () => _go('/profile/vehicles')),
          LuxButton.secondary(label: 'Business', icon: Icons.business_center_outlined, onPressed: () => _go('/profile/business')),
        ],
        extra: [
          const SectionHeader('Account'),
          LuxCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/notifications'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Settings & privacy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
