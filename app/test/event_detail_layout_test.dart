import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/di/providers.dart';
import 'package:member_app/core/network/api_client.dart';
import 'package:member_app/core/theme/app_theme.dart';
import 'package:member_app/features/events/data/events_repository.dart';
import 'package:member_app/features/events/presentation/pages/event_detail_page.dart';

class _FakeEvents extends EventsRepository {
  _FakeEvents() : super(ApiClient(baseUrl: 'http://localhost'));

  @override
  Future<Map<String, dynamic>> get(String id) async => {
    'id': id,
    'title': 'Founders Dinner',
    'description': 'Members only.',
    'startsAt': DateTime.utc(2026, 10, 26, 23).toIso8601String(),
    'endsAt': DateTime.utc(2026, 10, 27, 2).toIso8601String(),
    'timezone': 'America/New_York',
    'venueName': 'The Surf Club',
    'address': '9011 Collins Ave, Surfside, FL',
    'capacity': 40,
    'goingCount': 3,
    'waitlistCount': 0,
    'feeUsdCents': 100000,
    'rsvpOpen': true,
    'status': 'published',
    'myRsvp': {'status': 'going', 'paymentStatus': 'paid'},
    'speakers': <dynamic>[],
    'agenda': <dynamic>[],
  };
}

void main() {
  // Regression: the mobile RSVP bottom bar once stretched its buttons to the full screen height.
  testWidgets('mobile RSVP bar stays compact and content remains visible', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(_FakeEvents())],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const EventDetailPage(id: 'e1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('My ticket'), findsOneWidget);
    final buttonHeight = tester.getSize(find.ancestor(of: find.text('My ticket'), matching: find.byType(InkWell)).first).height;
    expect(buttonHeight, lessThan(80));
    final bar = tester.getRect(find.text('You\u2019re attending'));
    expect(bar.top, greaterThan(844 / 2), reason: 'RSVP bar must sit at the bottom, not cover the page');
    expect(find.text('Founders Dinner').hitTestable(), findsWidgets);
  });
}
