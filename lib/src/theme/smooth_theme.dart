import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';

/// Shares one [SmoothStyle] with all smooth widgets below it in the tree.
///
/// Put a `SmoothTheme` near the top of your app. Then every
/// `SmoothExpansionTile` and `SmoothSelect` below it uses that style. A widget
/// can still set its own [SmoothStyle] to change some of the values.
class SmoothTheme extends InheritedTheme {
  /// Makes a theme that gives [data] to the widgets in [child].
  const SmoothTheme({required this.data, required super.child, super.key});

  /// The shared style.
  final SmoothStyle data;

  /// Finds the shared style above [context], or null if there is none.
  static SmoothStyle? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SmoothTheme>()?.data;
  }

  /// Finds the shared style above [context]. Returns an empty style when there
  /// is none.
  static SmoothStyle of(BuildContext context) {
    return maybeOf(context) ?? const SmoothStyle();
  }

  /// Builds the final style for [context].
  ///
  /// It lays [style] over the shared theme, and both over the default. The
  /// widgets call this for you.
  static SmoothResolvedStyle resolve(BuildContext context, SmoothStyle? style) {
    return (style ?? const SmoothStyle()).resolveFrom(maybeOf(context));
  }

  @override
  bool updateShouldNotify(SmoothTheme oldWidget) => data != oldWidget.data;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return SmoothTheme(data: data, child: child);
  }
}
