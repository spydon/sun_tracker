import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/ar/sky_projection.dart';
import 'package:sun_tracker/src/sensors/device_orientation_source.dart';
import 'package:sun_tracker/src/ui/app_logo.dart';
import 'package:sun_tracker/src/ui/formatting.dart';

/// Fills the available space with the camera preview, cropping as needed.
class CameraBackground extends StatelessWidget {
  const CameraBackground({
    required this.controller,
    required this.previewSize,
    super.key,
  });

  final CameraController? controller;

  /// The preview size in portrait orientation.
  final Size previewSize;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1F3A), Color(0xFF2B4C7E), Color(0xFF1B1B1B)],
          ),
        ),
      );
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox.fromSize(
          size: previewSize,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.child,
    this.color = const Color(0xB31C1B22),
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shows the true heading the camera is pointing towards.
class HeadingIndicator extends StatelessWidget {
  const HeadingIndicator({
    required this.orientation,
    required this.northOffset,
    super.key,
  });

  final DeviceOrientationSource orientation;
  final double northOffset;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: orientation,
      builder: (context, _) {
        if (!orientation.hasData) {
          return const SizedBox.shrink();
        }
        final projection = SkyProjection(
          deviceToWorld: orientation.deviceToWorld,
          northOffset: northOffset,
          focalLength: 1,
          center: Offset.zero,
        );
        final heading = projection.heading;
        final pitch = projection.pitch * 180 / math.pi;
        return _OverlayPill(
          child: Text(
            '${compassPoint(heading)} ${formatDegrees(heading)}'
            '   ${pitch >= 0 ? '↑' : '↓'} ${pitch.abs().toStringAsFixed(0)}°',
          ),
        );
      },
    );
  }
}

/// Heading errors above this many radians trigger a calibration hint.
const double _inaccurateHeading = 30 * math.pi / 180;

/// Asks the user to calibrate the compass when the magnetometer is unreliable.
class CompassAccuracyWarning extends StatelessWidget {
  const CompassAccuracyWarning({required this.orientation, super.key});

  final DeviceOrientationSource orientation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: orientation,
      builder: (context, _) {
        final accuracy = orientation.headingAccuracy;
        final error = orientation.error;
        if (error != null) {
          return _OverlayPill(
            color: const Color(0xE6B3261E),
            child: Text(error),
          );
        }
        if (accuracy == null || accuracy < _inaccurateHeading) {
          return const SizedBox.shrink();
        }
        return _OverlayPill(
          color: Color(0xE6B3261E),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Compass inaccurate, move the phone in a figure eight',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Shown above the message, the app logo is shown when this is null.
  final IconData? icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final icon = this.icon;
    return Card(
      color: const Color(0xF21C1B22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const AppLogo(size: 64)
            else
              Icon(icon, color: const Color(0xFFF5C542), size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
