import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/settings/calibration.dart';
import 'package:sun_tracker/src/ui/app_logo.dart';

class CalibrationSheet extends StatelessWidget {
  const CalibrationSheet({
    required this.calibration,
    required this.detectedFieldOfView,
    required this.declination,
    super.key,
  });

  final Calibration calibration;
  final double detectedFieldOfView;
  final double? declination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final declination = this.declination;
    return ListenableBuilder(
      listenable: calibration,
      builder: (context, _) {
        final offset = calibration.headingOffset;
        final scale = calibration.fieldOfViewScale;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 40),
                    const SizedBox(width: 12),
                    Text('Calibration', style: textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If the overlay does not line up with the real sun, move the '
                  'phone in a figure eight to calibrate the compass, then '
                  'fine tune with the sliders below.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Compass correction: ${offset.toStringAsFixed(1)}°',
                  style: textTheme.labelLarge,
                ),
                Slider(
                  value: offset,
                  min: -Calibration.maxHeadingOffset,
                  max: Calibration.maxHeadingOffset,
                  divisions: 240,
                  onChanged: (value) => calibration.headingOffset = value,
                ),
                Text(
                  'Field of view: '
                  '${(detectedFieldOfView * scale).toStringAsFixed(1)}° '
                  '(${(scale * 100).round()} percent of detected)',
                  style: textTheme.labelLarge,
                ),
                Slider(
                  value: scale,
                  min: Calibration.minFieldOfViewScale,
                  max: Calibration.maxFieldOfViewScale,
                  divisions: 80,
                  onChanged: (value) => calibration.fieldOfViewScale = value,
                ),
                if (declination != null)
                  Text(
                    'Magnetic declination here: '
                    '${declination.abs().toStringAsFixed(1)}° '
                    '${declination >= 0 ? 'east' : 'west'} (applied automatically)',
                    style: textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: calibration.reset,
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
