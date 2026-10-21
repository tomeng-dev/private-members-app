import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/presentation/application_detail_page.dart';
import '../../features/admin/presentation/applications_page.dart';
import '../../features/admin/presentation/audit_page.dart';
import '../../features/admin/presentation/broadcast_page.dart';
import '../../features/admin/presentation/checkin_page.dart';
import '../../features/admin/presentation/event_detail_admin_page.dart';
import '../../features/admin/presentation/events_page.dart';
import '../../features/admin/presentation/invites_page.dart';
import '../../features/admin/presentation/member_detail_page.dart';
import '../../features/admin/presentation/members_page.dart';
import '../../features/admin/presentation/overview_page.dart';
import '../../features/admin/presentation/reports_page.dart';
import '../../features/admin/presentation/settings_page.dart';
import '../../features/admin/presentation/shell.dart';
import '../../features/admin/presentation/vehicles_page.dart';
import '../../features/auth/presentation/login_page.dart';

/// Subtle fade for in-console navigation (respects reduced motion).
Page<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 160),
  transitionsBuilder: (context, animation, _, child) => MediaQuery.of(context).disableAnimations
      ? child
      : FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
);

GoRoute _r(String path, Widget Function(GoRouterState s) build) => GoRoute(path: path, pageBuilder: (_, s) => _page(s, build(s)));

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginPage()),
      GoRoute(path: '/', redirect: (_, __) => '/overview'),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.toString(), child: child),
        routes: [
          _r('/overview', (_) => const OverviewPage()),
          _r('/applications', (_) => const ApplicationsPage()),
          _r('/applications/:id', (s) => ApplicationDetailPage(id: s.pathParameters['id']!)),
          GoRoute(
            path: '/members',
            pageBuilder: (_, s) => _page(s, MembersPage(openId: s.uri.queryParameters['open'])),
          ),
          _r('/members/:id', (s) => MemberDetailPage(id: s.pathParameters['id']!)),
          _r('/vehicles', (_) => const VehiclesVerificationPage()),
          _r('/dues', (_) => const DuesPage()),
          _r('/invites', (_) => const InvitesPage()),
          _r('/events', (_) => const EventsPage()),
          _r('/events/:id', (s) => EventDetailAdminPage(id: s.pathParameters['id']!)),
          _r('/events/:id/checkin', (s) => CheckinPage(eventId: s.pathParameters['id']!)),
          _r('/checkin', (_) => const EventsPage(checkinMode: true)),
          _r('/reports', (_) => const ReportsPage()),
          _r('/reports/messages', (_) => const ReportsPage(messagesOnly: true)),
          _r('/broadcast', (_) => const BroadcastPage()),
          _r('/audit', (_) => const AuditPage()),
          _r('/staff', (_) => const StaffRolesPage()),
          _r('/settings', (_) => const SettingsPage()),
        ],
      ),
    ],
  );
});
