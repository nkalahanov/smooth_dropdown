/// Smooth dropdown widgets for Flutter.
///
/// This package has two main widgets. `SmoothExpansionTile` shows any content
/// with a smooth open and close move. `SmoothSelect` lets a user open a list
/// and tap one option to pick it.
///
/// Both widgets move fully on the render layer. There is no `setState` and no
/// `AnimatedBuilder` for the motion.
///
/// Change the look with `SmoothStyle`, `SmoothPalette`, and `SmoothMotionSpec`.
/// Share one look with `SmoothTheme`. Open and close from your own code with
/// `SmoothExpansionController`.
library;

export 'src/foundation/smooth_motion_state.dart';
export 'src/foundation/smooth_trace.dart';
export 'src/rendering/render_smooth_text.dart' show SmoothRevealText;
export 'src/rendering/smooth_indicators.dart' show SmoothDefaultIndicator;
export 'src/theme/smooth_highlight.dart';
export 'src/theme/smooth_motion_spec.dart';
export 'src/theme/smooth_palette.dart';
export 'src/theme/smooth_style.dart';
export 'src/theme/smooth_theme.dart';
export 'src/widgets/smooth_expansion_tile.dart';
export 'src/widgets/smooth_picker.dart';
export 'src/widgets/smooth_reveal_scope.dart';
export 'src/widgets/smooth_select.dart';
export 'src/widgets/smooth_shell.dart'
    show SmoothExpansionController, SmoothHeaderBuilder, SmoothIndicatorBuilder;
