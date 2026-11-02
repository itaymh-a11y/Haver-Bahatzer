import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/dog_contract_rules.dart';
import '../../models/dog_contract.dart';
import '../../models/dog_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../common/error_snackbar.dart';

class DogContractCard extends StatefulWidget {
  final Dog dog;

  const DogContractCard({super.key, required this.dog});

  @override
  State<DogContractCard> createState() => _DogContractCardState();
}

class _DogContractCardState extends State<DogContractCard> {
  bool _busy = false;

  Future<void> _pickAndUpload({required bool startNew}) async {
    final contract = widget.dog.contract;
    if (startNew && contract != null && contract.photoUrls.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.uploadNewContract),
          content: const Text(
            'החוזה הנוכחי יעבור לחוזים קודמים, ותוקף של שנה יתחיל מיום ההעלאה החדשה.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.uploadNewContract),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

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
    if (source == null || !mounted) return;

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<DogProvider>();
    await provider.uploadContractPhoto(
      dogId: widget.dog.id,
      imageFile: File(picked.path),
      startNew: startNew,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final error = provider.errorMessage;
    if (error != null) {
      showErrorSnackbar(context, error);
      provider.clearError();
    } else {
      showSuccessSnackbar(context, AppStrings.contractUploaded);
    }
  }

  Future<void> _removePhoto(String url) async {
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

    final provider = context.read<DogProvider>();
    await provider.removeContractPhoto(dogId: widget.dog.id, photoUrl: url);
    if (!mounted) return;
    final error = provider.errorMessage;
    if (error != null) {
      showErrorSnackbar(context, error);
      provider.clearError();
    }
  }

  void _showPhoto(String url) {
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
    final dog = widget.dog;
    final bookings = context.watch<BookingProvider>().bookings;
    final today = DateTime.now();
    final contract = dog.contract;
    final valid = contract != null && contract.isValidOn(today);
    final alert = DogContractRules.alertForDog(dog, bookings, today);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final previous = [...dog.previousContracts]
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.yearlyContract,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (alert == DogContractAlert.missing) ...[
              _StatusBanner(
                color: AppColors.contractAlert,
                icon: Icons.warning_amber_rounded,
                text: AppStrings.missingContract,
              ),
              const SizedBox(height: 12),
            ] else if (alert == DogContractAlert.expiring) ...[
              _StatusBanner(
                color: AppColors.contractExpiring,
                icon: Icons.schedule,
                text:
                    '${AppStrings.contractExpiringSoon} · ${contractDaysRemainingLabel(contract!.daysRemainingOn(today))}',
              ),
              const SizedBox(height: 12),
            ],
            if (contract == null)
              const Text(
                'אין חוזה שנתי',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              _CurrentContract(
                contract: contract,
                valid: valid,
                dateFormat: dateFormat,
                today: today,
                onOpen: _showPhoto,
                onRemove: _removePhoto,
              ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else if (valid) ...[
              OutlinedButton.icon(
                onPressed: () => _pickAndUpload(startNew: false),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text(AppStrings.addContractPhoto),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => _pickAndUpload(startNew: true),
                  child: const Text(AppStrings.uploadNewContract),
                ),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => _pickAndUpload(startNew: true),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(contract == null
                    ? AppStrings.uploadContract
                    : AppStrings.uploadNewContract),
              ),
            if (previous.isNotEmpty) ...[
              const Divider(height: 28),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${AppStrings.previousContracts} (${previous.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  children: [
                    for (final old in previous)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PreviousContract(
                          contract: old,
                          dateFormat: dateFormat,
                          onOpen: _showPhoto,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentContract extends StatelessWidget {
  final DogContract contract;
  final bool valid;
  final DateFormat dateFormat;
  final DateTime today;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRemove;

  const _CurrentContract({
    required this.contract,
    required this.valid,
    required this.dateFormat,
    required this.today,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final expiring = valid && contract.expiresInLessThanMonth(today);
    final color = !valid
        ? AppColors.contractAlert
        : expiring
            ? AppColors.contractExpiring
            : AppColors.primary;
    final totalDays = contractDateOnly(contract.expiresAt)
        .difference(contractDateOnly(contract.uploadedAt))
        .inDays;
    final elapsed = contractDateOnly(today)
        .difference(contractDateOnly(contract.uploadedAt))
        .inDays
        .clamp(0, totalDays <= 0 ? 1 : totalDays);
    final progress = totalDays <= 0 ? 1.0 : elapsed / totalDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valid
              ? 'בתוקף · ${contractDaysRemainingLabel(contract.daysRemainingOn(today))}'
              : 'פג תוקף ב-${dateFormat.format(contract.expiresAt)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              dateFormat.format(contract.uploadedAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(contract.expiresAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PhotoStrip(
          urls: contract.photoUrls,
          onOpen: onOpen,
          onRemove: onRemove,
        ),
      ],
    );
  }
}

class _PreviousContract extends StatelessWidget {
  final DogContract contract;
  final DateFormat dateFormat;
  final ValueChanged<String> onOpen;

  const _PreviousContract({
    required this.contract,
    required this.dateFormat,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${dateFormat.format(contract.uploadedAt)} – ${dateFormat.format(contract.expiresAt)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _PhotoStrip(urls: contract.photoUrls, onOpen: onOpen),
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<String> urls;
  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onRemove;

  const _PhotoStrip({
    required this.urls,
    required this.onOpen,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final url = urls[index];
          return Stack(
            children: [
              GestureDetector(
                onTap: () => onOpen(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove!(url),
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
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _StatusBanner({
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
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
