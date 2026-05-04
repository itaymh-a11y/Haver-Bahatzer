import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/bookings/booking_card.dart';
import '../bookings/booking_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isWeekView = false;

  DateTime _startOfWeek(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final daysFromSunday = normalized.weekday % 7;
    return normalized.subtract(Duration(days: daysFromSunday));
  }

  List<DateTime> _weekDays(DateTime focusedDay) {
    final start = _startOfWeek(focusedDay);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final dogProvider = context.watch<DogProvider>();
    final selectedBookings = provider.getBookingsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendar),
        actions: [
          IconButton(
            tooltip: _isWeekView ? 'חזרה לתצוגת חודש' : 'זום שבועי',
            icon: Icon(_isWeekView ? Icons.zoom_out_map : Icons.zoom_in_map),
            onPressed: () => setState(() => _isWeekView = !_isWeekView),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Booking>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            calendarFormat: _isWeekView ? CalendarFormat.week : CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: provider.getBookingsForDay,
            locale: 'he_IL',
            startingDayOfWeek: StartingDayOfWeek.sunday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'חודש',
              CalendarFormat.week: 'שבוע',
            },
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 2,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;

                final hasBoarding = events
                    .any((e) => e.type == BookingType.boarding);
                final hasIntro = events
                    .any((e) => e.type == BookingType.introMeeting);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBoarding)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.boardingDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasIntro)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.introMeetingDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              },
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _isWeekView
                ? _WeekKennelView(
                    weekDays: _weekDays(_focusedDay),
                    bookingProvider: provider,
                    dogProvider: dogProvider,
                  )
                : selectedBookings.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.noBookings,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: selectedBookings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            BookingCard(booking: selectedBookings[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingFormScreen(initialDate: _selectedDay),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WeekKennelView extends StatelessWidget {
  final List<DateTime> weekDays;
  final BookingProvider bookingProvider;
  final DogProvider dogProvider;

  const _WeekKennelView({
    required this.weekDays,
    required this.bookingProvider,
    required this.dogProvider,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minDayColumnWidth = 230.0;
        final targetWidth = minDayColumnWidth * weekDays.length;
        final rowWidth =
            constraints.maxWidth > targetWidth ? constraints.maxWidth : targetWidth;
        final dayColumnWidth = rowWidth / weekDays.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: rowWidth,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weekDays.map((day) {
                  final dayBookings = bookingProvider
                      .getBookingsForDay(day)
                      .where((b) => b.type == BookingType.boarding)
                      .toList();

                  return SizedBox(
                    width: dayColumnWidth,
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayTitle(day),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ...KennelConstants.all.map((kennel) {
                              final kennelBookings = dayBookings
                                  .where((b) => b.kennelId == kennel.id)
                                  .toList();
                              final dogIds = <String>{};
                              for (final b in kennelBookings) {
                                dogIds.addAll(b.dogIds);
                              }
                              final dogNames = dogIds.map((id) {
                                final idx = dogProvider.dogs.indexWhere((d) => d.id == id);
                                return idx != -1 ? dogProvider.dogs[idx].name : id;
                              }).toList();

                              final occupied = dogIds.isNotEmpty;
                              final isFull = dogIds.length >= kennel.maxDogs;
                              final statusText =
                                  occupied ? (isFull ? 'מלא' : 'תפוס חלקית') : 'ריק';
                              final statusColor = occupied
                                  ? (isFull ? AppColors.error : Colors.orange)
                                  : Colors.green;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kennel.hebrewName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$statusText (${dogIds.length}/${kennel.maxDogs})',
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dogNames.isEmpty ? '—' : dogNames.join(', '),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  String _dayTitle(DateTime day) {
    const dayNames = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    final weekdayIndex = day.weekday % 7;
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return 'יום ${dayNames[weekdayIndex]} • $d/$m';
  }
}
