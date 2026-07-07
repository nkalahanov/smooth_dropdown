import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/rendering/smooth_highlight_list.dart';
import 'package:smooth_dropdown/src/rendering/smooth_indicators.dart';
import 'package:smooth_dropdown/src/theme/smooth_highlight.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';
import 'package:smooth_dropdown/src/theme/smooth_theme.dart';
import 'package:smooth_dropdown/src/widgets/smooth_picker.dart'
    show SmoothPickerPhase;
import 'package:smooth_dropdown/src/widgets/smooth_shell.dart';

const TextStyle _fallbackLabelStyle = TextStyle(
  color: Color(0xF2FFFFFF),
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

// Keyboard intents for the field. Enter/Space opens a closed field or commits
// the active option in an open one; the arrows and Home/End walk the keyboard
// cursor through the options, driving the same spring-glide highlight; Escape
// (Flutter's own `DismissIntent`) closes an open field.
class _OpenOrSelectIntent extends Intent {
  const _OpenOrSelectIntent();
}

class _MoveHighlightIntent extends Intent {
  const _MoveHighlightIntent(this.step);

  /// +1 moves the cursor to the next option, -1 to the previous.
  final int step;
}

class _JumpHighlightIntent extends Intent {
  const _JumpHighlightIntent({required this.toEnd});

  /// True jumps to the last enabled option, false to the first.
  final bool toEnd;
}

// Escape only does anything when the field is open, so when it is closed the
// action reports disabled and the key bubbles to a parent (a dialog, say) that
// may want it. This keeps the field a good citizen inside larger widgets.
class _SelectDismissAction<T> extends Action<DismissIntent> {
  _SelectDismissAction(this._state);

  final _SmoothSelectState<T> _state;

  @override
  bool isEnabled(DismissIntent intent) =>
      _state.mounted && _state._controller.isExpanded;

  @override
  Object? invoke(DismissIntent intent) {
    _state._closeFromKeyboard();
    return null;
  }
}

/// Builds the header view of the picked item.
typedef SmoothSelectedBuilder<T> =
    Widget Function(BuildContext context, SmoothSelectItem<T> item);

/// One option in a [SmoothSelect].
///
/// It holds a [value] and a [child] to show. Two items should not share the
/// same [value].
@immutable
class SmoothSelectItem<T> {
  /// Makes an option.
  const SmoothSelectItem({
    required this.value,
    required this.child,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The value this option stands for. It is sent to `onChanged` on a tap.
  final T value;

  /// The widget shown for this option.
  final Widget child;

  /// A widget at the start of the option row, such as an icon.
  final Widget? leading;

  /// A widget at the end of the option row.
  ///
  /// It takes any widget, not just an icon — a badge, a bit of trailing text, a
  /// swatch — so a row can carry its own mark next to the traveling highlight.
  final Widget? trailing;

  /// Whether this option can be tapped.
  final bool enabled;

  /// A label read out by a screen reader, or null to use the child.
  final String? semanticLabel;
}

/// A field that opens a list of options for the user to pick one.
///
/// It works like Flutter's `DropdownButton`, but it opens **in place** with the
/// smooth move. It does not float over other widgets. It pushes the widgets
/// below it, so put it inside a scroll view when space is tight.
///
/// It is a controlled field. You pass the current [value] and an [onChanged].
/// When the user taps an option, [onChanged] runs with the new value. You then
/// store the value and pass it back. Set [onChanged] to null to turn the field
/// off.
class SmoothSelect<T> extends StatefulWidget {
  /// Makes a select field.
  const SmoothSelect({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.disabledHint,
    this.selectedItemBuilder,
    this.leading,
    this.trailing,
    this.style,
    this.controller,
    this.menuMaxHeight,
    this.closeOnSelect = true,
    this.highlight,
    this.entrance,
    this.phaseSeed,
    super.key,
  });

  /// The list of options to show.
  final List<SmoothSelectItem<T>> items;

  /// Called with the new value when the user picks an option. Null turns the
  /// field off.
  final ValueChanged<T?>? onChanged;

  /// The value picked now, or null for no pick.
  final T? value;

  /// Shown in the header when there is no pick.
  final Widget? hint;

  /// Shown in the header when the field is off. Falls back to [hint].
  final Widget? disabledHint;

  /// Builds the header view of the picked item, or null to show its child.
  final SmoothSelectedBuilder<T>? selectedItemBuilder;

  /// A widget at the start of the header, such as an icon.
  final Widget? leading;

  /// Builds the trailing mark, or null to use the default arrow.
  final SmoothIndicatorBuilder? trailing;

  /// The look of this field, laid over the theme and the default.
  final SmoothStyle? style;

  /// An outside controller to open and close the field from your code.
  final SmoothExpansionController? controller;

  /// The biggest height for the open list. A taller list scrolls.
  final double? menuMaxHeight;

  /// Whether the field closes after a pick.
  final bool closeOnSelect;

  /// The look and physics of the highlight box in the open list.
  ///
  /// One box marks the current value: at rest it sits on the picked option.
  /// When the list is short enough to fit (no [menuMaxHeight]) the box can also
  /// be dragged and flung — it lifts off under the finger, follows it, and on
  /// release springs to the nearest option and comes to rest there. Tapping an
  /// option glides the box to it. Null uses a themed default built from the
  /// field's own colors.
  final SmoothHighlight? highlight;

  /// An entrance value that fades and slides the whole field in, or null.
  final Animation<double>? entrance;

  /// A seed that shifts the wave so stacked fields do not ripple as one.
  final Object? phaseSeed;

  @override
  State<SmoothSelect<T>> createState() => _SmoothSelectState<T>();
}

class _SmoothSelectState<T> extends State<SmoothSelect<T>>
    with SingleTickerProviderStateMixin {
  SmoothExpansionController? _fallback;

  // The pixel-space center Y of the gliding selection highlight, plus the
  // layout the render list fills so this state's physics read the same option
  // centers the painter draws with.
  late final AnimationController _pos;
  final SmoothHighlightGeometry _geometry = SmoothHighlightGeometry();
  SmoothPickerPhase _phase = SmoothPickerPhase.idle;
  SmoothHighlight _activeHighlight = const SmoothHighlight();
  bool _reduce = false;

  // The option the in-flight settle spring is aimed at, or null when nothing is
  // settling. It lets an outside value change re-aim the spring at the new pick
  // instead of letting it finish to a stale target and snap.
  int? _settleTarget;

  // The keyboard cursor: the option the arrows have walked to while the list is
  // open, or null when the keyboard is not driving. When set, the resting box
  // sits on it instead of the committed selection, so arrow navigation previews
  // a choice before Enter commits it. It is always null during touch, so touch
  // and drag behave exactly as before.
  int? _activeIndex;

  // Whether to paint the focus ring. Driven by the focus highlight mode, so it
  // shows for keyboard and switch users and stays hidden on plain touch/mouse.
  bool _showFocusRing = false;

  final FocusNode _focusNode = FocusNode(debugLabel: 'SmoothSelect');

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): _OpenOrSelectIntent(),
        SingleActivator(LogicalKeyboardKey.space): _OpenOrSelectIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveHighlightIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveHighlightIntent(-1),
        SingleActivator(LogicalKeyboardKey.home): _JumpHighlightIntent(
          toEnd: false,
        ),
        SingleActivator(LogicalKeyboardKey.end): _JumpHighlightIntent(
          toEnd: true,
        ),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _OpenOrSelectIntent: CallbackAction<_OpenOrSelectIntent>(
      onInvoke: (_) => _activate(),
    ),
    _MoveHighlightIntent: CallbackAction<_MoveHighlightIntent>(
      onInvoke: (intent) {
        _moveActive(intent.step);
        return null;
      },
    ),
    _JumpHighlightIntent: CallbackAction<_JumpHighlightIntent>(
      onInvoke: (intent) {
        _jumpActive(toEnd: intent.toEnd);
        return null;
      },
    ),
    DismissIntent: _SelectDismissAction<T>(this),
  };

  SmoothExpansionController get _controller => widget.controller ?? _fallback!;

  bool get _enabled => widget.onChanged != null;

  int get _selectedIndex =>
      widget.items.indexWhere((e) => e.value == widget.value);

  bool _optionEnabled(int i) =>
      _enabled && i >= 0 && i < widget.items.length && widget.items[i].enabled;

  // Parks [pos] off-screen between interactions. While a finger or spring
  // drives it the box follows [pos]; parked, the painter falls back to the
  // selected row, so the final pick stays marked and only ever one box shows.
  static const double _offscreen = double.infinity;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _fallback = SmoothExpansionController();
    _pos = AnimationController.unbounded(vsync: this)..value = _offscreen;
  }

  @override
  void didUpdateWidget(SmoothSelect<T> old) {
    super.didUpdateWidget(old);
    if (!identical(widget.controller, old.controller)) {
      if (widget.controller != null && _fallback != null) {
        _fallback!.dispose();
        _fallback = null;
      } else if (widget.controller == null && _fallback == null) {
        _fallback = SmoothExpansionController();
      }
    }
    // A field that turns off while open cannot be closed by a tap. Close it now
    // so it can never sit stuck open in a state the user cannot leave.
    if (!_enabled && _controller.isExpanded) _controller.collapse();
    // A value changed from outside at rest needs no work: [pos] is parked, so
    // the render's fallback re-reads the selected row and the resting box
    // follows the new value on its own. Mid-settle it does need work, or the
    // spring would finish to the old target and snap — so re-aim it.
    _retargetSettleToSelection();
  }

  // Re-aims an in-flight settle at the current selection when the value changed
  // from outside while the box was still travelling. Keeping the live velocity
  // makes the spring bend toward the new pick smoothly instead of gliding to
  // the stale target and jumping. The [_settleTarget] guard skips the common
  // case where the change is this widget's own commit echoing back (the spring
  // is already headed there), so it never fights its own glide.
  void _retargetSettleToSelection() {
    if (_phase != SmoothPickerPhase.settling) return;
    if (_settleTarget == null) return;
    if (_selectedIndex < 0 || _selectedIndex == _settleTarget) return;
    if (!_pos.value.isFinite) return;
    _moveTo(_selectedIndex, _pos.velocity);
  }

  @override
  void dispose() {
    _pos.dispose();
    _focusNode.dispose();
    _fallback?.dispose();
    super.dispose();
  }

  SmoothSelectItem<T>? _selectedItem() {
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  void _pick(T value) {
    widget.onChanged?.call(value);
    if (widget.closeOnSelect) _controller.collapse();
  }

  void _trace(String message) {
    if (SmoothTrace.enabled && SmoothTrace.pick) {
      SmoothTrace.emit('pick', 'select $message');
    }
  }

  static String _f(double v) => v.toStringAsFixed(1);

  int _nearestEnabled(int index) {
    final n = widget.items.length;
    if (n == 0) return 0;
    final start = index < 0 ? 0 : (index >= n ? n - 1 : index);
    if (_optionEnabled(start)) return start;
    for (var d = 1; d < n; d++) {
      final lo = start - d;
      final hi = start + d;
      if (lo >= 0 && _optionEnabled(lo)) return lo;
      if (hi < n && _optionEnabled(hi)) return hi;
    }
    return start;
  }

  double _rubber(double past, double band) => band * past / (band + past);

  double _rubberClamp(double y) {
    final lo = _geometry.firstCenter;
    final hi = _geometry.lastCenter;
    final band = _activeHighlight.rubberBand;
    if (y < lo) return lo - _rubber(lo - y, band);
    if (y > hi) return hi + _rubber(y - hi, band);
    return y;
  }

  void _onDragStart(DragStartDetails details) {
    _clearActive();
    if (_geometry.count == 0) return;
    _phase = SmoothPickerPhase.dragging;
    // Born under the finger, with no grab offset — grabbing from anywhere picks
    // the box up exactly where the touch lands instead of trailing behind it.
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
    _pickAt(target, velocity);
  }

  void _onDragCancel() {
    if (_phase != SmoothPickerPhase.dragging) return;
    _trace('dragCancel pos=${_f(_pos.value)}');
    _pickAt(_nearestEnabled(_geometry.nearestIndex(_pos.value)), 0);
  }

  // Commits on release, then glides. The value change is never gated on the
  // spring, so letting go picks at once; the glide that follows is cosmetic.
  void _pickAt(int index, double velocity) {
    _commit(index);
    _moveTo(index, velocity);
  }

  // A tap picks an option outright, like a drag release with no throw. Rather
  // than let the value change snap the resting box to the new row, the box is
  // seeded at its current resting centre and sprung to the tapped row under the
  // same physics as a fling — one spring, one controller — so the highlight
  // glides across the list instead of teleporting. The velocity-squash channel
  // rides the spring's own acceleration for free: the box stretches through the
  // move and relaxes as it lands.
  void _tapAt(int index) {
    _clearActive();
    final target = _nearestEnabled(index);
    if (!_optionEnabled(target)) return;
    // Tapping the current pick has nowhere to glide.
    if (target == _selectedIndex) return;
    // A tap commits like a drag settle, so it honours commitOnRelease; and
    // under reduced motion there is no glide. Either way commit at once and let
    // the render's fallback place the box on the tapped row.
    if (!_activeHighlight.commitOnRelease || _reduce) {
      _commit(target);
      return;
    }
    // Seed a finite origin so the spring starts from the box's real position
    // and the render follows [pos] across the commit instead of the fallback
    // snapping to the new row. A glide already in flight keeps its live
    // position; at rest the origin is the current selected row's centre. With
    // no on-screen origin (nothing selected yet, or geometry unmeasured) there
    // is nothing to glide from, so commit and let the fallback pop the box on.
    if (!_pos.value.isFinite) {
      if (_geometry.count == 0 || _selectedIndex < 0) {
        _commit(target);
        return;
      }
      _pos.value = _geometry.centerOf(_selectedIndex);
    }
    _trace('tap target=$target from=${_f(_pos.value)}');
    _pickAt(target, 0);
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
    if (_reduce || !_activeHighlight.springSettles) {
      _pos.stop();
      _settleIdle(target);
      return;
    }
    final simulation = SpringSimulation(
      _activeHighlight.spring,
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
    // marked in the open list exactly where the glide landed.
    _pos.value = _offscreen;
    _trace('idle at=$index pos=rest');
  }

  void _commit(int index) {
    if (!_activeHighlight.commitOnRelease) return;
    if (!_optionEnabled(index)) return;
    final item = widget.items[index];
    if (item.value == widget.value) return;
    _trace('commit value=${item.value}');
    _pick(item.value);
  }

  // A coarse settle tolerance so the spring reports done the instant it is
  // visually home instead of chasing a 1e-3 tail for dozens of dead frames.
  static const Tolerance _settleTolerance = Tolerance(
    distance: 0.4,
    velocity: 12,
  );

  // The option the resting box sits on: the keyboard cursor while the arrows
  // are driving, otherwise the committed selection.
  int get _restIndex => _activeIndex ?? _selectedIndex;

  // Drops the keyboard cursor. A finger or a tap taking over relinquishes it,
  // so the resting box goes back to marking the committed selection.
  void _clearActive() {
    if (_activeIndex != null) setState(() => _activeIndex = null);
  }

  // Enter/Space. A closed field opens onto the current pick; an open one commits
  // the cursor and closes.
  Object? _activate() {
    if (!_enabled) return null;
    if (!_controller.isExpanded) {
      _openWithActive();
    } else {
      _selectActive();
    }
    return null;
  }

  // Opens with the cursor already on the current pick (or the first enabled
  // option), so the box appears where the eye expects and the arrows step from
  // there. WCAG's combobox pattern: opening also lands on the active option.
  void _openWithActive() {
    if (!_enabled) return;
    final start = _selectedIndex >= 0
        ? _nearestEnabled(_selectedIndex)
        : _nearestEnabled(0);
    setState(() => _activeIndex = _optionEnabled(start) ? start : null);
    _controller.expand();
    _trace('key open active=$_activeIndex');
  }

  // Commits the cursor's option like a tap, then closes if the field closes on
  // select. Enter on the option already picked just closes. The box is already
  // resting on the cursor, so no glide is needed here.
  void _selectActive() {
    final target = _activeIndex;
    if (target != null &&
        _optionEnabled(target) &&
        widget.items[target].value != widget.value) {
      _trace('key select $target');
      _pick(widget.items[target].value);
    } else if (widget.closeOnSelect) {
      _controller.collapse();
    }
    setState(() => _activeIndex = null);
  }

  // Escape. Closes an open field and keeps focus on the trigger, so the user
  // can reopen or tab on without hunting for focus.
  void _closeFromKeyboard() {
    _controller.collapse();
    setState(() => _activeIndex = null);
    _trace('key dismiss');
  }

  // Arrow up/down. On a closed field the arrows open it; on an open one they
  // walk the cursor to the next enabled option and glide the box to it.
  void _moveActive(int step) {
    if (!_enabled) return;
    if (!_controller.isExpanded) {
      _openWithActive();
      return;
    }
    final int next;
    if (_activeIndex == null) {
      next = _selectedIndex >= 0
          ? _nearestEnabled(_selectedIndex)
          : _nearestEnabled(step > 0 ? 0 : widget.items.length - 1);
    } else {
      next = _stepEnabled(_activeIndex!, step);
    }
    if (!_optionEnabled(next) || next == _activeIndex) return;
    _glideActiveTo(next);
  }

  // Home/End. Jumps the cursor to the first or last enabled option and glides.
  void _jumpActive({required bool toEnd}) {
    if (!_enabled) return;
    if (!_controller.isExpanded) {
      _openWithActive();
      return;
    }
    final target = toEnd
        ? _nearestEnabled(widget.items.length - 1)
        : _nearestEnabled(0);
    if (!_optionEnabled(target) || target == _activeIndex) return;
    _glideActiveTo(target);
  }

  // The next enabled option from [from] in direction [step], or [from] when
  // there is none that way — so the cursor stops at the ends rather than wraps.
  int _stepEnabled(int from, int step) {
    final n = widget.items.length;
    var i = from + step;
    while (i >= 0 && i < n) {
      if (_optionEnabled(i)) return i;
      i += step;
    }
    return from;
  }

  // Moves the keyboard cursor to [next] and springs the box there under the
  // same physics as a tap-glide. The origin is seeded finite first (from the
  // box's resting centre) so the spring starts on-screen instead of from the
  // parked sentinel; a glide already in flight keeps its live position and
  // velocity, so rapid arrow presses chain into one fluid sweep, not restarts.
  void _glideActiveTo(int next) {
    if (_geometry.count == 0) {
      setState(() => _activeIndex = next);
      return;
    }
    if (!_pos.value.isFinite) {
      final origin =
          _activeIndex ?? (_selectedIndex >= 0 ? _selectedIndex : next);
      _pos.value = _geometry.centerOf(origin);
    }
    setState(() => _activeIndex = next);
    _moveTo(next, _pos.value.isFinite ? _pos.velocity : 0);
  }

  void _onShowFocusHighlight(bool value) {
    if (value != _showFocusRing) setState(() => _showFocusRing = value);
  }

  // Losing focus (a Tab away, say) closes an open field and drops the cursor
  // and ring, so the field never sits open and unreachable off to the side.
  void _onFocusChange(bool hasFocus) {
    if (hasFocus) return;
    if (_controller.isExpanded) _controller.collapse();
    setState(() {
      _activeIndex = null;
      _showFocusRing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      () {
        if (widget.value == null) return true;
        final matches = widget.items
            .where((i) => i.value == widget.value)
            .length;
        return matches <= 1;
      }(),
      'SmoothSelect has more than one item with the value ${widget.value}. '
      'Item values must be unique.',
    );

    _reduce = MediaQuery.disableAnimationsOf(context);
    final resolved = SmoothTheme.resolve(context, widget.style);
    final selected = _selectedItem();
    // The one selection highlight is the gliding box, and it carries the tick.
    // If the caller did not choose a tick color, give it the theme accent so a
    // plain `SmoothHighlight()` still marks its pick and the mark travels.
    final base =
        widget.highlight ?? SmoothHighlight(color: resolved.highlightColor);
    _activeHighlight = base.checkColor == null
        ? base.copyWith(checkColor: resolved.palette.accent)
        : base;

    Widget label;
    if (selected != null) {
      label =
          widget.selectedItemBuilder?.call(context, selected) ?? selected.child;
    } else {
      label =
          (_enabled ? widget.hint : widget.disabledHint ?? widget.hint) ??
          const SizedBox.shrink();
    }

    final options = <Widget>[
      for (var i = 0; i < widget.items.length; i++)
        RepaintBoundary(
          child: _SmoothOption(
            resolved: resolved,
            selected: widget.items[i].value == widget.value,
            enabled: _enabled && widget.items[i].enabled,
            semanticLabel: widget.items[i].semanticLabel,
            onTap: () => _tapAt(i),
            leading: widget.items[i].leading,
            trailing: widget.items[i].trailing,
            child: widget.items[i].child,
          ),
        ),
    ];

    final directionality = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final list = SmoothHighlightList(
      pos: _pos,
      highlight: _activeHighlight,
      geometry: _geometry,
      reduce: _reduce,
      selectedIndex: _restIndex,
      label: 'select',
      textDirection: directionality,
      children: options,
    );

    final scrollable = widget.menuMaxHeight != null;
    // Drag is only wired when the list is short enough to fit: inside a scroll
    // view the vertical drag belongs to the scroll, so there the highlight only
    // springs to the picked value instead of following a finger.
    final draggable = _enabled && !scrollable && _activeHighlight.draggable;

    Widget body = list;
    if (draggable) {
      body = GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onVerticalDragCancel: _onDragCancel,
        child: list,
      );
    }
    if (scrollable) body = SingleChildScrollView(child: list);

    final shell = SmoothShell(
      controller: _controller,
      initiallyExpanded: false,
      onExpansionChanged: null,
      style: widget.style,
      entrance: widget.entrance,
      phaseSeed: widget.phaseSeed,
      menuMaxHeight: widget.menuMaxHeight,
      scrollableBody: scrollable,
      headerBuilder: (ctx, expand, control) => _SmoothSelectHeader(
        resolved: resolved,
        expand: expand,
        controller: control,
        enabled: _enabled,
        label: label,
        onToggle: () => _toggleFromHeader(control),
        leading: widget.leading,
        trailing: widget.trailing,
      ),
      child: body,
    );

    // Keyboard and switch access. The field is one focusable stop (a combobox):
    // Enter/Space opens and commits, the arrows and Home/End walk the options,
    // driving the same spring-glide highlight, and Escape closes. Focus stays
    // on this trigger the whole time — it never jumps into the option list — so
    // tab order stays sane. Disabled fields drop out of the focus order wholly.
    // Every action is dormant until a key is pressed, so touch is untouched.
    final focusable = FocusableActionDetector(
      focusNode: _focusNode,
      enabled: _enabled,
      shortcuts: _shortcuts,
      actions: _actions,
      onShowFocusHighlight: _onShowFocusHighlight,
      onFocusChange: _onFocusChange,
      child: shell,
    );

    // The focus ring is painted over the field, not around it, so showing it
    // never nudges the layout. It only appears in the keyboard focus mode.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(resolved.radius),
        border: Border.all(
          color: _showFocusRing
              ? resolved.palette.accent
              : const Color(0x00000000),
          width: 2,
        ),
      ),
      child: focusable,
    );
  }

  // A header tap first pulls focus to the field so the keyboard works from
  // there on, then toggles. Closing this way also drops the keyboard cursor, so
  // a reopen starts fresh on the committed pick rather than a stale cursor.
  void _toggleFromHeader(SmoothExpansionController control) {
    _focusNode.requestFocus();
    if (control.isExpanded) {
      control.collapse();
      _clearActive();
    } else {
      control.expand();
    }
  }
}

