class FirestorePaths {
  FirestorePaths._();

  static const dogs = 'dogs';
  static const bookings = 'bookings';
  static const tags = 'tags';
  static const vacations = 'vacations';
  static const pensionProducts = 'pension_products';
  static const pensionOrders = 'pension_orders';

  static String dogDocument(String dogId) => 'dogs/$dogId';
  static String bookingDocument(String bookingId) => 'bookings/$bookingId';
}
