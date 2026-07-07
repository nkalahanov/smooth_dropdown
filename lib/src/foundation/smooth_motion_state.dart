import 'package:flutter/animation.dart';

/// The named states of a smooth tile.
///
/// The tile is always in one of these four states. The motion code reads the
/// state instead of many true or false flags.
enum SmoothMotionState {
  /// The tile is closed and still.
  collapsed,

  /// The tile is opening right now.
  expanding,

  /// The tile is open and still.
  expanded,

  /// The tile is closing right now.
  collapsing;

  /// Reads the state from an [AnimationStatus] of the open animation.
  static SmoothMotionState fromStatus(AnimationStatus status) {
    return switch (status) {
      AnimationStatus.forward => SmoothMotionState.expanding,
      AnimationStatus.reverse => SmoothMotionState.collapsing,
      AnimationStatus.completed => SmoothMotionState.expanded,
      AnimationStatus.dismissed => SmoothMotionState.collapsed,
    };
  }

  /// True when the tile is opening or closing.
  bool get isMoving =>
      this == SmoothMotionState.expanding ||
      this == SmoothMotionState.collapsing;

  /// True when the tile is open or opening.
  bool get isOpenOrOpening =>
      this == SmoothMotionState.expanded || this == SmoothMotionState.expanding;
}
