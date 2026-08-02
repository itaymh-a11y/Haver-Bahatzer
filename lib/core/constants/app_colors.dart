import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF2E7D32);       // Forest green
  static const primaryLight = Color(0xFF60AD5E);
  static const primaryDark = Color(0xFF005005);
  static const secondary = Color(0xFFF9A825);     // Warm amber
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFD32F2F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onBackground = Color(0xFF212121);
  static const onSurface = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFBDBDBD);
  static const chipBackground = Color(0xFFE8F5E9);

  // Booking status colors
  static const statusUpcoming = Color(0xFF1565C0);   // blue
  static const statusActive = Color(0xFF2E7D32);     // green
  static const statusCompleted = Color(0xFF757575);  // grey
  static const contractAlert = Color(0xFFD32F2F);    // red
  static const boardingDot = Color(0xFF2E7D32);      // green dot on calendar
  static const introMeetingDot = Color(0xFFF9A825);  // amber dot on calendar
  static const vacationDay = Color(0xFF9E9E9E);     // blocked vacation days

  // Calendar stay-phase colors (dog chips) — distinct from kennel occupancy
  static const stayCheckIn = Color(0xFF1565C0);      // first day — entering
  static const stayMiddle = Color(0xFF2E7D32);       // mid-stay
  static const stayCheckOut = Color(0xFFE65100);     // last day — leaving
  static const stayCheckInAndOut = Color(0xFF6A1B9A); // same-day in+out
  static const softHold = Color(0xFFF9A825); // amber — matches intro meetings

  // Kennel occupancy (monochrome — does not compete with stay-phase colors)
  static const occupancyEmpty = Color(0xFF9E9E9E);
  static const occupancyPartial = Color(0xFF616161);
  static const occupancyFull = Color(0xFF212121);

  // Tag colors
  static const tagAggressive = Color(0xFFFFCDD2);
  static const tagAggressiveText = Color(0xFFC62828);
  static const tagMedication = Color(0xFFE3F2FD);
  static const tagMedicationText = Color(0xFF1565C0);
  static const tagEscapist = Color(0xFFFFF9C4);
  static const tagEscapistText = Color(0xFF7B4500);
}
