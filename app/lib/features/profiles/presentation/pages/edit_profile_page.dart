import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});
  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final company = TextEditingController();
  final title = TextEditingController();
  final city = TextEditingController();
  final stateCtrl = TextEditingController();
  final bio = TextEditingController();
  bool showEmail = false;
  bool showPhone = false;
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
      firstName.text = p.firstName;
      lastName.text = p.lastName;
      company.text = p.company ?? '';
      title.text = p.title ?? '';
      city.text = p.city ?? '';
      stateCtrl.text = p.state ?? '';
      bio.text = p.bio ?? '';
      showEmail = p.showEmail;
      showPhone = p.showPhone;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [firstName, lastName, company, title, city, stateCtrl, bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(profilesRepositoryProvider).updateProfile({
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'company': company.text.trim(),
        'title': title.text.trim(),
        'city': city.text.trim(),
        'state': stateCtrl.text.trim(),
        'bio': bio.text.trim(),
        'showEmail': showEmail,
        'showPhone': showPhone,
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
        title: const Text('Edit profile'),
      ),
      body: loading && firstName.text.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stateCtrl,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bio,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                SwitchListTile(
                  title: const Text('Show email to members', style: TextStyle(fontSize: 16)),
                  value: showEmail,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => setState(() => showEmail = v),
                ),
                SwitchListTile(
                  title: const Text('Show phone to members', style: TextStyle(fontSize: 16)),
                  value: showPhone,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => setState(() => showPhone = v),
                ),
                if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: loading ? null : _save, child: const Text('Save')),
              ],
            ),
    );
  }
}