class _SmoothSelectHeader extends StatelessWidget {
  const _SmoothSelectHeader({
    required this.resolved,
    required this.expand,
    required this.controller,
    required this.enabled,
    required this.label,
    required this.onToggle,
    this.leading,
    this.trailing,
  });

  final SmoothResolvedStyle resolved;
  final Animation<double> expand;
  final SmoothExpansionController controller;
  final bool enabled;
  final Widget label;
  final VoidCallback onToggle;
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

    final row = Row(
      children: <Widget>[
        if (lead != null) ...<Widget>[lead, const SizedBox(width: 12)],
        Expanded(
          child: DefaultTextStyle.merge(
            style: _fallbackLabelStyle.merge(resolved.titleTextStyle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: label,
          ),
        ),
        const SizedBox(width: 8),
        indicator,
      ],
    );

    Widget content = Padding(padding: resolved.headerPadding, child: row);
    if (!enabled) content = Opacity(opacity: 0.5, child: content);

    final tappable = enabled
        ? GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            child: content,
          )
        : content;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => MergeSemantics(
        child: Semantics(
          button: enabled,
          expanded: controller.isExpanded,
          onTap: enabled ? onToggle : null,
          child: child,
        ),
      ),
      child: tappable,
    );
  }
}

class _SmoothOption extends StatefulWidget {
  const _SmoothOption({
    required this.resolved,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.leading,
    this.trailing,
    this.semanticLabel,
  });

