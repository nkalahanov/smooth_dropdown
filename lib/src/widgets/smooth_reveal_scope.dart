import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';

/// Shares the tile's live animations with the content inside it.
///
/// The tile puts this above its open content. A child can read the animations
/// and add its own effect that follows the tile. `SmoothRevealText` uses it.
///
/// It shares the [Animation] objects, not a single frame value. So a child
/// that reads it never gets an old value.
class SmoothRevealScope extends InheritedWidget {
  /// Makes a reveal scope.
  const SmoothRevealScope({
    required this.expand,
    required this.contentReveal,
    required this.style,
    required super.child,
    super.key,
  });

  /// The open value of the tile, from 0 (closed) to 1 (open).
  final Animation<double> expand;

  /// The staggered value for the content, from 0 to 1.
  final Animation<double> contentReveal;

  /// The resolved look of the tile.
  final SmoothResolvedStyle style;

  /// Finds the nearest reveal scope above [context], or null if there is none.
  static SmoothRevealScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SmoothRevealScope>();
  }

  @override
  bool updateShouldNotify(SmoothRevealScope old) =>
      !identical(old.expand, expand) ||
      !identical(old.contentReveal, contentReveal) ||
      !identical(old.style, style);
}
