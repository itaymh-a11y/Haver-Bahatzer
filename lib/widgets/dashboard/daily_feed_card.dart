import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/booking_model.dart';
import '../../providers/dog_provider.dart';

class DailyFeedCard extends StatelessWidget {
  final DateTime selectedDay;
  final List<Booking> checkIns;
  final List<Booking> checkOuts;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback? onGoToToday;

  const DailyFeedCard({
    super.key,
    required this.selectedDay,
    required this.checkIns,
    required this.checkOuts,
    required this.onPreviousDay,
    required this.onNextDay,
    this.onGoToToday,
  });

  bool get _isToday {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _isToday
        ? AppStrings.goToToday
        : DateFormat('EEEE, dd/MM/yyyy', 'he').format(selectedDay);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'יום הבא',
                    onPressed: onNextDay,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        children: [
                          Text(
                            dateLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (!_isToday && onGoToToday != null)
                            TextButton(
                              onPressed: onGoToToday,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(AppStrings.goToToday),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'יום קודם',
                    onPressed: onPreviousDay,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FeedColumn(
                    title: _isToday
                        ? AppStrings.todayCheckIns
                        : AppStrings.checkIns,
                    bookings: checkIns,
                    icon: Icons.login,
                    color: AppColors.primary,
                  ),
                ),
                const VerticalDivider(width: 24),
                Expanded(
                  child: _FeedColumn(
                    title: _isToday
                        ? AppStrings.todayCheckOuts
                        : AppStrings.checkOuts,
                    bookings: checkOuts,
                    icon: Icons.logout,
                    color: AppColors.statusCompleted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedColumn extends StatelessWidget {
  final String title;
  final List<Booking> bookings;
  final IconData icon;
  final Color color;

  const _FeedColumn({
    required this.title,
    required this.bookings,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dogs = context.watch<DogProvider>().dogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty)
          Text(
            AppStrings.noBookings,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          )
        else
          ...bookings.map((b) {
            final names = b.dogIds
                .map((id) => dogs.firstWhere(
                      (d) => d.id == id,
                      orElse: () => dogs.first,
                    ).name)
                .where((n) => n.isNotEmpty)
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                names.isNotEmpty ? names : b.id,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
      ],
    );
  }
}
