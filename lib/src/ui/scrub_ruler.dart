import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/ui/formatting.dart';
import 'package:sun_tracker/src/ui/local_minutes.dart';

class RulerTick {
  const RulerTick({required this.value, required this.length, this.label});

  final double value;

  /// Relative tick length between 0 and 1.
  final double length;

  final String? label;
}

abstract class RulerScale {
  const RulerScale();

  double get pixelsPerUnit;

  Iterable<RulerTick> ticksBetween(double from, double to);
}

/// A scale over local minutes that shows every ten minutes of a day.
class TimeOfDayScale extends RulerScale {
  const TimeOfDayScale();

  @override
  double get pixelsPerUnit => 2;

  @override
  Iterable<RulerTick> ticksBetween(double from, double to) sync* {
    final first = (from / 10).floor() * 10;
    for (var minutes = first; minutes <= to; minutes += 10) {
      final minuteOfDay = minutes % 1440;
      if (minuteOfDay % 60 == 0) {
        final hour = minuteOfDay ~/ 60;
        yield RulerTick(
          value: minutes.toDouble(),
          length: 1,
          label: '${hour.toString().padLeft(2, '0')}:00',
        );
      } else {
        yield RulerTick(
          value: minutes.toDouble(),
          length: minuteOfDay % 30 == 0 ? 0.6 : 0.35,
        );
      }
    }
  }
}

/// A scale over local minutes that shows the days and months of a year.
class DayOfYearScale extends RulerScale {
  const DayOfYearScale();

  @override
  double get pixelsPerUnit => 5 / LocalMinutes.perDay;

  @override
  Iterable<RulerTick> ticksBetween(double from, double to) sync* {
    final firstDay = LocalMinutes.dayIndex(from) - 1;
    final lastDay = LocalMinutes.dayIndex(to) + 1;
    for (var day = firstDay; day <= lastDay; day++) {
      final date = LocalMinutes.dateOfDay(day);
      final value = day * LocalMinutes.perDay + LocalMinutes.perDay / 2;
      if (date.day == 1) {
        final month = monthNames[date.month - 1];
        yield RulerTick(
          value: value,
          length: 1,
          label: date.month == 1 ? '$month ${date.year}' : month,
        );
      } else if (date.day == 15) {
        yield RulerTick(value: value, length: 0.6);
      } else if (date.day == 8 || date.day == 22) {
        yield RulerTick(value: value, length: 0.35);
      }
    }
  }
}

/// A horizontally scrollable ruler with a fixed marker in the middle.
class ScrubRuler extends StatefulWidget {
  const ScrubRuler({
    required this.value,
    required this.scale,
    required this.onChanged,
    this.height = 46,
    super.key,
  });

  final double value;
  final RulerScale scale;
  final ValueChanged<double> onChanged;
  final double height;

  @override
  State<ScrubRuler> createState() => _ScrubRulerState();
}

class _ScrubRulerState extends State<ScrubRuler>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fling = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onFling);

  double _startValue = 0;
  double _dragOffset = 0;

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _fling.stop();
    _startValue = widget.value;
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.delta.dx;
    _emit(_dragOffset);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() < 80) {
      return;
    }
    _fling.value = _dragOffset;
    _fling.animateWith(FrictionSimulation(0.08, _dragOffset, velocity));
  }

  void _onFling() => _emit(_fling.value);

  void _emit(double offset) {
    widget.onChanged(_startValue - offset / widget.scale.pixelsPerUnit);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RulerPainter(value: widget.value, scale: widget.scale),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.value, required this.scale});

  final double value;
  final RulerScale scale;

  static const _labelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final halfRange = centerX / scale.pixelsPerUnit;
    const top = 10.0;
    const maxTickLength = 14.0;
    final tickPaint = Paint()
      ..color = Colors.white60
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (final tick in scale.ticksBetween(
      value - halfRange,
      value + halfRange,
    )) {
      final x = centerX + (tick.value - value) * scale.pixelsPerUnit;
      final length = maxTickLength * tick.length;
      final tickTop = top + (maxTickLength - length) / 2;
      canvas.drawLine(
        Offset(x, tickTop),
        Offset(x, tickTop + length),
        tickPaint..color = tick.label == null ? Colors.white54 : Colors.white,
      );
      final label = tick.label;
      if (label != null) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: _labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(x - painter.width / 2, top + maxTickLength + 4),
        );
      }
    }

    canvas.drawPath(
      Path()
        ..moveTo(centerX - 6, 0)
        ..lineTo(centerX + 6, 0)
        ..lineTo(centerX, 9)
        ..close(),
      Paint()..color = const Color(0xFFFF4D4D),
    );
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.scale != scale;
}
