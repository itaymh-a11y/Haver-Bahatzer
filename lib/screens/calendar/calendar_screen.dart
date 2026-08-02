import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/booking_model.dart';
import '../../models/stay_phase.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/vacation_provider.dart';
import '../../widgets/bookings/booking_card.dart';
import '../bookings/booking_form_screen.dart';
import 'vacations_screen.dart';

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
    final vacationProvider = context.watch<VacationProvider>();
    final dogProvider = context.watch<DogProvider>();
    final selectedBookings = [
      ...provider.getBookingsForDay(_selectedDay),
      ...provider.getSoftHoldsForDay(_selectedDay).where(
            (hold) => !provider
                .getBookingsForDay(_selectedDay)
                .any((b) => b.id == hold.id),
          ),
    ];
    final isSelectedDayVacation = vacationProvider.isDayBlocked(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendar),
        actions: [
          IconButton(
            tooltip: AppStrings.vacations,
            icon: const Icon(Icons.beach_access_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VacationsScreen(initialStartDate: _selectedDay),
              ),
            ),
          ),
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
              defaultBuilder: (context, day, focusedDay) =>
                  _buildVacationDay(context, day, vacationProvider),
              todayBuilder: (context, day, focusedDay) =>
                  _buildVacationDay(context, day, vacationProvider, isToday: true),
              selectedBuilder: (context, day, focusedDay) =>
                  _buildVacationDay(context, day, vacationProvider, isSelected: true),
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
                    vacationProvider: vacationProvider,
                  )
                : Column(
                    children: [
                      if (selectedBookings.any(
                          (b) => b.type == BookingType.boarding))
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: StayPhaseLegend(),
                        ),
                      Expanded(
                        child: selectedBookings.isEmpty
                            ? Center(
                                child: Text(
                                  isSelectedDayVacation
                                      ? AppStrings.vacationDay
                                      : AppStrings.noBookings,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: selectedBookings.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => BookingCard(
                                  booking: selectedBookings[i],
                                  referenceDay: _selectedDay,
                                ),
                              ),
                      ),
                    ],
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

  Widget? _buildVacationDay(
    BuildContext context,
    DateTime day,
    VacationProvider vacationProvider, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    if (!vacationProvider.isDayBlocked(day)) return null;

    final Color fill;
    final Color textColor;
    if (isSelected) {
      fill = AppColors.primary.withValues(alpha: 0.85);
      textColor = Colors.white;
    } else if (isToday) {
      fill = AppColors.vacationDay.withValues(alpha: 0.35);
      textColor = AppColors.onSurface;
    } else {
      fill = AppColors.vacationDay.withValues(alpha: 0.22);
      textColor = AppColors.onSurface;
    }

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.vacationDay,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(color: textColor),
      ),
    );
  }
}

class _WeekKennelView extends StatelessWidget {
  final List<DateTime> weekDays;
  final BookingProvider bookingProvider;
  final DogProvider dogProvider;
  final VacationProvider vacationProvider;

  const _WeekKennelView({
    required this.weekDays,
    required this.bookingProvider,
    required this.dogProvider,
    required this.vacationProvider,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StayPhaseLegend(),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.handshake_outlined,
                          size: 14, color: AppColors.softHold),
                      SizedBox(width: 4),
                      Text(
                        AppStrings.softHoldCalendarLabel,
                        style: TextStyle(
                          color: AppColors.softHold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
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
                        final softHolds =
                            bookingProvider.getSoftHoldsForDay(day);
                        final isVacation = vacationProvider.isDayBlocked(day);

                        return SizedBox(
                          width: dayColumnWidth,
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: isVacation
                                ? AppColors.vacationDay.withValues(alpha: 0.08)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dayTitle(day),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (isVacation) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      AppStrings.vacationDay,
                                      style: TextStyle(
                                        color: AppColors.vacationDay
                                            .withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  ...KennelConstants.all.map((kennel) {
                                    final kennelBookings = dayBookings
                                        .where((b) =>
                                            b.kennelIdForDate(day) ==
                                            kennel.id)
                                        .toList();

                                    final dogPhases = <String, StayPhase>{};
                                    for (final b in kennelBookings) {
                                      final phase =
                                          StayPhase.forBookingDay(b, day);
                                      for (final id in b.dogIds) {
                                        dogPhases.putIfAbsent(
                                            id, () => phase);
                                      }
                                    }

                                    final dogEntries =
                                        dogPhases.entries.map((e) {
                                      final idx = dogProvider.dogs
                                          .indexWhere((d) => d.id == e.key);
                                      final name = idx != -1
                                          ? dogProvider.dogs[idx].name
                                          : e.key;
                                      return _DogStayEntry(
                                        name: name,
                                        phase: e.value,
                                      );
                                    }).toList()
                                          ..sort((a, b) =>
                                              a.name.compareTo(b.name));

                                    final softHoldNames = softHolds
                                        .where((h) =>
                                            h.softHoldKennelId == kennel.id)
                                        .expand((h) => h.dogIds)
                                        .map((id) {
                                      final idx = dogProvider.dogs
                                          .indexWhere((d) => d.id == id);
                                      return idx != -1
                                          ? dogProvider.dogs[idx].name
                                          : id;
                                    }).toSet()
                                        .toList()
                                      ..sort();

                                    final occupied = dogEntries.isNotEmpty;
                                    final isFull =
                                        dogEntries.length >= kennel.maxDogs;
                                    final statusText = occupied
                                        ? (isFull ? 'מלא' : 'תפוס חלקית')
                                        : 'ריק';
                                    final statusColor = occupied
                                        ? (isFull
                                            ? AppColors.occupancyFull
                                            : AppColors.occupancyPartial)
                                        : AppColors.occupancyEmpty;
                                    final statusIcon = occupied
                                        ? (isFull
                                            ? Icons.radio_button_checked
                                            : Icons.timelapse)
                                        : Icons.radio_button_unchecked;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withValues(alpha: 0.55),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      statusIcon,
                                                      size: 11,
                                                      color: statusColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$statusText (${dogEntries.length}/${kennel.maxDogs})',
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (dogEntries.isEmpty &&
                                              softHoldNames.isEmpty)
                                            const Text(
                                              '—',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            )
                                          else ...[
                                            if (dogEntries.isNotEmpty)
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: dogEntries
                                                    .map(
                                                      (entry) => StayPhaseChip(
                                                        label: entry.name,
                                                        phase: entry.phase,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            if (softHoldNames.isNotEmpty) ...[
                                              if (dogEntries.isNotEmpty)
                                                const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: softHoldNames
                                                    .map(
                                                      (name) => Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .softHold
                                                              .withValues(
                                                                  alpha: 0.14),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                            color: AppColors
                                                                .softHold,
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          '$name · ${AppStrings.softHold}',
                                                          style:
                                                              const TextStyle(
                                                            color: AppColors
                                                                .softHold,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ],
                                          ],
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
              ),
            ),
          ],
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

class _DogStayEntry {
  final String name;
  final StayPhase phase;

  const _DogStayEntry({required this.name, required this.phase});
}
