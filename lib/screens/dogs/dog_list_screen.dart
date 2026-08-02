import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/dog_provider.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/dogs/dog_card.dart';
import 'dog_form_screen.dart';

class DogListScreen extends StatelessWidget {
  const DogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dogCount = context.watch<DogProvider>().dogs.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.dogs} ($dogCount)'),
      ),
      body: Column(
        children: [
          _SearchBar(),
          _TagFilters(),
          Expanded(child: _DogList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DogFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<DogProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: AppStrings.searchDogs,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              provider.setSearchQuery('');
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        onChanged: provider.setSearchQuery,
      ),
    );
  }
}

class _TagFilters extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activeFilters = context.watch<DogProvider>().activeTagFilters;
    final dogProvider = context.read<DogProvider>();
    final allTags = context.watch<TagProvider>().tags;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: allTags.map((tag) {
          final isActive = activeFilters.contains(tag.id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(tag.label),
              selected: isActive,
              onSelected: (_) => dogProvider.toggleTagFilter(tag.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DogList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dogs = context.watch<DogProvider>().filteredDogs;

    if (dogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(AppStrings.noDogs,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 4),
            Text(AppStrings.noDogsSubtitle,
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: dogs.length,
      itemBuilder: (_, i) => DogCard(dog: dogs[i]),
    );
  }
}
