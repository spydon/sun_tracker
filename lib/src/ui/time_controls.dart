import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/ui/formatting.dart';
import 'package:sun_tracker/src/ui/local_minutes.dart';
import 'package:sun_tracker/src/ui/scrub_ruler.dart';

class TimeControls extends StatelessWidget {
  const TimeControls({
    required this.minutes,
    required this.isLive,
    required this.onMinutesChanged,
    required this.onDayChanged,
    required this.onResetToNow,
    required this.onPickDate,
    super.key,
  });

  /// The selected local time, see [LocalMinutes].
  final double minutes;
  final bool isLive;
  final ValueChanged<double> onMinutesChanged;
  final ValueChanged<double> onDayChanged;
  final VoidCallback onResetToNow;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final time = LocalMinutes.toDateTime(minutes);
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: const Color(0xF2111114),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        formatTime(time),
                        maxLines: 1,
                        softWrap: false,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatDate(time),
                        textAlign: TextAlign.center,
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Back to now',
                      onPressed: isLive ? null : onResetToNow,
                      color: const Color(0xFFF5C542),
                      disabledColor: Colors.white24,
                      icon: const Icon(Icons.restore),
                    ),
                    IconButton(
                      tooltip: 'Pick a date',
                      onPressed: onPickDate,
                      color: Colors.white,
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ],
                ),
              ),
              ScrubRuler(
                value: minutes,
                scale: const DayOfYearScale(),
                onChanged: onDayChanged,
              ),
              const SizedBox(height: 4),
              ScrubRuler(
                value: minutes,
                scale: const TimeOfDayScale(),
                onChanged: onMinutesChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
