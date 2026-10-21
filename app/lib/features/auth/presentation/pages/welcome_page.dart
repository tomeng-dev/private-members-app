import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/ui.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const _values = [
    (Icons.verified_outlined, 'Verified members', 'Every member and vehicle is personally reviewed.'),
    (Icons.event_available_outlined, 'Curated evenings', 'Private dinners, drives and track days.'),
    (Icons.lock_outline, 'Discreet by design', 'Private directory and member-only messaging.'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    final hero = _Hero(wide: wide);
    final panel = _Panel(values: _values);
    return Scaffold(
      backgroundColor: AppColors.black,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 6, child: hero),
                Expanded(
                  flex: 5,
                  child: Theme(data: Theme.of(context), child: panel),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned.fill(child: hero),
                Align(alignment: Alignment.bottomCenter, child: panel),
              ],
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CoverArt(seed: 'welcome-hero', height: double.infinity, showIcon: false),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0xE60A0A0B)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(wide ? AppSpacing.xxxl : AppSpacing.xl),
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
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: const Text(
                        'PM',
                        style: TextStyle(fontFamily: AppFonts.serif, color: AppColors.gold, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text(
                      'PRIVATE MEMBERS',
                      style: TextStyle(fontFamily: AppFonts.sans, letterSpacing: 3, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold),
                    ),
                  ],
                ),
                if (wide)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'An invitation-only\nclub for extraordinary\nautomobiles.',
                              style: TextStyle(fontFamily: AppFonts.serif, fontSize: 52, height: 1.1, fontWeight: FontWeight.w600, color: AppColors.white),
                            ),
                            SizedBox(height: AppSpacing.lg),
                            Text(
                              'Owners of exceptional cars, gathered with intent.',
                              style: TextStyle(fontFamily: AppFonts.sans, fontSize: 18, color: AppColors.champagne),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.values});
  final List<(IconData, String, String)> values;
  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    return Container(
      color: wide ? AppColors.black : Colors.transparent,
      child: SafeArea(
        top: wide,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    const Text(
                      'An invitation-only club for extraordinary automobiles.',
                      style: TextStyle(fontFamily: AppFonts.serif, fontSize: 32, height: 1.15, fontWeight: FontWeight.w600, color: AppColors.white),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ] else ...[
                    Semantics(
                      header: true,
                      child: const Text(
                        'Welcome',
                        style: TextStyle(fontFamily: AppFonts.serif, fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Apply for membership or sign in to continue.', style: TextStyle(fontSize: 16, color: AppColors.muted)),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  for (final v in values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.md)),
                            child: Icon(v.$1, color: AppColors.gold, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.$2,
                                  style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  v.$3,
                                  style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14.5, color: AppColors.muted, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  LuxButton(label: 'Apply for membership', expand: true, onPressed: () => context.push('/apply')),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: Color(0xFF4A4740)),
                    ),
                    onPressed: () => context.push('/login'),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(onPressed: () => context.push('/application-status'), child: const Text('Check application status')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
