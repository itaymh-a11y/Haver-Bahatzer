import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/booking_model.dart';
import '../../providers/dog_provider.dart';
import '../../screens/bookings/booking_detail_screen.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;

  const BookingCard({super.key, required this.booking});

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

  @override
  Widget build(BuildContext context) {
    final dogs = context.watch<DogProvider>().dogs;
    final dogNames = booking.dogIds
        .map((id) {
          final idx = dogs.indexWhere((d) => d.id == id);
          return idx != -1 ? dogs[idx].name : '';
        })
        .where((n) => n.isNotEmpty)
        .join(', ');

    final dateFormat = DateFormat('dd/MM/yy', 'he');
    final statusColor = _statusColor(booking.status);
    final kennelInfo = booking.kennelId != null
        ? KennelConstants.findById(booking.kennelId!)
        : null;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BookingDetailScreen(booking: booking)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dogNames.isNotEmpty ? dogNames : AppStrings.selectDogs,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(booking.status),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        booking.type == BookingType.boarding
                            ? Icons.home_outlined
                            : Icons.handshake_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        booking.type.hebrewLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (kennelInfo != null) ...[
                        const SizedBox(width: 8),
                        const Text('•',
                            style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Text(
                          kennelInfo.hebrewName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        booking.type == BookingType.introMeeting
                            ? dateFormat.format(booking.startDate)
                            : '${dateFormat.format(booking.startDate)} – ${dateFormat.format(booking.endDate)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (booking.type == BookingType.introMeeting &&
                          booking.meetingTime != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          booking.meetingTime!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (booking.type == BookingType.boarding &&
                      booking.totalPrice != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          booking.isPaid
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: booking.isPaid
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.remainingAmount <= 0.01
                              ? '₪${booking.totalPrice!.toStringAsFixed(0)}  ${AppStrings.isPaid}'
                              : booking.paidAmount > 0
                                  ? '${AppStrings.partiallyPaid} ${booking.paidAmount.toStringAsFixed(0)}/${booking.totalPrice!.toStringAsFixed(0)}'
                                  : '₪${booking.totalPrice!.toStringAsFixed(0)}  ${AppStrings.unpaid}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: booking.remainingAmount <= 0.01
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (booking.needsContractAlert)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    color: AppColors.contractAlert,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppStrings.missingContract,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
