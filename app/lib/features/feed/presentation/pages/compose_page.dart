import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({super.key});
  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  static const maxLen = 2000;
  final body = TextEditingController();
  final link = TextEditingController();
  bool showLink = false;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    body.addListener(() => setState(() {}));
    link.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    body.dispose();
    link.dispose();
    super.dispose();
  }

  bool get _valid {
    final b = body.text.trim();
    final l = link.text.trim();
    if (b.isEmpty && l.isEmpty) return false;
    if (b.length > maxLen) return false;
    if (l.isNotEmpty && !(Uri.tryParse(l)?.isScheme('https') ?? false)) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref
          .read(feedRepositoryProvider)
          .createPost(body: body.text.trim().isEmpty ? null : body.text.trim(), linkUrl: link.text.trim().isEmpty ? null : link.text.trim());
      if (!mounted) return;
      showToast(context, 'Posted', kind: ToastKind.success);
      context.pop();
    } on Failure catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    final remaining = maxLen - body.text.length;
    final linkBad = link.text.trim().isNotEmpty && !(Uri.tryParse(link.text.trim())?.isScheme('https') ?? false);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SizedBox(
              height: 44,
              child: LuxButton(label: 'Post', loading: loading, onPressed: _valid ? _submit : null),
            ),
          ),
        ],
      ),
      body: CenteredContent(
        maxWidth: AppBreakpoints.feedMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            TextField(
              controller: body,
              autofocus: true,
              maxLines: null,
              minLines: 6,
              style: context.text.bodyLarge?.copyWith(fontSize: 19),
              decoration: const InputDecoration(
                hintText: 'Share a drive, an event recap, or a question for members…',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('$remaining', style: context.text.bodySmall?.copyWith(color: remaining < 0 ? lux.danger : lux.textMuted)),
            ),
            const Divider(),
            AnimatedSize(
              duration: AppMotion.medium,
              child: showLink
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: TextField(
                        controller: link,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Link (https://…)',
                          prefixIcon: const Icon(Icons.link),
                          errorText: linkBad ? 'Links must start with https://' : null,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.link, size: 18),
                  label: const Text('Add link'),
                  selected: showLink,
                  onSelected: (v) => setState(() => showLink = v),
                ),
                ActionChip(
                  avatar: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('Photo'),
                  onPressed: () => showToast(context, 'Photo uploads arrive with media storage setup'),
                ),
              ],
            ),
            if (error != null) ...[const SizedBox(height: AppSpacing.lg), ErrorBanner(error!)],
            const SizedBox(height: AppSpacing.xl),
            Text('Posts are visible to approved members only.', style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