  final SmoothResolvedStyle resolved;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  State<_SmoothOption> createState() => _SmoothOptionState();
}

class _SmoothOptionState extends State<_SmoothOption>
    with TickerProviderStateMixin {
  late final AnimationController _hover;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    final motion = widget.resolved.motion;
    _hover = AnimationController(
      vsync: this,
      duration: _floor(motion.hoverDuration),
    );
    _press = AnimationController(
      vsync: this,
      duration: _floor(motion.pressDuration),
    );
  }

  static Duration _floor(Duration value) {
    const min = Duration(milliseconds: 1);
    return value < min ? min : value;
  }

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  void _setHover(bool on) {
    unawaited(on ? _hover.forward() : _hover.reverse());
  }

  void _setPress(bool on) {
    unawaited(on ? _press.forward() : _press.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.resolved.palette;
    final row = Row(
      children: <Widget>[
        if (widget.leading != null) ...<Widget>[
          IconTheme.merge(
            data: IconThemeData(color: palette.accent, size: 18),
            child: widget.leading!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Color(0xF2FFFFFF),
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: widget.child,
          ),
        ),
        if (widget.trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          IconTheme.merge(
            data: IconThemeData(color: palette.accent, size: 18),
            child: widget.trailing!,
          ),
        ],
      ],
    );

    // The one selection mark is the gliding highlight box painted behind these
    // rows; each row only carries its own transient hover and press feedback,
    // so a settled pick is never shown twice.
    final base = CustomPaint(
      painter: _OptionHighlightPainter(
        hover: _hover,
        press: _press,
        color: widget.resolved.highlightColor,
        radius: widget.resolved.radius * 0.5,
      ),
      child: Padding(padding: widget.resolved.optionPadding, child: row),
    );

    if (!widget.enabled) {
      return Semantics(
        container: true,
        enabled: false,
        label: widget.semanticLabel,
        child: Opacity(opacity: 0.4, child: base),
      );
    }

    final interactive = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Listener(
        onPointerDown: (_) => _setPress(true),
        onPointerUp: (_) => _setPress(false),
        onPointerCancel: (_) => _setPress(false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          child: base,
        ),
      ),
    );

    // MergeSemantics + the excluded gesture above fold the label, the button
    // role, and the selected flag into one clear node for screen readers.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.semanticLabel,
        onTap: widget.onTap,
        child: interactive,
      ),
    );
  }
}

class _OptionHighlightPainter extends CustomPainter {
  _OptionHighlightPainter({
    required this.hover,
    required this.press,
    required this.color,
    required this.radius,
  }) : super(repaint: Listenable.merge(<Listenable>[hover, press]));

  final Animation<double> hover;
  final Animation<double> press;
  final Color color;
  final double radius;

  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final total = ui.clampDouble(
      hover.value * 0.08 + press.value * 0.10,
      0,
      0.4,
    );
    if (SmoothTrace.enabled && SmoothTrace.paint) {
      final n = SmoothTrace.bump('option.paint');
      if (SmoothTrace.keep(n)) {
        SmoothTrace.emit(
          'paint',
          'option   #$n hover=${SmoothTrace.f(hover.value)} '
              'press=${SmoothTrace.f(press.value)} '
              'total=${SmoothTrace.f(total)}',
        );
      }
    }
    if (total <= 0.001) return;
    _paint.color = color.withValues(alpha: total);
    final rect = (Offset.zero & size).deflate(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_OptionHighlightPainter old) =>
      old.color != color || old.radius != radius;
}
