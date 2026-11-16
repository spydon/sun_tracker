/// Converts between instants and a continuous count of local wall clock
/// minutes since 1 January 1970, so that every calendar day is exactly 1440
/// minutes long regardless of daylight saving time.
class LocalMinutes {
  const LocalMinutes._();

  static const perDay = 1440.0;

  static int dayIndexOf(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static double of(DateTime time) =>
      dayIndexOf(time) * perDay +
      time.hour * 60 +
      time.minute +
      time.second / 60 +
      time.millisecond / 60000;

  static DateTime dateOfDay(int dayIndex) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      dayIndex * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(utc.year, utc.month, utc.day);
  }

  static int dayIndex(double minutes) => (minutes / perDay).floor();

  static DateTime toDateTime(double minutes) {
    final day = dayIndex(minutes);
    final date = dateOfDay(day);
    final secondsOfDay = ((minutes - day * perDay) * 60).round();
    return DateTime(
      date.year,
      date.month,
      date.day,
      secondsOfDay ~/ 3600,
      (secondsOfDay ~/ 60) % 60,
      secondsOfDay % 60,
    );
  }
}
