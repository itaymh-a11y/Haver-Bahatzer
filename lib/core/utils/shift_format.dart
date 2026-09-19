String formatDurationMinutes(int minutes) {
  if (minutes < 0) minutes = 0;
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) {
    if (remainder == 0) return '0 דקות';
    return '$remainder דקות';
  }
  if (remainder == 0) {
    if (hours == 1) return 'שעה אחת';
    return '$hours שעות';
  }
  if (hours == 1) return 'שעה ו-$remainder דקות';
  return '$hours שעות ו-$remainder דקות';
}

String formatElapsedClock(Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = total.inHours.toString().padLeft(2, '0');
  final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
