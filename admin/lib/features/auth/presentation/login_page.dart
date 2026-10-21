import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});
  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _form = GlobalKey<FormState>();
  final email = TextEditingController(text: AppConfig.isDevelopment ? 'admin@example.com' : '');
  final password = TextEditingController();
  final totp = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;
  String? preAuthToken;
  bool needsSetup = false;
  String? otpauthUrl;
  List<dynamic>? recoveryCodes;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    totp.dispose();
    super.dispose();
  }

  Future<void> _done(Map<String, dynamic> data) async {
    ref.read(adminSessionProvider.notifier).setLoggedIn(true);
    if (data['user'] is Map) await ref.read(staffUserProvider.notifier).set(Map<String, dynamic>.from(data['user'] as Map));
    ref.invalidate(environmentProvider);
    if (mounted) context.go('/overview');
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ref.read(authRepositoryProvider).login(email.text.trim(), password.text);
      if (data['requiresTotp'] == true || data['requires2fa'] == true) {
        preAuthToken = data['preAuthToken'] as String?;
        needsSetup = data['setupRequired'] == true || data['needsSetup'] == true;
        if (needsSetup && preAuthToken != null) {
          final setup = await ref.read(authRepositoryProvider).beginTotpSetup(preAuthToken!);
          otpauthUrl = setup['otpauthUrl'] as String?;
        }
        setState(() {});
        return;
      }
      await _done(data);
    } on Failure catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _verify2fa() async {
    if (preAuthToken == null || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      Map<String, dynamic> data;
      if (needsSetup) {
        data = await ref.read(authRepositoryProvider).confirmTotpSetup(preAuthToken!, totp.text.trim());
        recoveryCodes = data['recoveryCodes'] as List?;
      } else {
        data = await ref.read(authRepositoryProvider).verifyTotp(preAuthToken!, totp.text.trim());
      }
      if (recoveryCodes != null && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Save your recovery codes'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Each code can be used once if you lose your authenticator.', style: ctx.text.bodySmall),
                  const SizedBox(height: Gap.md),
                  SelectableText(recoveryCodes!.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.6)),
                ],
              ),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('I saved them'))],
          ),
        );
      }
      await _done(data);
    } on Failure catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step2 = preAuthToken != null;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final t = context.tokens;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ADMIN',
                    style: TextStyle(fontSize: 12, letterSpacing: 4, color: t.accentText, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(step2 ? 'Two-factor authentication' : 'Sign in to the console', style: context.text.headlineMedium),
                  const SizedBox(height: Gap.sm),
                  Text(
                    step2
                        ? (needsSetup
                              ? 'Add this account to your authenticator app, then enter the 6-digit code.'
                              : 'Enter the 6-digit code from your authenticator app.')
                        : 'Staff accounts only. All actions are audit-logged.',
                    style: context.text.bodySmall?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: Gap.xl),
                  if (!step2) ...[
                    TextFormField(
                      controller: email,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded, size: 20)),
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: Gap.md),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                    ),
                  ] else ...[
                    if (needsSetup && otpauthUrl != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: Gap.md),
                        padding: const EdgeInsets.all(Gap.md),
                        decoration: BoxDecoration(
                          color: t.surfaceSunken,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: t.border),
                        ),
                        child: SelectableText(otpauthUrl!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ),
                    TextFormField(
                      controller: totp,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onFieldSubmitted: (_) => _verify2fa(),
                      decoration: const InputDecoration(labelText: 'Authentication code', prefixIcon: Icon(Icons.pin_outlined, size: 20)),
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) || (v ?? '').trim().length >= 8 ? null : 'Enter the 6-digit code (or a recovery code)',
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: Gap.md),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(Gap.md),
                        decoration: BoxDecoration(
                          color: t.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: t.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: t.danger, size: 18),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: Text(error!, style: TextStyle(color: t.danger, fontSize: 13.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: loading ? null : (step2 ? _verify2fa : _submit),
                    child: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                        : Text(step2 ? (needsSetup ? 'Enable 2FA' : 'Verify') : 'Sign in'),
                  ),
                  if (step2)
                    TextButton(
                      onPressed: () => setState(() {
                        preAuthToken = null;
                        totp.clear();
                      }),
                      child: const Text('Use a different account'),
                    ),
                  if (AppConfig.isDevelopment && !step2) ...[
                    const SizedBox(height: Gap.xl),
                    Container(
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: t.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: t.warning.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.developer_mode_rounded, size: 18, color: t.warning),
                          const SizedBox(width: Gap.sm),
                          Expanded(child: Text('Development build · seeded admin credentials are listed in the README.', style: context.text.bodySmall)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: form),
              ],
            )
          : form,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0B), Color(0xFF1E1910), Color(0xFF5A4518)],
          stops: [0, 0.55, 1],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold),
                ),
                child: const Text(
                  'PM',
                  style: TextStyle(fontFamily: AppFonts.serif, color: AppColors.gold, fontSize: 15),
                ),
              ),
              const SizedBox(width: Gap.md),
              const Text(
                'PRIVATE MEMBERS',
                style: TextStyle(color: AppColors.gold, letterSpacing: 3, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'The club,\nbehind the scenes.',
            style: TextStyle(fontFamily: AppFonts.serif, fontSize: 46, height: 1.1, color: AppColors.ivory, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Gap.lg),
          const SizedBox(
            width: 420,
            child: Text(
              'Review applications, manage members and dues, run events and keep the community safe — from one console.',
              style: TextStyle(color: Color(0xFFCFC8BB), fontSize: 15.5, height: 1.5),
            ),
          ),
          const SizedBox(height: 56),
        ],
      ),
    );
  }
}
