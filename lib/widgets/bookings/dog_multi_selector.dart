import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/dog_provider.dart';

class DogMultiSelector extends StatefulWidget {
  final List<String> selectedDogIds;
  final ValueChanged<List<String>> onChanged;

  const DogMultiSelector({
    super.key,
    required this.selectedDogIds,
    required this.onChanged,
  });

  @override
  State<DogMultiSelector> createState() => _DogMultiSelectorState();
}

class _DogMultiSelectorState extends State<DogMultiSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dogs = context.watch<DogProvider>().dogs;
    final selectedDogIds = widget.selectedDogIds;

    // Determine locked owner: once any dog is selected, only dogs from
    // the same owner are selectable.
    String? lockedOwnerPhone;
    for (final dog in dogs) {
      if (selectedDogIds.contains(dog.id)) {
        lockedOwnerPhone = dog.ownerPhone;
        break;
      }
    }

    final selectedDogs = dogs.where((d) => selectedDogIds.contains(d.id)).toList();
    final query = _query.trim().toLowerCase();
    final sortedByNewest = [...dogs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visibleDogs = query.isEmpty
        ? sortedByNewest.take(5).toList()
        : sortedByNewest.where((d) {
            final dogName = d.name.toLowerCase();
            final ownerName = d.ownerName.toLowerCase();
            return dogName.contains(query) || ownerName.contains(query);
          }).toList();

    return FormField<List<String>>(
      initialValue: selectedDogIds,
      validator: (v) =>
          (v == null || v.isEmpty) ? AppStrings.fieldRequired : null,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: AppStrings.selectDogs,
            errorText: state.errorText,
            border: const OutlineInputBorder(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'חיפוש לפי שם כלב / בעלים',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              if (selectedDogs.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: selectedDogs.map((dog) {
                    return FilterChip(
                      label: Text(
                        dog.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: true,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      onSelected: (_) {
                        final updated = List<String>.from(selectedDogIds)
                          ..remove(dog.id);
                        widget.onChanged(updated);
                        state.didChange(updated);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...visibleDogs.map((dog) {
                    final isSelected = selectedDogIds.contains(dog.id);
                    final isDisabled = !isSelected &&
                        lockedOwnerPhone != null &&
                        dog.ownerPhone != lockedOwnerPhone;
                    return FilterChip(
                      label: Text(
                        '${dog.name} • ${dog.ownerName}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      onSelected: isDisabled
                          ? null
                          : (selected) {
                              final updated = List<String>.from(selectedDogIds);
                              if (selected) {
                                updated.add(dog.id);
                              } else {
                                updated.remove(dog.id);
                              }
                              widget.onChanged(updated);
                              state.didChange(updated);
                            },
                    );
                  }),
                  if (visibleDogs.isEmpty)
                    Text(
                      query.isEmpty ? AppStrings.noDogs : 'לא נמצאו תוצאות לחיפוש',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
