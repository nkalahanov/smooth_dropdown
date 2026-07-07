import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/rendering/smooth_highlight_list.dart';
import 'package:smooth_dropdown/src/theme/smooth_highlight.dart';

/// One option in a [SmoothPicker].
///
/// It holds a [value] and a [child] to show. Two options should not share the
/// same [value]. Add a [leading] or [trailing] widget for an icon.
@immutable
class SmoothPickerItem<T> {
  /// Makes an option.
  const SmoothPickerItem({
    required this.value,
    required this.child,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The value this option stands for.
  final T value;

  /// The widget shown for this option.
  final Widget child;

  /// A widget at the start of the row, such as an icon.
  final Widget? leading;

  /// A widget at the end of the row.
  final Widget? trailing;

  /// Whether this option can be picked.
  final bool enabled;

  /// A label read out by a screen reader, or null to use the child.
  final String? semanticLabel;
}

/// The state of the highlight, as one explicit value.
///
/// The highlight is always in exactly one of these. There is no scattered set
/// of booleans, so it can never sit in a state no code handles.
enum SmoothPickerPhase {
  /// At rest with no finger down. The highlight sits on the selected option,
  /// drawn by the render's rest fallback.
  idle,

  /// A finger is dragging the highlight.
  dragging,

  /// A spring is carrying the highlight to its target after a release; when it
  /// arrives the box comes to rest on that option.
  settling,
}

/// A list of options with a soft highlight you drag to pick.
///
/// One highlight box marks the current value: at rest it sits on the picked
/// option. When you drag, it lifts off under your finger and follows it with
/// rubber-banded resistance at the ends, so the old row is not marked while a
/// drag is in flight; on release it springs to the nearest enabled option and
/// comes to rest there. Tapping an option picks it outright. The look and feel
/// come from a [SmoothHighlight].
///
/// It is a controlled widget: pass the current [value] and an [onChanged]. When
/// a drag or tap lands on a new option, [onChanged] runs with its value.
class SmoothPicker<T> extends StatefulWidget {
  /// Makes a picker.
  const SmoothPicker({
    required this.items,
    required this.value,
    required this.onChanged,
    this.highlight = const SmoothHighlight(),
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    super.key,
  });

  /// The options to show.
  final List<SmoothPickerItem<T>> items;

  /// The value picked now, or null for no pick.
  final T? value;

  /// Called when the highlight settles on a new value. Null turns picking off.
  final ValueChanged<T?>? onChanged;

  /// The look and physics of the moving highlight.
  final SmoothHighlight highlight;

  /// The space around each option's content.
  final EdgeInsets rowPadding;

  @override
  State<SmoothPicker<T>> createState() => _SmoothPickerState<T>();
}

class _SmoothPickerState<T> extends State<SmoothPicker<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pos;
  final SmoothHighlightGeometry _geometry = SmoothHighlightGeometry();
  SmoothPickerPhase _phase = SmoothPickerPhase.idle;
  bool _reduce = false;

  // The option the in-flight settle spring is aimed at, or null when nothing is
  // settling. It lets an outside value change re-aim the spring at the new pick
  // instead of letting it finish to a stale target and snap.
  int? _settleTarget;

  // Parks [pos] off-screen between interactions. While a finger or spring
  // drives it the box follows [pos]; parked, the painter falls back to the
  // selected row, so the current pick stays marked and only ever one box shows.
  static const double _offscreen = double.infinity;

  @override
  void initState() {
    super.initState();
    _pos = AnimationController.unbounded(vsync: this)..value = _offscreen;
  }

  @override
  void didUpdateWidget(SmoothPicker<T> old) {
    super.didUpdateWidget(old);
    // A value changed from outside at rest is picked up by the render fallback
    // on its own. Mid-settle it would let the spring finish to the old target
    // and snap, so re-aim the spring at the new selection, keeping its live
    // velocity so the redirect stays smooth. The [_settleTarget] guard skips
    // the case where the change is this widget's own commit echoing back.
    if (_phase != SmoothPickerPhase.settling) return;
    if (_settleTarget == null) return;
    if (_selectedIndex < 0 || _selectedIndex == _settleTarget) return;
    if (!_pos.value.isFinite) return;
    _moveTo(_selectedIndex, _pos.velocity);
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  int get _selectedIndex =>
      widget.items.indexWhere((e) => e.value == widget.value);

  void _trace(String message) {
    if (SmoothTrace.enabled && SmoothTrace.pick) {
      SmoothTrace.emit('pick', 'picker $message');
    }
  }

  int _nearestEnabled(int index) {
    final n = widget.items.length;
    if (n == 0) return 0;
    final start = index < 0 ? 0 : (index >= n ? n - 1 : index);
    if (widget.items[start].enabled) return start;
    for (var d = 1; d < n; d++) {
      final lo = start - d;
      final hi = start + d;
      if (lo >= 0 && widget.items[lo].enabled) return lo;
      if (hi < n && widget.items[hi].enabled) return hi;
    }
    return start;
  }

  double _rubber(double past, double band) => band * past / (band + past);

  double _rubberClamp(double y) {
    final lo = _geometry.firstCenter;
    final hi = _geometry.lastCenter;
    final band = widget.highlight.rubberBand;
    if (y < lo) return lo - _rubber(lo - y, band);
    if (y > hi) return hi + _rubber(y - hi, band);
    return y;
  }

  void _onDragStart(DragStartDetails details) {
    if (_geometry.count == 0) return;
    _phase = SmoothPickerPhase.dragging;
    // The box is born under the finger — no grab offset, no jump to a resting
    // spot — so grabbing from anywhere (including the very bottom) picks the
    // highlight up exactly where the touch lands instead of trailing behind it.
    final clamped = _rubberClamp(details.localPosition.dy);
    _pos
      ..stop()
      ..value = clamped;
    _trace('dragStart y=${_f(details.localPosition.dy)} pos=${_f(clamped)}');
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_phase != SmoothPickerPhase.dragging) return;
    final raw = details.localPosition.dy;
    final clamped = _rubberClamp(raw);
    // A coalesced or duplicate pointer sample can report the same spot twice.
    // Re-setting the controller to that value still fires a repaint whose zero
    // delta dents the squash, so the box would pulse; skip the no-op.
    if (clamped == _pos.value) return;
    _pos.value = clamped;
    _trace(
      'dragMove y=${_f(raw)} pos=${_f(clamped)} over=${_f(raw - clamped)}',
    );
  }

  void _onDragEnd(DragEndDetails details) {
    if (_phase != SmoothPickerPhase.dragging) return;
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dy;
    final predicted = _pos.value + velocity * 0.15;
    final target = _nearestEnabled(
      _geometry.nearestIndex(_geometry.clampY(predicted)),
    );
    _trace(
      'dragEnd v=${_f(velocity)} predicted=${_f(predicted)} target=$target',
    );
    _pick(target, velocity);
  }

  void _onDragCancel() {
    if (_phase != SmoothPickerPhase.dragging) return;
    _trace('dragCancel pos=${_f(_pos.value)}');
    _pick(_nearestEnabled(_geometry.nearestIndex(_pos.value)), 0);
  }

  void _onTapUp(TapUpDetails details) {
    if (_geometry.count == 0) return;
    final target = _nearestEnabled(
      _geometry.nearestIndex(_geometry.clampY(details.localPosition.dy)),
    );
    _trace('tap y=${_f(details.localPosition.dy)} target=$target');
    // A tap is an instant pick: it commits at once, and the resting box then
    // follows the new value through the render's fallback.
    _commit(target);
  }

  // Commits the pick on release, then glides. The value change is never gated
  // on the spring settling, so there is no felt lag between letting go and the
  // selection landing; the spring that follows is purely cosmetic, and when it
  // settles the box comes to rest on the picked option.
  void _pick(int index, double velocity) {
    _commit(index);
    _moveTo(index, velocity);
  }

  void _moveTo(int index, double velocity) {
    final n = widget.items.length;
    if (n == 0) return;
    final target = _nearestEnabled(index);
    _phase = SmoothPickerPhase.settling;
    _settleTarget = target;
    final to = _geometry.centerOf(target);
    _trace(
      'settle target=$target to=${_f(to)} from=${_f(_pos.value)} '
      'v=${_f(velocity)} reduce=$_reduce',
    );
    // A spring with non-positive mass, stiffness, or damping never reaches its
    // target: the box would stick mid-travel and the phase pin on settling
    // forever. Treat it like reduced motion and land at once.
    if (_reduce || !widget.highlight.springSettles) {
      _pos.stop();
      _settleIdle(target);
      return;
    }
    final simulation = SpringSimulation(
      widget.highlight.spring,
      _pos.value,
      to,
      velocity,
      tolerance: _settleTolerance,
    );
    unawaited(
      _pos
          .animateWith(simulation)
          .then((_) => _settleIdle(target), onError: (Object _) {}),
    );
  }

  void _settleIdle(int index) {
    if (!mounted) return;
    _phase = SmoothPickerPhase.idle;
    _settleTarget = null;
    // Hand the box back to the render's rest fallback: parking [pos] off-screen
    // lets the painter draw it on the now-selected row, so the pick stays
    // marked exactly where the glide landed.
    _pos.value = _offscreen;
    _trace('idle at=$index pos=rest');
  }

  void _commit(int index) {
    if (!widget.highlight.commitOnRelease) return;
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (!item.enabled) return;
    if (item.value == widget.value) return;
    _trace('commit value=${item.value}');
    widget.onChanged?.call(item.value);
  }

  // A coarse settle tolerance so the spring reports done the instant it is
  // visually home (sub-pixel, near-still), instead of chasing a 1e-3 tail for
  // dozens of frames that repaint an unmoving box.
  static const Tolerance _settleTolerance = Tolerance(
    distance: 0.4,
    velocity: 12,
  );

  static String _f(double v) => v.toStringAsFixed(1);

  Widget _row(int i) {
    final item = widget.items[i];
    final content = Padding(
      padding: widget.rowPadding,
      child: Row(
        children: <Widget>[
          if (item.leading != null) ...<Widget>[
            item.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(child: item.child),
          if (item.trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            item.trailing!,
          ],
        ],
      ),
    );
    final visible = item.enabled
        ? content
        : Opacity(opacity: 0.4, child: content);
    return Semantics(
      button: item.enabled,
      selected: i == _selectedIndex,
      enabled: item.enabled,
      label: item.semanticLabel,
      onTap: item.enabled ? () => _commit(i) : null,
      child: visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.disableAnimationsOf(context);
    final n = widget.items.length;
    if (n == 0) return const SizedBox.shrink();
    final draggable = widget.highlight.draggable;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onVerticalDragStart: draggable ? _onDragStart : null,
      onVerticalDragUpdate: draggable ? _onDragUpdate : null,
      onVerticalDragEnd: draggable ? _onDragEnd : null,
      onVerticalDragCancel: draggable ? _onDragCancel : null,
      child: SmoothHighlightList(
        pos: _pos,
        highlight: widget.highlight,
        geometry: _geometry,
        reduce: _reduce,
        selectedIndex: _selectedIndex,
        label: 'picker',
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        children: <Widget>[for (var i = 0; i < n; i++) _row(i)],
      ),
    );
  }
}
