/// Formats amounts in ₪ for display (e.g. 9.9 → "9.90", 10 → "10.00").
String formatMoney(num amount) => amount.toDouble().toStringAsFixed(2);
