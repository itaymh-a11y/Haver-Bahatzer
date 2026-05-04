import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/booking_model.dart';
import '../../models/dog_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';

class FinancialsScreen extends StatefulWidget {
  const FinancialsScreen({super.key});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedMonth;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showIncomeDetails(
    BuildContext context,
    List<BookingPaymentEntry> entries,
    DogProvider dogProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _IncomeDetailsSheet(
        entries: entries,
        dogProvider: dogProvider,
      ),
    );
  }

  void _showHostedDogsDetails(
    BuildContext context,
    DateTime month,
    BookingProvider bookingProvider,
    DogProvider dogProvider,
  ) {
    final monthlyBookings = bookingProvider.boardingBookingsForMonth(month);
    final summariesByDog = <String, _HostedDogMonthSummary>{};

    for (final booking in monthlyBookings) {
      for (final dogId in booking.dogIds) {
        final summary = summariesByDog.putIfAbsent(
          dogId,
          () => _HostedDogMonthSummary(dogId: dogId),
        );
        summary.ranges.add(_DateRange(start: booking.startDate, end: booking.endDate));
        summary.totalDays += booking.numberOfDays;
      }
    }

    final summaries = summariesByDog.values.toList()
      ..sort((a, b) => b.totalDays.compareTo(a.totalDays));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HostedDogsDetailsSheet(
        summaries: summaries,
        dogProvider: dogProvider,
      ),
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final dogProvider = context.watch<DogProvider>();

    final monthRevenue = bookingProvider.revenueForMonth(_selectedMonth);
    final avgStay = bookingProvider.averageStayDaysForMonth(_selectedMonth);
    final dogsHosted = bookingProvider.uniqueDogsHostedForMonth(_selectedMonth);
    final dayDist = bookingProvider.bookingDayDistributionForMonth(_selectedMonth);
    final unpaid = bookingProvider.unpaidBookings;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcomingDebts = unpaid
        .where((b) => b.startDate.isAfter(todayDate))
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final endedDebts = unpaid
        .where((b) => b.endDate.isBefore(todayDate))
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final monthFormat = DateFormat('MMMM yyyy', 'he');
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    // ── Month picker (shared between both tabs) ────────────────────────────
    final monthPicker = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            }),
          ),
          Text(
            monthFormat.format(_selectedMonth),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCurrentMonth
                ? null
                : () => setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    }),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.financials),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'סטטיסטיקה'),
            Tab(text: 'הזמנות'),
          ],
        ),
      ),
      body: Column(
        children: [
          monthPicker,
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0: Statistics ──────────────────────────────────────
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // ── Widget 1: Monthly Income ───────────────────────────
                    _StatCard(
                      icon: Icons.payments_outlined,
                      label: 'הכנסות חודשיות',
                      value: '₪${monthRevenue.toStringAsFixed(0)}',
                      onTap: () => _showIncomeDetails(
                        context,
                        bookingProvider.paymentEntriesForMonth(_selectedMonth),
                        dogProvider,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Widget 2: Average Stay Days ────────────────────────
                    _StatCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'ממוצע ימי שהייה',
                      value: avgStay.toStringAsFixed(1),
                    ),
                    const SizedBox(height: 12),

                    // ── Widget 3: Dogs Hosted ──────────────────────────────
                    _StatCard(
                      icon: Icons.pets_outlined,
                      label: 'כלבים שאורחו',
                      value: '$dogsHosted',
                      onTap: () => _showHostedDogsDetails(
                        context,
                        _selectedMonth,
                        bookingProvider,
                        dogProvider,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Widget 4: Day-of-Week Distribution ─────────────────
                    _DayDistributionCard(distribution: dayDist),

                    const SizedBox(height: 24),

                    // ── Debt Tracker ───────────────────────────────────────
                    Text(AppStrings.debtTracker, style: titleStyle),
                    const SizedBox(height: 8),
                    if (unpaid.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          AppStrings.noUnpaid,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...[
                        Text(
                          'חובות להזמנות שהסתיימו ולא שולמו',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        if (endedDebts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'אין חובות בקבוצה זו',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ...endedDebts.map((b) => _DebtCard(
                                booking: b,
                                dogs: dogProvider.dogs,
                                dateFormat: dateFormat,
                              )),
                        const SizedBox(height: 12),
                        Text(
                          'חובות להזמנות שטרם התחילו',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        if (upcomingDebts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'אין חובות בקבוצה זו',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ...upcomingDebts.map((b) => _DebtCard(
                                booking: b,
                                dogs: dogProvider.dogs,
                                dateFormat: dateFormat,
                              )),
                      ],

                    const SizedBox(height: 24),
                  ],
                ),

                // ── Tab 1: Bookings Table ──────────────────────────────────
                _BookingsTableTab(
                  selectedMonth: _selectedMonth,
                  bookingProvider: bookingProvider,
                  dogProvider: dogProvider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bookings Table Tab ───────────────────────────────────────────────────────

class _BookingsTableTab extends StatelessWidget {
  final DateTime selectedMonth;
  final BookingProvider bookingProvider;
  final DogProvider dogProvider;

  const _BookingsTableTab({
    required this.selectedMonth,
    required this.bookingProvider,
    required this.dogProvider,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy', 'he');
    final bookings = bookingProvider.boardingBookingsOverlappingMonth(selectedMonth)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (bookings.isEmpty) {
      return const Center(
        child: Text(
          'אין הזמנות לחודש זה',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    const headerStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    Widget headerRow() => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              const Expanded(flex: 3, child: Text('שם בעלים', style: headerStyle)),
              const Expanded(flex: 2, child: Text('עלות', style: headerStyle)),
              const Expanded(flex: 2, child: Text('אמצעי תשלום', style: headerStyle)),
              SizedBox(
                width: 60,
                child: const Text('תאריך תשלום', style: headerStyle, textAlign: TextAlign.end),
              ),
            ],
          ),
        );

    return Column(
      children: [
        headerRow(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = bookings[i];
              final monthPayments = b.payments
                  .where((p) =>
                      p.paidAt.year == selectedMonth.year &&
                      p.paidAt.month == selectedMonth.month)
                  .toList()
                ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
              final monthPaidAmount =
                  monthPayments.fold<double>(0, (sum, p) => sum + p.amount);
              final hasAnyPayments = b.paidAmount > 0;
              final amountColor = monthPaidAmount > 0
                  ? AppColors.primary
                  : hasAnyPayments
                      ? Colors.blue.shade700
                      : AppColors.error;
              final ownerName = b.dogIds
                  .map((id) {
                    final idx = dogProvider.dogs.indexWhere((d) => d.id == id);
                    return idx != -1 ? dogProvider.dogs[idx].ownerName : '';
                  })
                  .where((n) => n.isNotEmpty)
                  .toSet()
                  .join(', ');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        ownerName.isNotEmpty ? ownerName : '—',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.totalPrice == null
                                ? '—'
                                : monthPaidAmount > 0
                                    ? '₪${monthPaidAmount.toStringAsFixed(0)} שולם'
                                    : '₪${b.totalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (monthPayments.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...monthPayments.map(
                              (p) => Text(
                                '₪${p.amount.toStringAsFixed(0)} ${p.method.hebrewLabel} ${dateFormat.format(p.paidAt)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        monthPayments.length > 1
                            ? 'מפוצל'
                            : monthPayments.isNotEmpty
                            ? monthPayments.last.method.hebrewLabel
                            : '—',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        monthPayments.length > 1
                            ? '—'
                            : monthPayments.isNotEmpty
                            ? dateFormat.format(monthPayments.last.paidAt)
                            : '—',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day Distribution Card ────────────────────────────────────────────────────

class _DayDistributionCard extends StatelessWidget {
  final List<double> distribution;

  const _DayDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'התפלגות ימי הזמנה',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = i < distribution.length ? distribution[i] : 0.0;
                return _DayBar(
                  fraction: fraction,
                  label: dayLabels[i],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final double fraction;
  final String label;

  const _DayBar({required this.fraction, required this.label});

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 80.0;
    final barHeight = (fraction * maxBarHeight).clamp(2.0, maxBarHeight);
    final pct = (fraction * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pct > 0)
          Text(
            '$pct%',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          )
        else
          const SizedBox(height: 16),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: fraction > 0 ? barHeight : maxBarHeight,
          decoration: BoxDecoration(
            color: fraction > 0 ? AppColors.primary : AppColors.chipBackground,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Debt Card ────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final Booking booking;
  final List<Dog> dogs;
  final DateFormat dateFormat;

  const _DebtCard({
    required this.booking,
    required this.dogs,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final dogNames = booking.dogIds
        .map((id) {
          final idx = dogs.indexWhere((d) => d.id == id);
          return idx != -1 ? dogs[idx].name : id;
        })
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(dogNames),
        subtitle: Text(
          '${dateFormat.format(booking.startDate)} – ${dateFormat.format(booking.endDate)}',
        ),
        trailing: Text(
          booking.paidAmount > 0
              ? '₪${booking.remainingAmount.toStringAsFixed(0)} מתוך ₪${booking.totalPrice!.toStringAsFixed(0)}'
              : '₪${booking.totalPrice!.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ── Income Details Modal ─────────────────────────────────────────────────────

class _IncomeDetailsSheet extends StatelessWidget {
  final List<BookingPaymentEntry> entries;
  final DogProvider dogProvider;

  const _IncomeDetailsSheet({
    required this.entries,
    required this.dogProvider,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy', 'he');
    final sorted = [...entries]
      ..sort((a, b) => b.payment.paidAt.compareTo(a.payment.paidAt));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'פירוט הכנסות',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${entries.length} תשלומים',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),

          if (sorted.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'אין הכנסות לחודש זה',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final entry = sorted[i];
                  final ownerName = entry.booking.dogIds
                      .map((id) {
                        final idx = dogProvider.dogs.indexWhere((d) => d.id == id);
                        return idx != -1 ? dogProvider.dogs[idx].ownerName : '';
                      })
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .join(', ');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // Owner name
                        Expanded(
                          flex: 3,
                          child: Text(
                            ownerName.isNotEmpty ? ownerName : '—',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        // Paid amount
                        Expanded(
                          flex: 2,
                          child: Text(
                            '₪${entry.payment.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Payment method
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.payment.method.hebrewLabel,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        // Payment date
                        SizedBox(
                          width: 60,
                          child: Text(
                            dateFormat.format(entry.payment.paidAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HostedDogsDetailsSheet extends StatelessWidget {
  final List<_HostedDogMonthSummary> summaries;
  final DogProvider dogProvider;

  const _HostedDogsDetailsSheet({
    required this.summaries,
    required this.dogProvider,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy', 'he');

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'כלבים שאורחו',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${summaries.length} כלבים',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),
          if (summaries.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'אין כלבים שאורחו בחודש זה',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: summaries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final summary = summaries[i];
                  final dogIndex = dogProvider.dogs.indexWhere((d) => d.id == summary.dogId);
                  final dog = dogIndex != -1 ? dogProvider.dogs[dogIndex] : null;
                  final dogName = dog?.name ?? 'כלב לא זמין';
                  final photoUrl = dog?.photoUrl;
                  final sortedRanges = [...summary.ranges]
                    ..sort((a, b) => b.start.compareTo(a.start));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.chipBackground,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.pets, color: AppColors.textSecondary)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dogName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'סה"כ ימים: ${summary.totalDays}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...sortedRanges.map(
                                (range) => Text(
                                  '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}  (${range.end.difference(range.start).inDays + 1} ימים)',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HostedDogMonthSummary {
  final String dogId;
  final List<_DateRange> ranges = [];
  int totalDays = 0;

  _HostedDogMonthSummary({required this.dogId});
}

class _DateRange {
  final DateTime start;
  final DateTime end;

  _DateRange({required this.start, required this.end});
}
