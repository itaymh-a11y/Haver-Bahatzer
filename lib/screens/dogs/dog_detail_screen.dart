import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/dog_model.dart';
import '../../models/tag_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/bookings/booking_card.dart';
import '../../widgets/dogs/dog_tag_chip.dart';
import 'dog_form_screen.dart';

class DogDetailScreen extends StatefulWidget {
  final Dog dog;

  const DogDetailScreen({super.key, required this.dog});

  @override
  State<DogDetailScreen> createState() => _DogDetailScreenState();
}

class _DogDetailScreenState extends State<DogDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _contactOwner(BuildContext context, String phone) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: const Text('התקשר'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await launchUrl(Uri(scheme: 'tel', path: phone));
                } catch (_) {
                  if (context.mounted) showErrorSnackbar(context, 'לא ניתן לחייג: $phone');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.primary),
              title: const Text('וואטסאפ'),
              onTap: () async {
                Navigator.pop(ctx);
                final digits = phone.replaceAll(RegExp(r'\D'), '');
                final normalized = digits.startsWith('0') ? '972${digits.substring(1)}' : digits;
                try {
                  await launchUrl(
                    Uri.parse('whatsapp://send?phone=$normalized'),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  try {
                    await launchUrl(
                      Uri.parse('https://wa.me/$normalized'),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    if (context.mounted) showErrorSnackbar(context, 'לא ניתן לפתוח וואטסאפ');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dogs = context.watch<DogProvider>().dogs;
    final liveDog = dogs.firstWhere((d) => d.id == widget.dog.id, orElse: () => widget.dog);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DogFormScreen(dog: liveDog)),
        ),
        child: const Icon(Icons.edit),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 62),
              title: Text(
                liveDog.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black87)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  liveDog.photoUrl != null && liveDog.photoUrl!.isNotEmpty
                      ? Image.network(liveDog.photoUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.pets, size: 80, color: Colors.white70),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'פרופיל'),
                Tab(text: 'סטטיסטיקות'),
                Tab(text: 'היסטוריית הזמנות'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProfileTab(dog: liveDog, onCall: () => _contactOwner(context, liveDog.ownerPhone)),
            _StatsTab(dog: liveDog),
            _HistoryTab(dog: liveDog),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Profile ────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final Dog dog;
  final VoidCallback onCall;

  const _ProfileTab({required this.dog, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _InfoCard(dog: dog, onCall: onCall),
        if (dog.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TagsCard(dog: dog),
        ],
        if (dog.notes != null && dog.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NotesCard(dog: dog),
        ],
        if (dog.additionalNotes != null && dog.additionalNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AdditionalNotesCard(dog: dog),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Tab 2: Statistics ─────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final Dog dog;

  const _StatsTab({required this.dog});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final totalDays = provider.totalBoardingDaysForDog(dog.id);
    final totalPaid = provider.totalPaidAmountForDog(dog.id);
    final distribution = provider.kennelDistributionForDog(dog.id);

    if (totalDays == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hotel_outlined, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('אין הזמנות עדיין', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _StatSummaryCard(totalDays: totalDays, totalPaid: totalPaid),
        const SizedBox(height: 16),
        _KennelDistributionCard(distribution: distribution),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final int totalDays;
  final double totalPaid;

  const _StatSummaryCard({required this.totalDays, required this.totalPaid});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('סיכום', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const Divider(height: 24),
            _StatRow(
              icon: Icons.hotel_outlined,
              label: 'סה״כ ימי אירוח',
              value: '$totalDays ימים',
            ),
            const SizedBox(height: 8),
            _StatRow(
              icon: Icons.payments_outlined,
              label: 'סה״כ שולם',
              value: '₪${totalPaid.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _KennelDistributionCard extends StatelessWidget {
  final Map<String, int> distribution;

  const _KennelDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold(0, (a, b) => a + b);
    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('התפלגות כלובים', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (distribution.isEmpty)
              const Text('אין נתוני כלובים',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...sorted.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _KennelBar(
                      kennelId: entry.key,
                      count: entry.value,
                      total: total,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _KennelBar extends StatelessWidget {
  final String kennelId;
  final int count;
  final int total;

  const _KennelBar({required this.kennelId, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final name = KennelConstants.findById(kennelId)?.hebrewName ?? kennelId;
    final pct = total > 0 ? (count / total * 100).round() : 0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total > 0 ? count / total : 0,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$pct%',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Tab 3: History ────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final Dog dog;

  const _HistoryTab({required this.dog});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final bookings = [...provider.boardingBookingsForDog(dog.id)]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (bookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('אין הזמנות עדיין', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => BookingCard(booking: bookings[index]),
    );
  }
}

// ── Existing private widgets (unchanged) ──────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Dog dog;
  final VoidCallback onCall;

  const _InfoCard({required this.dog, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.pets, label: AppStrings.breed, value: dog.breed),
            if (dog.ageYears != null)
              _InfoRow(
                  icon: Icons.calendar_today,
                  label: AppStrings.age,
                  value: '${dog.ageYears} ${AppStrings.ageYears}'),
            if (dog.isMale != null)
              _InfoRow(
                  icon: dog.isMale! ? Icons.male : Icons.female,
                  label: 'מין',
                  value: dog.isMale! ? 'זכר' : 'נקבה'),
            if (dog.dailyRate != null)
              _InfoRow(
                  icon: Icons.payments_outlined,
                  label: AppStrings.dailyRate,
                  value: '₪${dog.dailyRate!.toStringAsFixed(0)} ליום'),
            _InfoRow(icon: Icons.person, label: AppStrings.ownerName, value: dog.ownerName),
            InkWell(
              onTap: onCall,
              child: _InfoRow(
                icon: Icons.phone,
                label: AppStrings.ownerPhone,
                value: dog.ownerPhone,
                valueColor: AppColors.primary,
              ),
            ),
            if (dog.mealsPerDay != null)
              _InfoRow(
                icon: Icons.restaurant,
                label: 'מס\' ארוחות ביום',
                value: '${dog.mealsPerDay}',
              ),
            if (dog.isNeutered != null)
              _InfoRow(
                icon: Icons.health_and_safety,
                label: 'מסורס / מעוקרת',
                value: dog.isNeutered! ? 'כן' : 'לא',
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsCard extends StatelessWidget {
  final Dog dog;

  const _TagsCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();
    final resolvedTags = dog.tags
        .map((id) => tagProvider.findById(id))
        .whereType<CustomTag>()
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.tags, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: resolvedTags.map((tag) => DogTagChip(tag: tag)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final Dog dog;

  const _NotesCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.notes, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(dog.notes ?? '', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AdditionalNotesCard extends StatelessWidget {
  final Dog dog;

  const _AdditionalNotesCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('הערות נוספות', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(dog.additionalNotes ?? '', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
