import 'dart:ui';

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
    required this.onHide,
    super.key,
  });

  final DateTime date;
  final SunDay day;
  final SunPosition sun;
  final double latitude;
  final double longitude;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sunriseColor = isDark
        ? const Color(0xFFFFC94D)
        : const Color(0xFFB27500);
    final sunsetColor = isDark
        ? const Color(0xFFFF86B0)
        : const Color(0xFFC2185B);
    final nightColor = isDark
        ? const Color(0xFF9FA8DA)
        : const Color(0xFF3949AB);
    final sunrise = day.sunrise;
    final sunset = day.sunset;
    final dayLength = day.dayLength;
    final borderRadius = BorderRadius.circular(20);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.72 : 0.8),
              borderRadius: borderRadius,
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formatDate(date),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 24,
                        child: IconButton(
                          tooltip: 'Hide details',
                          onPressed: onHide,
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          color: colors.onSurfaceVariant,
                          icon: const Icon(Icons.expand_more),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  switch (day.kind) {
                    DayKind.midnightSun
                        when sunrise == null && sunset == null =>
                      _EventTile(
                        icon: Icons.wb_sunny,
                        color: sunriseColor,
                        label: 'Midnight sun',
                        value: 'No sunset',
                      ),
                    DayKind.polarNight => _EventTile(
                      icon: Icons.dark_mode,
                      color: nightColor,
                      label: 'Polar night',
                      value: 'No sunrise',
                    ),
                    _ => Row(
                      children: [
                        Expanded(
                          child: _EventTile(
                            icon: Icons.wb_twilight,
                            color: sunriseColor,
                            label: 'Sunrise',
                            value: sunrise == null
                                ? 'None'
                                : formatTime(sunrise),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _EventTile(
                            icon: Icons.nights_stay,
                            color: sunsetColor,
                            label: 'Sunset',
                            value: sunset == null ? 'None' : formatTime(sunset),
                          ),
                        ),
                      ],
                    ),
                  },
                  const SizedBox(height: 10),
                  if (dayLength != null)
                    _DetailLine(
                      icon: Icons.hourglass_bottom,
                      text: '${formatDuration(dayLength)} of daylight',
                    ),
                  _DetailLine(
                    icon: Icons.explore,
                    text:
                        'Sun at ${formatDegrees(sun.azimuth)} '
                        '${compassPoint(sun.azimuth)}, '
                        '${formatDegrees(sun.altitude, decimals: 1)} high',
                  ),
                  _DetailLine(
                    icon: Icons.place,
                    text: formatCoordinates(latitude, longitude),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small button that brings back a hidden [SunInfoCard].
class ShowInfoButton extends StatelessWidget {
  const ShowInfoButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: colors.surface.withValues(alpha: isDark ? 0.72 : 0.8),
          shape: CircleBorder(
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: IconButton(
            tooltip: 'Show details',
            onPressed: onPressed,
            color: colors.primary,
            icon: const Icon(Icons.info_outline),
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
