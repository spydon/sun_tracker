import 'dart:math' as math;

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _compassPoints = [
  'N',
  'NNE',
  'NE',
  'ENE',
  'E',
  'ESE',
  'SE',
  'SSE',
  'S',
  'SSW',
  'SW',
  'WSW',
  'W',
  'WNW',
  'NW',
  'NNW',
];

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatTime(DateTime time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

String formatDate(DateTime time) =>
    '${time.day} ${monthNames[time.month - 1]} ${time.year}';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final hourText = hours == 1 ? 'hour' : 'hours';
  final minuteText = minutes == 1 ? 'minute' : 'minutes';
  return '$hours $hourText $minutes $minuteText';
}

String formatDegrees(double radians, {int decimals = 0}) =>
    '${(radians * 180 / math.pi).toStringAsFixed(decimals)}°';

String compassPoint(double azimuthRadians) {
  final degrees = azimuthRadians * 180 / math.pi;
  final index = ((degrees / 22.5).round()) % 16;
  return _compassPoints[index];
}

String formatCoordinates(double latitude, double longitude) {
  final latitudeText =
      '${latitude.abs().toStringAsFixed(2)}° ${latitude >= 0 ? 'N' : 'S'}';
  final longitudeText =
      '${longitude.abs().toStringAsFixed(2)}° ${longitude >= 0 ? 'E' : 'W'}';
  return '$latitudeText, $longitudeText';
}
