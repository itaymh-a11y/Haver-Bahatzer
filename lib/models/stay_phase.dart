import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import 'booking_model.dart';

/// Where a calendar day falls within a boarding stay.
enum StayPhase {
  checkIn,
  middle,
  checkOut,
  checkInAndOut;

  static StayPhase forBookingDay(Booking booking, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      booking.startDate.year,
      booking.startDate.month,
      booking.startDate.day,
    );
    final end = DateTime(
      booking.endDate.year,
      booking.endDate.month,
      booking.endDate.day,
    );
    final isCheckIn = d == start;
    final isCheckOut = d == end;
    if (isCheckIn && isCheckOut) return StayPhase.checkInAndOut;
    if (isCheckIn) return StayPhase.checkIn;
    if (isCheckOut) return StayPhase.checkOut;
    return StayPhase.middle;
  }

  Color get color => switch (this) {
        StayPhase.checkIn => AppColors.stayCheckIn,
        StayPhase.middle => AppColors.stayMiddle,
        StayPhase.checkOut => AppColors.stayCheckOut,
        StayPhase.checkInAndOut => AppColors.stayCheckInAndOut,
      };

  String get label => switch (this) {
        StayPhase.checkIn => AppStrings.stayLegendCheckIn,
        StayPhase.middle => AppStrings.stayLegendMiddle,
        StayPhase.checkOut => AppStrings.stayLegendCheckOut,
        StayPhase.checkInAndOut => AppStrings.stayLegendSameDay,
      };
}

class StayPhaseLegend extends StatelessWidget {
  const StayPhaseLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: StayPhase.values
          .map(
            (phase) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: phase.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  phase.label,
                  style: TextStyle(
                    color: phase.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class StayPhaseChip extends StatelessWidget {
  final String label;
  final StayPhase phase;

  const StayPhaseChip({
    super.key,
    required this.label,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: phase.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: phase.color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: phase.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
