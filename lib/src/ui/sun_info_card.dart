import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/astronomy/sun_calculator.dart';
import 'package:sun_tracker/src/ui/formatting.dart';

class SunInfoCard extends StatelessWidget {
  const SunInfoCard({
    required this.date,
    required this.day,
    required this.sun,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final DateTime date;
  final SunDay day;
  final SunPosition sun;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sunrise = day.sunrise;
    final sunset = day.sunset;
    final dayLength = day.dayLength;
    final small = textTheme.bodySmall?.copyWith(color: Colors.black87);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(date),
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              switch (day.kind) {
                DayKind.midnightSun when sunrise == null && sunset == null =>
                  const _SunEventRow(
                    icon: Icons.wb_sunny,
                    color: Color(0xFFE5A100),
                    text: 'Midnight sun, no sunset',
                  ),
                DayKind.polarNight => const _SunEventRow(
                  icon: Icons.dark_mode,
                  color: Color(0xFF5C6BC0),
                  text: 'Polar night, no sunrise',
                ),
                _ => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SunEventRow(
                      icon: Icons.wb_twilight,
                      color: const Color(0xFFE5A100),
                      text: sunrise == null ? 'None' : formatTime(sunrise),
                    ),
                    const SizedBox(width: 14),
                    _SunEventRow(
                      icon: Icons.nights_stay,
                      color: const Color(0xFFE0457B),
                      text: sunset == null ? 'None' : formatTime(sunset),
                    ),
                  ],
                ),
              },
              if (dayLength != null) ...[
                const SizedBox(height: 4),
                Text('Daylight ${formatDuration(dayLength)}', style: small),
              ],
              const SizedBox(height: 4),
              Text(
                'Sun at ${formatDegrees(sun.azimuth)} ${compassPoint(sun.azimuth)}, '
                '${formatDegrees(sun.altitude, decimals: 1)} high',
                style: small,
              ),
              const SizedBox(height: 2),
              Text(
                formatCoordinates(latitude, longitude),
                style: small?.copyWith(color: const Color(0xFFE0457B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SunEventRow extends StatelessWidget {
  const _SunEventRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
