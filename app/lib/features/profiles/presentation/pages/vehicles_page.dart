import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/member_profile.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});
  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  List<VehicleItem> items = [];
  bool loading = true;
  String? error;

  final make = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController(text: '2020');
  final color = TextEditingController();
  final plate = TextEditingController();
  bool blurPlate = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    make.dispose();
    model.dispose();
    year.dispose();
    color.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final p = await ref.read(profilesRepositoryProvider).myProfile();
      items = p.vehicles;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    try {
      final v = await ref.read(profilesRepositoryProvider).createVehicle({
        'make': make.text.trim(),
        'model': model.text.trim(),
        'year': int.parse(year.text.trim()),
        'color': color.text.trim(),
        'plateNumber': plate.text.trim().isEmpty ? null : plate.text.trim(),
        'blurPlate': blurPlate,
      });
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        await ref.read(profilesRepositoryProvider).uploadVehiclePhoto(vehicleId: v.id, filename: file.name, bytes: bytes, mimeType: 'image/jpeg');
      }
      make.clear();
      model.clear();
      color.clear();
      plate.clear();
      await _load();
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=profile'),
        title: const Text('My vehicles'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (loading) const LinearProgressIndicator(color: AppColors.gold),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final v in items)
            ListTile(
              title: Text('${v.year} ${v.make} ${v.model}', style: const TextStyle(fontSize: 17)),
              subtitle: Text(
                '${v.color ?? ''} ${v.blurPlate ? '(plate blurred)' : v.plateNumber ?? ''}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  await ref.read(profilesRepositoryProvider).deleteVehicle(v.id);
                  await _load();
                },
              ),
            ),
          const Divider(),
          Text('Add vehicle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: make,
            decoration: const InputDecoration(labelText: 'Make'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: model,
            decoration: const InputDecoration(labelText: 'Model'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: color,
            decoration: const InputDecoration(labelText: 'Color'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: plate,
            decoration: const InputDecoration(labelText: 'Plate (optional)'),
          ),
          SwitchListTile(
            title: const Text('Blur plate for other members', style: TextStyle(fontSize: 16)),
            value: blurPlate,
            activeThumbColor: AppColors.gold,
            onChanged: (v) => setState(() => blurPlate = v),
          ),
          ElevatedButton(onPressed: _add, child: const Text('Save vehicle (optional photo next)')),
        ],
      ),
    );
  }
}
