import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class EventTicketPage extends ConsumerStatefulWidget {
  const EventTicketPage({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends ConsumerState<EventTicketPage> {
  Map<String, dynamic>? ticket;
  Map<String, dynamic>? event;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = ref.read(eventsRepositoryProvider);
      ticket = await repo.ticket(widget.eventId);
      event = await repo.get(widget.eventId).catchError((_) => <String, dynamic>{});
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final starts = DateTime.tryParse(event?['startsAt']?.toString() ?? '')?.toLocal();
    final expires = DateTime.tryParse(ticket?['expiresAt']?.toString() ?? '')?.toLocal();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=events'),
        title: const Text('Your ticket'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorState(message: error!, onRetry: _load)
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1710), Color(0xFF0A0A0B)]),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MEMBER PASS',
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  letterSpacing: 2.4,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                ticket?['eventTitle']?.toString() ?? event?['title']?.toString() ?? '',
                                style: const TextStyle(
                                  fontFamily: AppFonts.serif,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                  height: 1.2,
                                ),
                              ),
                              if (starts != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '${DateFormat.yMMMMEEEEd().format(starts)} · ${DateFormat.jm().format(starts)}',
                                  style: const TextStyle(color: AppColors.champagne, fontSize: 15),
                                ),
                              ],
                              if (event?['venueName'] != null) Text('${event!['venueName']}', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                            ],
                          ),
                        ),
                        const _Perforation(),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Semantics(
                                label: 'QR code ticket. Show this to staff at check-in.',
                                image: true,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
                                  child: QrImageView(data: ticket?['token']?.toString() ?? '', size: 240, backgroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.brightness_high_rounded, color: AppColors.gold, size: 20),
                                  SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      'Turn up screen brightness at check-in',
                                      style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              if (expires != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text('Valid until ${DateFormat.MMMd().add_jm().format(expires)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
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

class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          Center(
            child: LayoutBuilder(
              builder: (_, c) {
                final n = (c.maxWidth / 12).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(n, (_) => Container(width: 5, height: 1.5, color: AppColors.gold.withValues(alpha: 0.4))),
                );
              },
            ),
          ),
          Positioned(
            left: -12,
            top: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: -12,
            top: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
