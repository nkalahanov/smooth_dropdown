import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/rendering/render_smooth_text.dart';
import 'package:smooth_dropdown/src/rendering/smooth_indicators.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';
import 'package:smooth_dropdown/src/theme/smooth_theme.dart';
import 'package:smooth_dropdown/src/widgets/smooth_shell.dart';

const TextStyle _fallbackTitleStyle = TextStyle(
  color: Color(0xF2FFFFFF),
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

const TextStyle _fallbackSubtitleStyle = TextStyle(
  color: Color(0x99FFFFFF),
  fontSize: 13,
  height: 1.3,
);

/// A card that shows any content with a smooth open and close move.
///
/// Tap the header to open or close it. The header always shows. The [child]
/// shows when the tile is open. The [child] can be any widget.
///
/// Give a [title], a [leading] widget, or your own [headerBuilder]. For a
/// simple title and text, use `SmoothExpansionTile.text`.
///
/// The tile grows and shrinks in place. It pushes the widgets below it. Put it
/// in a scroll view when the content can be tall.
class SmoothExpansionTile extends StatelessWidget {
  /// Makes a tile with a header and any [child] content.
  const SmoothExpansionTile({
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.headerBuilder,
    this.style,
    this.controller,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.entrance,
    this.phaseSeed,
    this.menuMaxHeight,
    super.key,
  }) : assert(
         headerBuilder == null ||
             (title == null &&
                 subtitle == null &&
                 leading == null &&
                 trailing == null),
         'Use headerBuilder on its own, or use title, leading, and trailing.',
       ),
       assert(
         title != null || leading != null || headerBuilder != null,
         'Give a title, a leading widget, or a headerBuilder.',
       ),
       assert(
         controller == null || !initiallyExpanded,
         'Do not set both a controller and initiallyExpanded.',
       );

  /// Makes a tile with a title and a block of text that rises as it opens.
  ///
  /// This is a short way to make the common help-card or FAQ tile.
  factory SmoothExpansionTile.text({
    required String title,
    required String text,
    Key? key,
    IconData? icon,
    SmoothStyle? style,
    SmoothExpansionController? controller,
    bool initiallyExpanded = false,
    ValueChanged<bool>? onExpansionChanged,
    Animation<double>? entrance,
    Object? phaseSeed,
  }) {
    return SmoothExpansionTile(
      key: key,
      title: Text(title),
      leading: icon == null ? null : Icon(icon),
      style: (style ?? const SmoothStyle()).copyWith(revealContent: false),
      controller: controller,
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      entrance: entrance,
      phaseSeed: phaseSeed,
      child: SmoothRevealText(text),
    );
  }

  /// The content shown when the tile is open. It can be any widget.
  final Widget child;

  /// The main label in the header. It can be any widget.
  final Widget? title;

  /// A small label under the title, or null for none.
  final Widget? subtitle;

  /// A widget at the start of the header, such as an icon.
  final Widget? leading;

  /// Builds the trailing mark, or null to use the default arrow.
  final SmoothIndicatorBuilder? trailing;

  /// Builds the whole header. Use it for full control. When set, do not set
  /// [title], [subtitle], [leading], or [trailing].
  final SmoothHeaderBuilder? headerBuilder;

  /// The look of this tile, laid over the theme and the default.
  final SmoothStyle? style;

  /// An outside controller to open and close the tile from your code.
  final SmoothExpansionController? controller;

  /// Whether the tile starts open. Only used when there is no [controller].
  final bool initiallyExpanded;

  /// Called with the new open state each time the tile opens or closes.
  final ValueChanged<bool>? onExpansionChanged;

  /// An entrance value that fades and slides the whole tile in, or null.
  final Animation<double>? entrance;

  /// A seed that shifts the wave so stacked tiles do not ripple as one.
  final Object? phaseSeed;

  /// The biggest height for the open content, or null for no cap.
  ///
  /// Content taller than this is clipped. To scroll instead, pass a scrolling
  /// widget (like a `ListView`) as the [child].
  final double? menuMaxHeight;

  @override
  Widget build(BuildContext context) {
    final resolved = SmoothTheme.resolve(context, style);
    final builder =
        headerBuilder ??
        (ctx, expand, control) => _SmoothTileHeader(
          resolved: resolved,
          expand: expand,
          controller: control,
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
        );
    return SmoothShell(
      headerBuilder: builder,
      style: style,
      controller: controller,
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      entrance: entrance,
      phaseSeed: phaseSeed,
      menuMaxHeight: menuMaxHeight,
      child: child,
    );
  }
}

class _SmoothTileHeader extends StatelessWidget {
  const _SmoothTileHeader({
    required this.resolved,
    required this.expand,
    required this.controller,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final SmoothResolvedStyle resolved;
  final Animation<double> expand;
  final SmoothExpansionController controller;
  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final SmoothIndicatorBuilder? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = resolved.palette;
    final indicator =
        trailing?.call(context, expand) ??
        SmoothDefaultIndicator(
          expand: expand,
          color: palette.accent,
          curve: resolved.motion.chevronCurve,
        );

    var lead = leading;
    if (lead != null) {
      lead = IconTheme.merge(
        data: IconThemeData(color: palette.accentBright, size: 18),
        child: lead,
      );
      if (resolved.leadingGlow) {
        lead = CustomPaint(
          painter: SmoothIconGlowPainter(expand: expand, color: palette.accent),
          child: Padding(padding: resolved.iconTilePadding, child: lead),
        );
      }
    }

    final titleStyle = _fallbackTitleStyle.merge(resolved.titleTextStyle);
    final titleText = DefaultTextStyle.merge(
      style: titleStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      child: title ?? const SizedBox.shrink(),
    );
    final titleBlock = subtitle == null
        ? titleText
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleText,
              const SizedBox(height: 2),
              DefaultTextStyle.merge(
                style: _fallbackSubtitleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                child: subtitle!,
              ),
            ],
          );

    final row = Row(
      children: <Widget>[
        if (lead != null) ...<Widget>[lead, const SizedBox(width: 12)],
        Expanded(child: titleBlock),
        const SizedBox(width: 8),
        indicator,
      ],
    );

    final tappable = GestureDetector(
      onTap: controller.toggle,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: Padding(padding: resolved.headerPadding, child: row),
    );

    // The Semantics "expanded" state must follow the open state for screen
    // readers. This is a discrete state change, not motion, so a small rebuild
    // of the Semantics node is right here. The child is built once and reused,
    // so the header content and its painters never rebuild. MergeSemantics
    // folds the title label into this button node, and the gesture above is
    // excluded so the node is not split by a second tap action.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => MergeSemantics(
        child: Semantics(
          button: true,
          expanded: controller.isExpanded,
          onTap: controller.toggle,
          child: child,
        ),
      ),
      child: tappable,
    );
  }
}
