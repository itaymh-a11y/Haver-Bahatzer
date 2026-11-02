import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../core/utils/dog_contract_rules.dart';
import '../../models/booking_model.dart';
import '../../models/dog_contract.dart';
import '../../models/dog_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/error_snackbar.dart';
import '../dogs/dog_detail_screen.dart';
import 'booking_form_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.upcoming:
        return AppColors.statusUpcoming;
      case BookingStatus.active:
        return AppColors.statusActive;
      case BookingStatus.completed:
        return AppColors.statusCompleted;
    }
  }

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.upcoming:
        return AppStrings.statusUpcoming;
      case BookingStatus.active:
        return AppStrings.statusActive;
      case BookingStatus.completed:
        return AppStrings.statusCompleted;
    }
  }

  Future<void> _contactOwner(String phone) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: const Text('התקשר'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await launchUrl(Uri(scheme: 'tel', path: phone));
                } catch (_) {
                  if (mounted) showErrorSnackbar(context, 'לא ניתן לחייג: $phone');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.primary),
              title: const Text('וואטסאפ'),
              onTap: () async {
                Navigator.pop(ctx);
                final digits = phone.replaceAll(RegExp(r'\D'), '');
                final normalized = digits.startsWith('0') ? '972${digits.substring(1)}' : digits;
                try {
                  await launchUrl(
                    Uri.parse('whatsapp://send?phone=$normalized'),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  try {
                    await launchUrl(
                      Uri.parse('https://wa.me/$normalized'),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    if (mounted) showErrorSnackbar(context, 'לא ניתן לפתוח וואטסאפ');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullContract(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.close),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Track live updates via provider (e.g. after contract upload)
    final bookingProvider = context.watch<BookingProvider>();
    final liveBooking = bookingProvider.bookings.firstWhere(
        (b) => b.id == widget.booking.id,
        orElse: () => widget.booking);

    final dogs = context.watch<DogProvider>().dogs;
    final bookingDogs = liveBooking.dogIds
        .map((id) {
          final idx = dogs.indexWhere((d) => d.id == id);
          return idx != -1 ? dogs[idx] : null;
        })
        .whereType<Dog>()
        .toList();

    // Unique owners keyed by phone so duplicates (same owner, multiple dogs) collapse
    final ownersByPhone = <String, String>{};
    for (final dog in bookingDogs) {
      ownersByPhone[dog.ownerPhone] = dog.ownerName;
    }

    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final statusColor = _statusColor(liveBooking.status);
    final kennelInfo = liveBooking.kennelId != null
        ? KennelConstants.findById(liveBooking.kennelId!)
        : null;
    final kennelChanges = liveBooking.effectiveKennelChanges;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.booking),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BookingFormScreen(booking: liveBooking)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status chip
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(liveBooking.status),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                liveBooking.type.hebrewLabel,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),

          _DogContractAlerts(booking: liveBooking, dogs: bookingDogs),

          const SizedBox(height: 20),

          // Dogs — each name is tappable → dog profile
          _LabelRow(
            label: AppStrings.dogs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bookingDogs.map((dog) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DogDetailScreen(dog: dog)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    dog.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                  ),
                ),
              )).toList(),
            ),
          ),

          // Owner name + phone per unique owner
          ...ownersByPhone.entries.map((entry) {
            final phone = entry.key;
            final name = entry.value;
            return Column(
              children: [
                _DetailRow(label: 'בעלים', value: name),
                _LabelRow(
                  label: 'טלפון',
                  child: GestureDetector(
                    onTap: () => _contactOwner(phone),
                    child: Row(
                      children: [
                        Text(
                          phone,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chat_outlined, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),

          if (kennelInfo != null && kennelChanges.isEmpty)
            _DetailRow(label: AppStrings.kennel, value: kennelInfo.hebrewName),
          if (kennelInfo != null && kennelChanges.isNotEmpty) ...[
            _DetailRow(
              label: AppStrings.initialKennel,
              value: kennelInfo.hebrewName,
            ),
            for (var i = 0; i < kennelChanges.length; i++) ...[
              _DetailRow(
                label: '${AppStrings.newKennel} ${i + 1}',
                value: KennelConstants.findById(kennelChanges[i].kennelId)
                        ?.hebrewName ??
                    kennelChanges[i].kennelId,
              ),
              _DetailRow(
                label: '${AppStrings.kennelChangeStartDate} ${i + 1}',
                value: dateFormat.format(kennelChanges[i].startDate),
              ),
            ],
          ],

          if (liveBooking.type == BookingType.boarding) ...[
            _DetailRow(
                label: AppStrings.startDate,
                value: dateFormat.format(liveBooking.startDate)),
            _DetailRow(
                label: AppStrings.endDate,
                value: dateFormat.format(liveBooking.endDate)),
            _DetailRow(label: 'ימים', value: '${liveBooking.numberOfDays}'),
          ],

          if (liveBooking.type == BookingType.introMeeting) ...[
            _DetailRow(
                label: AppStrings.date,
                value: dateFormat.format(liveBooking.startDate)),
            if (liveBooking.meetingTime != null)
              _DetailRow(
                  label: AppStrings.meetingTime,
                  value: liveBooking.meetingTime!),
            if (liveBooking.hasSoftHold) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softHold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: bookingProvider.isSoftHoldDisplaced(liveBooking)
                        ? AppColors.error
                        : AppColors.softHold,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookingProvider.isSoftHoldDisplaced(liveBooking)
                          ? AppStrings.softHoldDisplacedBadge
                          : AppStrings.softHold,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: bookingProvider.isSoftHoldDisplaced(liveBooking)
                            ? AppColors.error
                            : AppColors.softHold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${KennelConstants.findById(liveBooking.softHoldKennelId!)?.hebrewName ?? liveBooking.softHoldKennelId}',
                    ),
                    Text(
                      '${dateFormat.format(liveBooking.softHoldStartDate!)} – ${dateFormat.format(liveBooking.softHoldEndDate!)}',
                    ),
                    if (bookingProvider.isSoftHoldDisplaced(liveBooking)) ...[
                      const SizedBox(height: 8),
                      Text(
                        () {
                          final alt = bookingProvider.suggestAlternativeKennel(
                            dogIds: liveBooking.dogIds,
                            start: liveBooking.softHoldStartDate!,
                            end: liveBooking.softHoldEndDate!,
                            excludeKennelId: liveBooking.softHoldKennelId,
                          );
                          if (alt == null) {
                            return AppStrings.softHoldNoAltKennel;
                          }
                          return '${AppStrings.softHoldAltKennel}: ${KennelConstants.findById(alt)?.hebrewName ?? alt}';
                        }(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.softHoldConvertHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingFormScreen(
                            initialType: BookingType.boarding,
                            initialDogIds: liveBooking.dogIds,
                            initialKennelId: liveBooking.softHoldKennelId,
                            initialStartDate: liveBooking.softHoldStartDate,
                            initialEndDate: liveBooking.softHoldEndDate,
                            clearSoftHoldIntroId: liveBooking.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text(AppStrings.softHoldConvert),
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (liveBooking.totalPrice != null) ...[
            _DetailRow(
                label: AppStrings.totalPrice,
                value: '₪${liveBooking.totalPrice!.toStringAsFixed(0)}'),
            _DetailRow(
              label: AppStrings.isPaid,
              value: liveBooking.remainingAmount <= 0.01
                  ? AppStrings.isPaid
                  : liveBooking.paidAmount > 0
                      ? '${AppStrings.partiallyPaid} ${liveBooking.paidAmount.toStringAsFixed(0)}/${liveBooking.totalPrice!.toStringAsFixed(0)}'
                      : AppStrings.unpaid,
              valueColor:
                  liveBooking.remainingAmount <= 0.01
                      ? AppColors.primary
                      : liveBooking.paidAmount > 0
                          ? Colors.orange
                          : AppColors.error,
            ),
            if (liveBooking.payments.isNotEmpty)
              _DetailRow(
                  label: AppStrings.paymentMethod,
                  value: liveBooking.payments.last.method.hebrewLabel),
          ],

          if (liveBooking.type == BookingType.boarding &&
              (liveBooking.status == BookingStatus.upcoming ||
                  liveBooking.status == BookingStatus.active ||
                  liveBooking.contractPhotoUrls.isNotEmpty)) ...[
            const Divider(height: 32),
            if (liveBooking.status == BookingStatus.upcoming ||
                liveBooking.status == BookingStatus.active) ...[
              Text(
                AppStrings.yearlyContract,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.contractUploadOnDogProfile,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (liveBooking.contractPhotoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                AppStrings.contractUploadedOnBooking,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: liveBooking.contractPhotoUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = liveBooking.contractPhotoUrls[i];
                    return GestureDetector(
                      onTap: () => _showFullContract(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DogContractAlerts extends StatelessWidget {
  final Booking booking;
  final List<Dog> dogs;

  const _DogContractAlerts({required this.booking, required this.dogs});

  @override
  Widget build(BuildContext context) {
    if (booking.type != BookingType.boarding) return const SizedBox.shrink();
    if (booking.status != BookingStatus.upcoming &&
        booking.status != BookingStatus.active) {
      return const SizedBox.shrink();
    }

    final today = DateTime.now();
    final missing = <Dog>[];
    final expiring = <Dog>[];
    for (final id in booking.dogIds) {
      final index = dogs.indexWhere((dog) => dog.id == id);
      if (index == -1) continue;
      final dog = dogs[index];
      final status = DogContractRules.statusOf(dog, today);
      if (status == DogContractAlert.missing) missing.add(dog);
      if (status == DogContractAlert.expiring) expiring.add(dog);
    }
    if (missing.isEmpty && expiring.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (missing.isNotEmpty)
            _AlertBanner(
              color: AppColors.contractAlert,
              icon: Icons.warning_amber_rounded,
              text: missing.length == 1
                  ? '${missing.first.name}: ${AppStrings.missingContract}'
                  : '${AppStrings.missingContract} ${missing.map((dog) => dog.name).join(', ')}',
            ),
          if (missing.isNotEmpty && expiring.isNotEmpty)
            const SizedBox(height: 8),
          if (expiring.isNotEmpty)
            _AlertBanner(
              color: AppColors.contractExpiring,
              icon: Icons.schedule,
              text: expiring
                  .map((dog) =>
                      '${dog.name}: ${AppStrings.contractExpiringSoon} · ${contractDaysRemainingLabel(dog.contract!.daysRemainingOn(today))}')
                  .join('\n'),
            ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return _LabelRow(
      label: label,
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabelRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
