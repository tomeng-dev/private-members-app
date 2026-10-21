import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key, required this.token, this.isReset = false});
  final String token;
  final bool isReset;

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (widget.isReset) {
        await repo.resetPassword(token: widget.token, password: _password.text);
      } else {
        await repo.setPassword(token: widget.token, password: _password.text);
      }
      if (!mounted) return;
      showToast(context, 'Password saved — please sign in', kind: ToastKind.success);
      context.go('/login');
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
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.isReset ? 'Reset your password' : 'Set your password', style: context.text.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Use at least 12 characters with a mix of letters, numbers and symbols.',
                    style: context.text.bodyMedium?.copyWith(color: context.lux.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  LuxTextField(
                    label: 'New password',
                    controller: _password,
                    obscure: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => (v == null || v.length < 12) ? 'Use at least 12 characters' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LuxTextField(
                    label: 'Confirm password',
                    controller: _confirm,
                    obscure: true,
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[const SizedBox(height: AppSpacing.lg), ErrorBanner(_error!)],
                  const SizedBox(height: AppSpacing.xl),
                  LuxButton(label: 'Save password', loading: _loading, expand: true, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
