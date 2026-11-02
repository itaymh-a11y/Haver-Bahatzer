import '../../models/booking_model.dart';
import '../../models/dog_contract.dart';
import '../../models/dog_model.dart';

class DogContractRules {
  DogContractRules._();

  static DogContractAlert statusOf(Dog dog, [DateTime? on]) {
    final date = on ?? DateTime.now();
    final contract = dog.contract;
    if (contract == null || !contract.isValidOn(date)) {
      return DogContractAlert.missing;
    }
    if (contract.expiresInLessThanMonth(date)) {
      return DogContractAlert.expiring;
    }
    return DogContractAlert.none;
  }

  static bool hasActiveOrUpcomingStay(String dogId, List<Booking> bookings) {
    return bookings.any(
      (booking) =>
          booking.type == BookingType.boarding &&
          booking.dogIds.contains(dogId) &&
          (booking.status == BookingStatus.upcoming ||
              booking.status == BookingStatus.active),
    );
  }

  /// Shown on the dog. Dogs with no active or upcoming stay stay quiet.
  static DogContractAlert alertForDog(
    Dog dog,
    List<Booking> bookings, [
    DateTime? on,
  ]) {
    if (!hasActiveOrUpcomingStay(dog.id, bookings)) {
      return DogContractAlert.none;
    }
    return statusOf(dog, on);
  }

  /// Worst status among the dogs on an open boarding stay.
  static DogContractAlert alertForBooking(
    Booking booking,
    List<Dog> dogs, [
    DateTime? on,
  ]) {
    if (booking.type != BookingType.boarding) return DogContractAlert.none;
    if (booking.status != BookingStatus.upcoming &&
        booking.status != BookingStatus.active) {
      return DogContractAlert.none;
    }

    final date = on ?? DateTime.now();
    var sawDog = false;
    var expiring = false;
    for (final id in booking.dogIds) {
      final index = dogs.indexWhere((dog) => dog.id == id);
      if (index == -1) continue;
      sawDog = true;
      final status = statusOf(dogs[index], date);
      if (status == DogContractAlert.missing) return DogContractAlert.missing;
      if (status == DogContractAlert.expiring) expiring = true;
    }
    if (!sawDog) return DogContractAlert.none;
    if (expiring) return DogContractAlert.expiring;
    return DogContractAlert.none;
  }
}
