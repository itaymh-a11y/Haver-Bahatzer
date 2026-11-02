import 'package:flutter_test/flutter_test.dart';
import 'package:haver_bahatzer/models/dog_contract.dart';

void main() {
  DogContract contractOn(int year, int month, int day) {
    return DogContract(
      photoUrls: const ['https://example.com/contract.jpg'],
      uploadedAt: DateTime(year, month, day, 15, 30),
    );
  }

  test('stays valid from the upload day through the same day next year', () {
    final contract = contractOn(2026, 11, 2);

    expect(contract.expiresAt, DateTime(2027, 11, 2));
    expect(contract.isValidOn(DateTime(2026, 11, 2, 8)), isTrue);
    expect(contract.isValidOn(DateTime(2027, 11, 2, 23)), isTrue);
    expect(contract.isValidOn(DateTime(2027, 11, 3)), isFalse);
    expect(contract.daysRemainingOn(DateTime(2027, 11, 2)), 0);
    expect(contract.daysRemainingOn(DateTime(2027, 11, 3)), -1);
  });

  test('turns orange only when less than a calendar month remains', () {
    final contract = contractOn(2026, 11, 2);

    expect(contract.expiresInLessThanMonth(DateTime(2027, 10, 2)), isFalse);
    expect(contract.expiresInLessThanMonth(DateTime(2027, 10, 3)), isTrue);
    expect(contract.expiresInLessThanMonth(DateTime(2027, 11, 2)), isTrue);
    expect(contract.expiresInLessThanMonth(DateTime(2027, 11, 3)), isFalse);
  });

  test('a contract without photos is not valid', () {
    final contract = DogContract(
      photoUrls: const [],
      uploadedAt: DateTime(2026, 11, 2),
    );

    expect(contract.isValidOn(DateTime(2026, 11, 2)), isFalse);
  });
}
