import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      setState(() => _sent = true);
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallback: '/login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
            child: _sent
                ? const EmptyState(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Check your inbox',
                    message: 'If that email belongs to a member, a reset link is on its way. It expires in 1 hour.',
                  )
                : Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Forgot password', style: context.text.displaySmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter your member email and we\u2019ll send a reset link.',
                          style: context.text.bodyMedium?.copyWith(color: context.lux.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        LuxTextField(
                          label: 'Email',
                          controller: _email,
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[const SizedBox(height: AppSpacing.lg), ErrorBanner(_error!)],
                        const SizedBox(height: AppSpacing.xl),
                        LuxButton(label: 'Send reset link', loading: _loading, expand: true, onPressed: _submit),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
