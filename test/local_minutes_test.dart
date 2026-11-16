import 'package:flutter_test/flutter_test.dart';
import 'package:sun_tracker/src/ui/local_minutes.dart';

void main() {
  test('round trips local wall clock time', () {
    final time = DateTime(2026, 7, 26, 15, 2);
    final minutes = LocalMinutes.of(time);
    expect(LocalMinutes.toDateTime(minutes), time);
  });

  test('rolls over to the next day after midnight', () {
    final minutes = LocalMinutes.of(DateTime(2026, 12, 31, 23, 50)) + 20;
    expect(LocalMinutes.toDateTime(minutes), DateTime(2027, 1, 1, 0, 10));
  });

  test('keeps every day the same length across daylight saving time', () {
    final before = LocalMinutes.of(DateTime(2026, 3, 28, 12));
    final after = LocalMinutes.of(DateTime(2026, 3, 30, 12));
    expect(after - before, 2 * LocalMinutes.perDay);
  });
}
