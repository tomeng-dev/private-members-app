import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../widgets/dev_quick_login.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.devMode = AppConfig.isDevelopment, this.devAccountsLoader});

  /// Defaults to the compile-time APP_ENV flag. Tests may force it.
  final bool devMode;
  final DevAccountsLoader? devAccountsLoader;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<List<DevAccount>> _loadDevAccounts() async {
    final res = await ref.read(apiClientProvider).raw.get('/dev/accounts');
    final items = (res.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(DevAccount.fromJson).toList();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(loginUseCaseProvider)(email: _email.text.trim(), password: _password.text);
      ref.read(authSessionProvider.notifier).setLoggedIn(true);
      if (mounted) context.go('/home');
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unable to sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(header: true, child: Text('Welcome back', style: context.text.displaySmall)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Sign in with your member email and password.', style: context.text.bodyLarge?.copyWith(color: context.lux.textMuted)),
                      const SizedBox(height: AppSpacing.xxl),
                      LuxTextField(
                        label: 'Email',
                        controller: _email,
                        hint: 'you@company.com',
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LuxTextField(
                        label: 'Password',
                        controller: _password,
                        prefixIcon: Icons.lock_outline,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: Validators.password,
                        onSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
                      ),
                      if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: AppSpacing.lg)],
                      LuxButton(label: 'Sign in', loading: _loading, expand: true, onPressed: _submit),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Not a member yet?', style: context.text.bodyMedium?.copyWith(color: context.lux.textMuted)),
                          TextButton(onPressed: () => context.go('/apply'), child: const Text('Apply')),
                        ],
                      ),
                      if (widget.devMode) ...[
                        const SizedBox(height: AppSpacing.xl),
                        DevQuickLogin(
                          loader: widget.devAccountsLoader ?? _loadDevAccounts,
                          onPick: (a) {
                            _email.text = a.email;
                            if (AppConfig.devMemberPassword.isEmpty) {
                              // No --dart-define=DEV_MEMBER_PASSWORD: let the developer type it.
                              _password.clear();
                              return;
                            }
                            _password.text = AppConfig.devMemberPassword;
                            _submit();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
