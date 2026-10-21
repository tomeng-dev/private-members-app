import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Honor system text scaling; clamp extreme values for layout safety.
        final scaler = mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6);
        return MediaQuery(
          data: mq.copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      title: 'Private Members · Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
