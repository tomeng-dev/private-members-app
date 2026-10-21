import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/ui/ui.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final has = await ref.read(authRepositoryProvider).hasSession();
    if (!mounted) return;
    ref.read(authSessionProvider.notifier).setLoggedIn(has);
    context.go(has ? '/home' : '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Private Members',
              style: TextStyle(fontFamily: AppFonts.serif, fontSize: 34, color: AppColors.white, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'AUTOMOTIVE CLUB',
              style: TextStyle(fontFamily: AppFonts.sans, fontSize: 12, letterSpacing: 3, color: AppColors.gold, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.xxl),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}
