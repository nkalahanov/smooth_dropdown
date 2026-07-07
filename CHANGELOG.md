# Changelog

## 1.0.0

First stable release.

- `SmoothExpansionTile` shows any widget with a smooth open and close move.
  It also has a `SmoothExpansionTile.text` maker for a simple title and text.
- `SmoothSelect` lets a user open a list and tap one option to pick it. When the
  list fits without scrolling, the open list also carries the draggable
  `SmoothHighlight`.
- `SmoothPicker` is a draggable, spring-inertial selection list styled with
  `SmoothHighlight`. The velocity squash on the box is smoothed, teleport-guarded,
  and eased into its ceiling through a soft knee, so a brisk drag and a hard fling
  read differently instead of both pinning to `SmoothHighlight.maxStretch`, and
  its sides never snap; the overscroll pull is held inside
  `SmoothHighlight.rubberBand`.
- One highlight, and it is the single selection mark. At rest it sits on the
  picked option. The moment you drag, it lifts off under your finger and follows
  it exactly — no trailing offset, whether you grab from the top or the bottom —
  so the old row is never marked at the same time. On release it springs to the
  nearest option and comes to rest there, relaxing to a clean full-size box. It
  carries its own tick via `SmoothHighlight.checkColor`. A drag release or a tap
  commits the pick at once, with no wait for the spring to settle. Tapping a
  different option in an open list glides the highlight to it on the same spring
  — a soft accelerate, a small organic overshoot, and a clean settle — instead
  of jumping, so a tap and a drag land the box the same way.
- The highlight never hangs and never snaps. A value changed from outside while
  the box is still gliding re-aims the in-flight spring at the new pick, keeping
  its velocity, so it bends toward the new option instead of finishing to the
  old one and jumping. A spring that could never come to rest (a non-positive
  mass, stiffness, or damping) falls back to an instant move rather than driving
  a spring that would leave the box stuck mid-travel; `SmoothHighlight` exposes
  this as `springSettles`.
- `SmoothExpansionController` opens and closes a tile from your own code.
- Full theming with `SmoothStyle`, `SmoothPalette`, and `SmoothMotionSpec`.
- `SmoothTheme` shares one style with many widgets.
- All motion runs on the render layer. There is no `setState` and no
  `AnimatedBuilder` for the motion.
- The widgets respect the "reduce motion" setting.
- `SmoothSelect` is fully keyboard and switch operable, following the WCAG
  combobox pattern. It is one focus stop: Enter or Space opens the list and
  commits the highlighted option, the arrows and Home/End walk the options —
  driving the very same spring-glide highlight, so a keyboard walk looks like a
  drag — and Escape closes it. Focus stays on the field the whole time and never
  jumps into the list, so tab order stays sane; a disabled field drops out of
  the focus order. A focus ring shows only under keyboard focus, and every key
  path is dormant under touch, so touch behaviour is unchanged.
- Right-to-left is honoured throughout: the rising reveal text lays out in the
  ambient `Directionality`, and the traveling selection tick rides the trailing
  edge of the highlight — the left of the box in right-to-left.
- `SmoothSelectItem` gains a `trailing` slot for any widget (a badge, trailing
  text, a swatch), matching `SmoothPickerItem`.
