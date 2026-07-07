import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// A deep debug trace tool for the smooth widgets.
///
/// It prints the exact numbers behind every frame: layout sizes, paint passes,
/// wave math, the glow and the bottom crest sizes, ticker starts and stops,
/// hit tests, and widget lifecycle. Use it to see the truth of what the motion
/// does, or to tune a channel such as the edge glow.
///
/// It is off by default, so a real app stays silent and fast. While
/// [enabled] is false no trace string is ever built, so the cost is two field
/// reads at each trace point. Turn it on from your app before you run:
///
/// ```dart
/// void main() {
///   SmoothTrace.enabled = true; // master switch on
///   runApp(const MyApp());
/// }
/// ```
///
/// Turn single groups off to cut noise, for example `SmoothTrace.text = false`.
/// Raise [sample] to print one frame in every N on the busiest paint paths.
///
/// Every line starts with a `[smooth:<group>]` tag, so you can filter the
/// console, for example `grep '\[smooth:glow\]'`.
class SmoothTrace {
  SmoothTrace._();

  /// The master switch. While false, nothing prints and no trace string is
  /// built.
  static bool enabled = false;

  /// Traces render box layout: sizes, the height factor, and height caps.
  static bool layout = true;

  /// Traces every paint pass with its repaint counter.
  static bool paint = true;

  /// Traces wave math: amplitude, phase, and surface lift samples.
  static bool geometry = true;

  /// Traces the card glow, the bottom crest, and the icon glow sizes, blur
  /// sigmas, and alphas. This is the group to watch for edge tuning.
  static bool glow = true;

  /// Traces ticker start and stop and the open and close state machine.
  static bool ticker = true;

  /// Traces build, attach, and dispose of the widgets.
  static bool lifecycle = true;

  /// Traces hit testing on the open content.
  static bool hitTest = true;

  /// Traces the rising text render pass.
  static bool text = true;

  /// Traces the squash and the entrance slide transforms.
  static bool transform = true;

  /// Traces the draggable selection highlight: geometry, drag, spring, and the
  /// picker state machine.
  static bool pick = true;

  /// On the busiest paint paths, print one frame in every [sample]. A value
  /// of 1 prints every frame. Counters still step every frame.
  static int sample = 1;

  static final Map<String, int> _counters = <String, int>{};

  /// Turns the master switch on. Every group is on by default.
  static void enableAll() {
    enabled = true;
  }

  /// Turns the master switch off.
  static void disableAll() {
    enabled = false;
  }

  /// Steps the counter named [key] and returns the new value.
  static int bump(String key) {
    final next = (_counters[key] ?? 0) + 1;
    _counters[key] = next;
    return next;
  }

  /// Reads the counter named [key] without changing it.
  static int count(String key) => _counters[key] ?? 0;

  /// Clears every counter back to zero.
  static void resetCounters() => _counters.clear();

  /// True when frame number [n] survives the [sample] rate.
  static bool keep(int n) => sample <= 1 || n % sample == 0;

  /// Formats a double with three places for tidy, aligned output.
  static String f(double value) => value.toStringAsFixed(3);

  /// Formats a double with one place.
  static String f1(double value) => value.toStringAsFixed(1);

  /// Formats a size as `WxH` with one place.
  static String size(Size value) => '${f1(value.width)}x${f1(value.height)}';

  /// Formats a rect as `L,T WxH` with one place.
  static String rect(Rect value) =>
      '${f1(value.left)},${f1(value.top)} '
      '${f1(value.width)}x${f1(value.height)}';

  /// Prints one trace line under [tag].
  static void emit(String tag, String message) =>
      debugPrintSynchronously('[smooth:$tag] $message');
}
