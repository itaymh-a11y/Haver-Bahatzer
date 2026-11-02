import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/dog_contract_rules.dart';
import '../../models/dog_contract.dart';
import '../../models/dog_model.dart';
import '../../models/tag_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/tag_provider.dart';
import '../../screens/dogs/dog_detail_screen.dart';
import 'dog_tag_chip.dart';

class DogCard extends StatelessWidget {
  final Dog dog;

  const DogCard({super.key, required this.dog});

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();
    final contractAlert = DogContractRules.alertForDog(
      dog,
      context.watch<BookingProvider>().bookings,
    );
    final resolvedTags = dog.tags
        .map((id) => tagProvider.findById(id))
        .whereType<CustomTag>()
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DogDetailScreen(dog: dog)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _DogAvatar(dog: dog),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dog.breed,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dog.ownerName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (contractAlert != DogContractAlert.none) ...[
                      const SizedBox(height: 6),
                      _ContractChip(alert: contractAlert),
                    ],
                    if (resolvedTags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: resolvedTags
                            .map((tag) => DogTagChip(tag: tag, small: true))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractChip extends StatelessWidget {
  final DogContractAlert alert;

  const _ContractChip({required this.alert});

  @override
  Widget build(BuildContext context) {
    final missing = alert == DogContractAlert.missing;
    final color =
        missing ? AppColors.contractAlert : AppColors.contractExpiring;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        missing ? AppStrings.missingContract : AppStrings.contractExpiringSoon,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DogAvatar extends StatelessWidget {
  final Dog dog;

  const _DogAvatar({required this.dog});

  @override
  Widget build(BuildContext context) {
    if (dog.photoUrl != null && dog.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(dog.photoUrl!),
      );
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        dog.name.isNotEmpty ? dog.name[0] : '?',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
