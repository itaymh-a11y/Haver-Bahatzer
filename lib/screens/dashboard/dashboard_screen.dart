import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/pension_provider.dart';
import '../../providers/vacation_provider.dart';
import '../../widgets/dashboard/daily_feed_card.dart';
import '../../widgets/dashboard/intro_reminders_card.dart';
import '../../widgets/dashboard/occupancy_bar.dart';
import '../bookings/booking_list_screen.dart';
import '../calendar/calendar_screen.dart';
import '../dogs/dog_list_screen.dart';
import '../financials/financials_screen.dart';
import '../pension/pension_hub_screen.dart';
import '../settings/tag_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _selectedFeedDay;

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedFeedDay = _todayDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DogProvider>().startListening();
      context.read<BookingProvider>().startListening();
      context.read<VacationProvider>().startListening();
      context.read<PensionProvider>().startListening();
    });
  }

  void _shiftFeedDay(int days) {
    setState(() {
      _selectedFeedDay = _selectedFeedDay.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'הגדרות תגיות',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.logout,
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const OccupancyBar(),
          const SizedBox(height: 12),
          DailyFeedCard(
            selectedDay: _selectedFeedDay,
            checkIns: bookingProvider.checkInsForDay(_selectedFeedDay),
            checkOuts: bookingProvider.checkOutsForDay(_selectedFeedDay),
            onPreviousDay: () => _shiftFeedDay(-1),
            onNextDay: () => _shiftFeedDay(1),
            onGoToToday: () => setState(() => _selectedFeedDay = _todayDate),
          ),
          const SizedBox(height: 12),
          IntroRemindersCard(intros: bookingProvider.todayIntros),
          const SizedBox(height: 20),
          _NavigationGrid(),
        ],
      ),
    );
  }
}

class _NavigationGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.calendar_month,
                label: AppStrings.calendar,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavCard(
                icon: Icons.book_online_outlined,
                label: AppStrings.bookings,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingListScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.pets,
                label: AppStrings.dogs,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DogListScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavCard(
                icon: Icons.bar_chart_outlined,
                label: AppStrings.financials,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FinancialsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.inventory_2_outlined,
                label: AppStrings.pensionProducts,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PensionHubScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
