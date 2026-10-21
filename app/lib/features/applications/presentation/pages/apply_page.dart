import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

/// Pure validation rules for the application form (unit tested).
class ApplyRules {
  ApplyRules._();
  static const minVehicleValue = 200000;
  static String? year(String? v) {
    final y = int.tryParse((v ?? '').trim());
    final max = DateTime.now().year + 1;
    if (y == null) return 'Enter the model year';
    if (y < 1900 || y > max) return 'Year must be between 1900 and $max';
    return null;
  }

  static String? value(String? v) {
    final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null) return 'Enter an estimated value';
    if (n < minVehicleValue) return 'Membership requires a vehicle valued at \$200,000 or more';
    return null;
  }
}

class ApplyPage extends ConsumerStatefulWidget {
  const ApplyPage({super.key});

  @override
  ConsumerState<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends ConsumerState<ApplyPage> {
  static const steps = ['About you', 'Business', 'Vehicle', 'Review'];
  int step = 0;
  final _forms = List.generate(4, (_) => GlobalKey<FormState>());
  final email = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final company = TextEditingController();
  final title = TextEditingController();
  final city = TextEditingController();
  final stateCtrl = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController();
  final value = TextEditingController();
  final invite = TextEditingController();
  bool consentPrivacy = false;
  bool consentTerms = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    for (final c in [email, firstName, lastName, phone, company, title, city, stateCtrl, make, model, year, value, invite]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  void _next() {
    if (!(_forms[step].currentState?.validate() ?? true)) return;
    if (step < steps.length - 1) {
      setState(() {
        step++;
        error = null;
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!consentPrivacy || !consentTerms) {
      setState(() => error = 'Please accept the Privacy Notice and Terms to continue.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final app = await ref.read(applicationsRepositoryProvider).submit({
        'email': email.text.trim(),
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'phone': _t(phone),
        'company': _t(company),
        'title': _t(title),
        'city': _t(city),
        'state': _t(stateCtrl),
        'vehicleMake': make.text.trim(),
        'vehicleModel': model.text.trim(),
        'vehicleYear': int.parse(year.text.trim()),
        'vehicleEstimatedValue': int.parse(value.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'inviteCode': _t(invite),
        'consentPrivacy': true,
        'consentTerms': true,
      });
      if (mounted) context.go('/application-status?email=${Uri.encodeComponent(app.email)}');
    } on Failure catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'Could not submit your application. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _stepBody() {
    const gap = SizedBox(height: AppSpacing.lg);
    switch (step) {
      case 0:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: LuxTextField(
                    label: 'First name',
                    controller: firstName,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (v) => Validators.required(v, 'First name'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LuxTextField(
                    label: 'Last name',
                    controller: lastName,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: (v) => Validators.required(v, 'Last name'),
                  ),
                ),
              ],
            ),
            gap,
            LuxTextField(
              label: 'Email',
              controller: email,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            ),
            gap,
            LuxTextField(label: 'Phone (optional)', controller: phone, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            gap,
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LuxTextField(label: 'City', controller: city, validator: (v) => Validators.required(v, 'City')),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: LuxTextField(label: 'State', controller: stateCtrl),
                ),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            LuxTextField(label: 'Company', controller: company, prefixIcon: Icons.business_outlined, validator: (v) => Validators.required(v, 'Company')),
            gap,
            LuxTextField(label: 'Title', controller: title, prefixIcon: Icons.badge_outlined, hint: 'e.g. Founder & CEO'),
            gap,
            LuxTextField(
              label: 'Invite code (optional)',
              controller: invite,
              prefixIcon: Icons.confirmation_number_outlined,
              helper: 'If a member referred you, enter their invite code.',
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            LuxTextField(
              label: 'Make',
              controller: make,
              prefixIcon: Icons.directions_car_outlined,
              hint: 'e.g. Ferrari',
              validator: (v) => Validators.required(v, 'Make'),
            ),
            gap,
            LuxTextField(label: 'Model', controller: model, hint: 'e.g. SF90 Stradale', validator: (v) => Validators.required(v, 'Model')),
            gap,
            Row(
              children: [
                Expanded(
                  child: LuxTextField(label: 'Year', controller: year, keyboardType: TextInputType.number, validator: ApplyRules.year),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LuxTextField(
                    label: 'Estimated value (USD)',
                    controller: value,
                    keyboardType: TextInputType.number,
                    validator: ApplyRules.value,
                    hint: '250000',
                  ),
                ),
              ],
            ),
            gap,
            LuxCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.lux.accentText),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Proof of ownership can be uploaded after you submit. Plates are always blurred for other members.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        final money = NumberFormat.simpleCurrency(decimalDigits: 0);
        final v = int.tryParse(value.text.replaceAll(RegExp(r'[^0-9]'), ''));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LuxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _review('Name', '${firstName.text} ${lastName.text}', 0),
                  _review('Email', email.text, 0),
                  _review('Location', [city.text, stateCtrl.text].where((s) => s.isNotEmpty).join(', '), 0),
                  _review('Business', [title.text, company.text].where((s) => s.isNotEmpty).join(' · '), 1),
                  _review('Vehicle', '${year.text} ${make.text} ${model.text}', 2),
                  _review('Value', v == null ? '' : money.format(v), 2),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              value: consentPrivacy,
              onChanged: (x) => setState(() => consentPrivacy = x ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I have read and agree to the Privacy Notice'),
            ),
            CheckboxListTile(
              value: consentTerms,
              onChanged: (x) => setState(() => consentTerms = x ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree to the Membership Terms'),
            ),
          ],
        );
    }
  }

  Widget _review(String k, String v, int editStep) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        SizedBox(width: 96, child: Text(k, style: context.text.bodySmall)),
        Expanded(child: Text(v.trim().isEmpty ? '—' : v, style: context.text.bodyMedium)),
        IconButton(tooltip: 'Edit $k', onPressed: () => setState(() => step = editStep), icon: const Icon(Icons.edit_outlined, size: 18)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/welcome'),
          title: const Text('Apply for membership'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
                    child: _StepIndicator(steps: steps, current: step),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Form(
                        key: _forms[step],
                        child: AnimatedSwitcher(
                          duration: AppMotion.medium,
                          child: KeyedSubtree(
                            key: ValueKey(step),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(header: true, child: Text(steps[step], style: context.text.headlineMedium)),
                                const SizedBox(height: AppSpacing.xs),
                                Text('Step ${step + 1} of ${steps.length}', style: context.text.bodySmall),
                                const SizedBox(height: AppSpacing.xl),
                                _stepBody(),
                                if (error != null) ...[const SizedBox(height: AppSpacing.lg), ErrorBanner(error!)],
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: lux.border)),
                    ),
                    child: Row(
                      children: [
                        if (step > 0) ...[
                          Expanded(
                            child: LuxButton.secondary(label: 'Back', onPressed: loading ? null : () => setState(() => step--)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Expanded(
                          flex: 2,
                          child: LuxButton(label: step < steps.length - 1 ? 'Continue' : 'Submit application', loading: loading, onPressed: _next),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});
  final List<String> steps;
  final int current;
  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              AnimatedContainer(
                duration: AppMotion.medium,
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.gold : Colors.transparent,
                  border: Border.all(color: i <= current ? AppColors.gold : lux.border, width: 1.5),
                ),
                child: i < current
                    ? const Icon(Icons.check, size: 16, color: AppColors.black)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == current ? AppColors.black : lux.textMuted),
                      ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    color: i < current ? AppColors.gold : lux.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
