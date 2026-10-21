import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/application.dart';

class ApplicationStatusPage extends ConsumerStatefulWidget {
  const ApplicationStatusPage({super.key, required this.email});
  final String email;

  @override
  ConsumerState<ApplicationStatusPage> createState() => _ApplicationStatusPageState();
}

class _ApplicationStatusPageState extends ConsumerState<ApplicationStatusPage> {
  late final _email = TextEditingController(text: widget.email);
  MemberApplication? app;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.email.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (Validators.email(_email.text) != null) {
      setState(() => error = 'Enter the email you applied with.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final a = await ref.read(applicationsRepositoryProvider).statusByEmail(_email.text.trim());
      setState(() => app = a);
    } on Failure catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  static const _steps = ['submitted', 'under_review', 'decision'];

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    final a = app;
    final status = a?.status ?? '';
    final idx = switch (status) {
      'submitted' => 0,
      'under_review' || 'more_info_needed' => 1,
      'approved' || 'declined' => 2,
      _ => -1,
    };
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/welcome'),
        title: const Text('Application status'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a == null) ...[
                    Text('Check your application', style: context.text.headlineMedium),
                    const SizedBox(height: AppSpacing.lg),
                    LuxTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, onSubmitted: (_) => _load()),
                    const SizedBox(height: AppSpacing.lg),
                    if (error != null) ...[ErrorBanner(error!), const SizedBox(height: AppSpacing.lg)],
                    LuxButton(label: 'Check status', loading: loading, expand: true, onPressed: _load),
                  ] else ...[
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Icon(
                          status == 'approved'
                              ? Icons.verified
                              : status == 'declined'
                              ? Icons.close
                              : Icons.hourglass_top_rounded,
                          color: AppColors.gold,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      switch (status) {
                        'approved' => 'Welcome to the club',
                        'declined' => 'Application closed',
                        'more_info_needed' => 'More information needed',
                        _ => 'Thank you, ${a.firstName}',
                      },
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      status == 'approved'
                          ? 'Check your email to set your password, then sign in.'
                          : 'Our membership committee reviews every application personally.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: lux.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LuxCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(i <= idx ? Icons.check_circle : Icons.radio_button_unchecked, color: i <= idx ? AppColors.gold : lux.textMuted),
                              title: Text(['Submitted', 'Under review', 'Decision'][i]),
                              subtitle: i == 1 && a.moreInfoMessage != null
                                  ? Text(a.moreInfoMessage!)
                                  : i == 2 && a.declineReason != null
                                  ? Text(a.declineReason!)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LuxCard(
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_outlined, color: lux.accentText),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text('${a.vehicleYear} ${a.vehicleMake} ${a.vehicleModel}', style: context.text.titleSmall)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LuxButton.secondary(
                      label: status == 'approved' ? 'Sign in' : 'Back to welcome',
                      expand: true,
                      onPressed: () => context.go(status == 'approved' ? '/login' : '/welcome'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
