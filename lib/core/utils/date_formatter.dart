import 'package:intl/intl.dart';

class DateFormatter {
  /// Standard full date and time format: dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(date);
  }

  /// Standard date only format: dd/MM/yyyy
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  /// Standard time only format: HH:mm
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'fr_FR').format(date);
  }

  /// Time with seconds: HH:mm:ss
  static String formatTimeSeconds(DateTime date) {
    return DateFormat('HH:mm:ss', 'fr_FR').format(date);
  }

  /// Premium display format: dd MMMM yyyy • HH:mm
  static String formatPremium(DateTime date) {
    return DateFormat('dd MMMM yyyy • HH:mm', 'fr_FR').format(date);
  }

  /// File name safe format: yyyyMMdd_HHmm
  static String formatFileName(DateTime date) {
    return DateFormat('yyyyMMdd_HHmm').format(date);
  }

  /// Short date format: dd/MM
  static String formatShortDate(DateTime date) {
    return DateFormat('dd/MM', 'fr_FR').format(date);
  }

  /// Full date format: EEEE d MMMM yyyy
  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  }

  /// Long date format: dd MMMM yyyy
  static String formatLongDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
  }

  /// Month name only: MMMM
  static String formatMonth(DateTime date) {
    return DateFormat('MMMM', 'fr_FR').format(date);
  }

  /// Compact date and time: dd/MM/yy HH:mm
  static String formatCompact(DateTime date) {
    return DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(date);
  }

  /// ISO date for internal/comparison use: yyyy-MM-dd
  static String formatISODate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Short year format: dd/MM/yy
  static String formatShortYear(DateTime date) {
    return DateFormat('dd/MM/yy', 'fr_FR').format(date);
  }

  /// Day and Month only: dd/MM
  static String formatDayMonth(DateTime date) {
    return DateFormat('dd/MM', 'fr_FR').format(date);
  }

  /// Compact date for file names: yyyyMMdd
  static String formatDateCompact(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  /// Database/ISO date format: yyyy-MM-dd
  static String formatDateDb(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Day, Month (short) and Time: dd MMM HH:mm
  static String formatDayMonthTime(DateTime date) {
    return DateFormat('dd MMM HH:mm', 'fr_FR').format(date);
  }

  /// Compact date: dd/MM
  static String formatCompactDate(DateTime date) {
    return DateFormat('dd/MM', 'fr_FR').format(date);
  }

  /// Month and Year: MMM yy
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yy', 'fr_FR').format(date);
  }

  /// Number formatting: 1 000 000
  static String formatNumber(num value, {int decimalDigits = 0}) {
    return NumberFormat.decimalPattern('fr_FR').format(value).replaceAll('\u00A0', ' ').trim();
  }

  /// Currency formatting: 1 000 000 F
  /// "Smart" formatting: eliminates .0 but preserves non-zero decimals.
  static String formatCurrency(num value, String symbol, {bool removeDecimals = true}) {
    if (removeDecimals && value % 1 == 0) {
      final fmt = formatNumberValue(value, decimalDigits: 0);
      return symbol.isEmpty ? fmt : '$fmt $symbol';
    }
    // For fractional values, we keep 2 decimals if not specifically removed, 
    // or use a smart pattern if the user wants "precision preservation".
    final fmt = formatNumberValue(value, decimalDigits: 2);
    return symbol.isEmpty ? fmt : '$fmt $symbol';
  }

  // Internal helper for precise decimal control
  static String formatNumberValue(num value, {int decimalDigits = 0}) {
     return NumberFormat.currency(
      symbol: '',
      decimalDigits: decimalDigits,
      locale: 'fr_FR',
    ).format(value).replaceAll('\u00A0', ' ').trim();
  }

  /// Formatte une quantité : enlève le .0 si c'est un entier, sinon garde les décimales.
  /// Ajoute également les séparateurs de milliers pour la lisibilité (ex: 1 250).
  static String formatQuantity(double value) {
    final formatter = NumberFormat.decimalPattern('fr_FR');
    return formatter.format(value).replaceAll('\u00A0', ' ').trim();
  }
}
