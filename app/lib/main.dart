import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MemberApp()));
}

class MemberApp extends ConsumerStatefulWidget {
  const MemberApp({super.key});
  @override
  ConsumerState<MemberApp> createState() => _MemberAppState();
}

class _MemberAppState extends ConsumerState<MemberApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPush());
  }

  Future<void> _initPush() async {
    final router = ref.read(appRouterProvider);
    await ref
        .read(pushMessagingProvider)
        .init(
          deepLink: (data) {
            final type = data['type']?.toString();
            final id = data['id']?.toString() ?? data['postId']?.toString() ?? data['eventId']?.toString() ?? data['conversationId']?.toString();
            if (type == null) return;
            if (type.contains('message') && id != null) {
              router.go('/messages/$id');
            } else if (type.contains('event') && id != null) {
              router.go('/events/$id');
            } else if (type.contains('post') && id != null) {
              router.go('/posts/$id');
            } else if (type.contains('notification')) {
              router.go('/notifications');
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scaler = mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6);
        return MediaQuery(
          data: mq.copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      title: 'Private Members',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
