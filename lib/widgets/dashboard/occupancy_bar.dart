import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';

class OccupancyBar extends StatefulWidget {
  const OccupancyBar({super.key});

  @override
  State<OccupancyBar> createState() => _OccupancyBarState();
}

class _OccupancyBarState extends State<OccupancyBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final dogs = context.watch<DogProvider>().dogs;

    final occupied = bookingProvider.currentlyOccupiedBookings;
    final occupiedCount = occupied.length;
    final total = KennelConstants.all.length;
    final fraction = total == 0 ? 0.0 : occupiedCount / total;

    // Sort bookings by KennelConstants.all order for consistent display
    final sortedOccupied = [...occupied]..sort((a, b) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final aKennel = a.kennelIdForDate(todayDate) ?? '';
        final bKennel = b.kennelIdForDate(todayDate) ?? '';
        final ai = KennelConstants.all.indexWhere((k) => k.id == aKennel);
        final bi = KennelConstants.all.indexWhere((k) => k.id == bKennel);
        return ai.compareTo(bi);
      });

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: occupiedCount > 0
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.occupancy,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      Text(
                        '$occupiedCount/$total ${AppStrings.unitsFreeOf}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      if (occupiedCount > 0) ...[
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.expand_more,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 12,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fraction >= 1.0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...sortedOccupied.map((booking) {
                              final today = DateTime.now();
                              final todayDate =
                                  DateTime(today.year, today.month, today.day);
                              final currentKennelId =
                                  booking.kennelIdForDate(todayDate);
                              final kennel = currentKennelId != null
                                  ? KennelConstants.findById(currentKennelId)
                                  : null;
                              final dogNames = booking.dogIds
                                  .map((id) {
                                    final idx = dogs.indexWhere((d) => d.id == id);
                                    return idx != -1 ? dogs[idx].name : '';
                                  })
                                  .where((n) => n.isNotEmpty)
                                  .join(', ');

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.home_outlined,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      kennel?.hebrewName ?? currentKennelId ?? '—',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('—',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dogNames.isNotEmpty ? dogNames : '—',
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
