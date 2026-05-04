import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/booking_model.dart';
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
  bool _isUploadingContract = false;

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

  Future<void> _removeContract(Booking liveBooking, String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחיקת תמונה'),
        content: const Text('האם למחוק תמונה זו מהחוזה?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('מחק', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<BookingProvider>();
    await provider.removeContractUrl(liveBooking, url);
    if (!mounted) return;
    final error = provider.errorMessage;
    if (error != null) {
      showErrorSnackbar(context, error);
      provider.clearError();
    }
  }

  Future<void> _uploadContract(Booking liveBooking) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppStrings.photoFromCamera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppStrings.photoFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingContract = true);

    final provider = context.read<BookingProvider>();
    await provider.uploadContract(liveBooking, File(picked.path));

    if (!mounted) return;
    setState(() => _isUploadingContract = false);

    final error = provider.errorMessage;
    if (error != null) {
      showErrorSnackbar(context, error);
      provider.clearError();
    } else {
      showSuccessSnackbar(context, AppStrings.contractUploaded);
    }
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
    final liveBooking = context
        .watch<BookingProvider>()
        .bookings
        .firstWhere((b) => b.id == widget.booking.id,
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

          if (liveBooking.needsContractAlert) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.contractAlert.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.contractAlert),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.contractAlert),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.missingContract,
                    style: const TextStyle(color: AppColors.contractAlert),
                  ),
                ],
              ),
            ),
          ],

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

          if (kennelInfo != null)
            _DetailRow(label: AppStrings.kennel, value: kennelInfo.hebrewName),

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

          // ── Contract section (boarding only) ───────────────────────────
          if (liveBooking.type == BookingType.boarding) ...[
            const Divider(height: 32),
            Text(
              'חוזה',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (liveBooking.contractPhotoUrls.isNotEmpty) ...[
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: liveBooking.contractPhotoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = liveBooking.contractPhotoUrls[i];
                    return Stack(
                      children: [
                        GestureDetector(
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
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeContract(liveBooking, url),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            _isUploadingContract
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(liveBooking.hasContract
                        ? 'הוסף תמונה לחוזה'
                        : AppStrings.snapContract),
                    onPressed: () => _uploadContract(liveBooking),
                  ),
          ],

          const SizedBox(height: 24),
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
