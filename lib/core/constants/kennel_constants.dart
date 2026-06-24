class KennelInfo {
  final String id;
  final String hebrewName;
  final int maxDogs;
  final bool sameOwnerRequired;

  const KennelInfo({
    required this.id,
    required this.hebrewName,
    required this.maxDogs,
    required this.sameOwnerRequired,
  });
}

class KennelConstants {
  KennelConstants._();

  static const largeCabin = KennelInfo(
    id: 'large_cabin',
    hebrewName: 'ביתן גדול',
    maxDogs: 5,
    sameOwnerRequired: false,
  );

  static const doubleKennel = KennelInfo(
    id: 'double',
    hebrewName: 'תא זוגי',
    maxDogs: 2,
    sameOwnerRequired: true,
  );

  static const single1 = KennelInfo(
    id: 'single_1',
    hebrewName: 'תא יחיד 1',
    maxDogs: 1,
    sameOwnerRequired: false,
  );

  static const single2 = KennelInfo(
    id: 'single_2',
    hebrewName: 'תא יחיד 2',
    maxDogs: 1,
    sameOwnerRequired: false,
  );

  static const single3 = KennelInfo(
    id: 'single_3',
    hebrewName: 'תא יחיד 3',
    maxDogs: 1,
    sameOwnerRequired: false,
  );

  static const all = [largeCabin, doubleKennel, single1, single2, single3];

  static KennelInfo? findById(String id) {
    for (final k in all) {
      if (k.id == id) return k;
    }
    return null;
  }
}
