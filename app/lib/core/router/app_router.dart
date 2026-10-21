import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/applications/presentation/pages/application_status_page.dart';
import '../../features/applications/presentation/pages/apply_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/set_password_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/events/presentation/pages/event_archive_page.dart';
import '../../features/events/presentation/pages/event_attendees_page.dart';
import '../../features/events/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/event_thread_page.dart';
import '../../features/events/presentation/pages/event_ticket_page.dart';
import '../../features/feed/domain/entities/post.dart';
import '../../features/feed/presentation/pages/compose_page.dart';
import '../../features/feed/presentation/pages/post_detail_page.dart';
import '../../features/messaging/presentation/pages/chat_page.dart';
import '../../features/notifications/presentation/pages/notification_prefs_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profiles/presentation/pages/business_page_editor.dart';
import '../../features/profiles/presentation/pages/edit_profile_page.dart';
import '../../features/profiles/presentation/pages/member_profile_page.dart';
import '../../features/profiles/presentation/pages/vehicles_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/home_shell.dart';
import '../theme/tokens.dart';

/// Shared fade-through + slight rise transition (respects reduce-motion).
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.standard);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

GoRoute _r(String path, Widget Function(GoRouterState s) build) => GoRoute(path: path, pageBuilder: (_, s) => _page(s, build(s)));

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      _r('/', (_) => const SplashPage()),
      _r('/welcome', (_) => const WelcomePage()),
      _r('/login', (_) => const LoginPage()),
      _r('/forgot-password', (_) => const ForgotPasswordPage()),
      _r('/set-password', (s) => SetPasswordPage(token: s.uri.queryParameters['token'] ?? '')),
      _r('/reset-password', (s) => SetPasswordPage(token: s.uri.queryParameters['token'] ?? '', isReset: true)),
      _r('/apply', (_) => const ApplyPage()),
      _r('/application-status', (s) => ApplicationStatusPage(email: s.uri.queryParameters['email'] ?? '')),
      _r('/home', (s) => HomeShell(initialTab: HomeShell.tabFromName(s.uri.queryParameters['tab']))),
      _r('/profile/edit', (_) => const EditProfilePage()),
      _r('/profile/vehicles', (_) => const VehiclesPage()),
      _r('/profile/business', (_) => const BusinessPageEditor()),
      _r('/members/:id', (s) => MemberProfilePage(id: s.pathParameters['id']!)),
      _r('/compose', (_) => const ComposePage()),
      _r('/posts/:id', (s) => PostDetailPage(id: s.pathParameters['id']!, post: s.extra is FeedPost ? s.extra as FeedPost : null)),
      _r(
        '/messages/:id',
        (s) => ChatPage(conversationId: s.pathParameters['id']!, peerName: s.uri.queryParameters['name'] ?? 'Chat', peerId: s.uri.queryParameters['peer']),
      ),
      _r('/events/:id', (s) => EventDetailPage(id: s.pathParameters['id']!)),
      _r('/events/:id/thread', (s) => EventThreadPage(eventId: s.pathParameters['id']!)),
      _r('/events/:id/ticket', (s) => EventTicketPage(eventId: s.pathParameters['id']!)),
      _r('/events/:id/attendees', (s) => EventAttendeesPage(eventId: s.pathParameters['id']!)),
      _r('/events/:id/archive', (s) => EventArchivePage(id: s.pathParameters['id']!)),
      _r('/notifications', (_) => const NotificationsPage()),
      _r('/settings', (_) => const SettingsPage()),
      _r('/settings/notifications', (_) => const NotificationPrefsPage()),
    ],
  );
});
