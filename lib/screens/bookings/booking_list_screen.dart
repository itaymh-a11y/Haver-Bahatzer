import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/bookings/booking_card.dart';
import 'booking_form_screen.dart';

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Booking> _sortByCheckoutDate(List<Booking> items) {
    final sorted = [...items];
    sorted.sort((a, b) => a.endDate.compareTo(b.endDate));
    return sorted;
  }

  int _paymentPriority(Booking b) {
    if (b.remainingAmount <= 0.01) return 2; // fully paid
    if (b.paidAmount > 0) return 1; // partially paid
    return 0; // unpaid
  }

  List<Booking> _sortCompleted(List<Booking> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final priorityCompare = _paymentPriority(a).compareTo(_paymentPriority(b));
      if (priorityCompare != 0) return priorityCompare;
      return a.endDate.compareTo(b.endDate);
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bookings),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.statusCompleted),
            Tab(text: AppStrings.statusActive),
            Tab(text: AppStrings.statusUpcoming),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingList(bookings: _sortCompleted(provider.completedBookings)),
          _BookingList(bookings: _sortByCheckoutDate(provider.activeBookings)),
          _BookingList(bookings: _sortByCheckoutDate(provider.upcomingBookings)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;

  const _BookingList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_online_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              AppStrings.noBookings,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
    );
  }
}
