import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class BusinessPageEditor extends ConsumerStatefulWidget {
  const BusinessPageEditor({super.key});
  @override
  ConsumerState<BusinessPageEditor> createState() => _BusinessPageEditorState();
}

class _BusinessPageEditorState extends ConsumerState<BusinessPageEditor> {
  final company = TextEditingController();
  final services = TextEditingController();
  final background = TextEditingController();
  final website = TextEditingController();
  final contactEmail = TextEditingController();
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(profilesRepositoryProvider).myProfile();
      final b = p.businessPage;
      if (b != null) {
        company.text = b.companyName;
        services.text = b.services ?? '';
        background.text = b.background ?? '';
        website.text = b.website ?? '';
        contactEmail.text = b.contactEmail ?? '';
      }
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    company.dispose();
    services.dispose();
    background.dispose();
    website.dispose();
    contactEmail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(profilesRepositoryProvider).upsertBusiness({
        'companyName': company.text.trim(),
        'services': services.text.trim(),
        'background': background.text.trim(),
        'website': website.text.trim(),
        'contactEmail': contactEmail.text.trim(),
        'showContactEmail': true,
      });
      if (mounted) context.pop();
    } on Failure catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=profile'),
        title: const Text('Business page'),
      ),
      body: loading && company.text.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: 'Company name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: services,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Services'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: background,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Background / resume'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: website,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactEmail,
                  decoration: const InputDecoration(labelText: 'Contact email'),
                ),
                if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: loading ? null : _save, child: const Text('Save business page')),
              ],
            ),
    );
  }
}
